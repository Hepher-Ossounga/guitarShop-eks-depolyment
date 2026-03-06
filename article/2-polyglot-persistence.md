# Polyglot Persistence in GuitarShop

*Part 2 — Four services, four databases, and what that means for deployment*

---

*This is Part 2 of a series documenting the full build and deployment of GuitarShop — a microservices e-commerce application built with Go, Java, Node.js, and deployed on AWS EKS. [Start with the overview](./1-overview.md) if this is the first article in the series.*

---

Each service in GuitarShop owns its own database. Not just a separate schema but a completely separate container, separate volume, and separate credentials. This is what database-per-service looks like in practice, and it has direct consequences for how the system is configured and deployed.

---

## The Four Databases

| Service  | Database       | Container                  | Port (internal) |
|----------|----------------|----------------------------|-----------------|
| Catalog  | MySQL 8        | `guitarshop-catalog-db`    | 3306            |
| Cart     | Redis 7        | `guitarshop-redis`         | 6379            |
| Checkout | PostgreSQL 15  | `guitarshop-checkout-db`   | 5432            |
| Orders   | PostgreSQL 15  | `guitarshop-orders-db`     | 5432            |

Four containers. Four persistent volumes. None of them are accessible from outside the Docker network. Only the service that owns them connects to them. Checkout and Orders each run their own PostgreSQL instance on port 5432 internally; they are isolated by container and volume, not by port.

---

## Catalog: MySQL

Stores products and categories. Structured relational data with a fixed schema: product name, brand, price, category, stock, image URL. MySQL is the right fit — the catalog runs structured queries, filters by category and brand, and has predictable relationships between tables.

Here is how that database container is defined in Docker Compose:

```yaml
catalog-db:
  image: mysql:8.0
  container_name: guitarshop-catalog-db
  environment:
    MYSQL_ROOT_PASSWORD: rootpassword
    MYSQL_DATABASE:      guitarshop_catalog
    MYSQL_USER:          guitarshop
    MYSQL_PASSWORD:      guitarshop123
  volumes:
    - catalog-db-data:/var/lib/mysql
  networks:
    - guitarshop-net
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "guitarshop", "-pguitarshop123"]
    <<: *hc-defaults
```

Three things to note. `MYSQL_DATABASE`, `MYSQL_USER`, and `MYSQL_PASSWORD` initialize the database and credentials on first boot. The named volume `catalog-db-data` maps to `/var/lib/mysql` — this is where MySQL stores its data files; without it, data is lost on container restart. The health check runs `mysqladmin ping` on a timer — the catalog application service will not start until this check passes.

---

## Cart: Redis

Stores active user sessions. Each cart is a key-value pair: `guitarshop:cart:{customerId}` maps to a serialized cart object with a 7-day TTL. No tables, no schema, no migrations. Redis is chosen because cart data is simple, session-scoped, and needs to be retrieved in under a millisecond.

Here is how the Redis container is defined:

```yaml
cart-redis:
  image: redis:7-alpine
  container_name: guitarshop-redis
  command: redis-server --appendonly yes
  volumes:
    - redis-data:/data
  networks:
    - guitarshop-net
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    <<: *hc-defaults
```

Two things stand out. The `command: redis-server --appendonly yes` line enables append-only persistence — without it Redis is purely in-memory and all cart data is lost on restart. The named volume `redis-data` maps to `/data`, which is where Redis writes its append log. The cart service connects via `REDIS_HOST` and `REDIS_PORT` — no schema migrations needed at any point.

---

## Checkout: PostgreSQL

Stores transaction records. The `checkouts` table uses a UUID primary key and stores the items list as `JSONB`. Checkout needs ACID transactions — if anything fails mid-write, the entire operation rolls back. No partial orders, no corrupt state.

Here is how the checkout database container is defined:

```yaml
checkout-db:
  image: postgres:15-alpine
  container_name: guitarshop-checkout-db
  environment:
    POSTGRES_DB:       guitarshop_checkout
    POSTGRES_USER:     guitarshop
    POSTGRES_PASSWORD: guitarshop123
  volumes:
    - checkout-db-data:/var/lib/postgresql/data
  networks:
    - guitarshop-net
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U guitarshop -d guitarshop_checkout"]
    <<: *hc-defaults
```

`POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` initialize the database on first boot. The named volume `checkout-db-data` maps to `/var/lib/postgresql/data`. Note that the checkout application service also requires `RABBITMQ_URL` in addition to the database variables — it publishes an `ORDER_CREATED` event to RabbitMQ immediately after writing to this database.

---

## Orders: PostgreSQL

Stores order lifecycle records. Same engine as Checkout, completely separate instance. The `status` field tracks each order through `PENDING → CONFIRMED → PROCESSING → SHIPPED → DELIVERED`.

Here is how the orders database container is defined:

```yaml
orders-db:
  image: postgres:15-alpine
  container_name: guitarshop-orders-db
  environment:
    POSTGRES_DB:       guitarshop_orders
    POSTGRES_USER:     guitarshop
    POSTGRES_PASSWORD: guitarshop123
  volumes:
    - orders-db-data:/var/lib/postgresql/data
  networks:
    - guitarshop-net
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U guitarshop -d guitarshop_orders"]
    <<: *hc-defaults
```

The key detail is the volume name: `orders-db-data`, not `checkout-db-data`. Same PostgreSQL image, completely separate data. The orders application service depends on both this database and RabbitMQ before it starts — it needs the database to write order records and the queue to receive `ORDER_CREATED` events from Checkout.

---

## What This Means for Deployment

Every database is an independent unit with its own container, volume, and credentials. In Docker Compose that means four separate service definitions and four named volumes. In Kubernetes it means four Deployments, four PersistentVolumeClaims, and four Secrets.

No service shares storage with another. Losing the cart Redis instance does not affect checkout. Restarting the orders database does not touch the catalog.

---

