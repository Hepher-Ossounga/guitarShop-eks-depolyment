# Running the Full Stack with Docker Compose

Docker Compose replaces all the individual `docker run` commands from the previous
sections with a single file that defines and runs all 10 containers together.

---

## I. Prerequisites

- EC2 instance running
- Docker installed
- Repository cloned

---

## II. What docker-compose.yml Manages

```
10 containers total:

  Infrastructure (5)                Microservices (5)
  ──────────────────                ─────────────────
  catalog-db   (MySQL)              catalog   (Go)
  checkout-db  (PostgreSQL)         cart      (Java/Spring Boot)
  orders-db    (PostgreSQL)         checkout  (Node.js)
  cart-redis   (Redis)              orders    (Java/Spring Boot)
  rabbitmq     (RabbitMQ)           ui        (Java/Spring Boot)
```

All 10 containers share one private network: `guitarshop-net`.
Only the UI is exposed to the outside world on port `8080`.

---

## III. Key Concepts in the File

### Network

```yaml
networks:
  guitarshop-net:
    driver: bridge
```

One shared network. Containers find each other by service name
(e.g. `catalog-db`, `cart-redis`) — no IP addresses needed.

---

### Volumes

```yaml
volumes:
  catalog-db-data:
  checkout-db-data:
  orders-db-data:
  redis-data:
  rabbitmq-data:
```

Persistent storage for all databases. Data survives `docker compose down`
and is restored on the next `docker compose up`.

> To wipe all data and start fresh: `docker compose down -v`

---

### Health Check Defaults

```yaml
x-healthcheck-defaults: &hc-defaults
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

Shared health check settings applied to every service with `<<: *hc-defaults`.
Docker checks each container every 10 seconds, allows 30 seconds to start,
and marks it unhealthy after 5 failed checks.

---

### depends_on with Health Checks

```yaml
catalog:
  depends_on:
    catalog-db:
      condition: service_healthy
```

`condition: service_healthy` means catalog will not start until `catalog-db`
passes its health check. This enforces the correct startup order automatically:

```
Step 1 — Infrastructure starts first:
  catalog-db, checkout-db, orders-db, cart-redis, rabbitmq

Step 2 — Microservices start once their dependencies are healthy:
  catalog  (waits for catalog-db)
  cart     (waits for cart-redis)
  checkout (waits for checkout-db + rabbitmq)
  orders   (waits for orders-db + rabbitmq)

Step 3 — UI starts last:
  ui       (waits for catalog + cart + checkout + orders)
```

---

### Security Hardening

All microservices (`catalog`, `cart`, `checkout`, `orders`, `ui`) include the following security settings:

```yaml
cap_add:
  - NET_BIND_SERVICE
cap_drop:
  - ALL
read_only: true
security_opt:
  - no-new-privileges:true
tmpfs:
  - /tmp:rw,noexec,nosuid
```

- `cap_drop: ALL` — strips every Linux capability from the container
- `cap_add: NET_BIND_SERVICE` — adds back only the capability to bind to network ports, keeping flexibility to run on any port including privileged ports below 1024
- `read_only: true` — container filesystem cannot be written to (prevents malware persistence)
- `no-new-privileges:true` — process can never escalate its own privileges even via setuid binaries
- `tmpfs: /tmp` — mounts `/tmp` in RAM only; `noexec` prevents execution of files there, `nosuid` blocks privilege escalation

Infrastructure services (`catalog-db`, `checkout-db`, `orders-db`, `cart-redis`, `rabbitmq`) have `security_opt: no-new-privileges:true` but not `cap_drop` or `read_only` — databases need write access to their volumes and specific capabilities to manage file permissions.

---

### Secrets via Environment Variables

Passwords are never hardcoded. They are loaded from a `.env` file:

```yaml
environment:
  DB_PASSWORD: ${DB_PASSWORD}
```

```bash
# .env (never committed to git)
DB_PASSWORD=guitarshop123
```

---

### Ports

```yaml
ui:
  ports:
    - "8080:8080"

rabbitmq:
  ports:
    - "15672:15672"   # Management UI
```

Only two services expose ports to the host machine:
- `8080` → the storefront UI
- `15672` → RabbitMQ management dashboard (browser UI)

All other services are internal — only reachable inside `guitarshop-net`.

---

## IV. Run the Full Stack

```bash
cd guitar-shop-microservices
docker compose up --build
```

- `--build` forces Docker to rebuild all images from source
- Omit `--build` on subsequent runs to reuse cached images (faster)

To run in the background:

```bash
docker compose up --build -d
```

---

## V. Check Container Status

```bash
docker compose ps
```

All containers should show `healthy` in the STATUS column before the UI is accessible.

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## VI. Verify

Replace `<EC2-PUBLIC-IP>` with your EC2 instance's public IP address.

**UI (storefront):**
```bash
curl http://<EC2-PUBLIC-IP>:8080/health
```

**Individual service health checks:**
```bash
curl http://<EC2-PUBLIC-IP>:8080          # Full storefront in browser
```

**RabbitMQ Management Dashboard:**
```
http://<EC2-PUBLIC-IP>:15672
Username: guitarshop
Password: <value of DB_PASSWORD in your .env>
```

---

## VII. Useful Debug Commands

View logs for all services:
```bash
docker compose logs -f
```

View logs for a single service:
```bash
docker compose logs -f cart
docker compose logs -f ui
```

Restart a single service without rebuilding:
```bash
docker compose restart cart
```

Rebuild and restart a single service:
```bash
docker compose up --build -d cart
```

Open a shell inside a running container:
```bash
docker exec -it guitarshop-cart sh
```

---

## VIII. Startup Order Diagram

```
                    ┌─────────────┐
                    │  catalog-db │ (MySQL)
                    └──────┬──────┘
                           │ healthy
                           ▼
                    ┌─────────────┐
                    │   catalog   │ (Go)
                    └──────┬──────┘
                           │ healthy
                           │
┌────────────┐             │             ┌──────────────┐
│ cart-redis │             │             │  checkout-db │
└─────┬──────┘             │             └──────┬───────┘
      │ healthy            │                    │ healthy
      ▼                    │             ┌──────┴───────┐
┌──────────┐               │             │   rabbitmq   │
│   cart   │               │             └──────┬───────┘
└─────┬────┘               │                    │ healthy
      │ healthy            │             ┌──────┴───────┐    ┌───────────┐
      │                    │             │   checkout   │    │ orders-db │
      │                    │             └──────┬───────┘    └─────┬─────┘
      │                    │                    │ healthy          │ healthy
      │                    │                    │           ┌──────┴──────┐
      │                    │                    │           │   orders    │
      │                    │                    │           └──────┬──────┘
      │                    │                    │                  │ healthy
      └────────────────────┴────────────────────┴──────────────────┘
                                         │
                                         ▼
                                   ┌──────────┐
                                   │    ui    │  ← port 8080
                                   └──────────┘
```

---

## IX. Cleanup

Stop all containers (data is preserved):
```bash
docker compose down
```

Stop all containers and delete all data:
```bash
docker compose down -v
```

Stop all containers, delete data, and remove built images:
```bash
docker compose down -v --rmi all
```
