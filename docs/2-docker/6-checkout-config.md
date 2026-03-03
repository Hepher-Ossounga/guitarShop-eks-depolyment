# Checkout Service — Configuration Reference

> **No commands to run in this doc.** It is reference reading only — it explains what
> env vars the Node.js app expects so you understand why the `-e` flags in doc 5 are
> named the way they are.

Unlike Spring Boot services, checkout has no `application.yml`. Env vars are read directly
via `process.env.VAR || 'default'` across three source files.

---

## I. Database Connection

| Env Var       | Default               | Purpose                |
|---------------|-----------------------|------------------------|
| `DB_HOST`     | `checkout-db`         | PostgreSQL container   |
| `DB_PORT`     | `5432`                | PostgreSQL default port|
| `DB_NAME`     | `guitarshop_checkout` | Database to connect to |
| `DB_USER`     | `guitarshop`          | Database user          |
| `DB_PASSWORD` | `guitarshop123`       | Database password      |

Defaults match Docker Compose service names. The app retries the connection up to
**10 times** (3 seconds apart) and creates the `checkouts` table automatically on
first startup — no manual SQL needed.

---

## II. RabbitMQ Connection

| Env Var        | Default                                          | Purpose               |
|----------------|--------------------------------------------------|-----------------------|
| `RABBITMQ_URL` | `amqp://guitarshop:guitarshop123@rabbitmq:5672`  | Full connection URL   |

Checkout uses a **single URL** (unlike orders which uses four separate vars).
Format: `amqp://user:password@host:port`

The app **publishes** to the `checkout.events` queue every time an order is placed.
The orders service consumes from that same queue.

---

## II. Port

| Env Var | Default | Purpose              |
|---------|---------|----------------------|
| `PORT`  | `8080`  | Port the app listens on |

---

## III. Health Endpoint

```
GET /health
```

Manually coded in `index.js` — no Actuator. Path is `/health`, not `/checkout/health`.
