#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$ROOT_DIR/services/ai-insight-service-python"

cd "$SERVICE_DIR"

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created ai-insight-service-python/.env from .env.example."
fi

set -a
source .env
set +a

if [ ! -d .venv ]; then
    echo "Creating AI Insight virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

python -m pip install -r requirements.txt

echo "Starting AI Insight service on port ${PORT:-8084}..."

python -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8084}" --reload