#!/usr/bin/env bash

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONT_DIR="$ROOT_DIR/frontend"
PORT=3000

cd "$FRONT_DIR"

set -a
source "$FRONT_DIR/.env"
set +a

npm install

cleanup() {
    echo "Stopping frontend..."
}

trap cleanup INT TERM

echo "Starting frontend on port $PORT..."

npm run dev -- --port "$PORT"
