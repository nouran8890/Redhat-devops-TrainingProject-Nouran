#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$ROOT_DIR/services/booking-service-python"

cd "$SERVICE_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created services/booking-service-python/.env from .env.example."
  echo "Update MongoDB/RabbitMQ/AI Insight settings if needed."
fi

set -a
source .env
set +a

if [ ! -d .venv ]; then
  echo "Creating booking-service virtual environment..."
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install -r requirements.txt

echo "Starting booking-service on port ${PORT:-8083}..."
python -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8083}" --reload
