# Supabase + Grafana setup for Esomoire Genesis Control Plane

This is the recommended first production bundle for the Genesis bootstrap server.

## Target bundle

Use:

```text
Supabase Project = database + object storage + auth/JWT
Grafana Cloud Stack = OpenTelemetry traces, metrics, and logs
```

This gives the required environment variables:

```text
DATABASE_URL
OBJECT_STORE_BUCKET
OBJECT_STORE_ENDPOINT
OBJECT_STORE_ACCESS_KEY_ID
OBJECT_STORE_SECRET_ACCESS_KEY
JWT_ISSUER
JWT_AUDIENCE
JWT_JWKS_URL
JWT_SIGNING_KEY
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_EXPORTER_OTLP_HEADERS
```

## Step 1: Create Supabase project

Recommended project name:

```text
genesis-control-plane
```

After creation, collect the Postgres connection string and place it into:

```text
DATABASE_URL
```

Use the direct/pooled connection string according to deployment need. For a single server, direct is acceptable. For serverless or many short-lived workers, use a pooled connection string.

## Step 2: Create object storage bucket

Create a Supabase Storage bucket:

```text
genesis-evidence
```

Set:

```text
OBJECT_STORE_BUCKET="genesis-evidence"
```

For server-side evidence upload, generate S3 access keys in Supabase Storage S3 settings. Do not use these from the browser/client.

Expected endpoint pattern:

```text
OBJECT_STORE_ENDPOINT="https://PROJECT_REF.storage.supabase.co/storage/v1/s3"
```

Expected credential variables:

```text
OBJECT_STORE_ACCESS_KEY_ID="..."
OBJECT_STORE_SECRET_ACCESS_KEY="..."
```

## Step 3: Configure JWT authority

Use Supabase Auth as the first authority provider.

Set:

```text
JWT_ISSUER="https://PROJECT_REF.supabase.co/auth/v1"
JWT_AUDIENCE="authenticated"
JWT_JWKS_URL="https://PROJECT_REF.supabase.co/auth/v1/.well-known/jwks.json"
```

Prefer JWKS verification over copying a shared JWT secret into every service.

Only set `JWT_SIGNING_KEY` if you are running a private internal issuer or a controlled signing service.

## Step 4: Create Grafana Cloud stack

Recommended stack name:

```text
genesis-warden
```

Inside Grafana Cloud:

```text
Connections → Add new connection → OpenTelemetry
```

Generate the OpenTelemetry environment variables and copy:

```text
OTEL_EXPORTER_OTLP_PROTOCOL
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_EXPORTER_OTLP_HEADERS
```

Recommended service attributes:

```text
OTEL_SERVICE_NAME="genesis-control-plane"
OTEL_RESOURCE_ATTRIBUTES="deployment.environment=bootstrap,service.namespace=esomoire.genesis,service.version=0.1.0,service.instance.id=gns_bootstrap_001"
```

## Step 5: Prepare server `.env`

On the hardware/server:

```bash
mkdir -p /opt/esomoire/genesis
cd /opt/esomoire/genesis
curl -fsSL https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/.env.example -o .env
chmod 600 .env
```

Edit `.env` and replace every placeholder.

Never commit `.env` back to GitHub.

## Step 6: Apply database migration

Download the migration:

```bash
curl -fsSL https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/database/esomoire/migrations/0001_genesis_control_plane.sql -o 0001_genesis_control_plane.sql
```

Run it against your Postgres database:

```bash
psql "$DATABASE_URL" -f 0001_genesis_control_plane.sql
```

## Step 7: Fetch the public hardware manifest

The hardware/server bootstrap URL is:

```text
https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml
```

A node should fetch this manifest, then load private `.env`, then start services.

## Step 8: First health contract

Every service should expose:

```text
/healthz
/readyz
```

Expected local ports:

```text
genesis-registry        8081
empireos-license        8082
riveros-evidence        8083
silk-payment-runtime    8084
warden-observability    8085
```

## Step 9: Minimum first live check

After migration, confirm the bootstrap entity exists:

```sql
select entity_id, entity_name, entity_type, status, created_at
from entities
where entity_type = 'node'
order by created_at desc
limit 5;
```

Then confirm telemetry variables are loaded by the service process before the first request.

## Security rule

The public manifest defines what the system expects. The private `.env` supplies actual secrets. These must remain separated.
