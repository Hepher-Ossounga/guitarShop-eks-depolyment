# Catalog Service — Configuration Reference

> **No commands to run in this doc.** It is reference reading only — it explains what
> env vars the Go app expects so you understand why the `-e` flags in doc 3 are
> named the way they are.

Unlike the Spring Boot services, the catalog has no `application.yml`. Configuration is
read directly from environment variables in `cmd/main.go` using a `getEnv(key, default)`
helper — same idea, different mechanism.

---

## I. Database Connection

| Env Var       | Default              | Purpose               |
|---------------|----------------------|-----------------------|
| `DB_HOST`     | `catalog-db`         | MySQL container name  |
| `DB_PORT`     | `3306`               | MySQL default port    |
| `DB_NAME`     | `guitarshop_catalog` | Database to connect to|
| `DB_USER`     | `guitarshop`         | Database user         |
| `DB_PASSWORD` | `guitarshop123`      | Database password     |

The defaults match the Docker Compose service names, so `docker compose up` works
without explicit env vars. The app retries the connection up to **15 times** (4 seconds
apart) to wait for MySQL to finish starting — no manual timing needed.

---

## II. Port

| Env Var | Default | Purpose              |
|---------|---------|----------------------|
| `PORT`  | `8080`  | Port the app listens on |

This is why the Dockerfile has `EXPOSE 8080` and `docker run` uses `-p 8080:8080`.

---

## III. Database Seeding

On first startup the app automatically creates the tables and seeds the data —
6 categories and 10 products. **No manual SQL or setup required.**

---

## IV. Health Endpoint

```
GET /health
```

Unlike the Spring Boot services, there is no Actuator. This route is manually
registered in `main.go` — which is why the path is `/health`, not `/catalog/health`.
