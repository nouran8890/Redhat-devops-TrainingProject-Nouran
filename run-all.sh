#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${RUN_ALL_LOG_DIR:-$ROOT_DIR/logs}"

SERVICES=(
    "catalog:8081"
    "auth:8082"
    "booking:8083"
    "ai-insights:8084"
    "analytics:8085"
    "analytics-job:"
    "notification:"
    "frontend:3000"
)

declare -A PIDS

cleanup() {
    echo
    echo "Stopping all services..."
    for name in "${!PIDS[@]}"; do
        pid="${PIDS[$name]}"
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping $name (PID $pid)..."
            kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        fi
    done
    sleep 3
    for name in "${!PIDS[@]}"; do
        pid="${PIDS[$name]}"
        if kill -0 "$pid" 2>/dev/null; then
            echo "Force killing $name (PID $pid)..."
            kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
        fi
    done
    echo "All services stopped."
    exit 0
}

port_is_up() {
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk '{print $4}' | grep -qE ":[0-9]+$" &&
            ss -ltn | tr -s ' ' | cut -d' ' -f4 | grep -qE ":\b$1$"
    elif command -v nc >/dev/null 2>&1; then
        nc -z localhost "$1" >/dev/null 2>&1
    else
        command -v curl >/dev/null 2>&1 &&
            curl -sf "http://localhost:$1" >/dev/null 2>&1
    fi
}

readiness_report() {
    echo
    echo "Waiting for services to come up..."
    sleep 15
    echo
    echo "===== Service Status ====="
    for entry in "${SERVICES[@]}"; do
        name="${entry%%:*}"
        port="${entry##*:}"
        if [[ -n "$port" ]]; then
            if port_is_up "$port"; then
                echo "  $name         : PORT $port  UP"
            else
                echo "  $name         : PORT $port  DOWN  -> tail logs/$name.log"
            fi
        else
            echo "  $name         : no port   (check logs/$name.log)"
        fi
    done
    echo "=========================="
}

trap cleanup INT TERM

mkdir -p "$LOG_DIR"

for entry in "${SERVICES[@]}"; do
    name="${entry%%:*}"
    script="$ROOT_DIR/run-$name.sh"

    if [[ ! -x "$script" ]]; then
        echo "WARNING: $script not found or not executable, skipping $name."
        continue
    fi

    echo "Starting $name -> logs/$name.log"
    (
        cd "$ROOT_DIR"
        "./run-$name.sh"
    ) >"$LOG_DIR/$name.log" 2>&1 &
    PIDS[$name]=$!
done

readiness_report

echo
echo "All services launched. Press Ctrl+C to stop everything."
echo "Logs are in: $LOG_DIR"
echo

wait
