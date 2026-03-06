# Containerizing Polyglot Services

*Part 3 — Five services, four languages, five Dockerfiles*

---

*This is Part 3 of a series documenting the full build and deployment of GuitarShop — a microservices e-commerce application built with Go, Java, Node.js, and deployed on AWS EKS. [Start with the overview](https://github.com/Hepher-Ossounga/guitarShop-depolyment/blob/main/article/1-overview.md) if this is the first article in the series.*

---

Every service in GuitarShop runs in its own container. Five Dockerfiles — one per service — each handling a different language, a different build process, and a different runtime. Before looking at each one individually, it helps to understand the patterns they all share.

---

## Patterns Every Dockerfile Follows

**Multi-stage builds**

Every Dockerfile is split into two stages: a build stage and a runtime stage. The build stage compiles or packages the application using full build tools. The runtime stage runs the result using only what's needed at runtime. Build tools — compilers, Maven, npm — never make it into the final image. This keeps images small, reduces the attack surface, and speeds up pulls in Kubernetes.

**Layer caching for dependencies**

In every service, dependency files are copied and dependencies are installed *before* source code is copied. Docker caches each layer — if the dependency file hasn't changed, the install step is skipped entirely on the next build. Source code changes frequently; dependencies change rarely. This ordering means most rebuilds skip the slowest step.

```dockerfile
# Go — copy go.mod first, download deps, then copy source
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/

# Java — copy pom.xml first, download deps, then copy source
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src

# Node.js — copy package.json first, install deps, then copy source
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src
```

**Non-root user**

Docker containers run as root by default. All five services create a dedicated `guitarshop` user and switch to it before the process starts. The command differs by OS — Alpine uses `addgroup`/`adduser`, Ubuntu uses `groupadd`/`useradd` — but the result is the same.

```dockerfile
# Alpine (Go, Node.js)
RUN addgroup -S guitarshop && adduser -S guitarshop -G guitarshop

# Ubuntu (Java)
RUN groupadd -r guitarshop && useradd -r -g guitarshop guitarshop
```

After creating the user, ownership of the application files is transferred with `chown` before switching:

```dockerfile
RUN chown guitarshop:guitarshop app.jar
USER guitarshop
```

`chown` sets the file owner so the non-root user can actually read and execute the files. `USER guitarshop` switches the running process to that user. Both lines are always needed together.

**All services expose port 8080.** Internally, every service listens on the same port regardless of language. Port mapping to the host is handled in Docker Compose, not in the Dockerfile.

---

## Catalog: Go

Go is the only service that compiles to a static binary. The runtime stage needs nothing except the binary itself.

```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o catalog ./cmd/main.go

# Stage 2: Runtime
FROM alpine:3.19

WORKDIR /app
RUN addgroup -S guitarshop && adduser -S guitarshop -G guitarshop
COPY --from=builder /app/catalog .
RUN chown guitarshop:guitarshop catalog
USER guitarshop

EXPOSE 8080
ENTRYPOINT ["/app/catalog"]
```

The build flags on the compile step are specific to Go:

- `CGO_ENABLED=0` — disables C bindings, producing a fully static binary with no external library dependencies. Without this, the binary would depend on C libraries that may not exist in `alpine:3.19`.
- `GOOS=linux` — targets Linux regardless of what OS the build is running on.
- `-ldflags="-s -w"` — strips the symbol table (`-s`) and debug information (`-w`), reducing binary size with no runtime impact.

`apk add --no-cache git` installs git using Alpine's package manager. `--no-cache` skips writing the package index to disk, keeping the layer smaller. Git is required because `go mod download` may fetch some modules directly from source repositories.

The runtime stage is `alpine:3.19` — a minimal Linux image under 10MB. The final image contains only the compiled binary.

---

## Cart, Orders, UI: Java / Spring Boot

The three Java services are nearly identical. Maven builds the JAR in the build stage, the JRE runs it in the runtime stage.

```dockerfile
# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app
RUN groupadd -r guitarshop && useradd -r -g guitarshop guitarshop
COPY --from=builder /app/target/cart-service.jar app.jar
RUN chown guitarshop:guitarshop app.jar
USER guitarshop

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

`mvn dependency:go-offline` downloads all Maven dependencies before source is compiled. `-B` is batch mode — suppresses interactive prompts and progress output, which keeps CI logs clean.

`mvn clean package -DskipTests` compiles and packages the JAR. `-DskipTests` skips unit tests — tests belong in CI before the image is built, not inside Docker.

The build stage uses `maven:3.9-eclipse-temurin-17` which includes the full JDK and Maven. The runtime stage uses `eclipse-temurin:17-jre-jammy` — only the JRE. No compiler, no Maven in production.

The three services differ only in the JAR filename:
- Cart → `cart-service.jar`
- Orders → `orders-service-*.jar`
- UI → `ui-service-*.jar`

---

## Checkout: Node.js

Node.js doesn't compile — the source runs directly. The two stages exist purely for dependency isolation.

```dockerfile
# Stage 1: Dependencies
FROM node:18-alpine AS deps

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2: Runtime
FROM node:18-alpine

WORKDIR /app
RUN addgroup -S guitarshop && adduser -S guitarshop -G guitarshop
COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY package.json .
RUN chown -R guitarshop:guitarshop /app
USER guitarshop

EXPOSE 8080
CMD ["node", "src/index.js"]
```

`npm ci` is a clean install — deletes `node_modules` first and installs exactly what is in `package-lock.json` with no version resolution. More deterministic and faster than `npm install`. `--omit=dev` excludes dev dependencies — test frameworks, linters, type checkers — none of which belong in a production image.

Both stages use the same base image `node:18-alpine`. The separation exists to isolate the install layer for caching and to keep the final image free of anything npm-related beyond `node_modules`.

The Checkout service uses `CMD` instead of `ENTRYPOINT`. Both define what runs at startup, but `CMD` can be overridden by passing a different command to `docker run`, while `ENTRYPOINT` is fixed. Node.js convention favors `CMD` for flexibility during development.

---


