# Deploy with Docker Compose on EC2

---

## I. Prerequisites

- EC2 instance running
- Repository cloned

```bash
cd ecommerce-guitarshop/
```

---

## II. Install Docker Compose

```bash
# Create the CLI plugin directory
sudo mkdir -p /usr/local/lib/docker/cli-plugins

# Download the latest Docker Compose v2 binary
wget https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -O docker-compose

# Make it executable
chmod +x docker-compose

# Move it to the CLI plugins directory
sudo mv docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# Verify install
docker compose version
```

---

## III. Run the Stack

Set the required environment variable and start all containers:

```bash
export DB_PASSWORD='guitarshop123'

docker compose up
```

---

## IV. Access the App

Replace `<EC2-Instance-Public-IP>` with your EC2 instance's public IP:

```
http://<EC2-Instance-Public-IP>:8888
```

---

## V. Stop the Stack

```bash
docker compose down
```
