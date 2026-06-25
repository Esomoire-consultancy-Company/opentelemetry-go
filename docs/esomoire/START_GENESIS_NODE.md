# Start the Esomoire Genesis Node

This is the first runnable bootstrap service for the Genesis Control Plane.

It does four things:

```text
1. Reads the private server environment variables.
2. Fetches the public Genesis control-plane manifest.
3. Validates whether the node has enough configuration to start.
4. Exposes /healthz, /readyz, and /manifestz.
```

## 1. Clone the repository on the server

```bash
sudo mkdir -p /opt/esomoire/genesis
sudo chown -R "$USER":"$USER" /opt/esomoire
cd /opt/esomoire/genesis

git clone https://github.com/Esomoire-consultancy-Company/opentelemetry-go.git
cd opentelemetry-go
```

## 2. Create the private environment file

```bash
cd /opt/esomoire/genesis
curl -fsSL https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/.env.example -o .env
chmod 600 .env
```

Edit `.env` and paste the real Supabase + Grafana values.

Do not commit `.env` to GitHub.

## 3. Fetch the public hardware manifest

```bash
curl -fsSL https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml -o /opt/esomoire/genesis/genesis-control-plane.yaml
```

## 4. Apply the database migration

After `DATABASE_URL` is filled in `.env`:

```bash
cd /opt/esomoire/genesis
set -a
source .env
set +a

curl -fsSL https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/database/esomoire/migrations/0001_genesis_control_plane.sql -o 0001_genesis_control_plane.sql
psql "$DATABASE_URL" -f 0001_genesis_control_plane.sql
```

## 5. Run the node directly with Go

```bash
cd /opt/esomoire/genesis/opentelemetry-go
set -a
source /opt/esomoire/genesis/.env
set +a

go run ./cmd/esomoire-genesis-node
```

The service defaults to port `8081`.

## 6. Check health

```bash
curl http://127.0.0.1:8081/healthz
```

Expected result:

```json
{
  "service": "esomoire-genesis-node",
  "status": "healthy"
}
```

## 7. Check readiness

```bash
curl http://127.0.0.1:8081/readyz
```

If values are missing, it returns `not_ready` and lists only the missing variable names. It does not expose secret values.

## 8. Check manifest reachability

```bash
curl http://127.0.0.1:8081/manifestz
```

Expected result:

```json
{
  "manifest_url": "https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml",
  "http_status": 200,
  "reachable": true
}
```

## 9. Run with Docker Compose

From the repository root:

```bash
cd /opt/esomoire/genesis/opentelemetry-go

docker compose -f deploy/esomoire/docker-compose.yml up --build
```

For real production, replace the compose `env_file` with the private server file:

```text
/opt/esomoire/genesis/.env
```

## 10. Hardware configuration URL

Configure hardware to fetch this URL first:

```text
https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml
```

Then the server must load the private `.env` locally.

## Current limitation

This is the bootstrap node service, not the full Registry API yet. The next service layer should add actual APIs:

```text
POST /v1/registry/entities
GET  /v1/registry/entities/{entity_id}
POST /v1/evidence
POST /v1/licenses
POST /v1/payments
POST /v1/telemetry
```
