#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$ROOT_DIR/services/legacy-catalog-java"

cd "$SERVICE_DIR"

if ! sudo systemctl is-active --quiet mysql; then
    echo "ERROR: MySQL is not running."
    echo "Start it with: sudo systemctl start mysql"
    exit 1
fi

echo "Starting legacy-catalog on port 8081..."
mvn spring-boot:run