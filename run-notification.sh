#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$ROOT_DIR/services/notification-worker-go"

cd "$SERVICE_DIR"

export RABBITMQ_URL="${RABBITMQ_URL:-amqp://guest:guest@localhost:5672/}"
export RABBITMQ_QUEUE="${RABBITMQ_QUEUE:-bookings}"

echo "Starting notification worker..."
go run main.go