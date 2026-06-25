#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/esomoire/genesis}"
REPO_DIR="${REPO_DIR:-$APP_DIR/opentelemetry-go}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env}"
MANIFEST_URL="${GENESIS_MANIFEST_URL:-https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/genesis-control-plane.yaml}"

mkdir -p "$APP_DIR"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing environment file: $ENV_FILE" >&2
  echo "Create it from:" >&2
  echo "curl -fsSL https://raw.githubusercontent.com/Esomoire-consultancy-Company/opentelemetry-go/main/configs/esomoire/.env.example -o $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

export GENESIS_MANIFEST_URL="$MANIFEST_URL"

echo "Fetching manifest: $GENESIS_MANIFEST_URL"
curl -fsSL "$GENESIS_MANIFEST_URL" -o "$APP_DIR/genesis-control-plane.yaml"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Repository not found at $REPO_DIR" >&2
  echo "Clone it first:" >&2
  echo "git clone https://github.com/Esomoire-consultancy-Company/opentelemetry-go.git $REPO_DIR" >&2
  exit 1
fi

cd "$REPO_DIR"

echo "Starting Esomoire Genesis node..."
exec go run ./cmd/esomoire-genesis-node
