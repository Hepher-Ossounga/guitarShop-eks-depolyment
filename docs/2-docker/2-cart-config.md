# Cart Service — application.yml Reference

> **No commands to run in this doc.** It is reference reading only — it explains what
> the developer's config file does so you understand why the `-e` flags in doc 1 are
> named the way they are.

`src/main/resources/application.yml` is written by the developer and baked into the JAR
at build time. Connection values are left as placeholders; the real values are injected
at runtime via the `-e` flags you pass to `docker run`.

---

## I. Redis Connection

```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST:cart-redis}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}
```

| Env Var          | Default      | Purpose                          |
|------------------|--------------|----------------------------------|
| `REDIS_HOST`     | `cart-redis` | Which Redis instance to use      |
| `REDIS_PORT`     | `6379`       | Redis port                       |
| `REDIS_PASSWORD` | *(empty)*    | Redis auth (if required)         |

`${VAR:default}` means: use the env var if set, fall back to the default if not.
The defaults match Docker Compose service names so `docker compose up` works without
explicit env vars.

---

## II. Port

```yaml
server:
  port: 8080
```

This is why the Dockerfile has `EXPOSE 8080` and `docker run` uses `-p 8080:8080`.

---

## III. Health Endpoints

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
```

Without this block, `GET /cart/health` returns **404**. With it, Spring Boot Actuator
exposes `/actuator/health`, `/actuator/info`, and `/actuator/metrics` over HTTP.
The cart service maps `/cart/health` as a shortcut to the actuator health endpoint.
