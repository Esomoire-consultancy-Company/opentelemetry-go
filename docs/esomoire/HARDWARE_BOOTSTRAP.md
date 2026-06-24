# Esomoire Genesis Hardware Bootstrap

This document explains how a server or hardware node should use the public bootstrap manifest.

## Primary configuration URL

```text
https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml
```

Use this as the first configuration location for a Genesis node. The manifest tells the hardware what services exist, which environment variables are required, what datastore roles are expected, and what telemetry contract should be used.

## Important boundary

The manifest is public configuration. It must never contain secrets.

Secrets must be configured on the server as environment variables or through a proper secret manager.

Required production variables include:

```text
DATABASE_URL
OBJECT_STORE_BUCKET
OBJECT_STORE_ENDPOINT
OBJECT_STORE_ACCESS_KEY_ID
OBJECT_STORE_SECRET_ACCESS_KEY
JWT_ISSUER
JWT_AUDIENCE
JWT_SIGNING_KEY
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_EXPORTER_OTLP_HEADERS
```

Optional scale variables include:

```text
REDIS_URL
GENESIS_PUBLIC_API_BASE_URL
GENESIS_INTERNAL_API_BASE_URL
GENESIS_NODE_NAME
GENESIS_NODE_ID
GENESIS_SITE_ID
```

## Bootstrap sequence

A hardware node should follow this order:

```text
1. Fetch the raw manifest URL.
2. Load local environment variables.
3. Validate all required environment variables.
4. Connect to the canonical Postgres database using DATABASE_URL.
5. Connect to the object/evidence store.
6. Run schema migrations.
7. Start Genesis Registry service.
8. Start EmpireOS License service.
9. Start RiverOS Evidence service.
10. Start Silk Payment Runtime service.
11. Start Warden Observability service.
12. Emit node health and readiness telemetry.
```

## Service ports

Default local service ports:

| Service | Port |
|---|---:|
| genesis-registry | 8081 |
| empireos-license | 8082 |
| riveros-evidence | 8083 |
| silk-payment-runtime | 8084 |
| warden-observability | 8085 |

## First production database recommendation

Use Postgres as the canonical store. Suitable first options:

```text
Neon Postgres
Supabase Postgres
Railway Postgres
Cloud SQL Postgres
Self-hosted Postgres
```

The public manifest points to the environment variable name only:

```text
DATABASE_URL
```

The actual value should look like this pattern, but must remain private:

```text
postgresql://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require
```

## What this gives the server

The server gets one stable location URL for configuration:

```text
https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml
```

From that, it can discover:

- service names
- ports
- database role expectations
- object-store role expectations
- required secret names
- registry schema families
- telemetry event names
- health/readiness paths
- hardware bootstrap order

## What this does not yet provide

This does not yet create the real database, domain, API server, SSL certificate, or hardware agent. Those must be provisioned separately.

Once the actual server is ready, point `GENESIS_PUBLIC_API_BASE_URL` and `GENESIS_INTERNAL_API_BASE_URL` to the live URL or private network address.
