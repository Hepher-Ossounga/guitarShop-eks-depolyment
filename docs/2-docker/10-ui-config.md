# UI Service — application.yml Reference

> **No commands to run in this doc.** It is reference reading only — it explains what
> env vars the Spring Boot app expects so you understand why the `-e` flags in doc 9 are
> named the way they are.

The UI has no database. Its only dependencies are the four backend services it calls
over HTTP on every page load.

---

## I. Backend Service URLs

| Env Var                | Default                     | Purpose                          |
|------------------------|-----------------------------|----------------------------------|
| `CATALOG_SERVICE_URL`  | `http://catalog:8080`       | Where to fetch product data      |
| `CART_SERVICE_URL`     | `http://cart:8080`          | Where to read/write cart data    |
| `CHECKOUT_SERVICE_URL` | `http://checkout:8080`      | Where to submit orders           |
| `ORDERS_SERVICE_URL`   | `http://orders:8080`        | Where to fetch order history     |

Defaults use Docker Compose service names so `docker compose up` works without explicit
env vars. All backend calls happen **server-side** inside the UI container — the browser
only ever talks to the UI on port 8080.

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

Spring Boot Actuator — exposes `health` and `info` only (no `metrics` unlike cart and orders).
