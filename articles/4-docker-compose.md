# Docker Compose: Running the Full Stack Locally

*Part 4 — How ten containers start in the right order, connect to each other, and persist their data*

---

*This is Part 4 of a series documenting the full build and deployment of GuitarShop — a microservices e-commerce application built with Go, Java, Node.js, and deployed on AWS EKS. [Start with the overview](https://github.com/Hepher-Ossounga/guitarShop-depolyment/blob/main/article/1-overview.md) if this is the first article in the series.*

---

The Dockerfiles from Part 3 define how each service is built. Docker Compose defines how all ten containers run together. One file — `docker-compose.yml` — declares the network, the volumes, the startup order, the environment variables, and the health checks for the entire system. One command starts it all.

```bash
docker compose up --build
```

---

## The File Structure

The `docker-compose.yml` is organized into four top-level sections before the services are declared:

```yaml
version: "3.9"

networks:
  guitarshop-net:
    driver: bridge

volumes:
  catalog-db-data:
  checkout-db-data:
  orders-db-data:
  redis-data:
  rabbitmq-data:

x-healthcheck-defaults: &hc-defaults
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

**`networks`** — declares a single bridge network called `guitarshop-net`. Every container joins this network, which means they can reach each other by container name. `catalog-db` is reachable at the hostname `catalog-db`. `rabbitmq` is reachable at `rabbitmq`. Docker handles the DNS resolution internally.

**`volumes`** — declares five named volumes, one per stateful service. Named volumes persist data between container restarts. Without them, every `docker compose down` would wipe all database records, cart sessions, and message queue state.

**`x-healthcheck-defaults`** — a YAML anchor. The `&hc-defaults` tag marks it as a reusable block. Every health check in the file uses `<<: *hc-defaults` to merge these values in:

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  <<: *hc-defaults   # merges interval, timeout, retries, start_period
```

This avoids repeating the same four timing values across all ten services. If the retry count needs to change, it changes in one place.

---

## Infrastructure vs Microservices

The services are split into two groups. Infrastructure services use `image` — they pull a pre-built image from Docker Hub. Microservices use `build` — they build from the local Dockerfile.

```yaml
# Infrastructure — pull image
catalog-db:
  image: mysql:8.0

# Microservice — build from source
catalog:
  build:
    context: ./microservices/catalog
    dockerfile: Dockerfile
```

Infrastructure containers start first. Microservice containers wait for them.

---

## Health Checks and Startup Order

`depends_on` with `condition: service_healthy` is the mechanism that enforces startup order. A service will not start until every dependency it lists passes its health check.

Each infrastructure service has a health check tailored to its technology:

```yaml
# MySQL
test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "guitarshop", "-pguitarshop123"]

# PostgreSQL
test: ["CMD-SHELL", "pg_isready -U guitarshop -d guitarshop_checkout"]

# Redis
test: ["CMD", "redis-cli", "ping"]

# RabbitMQ
test: ["CMD", "rabbitmq-diagnostics", "ping"]
```

Each microservice then declares what it needs before starting:

```yaml
catalog:   depends_on: catalog-db    (healthy)
cart:      depends_on: cart-redis    (healthy)
checkout:  depends_on: checkout-db  (healthy) + rabbitmq (healthy)
orders:    depends_on: orders-db    (healthy) + rabbitmq (healthy)
ui:        depends_on: catalog, cart, checkout, orders (all healthy)
```

The UI Service is last — it depends on all four microservices being healthy before it accepts traffic. This creates a guaranteed startup chain:

```
Infrastructure → Microservices → UI
```

Without `condition: service_healthy`, `depends_on` only waits for the container to start — not for the application inside it to be ready. A database container can start in milliseconds but take 20+ seconds to be ready to accept connections. The health check condition closes that gap.

---

## Environment Variables

Environment variables are how the microservices know where to find their dependencies. The values use container names as hostnames — Docker resolves them on the internal network.

**Catalog** connects to MySQL:
```yaml
environment:
  DB_HOST:     catalog-db       # container name → resolved by Docker DNS
  DB_PORT:     "3306"
  DB_NAME:     guitarshop_catalog
  DB_USER:     guitarshop
  DB_PASSWORD: guitarshop123
```

**Cart** connects to Redis:
```yaml
environment:
  REDIS_HOST: cart-redis
  REDIS_PORT: "6379"
```

**Checkout** connects to PostgreSQL and RabbitMQ. The RabbitMQ connection is a single URL:
```yaml
environment:
  DB_HOST:      checkout-db
  DB_PORT:      "5432"
  DB_NAME:      guitarshop_checkout
  DB_USER:      guitarshop
  DB_PASSWORD:  guitarshop123
  RABBITMQ_URL: amqp://guitarshop:guitarshop123@rabbitmq:5672
```

**Orders** connects to PostgreSQL and RabbitMQ. The RabbitMQ connection is split into four separate variables — the Spring Boot AMQP library reads them individually:
```yaml
environment:
  DB_HOST:           orders-db
  DB_PORT:           "5432"
  DB_NAME:           guitarshop_orders
  DB_USER:           guitarshop
  DB_PASSWORD:       guitarshop123
  RABBITMQ_HOST:     rabbitmq
  RABBITMQ_PORT:     "5672"
  RABBITMQ_USER:     guitarshop
  RABBITMQ_PASSWORD: guitarshop123
```

**UI** connects to all four microservices. It doesn't connect to any database directly:
```yaml
environment:
  CATALOG_SERVICE_URL:  http://catalog:8080
  CART_SERVICE_URL:     http://cart:8080
  CHECKOUT_SERVICE_URL: http://checkout:8080
  ORDERS_SERVICE_URL:   http://orders:8080
```

---

## Ports: What's Exposed and What Isn't

Only two services expose ports to the host machine:

```yaml
# UI — the only public entry point
ui:
  ports:
    - "8080:8080"

# RabbitMQ — management UI for local inspection
rabbitmq:
  ports:
    - "15672:15672"
```

Every other service — all databases, Redis, and the four backend microservices — communicates only on the internal `guitarshop-net` network. They are not reachable from the host machine. The only way to reach the backend services is through the UI Service on port 8080.

The format `"8080:8080"` means `host_port:container_port`. The left side is what's accessible on the machine. The right side is what the container listens on.

---

## What `docker compose up --build` Does

Running the command triggers the following sequence:

1. Builds images for all five microservices from their Dockerfiles
2. Pulls images for the five infrastructure services from Docker Hub
3. Creates the `guitarshop-net` bridge network
4. Creates the five named volumes if they don't already exist
5. Starts infrastructure containers — MySQL, PostgreSQL ×2, Redis, RabbitMQ
6. Waits for each infrastructure health check to pass
7. Starts microservice containers as their dependencies become healthy
8. Waits for all four microservice health checks to pass
9. Starts the UI Service

The storefront is available at `http://localhost:8080` once the UI health check passes.

To stop and remove everything including all stored data:

```bash
docker compose down -v
```

The `-v` flag removes named volumes. Without it, the containers stop but the database data, Redis sessions, and RabbitMQ queues persist and are reused on the next `up`.

---


