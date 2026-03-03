# Orders Service — application.yml Reference

> **No commands to run in this doc.** It is reference reading only — it explains what
> env vars the Spring Boot app expects so you understand why the `-e` flags in doc 7 are
> named the way they are.

---

## I. Database Connection

| Env Var       | Default              | Purpose               |
|---------------|----------------------|-----------------------|
| `DB_HOST`     | `orders-db`          | PostgreSQL container  |
| `DB_PORT`     | `5432`               | PostgreSQL default port|
| `DB_NAME`     | `guitarshop_orders`  | Database to connect to|
| `DB_USER`     | `guitarshop`         | Database user         |
| `DB_PASSWORD` | `guitarshop123`      | Database password     |

Defaults match Docker Compose service names. Spring JPA (`ddl-auto: update`) creates
and updates tables automatically on startup — no manual SQL needed.

---

## II. RabbitMQ Connection

| Env Var             | Default        | Purpose                |
|---------------------|----------------|------------------------|
| `RABBITMQ_HOST`     | `rabbitmq`     | RabbitMQ container     |
| `RABBITMQ_PORT`     | `5672`         | RabbitMQ default port  |
| `RABBITMQ_USER`     | `guitarshop`   | RabbitMQ user          |
| `RABBITMQ_PASSWORD` | `guitarshop123`| RabbitMQ password      |

Unlike checkout which uses a single `RABBITMQ_URL`, orders uses four separate vars.
The app **consumes** from the `checkout.events` queue — the same queue checkout publishes to.

---

## III. Port

| Env Var | Default | Purpose              |
|---------|---------|----------------------|
| `PORT`  | `8080`  | Port the app listens on |

---

## IV. Health Endpoint

```
GET /orders/health
```

Spring Boot Actuator — the orders service maps `/orders/health` as a shortcut to
`/actuator/health`, which reports the status of the app, PostgreSQL, and RabbitMQ.
