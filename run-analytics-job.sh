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

# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install -r requirements.txt

JOB_INTERVAL="${JOB_INTERVAL:-60}"
echo "Running analytics job every ${JOB_INTERVAL}s (first run immediately)..."

while true; do
    python job.py || echo "analytics job failed (will retry in ${JOB_INTERVAL}s)"
    sleep "$JOB_INTERVAL"
done