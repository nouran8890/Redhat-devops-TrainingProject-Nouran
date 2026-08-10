#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$ROOT_DIR/services/auth-service-node"

cd "$SERVICE_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created services/auth-service-node/.env from .env.example."
  echo "Update PostgreSQL/JWT settings if needed."
fi

set -a
source .env
set +a

if [ ! -d node_modules ]; then
  echo "Installing auth-service dependencies..."
  npm install
fi

echo "Starting auth-service on port ${PORT:-8082}..."
npm start
