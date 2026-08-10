#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$ROOT_DIR/services/analytics-service-python"

cd "$SERVICE_DIR"

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created analytics-service-python/.env from .env.example."
fi

set -a
source .env
set +a

if [ ! -d .venv ]; then
    echo "Creating analytics-service virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

python -m pip install -r requirements.txt

echo "Starting analytics-service on port ${PORT:-8085}..."

python -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8085}" --reload