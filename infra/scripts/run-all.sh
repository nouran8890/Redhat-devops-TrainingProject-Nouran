#!/usr/bin/env bash
#
# infra/scripts/run-all.sh
#
# Builds and runs the whole EventHub system by hand with plain `podman`
# commands (no Compose). Run from anywhere -- paths are resolved relative
# to this script's location, assuming the layout:
#
#   <repo-root>/
#     services/<name>/Containerfile
#     frontend/Containerfile          (adjust FRONTEND_DIR below if different)
#     infra/scripts/run-all.sh        (this file)
#     infra/.env                      (optional overrides, see bottom of this file)
#
set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SERVICES_DIR="$REPO_ROOT/services"
FRONTEND_DIR="$REPO_ROOT/frontend"        # <-- adjust if your frontend lives elsewhere

ENV_FILE="$SCRIPT_DIR/../.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

# Config (all overridable via infra/.env -- nothing here is baked into an image)
NETWORK="eventhub-net"
TAG="phase2"

POSTGRES_DB="${POSTGRES_DB:-eventhub_auth}"
POSTGRES_USER="${POSTGRES_USER:-eventhub}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-eventhub}"

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root123}"
MYSQL_DATABASE="${MYSQL_DATABASE:-eventhub_catalog}"

JWT_SECRET="${JWT_SECRET:-change-me-in-phase2}"

# Helpers
log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m   ! %s\033[0m\n' "$*"; }

# Poll a TCP port on localhost until it accepts connections (or time out).
wait_for_port() {
  local name="$1" port="$2" timeout="${3:-60}"
  log "Waiting for $name on localhost:$port (timeout ${timeout}s)"
  local waited=0
  until (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; do
    exec 3>&- 2>/dev/null || true
    sleep 2; waited=$((waited + 2))
    if (( waited >= timeout )); then
      echo "Timed out waiting for $name on port $port" >&2
      exit 1
    fi
  done
  exec 3>&- 2>/dev/null || true
  echo "   $name is accepting connections."
}

# Poll a readiness command run *inside* a container until it succeeds.
wait_for_container_cmd() {
  local container="$1" timeout="${2:-60}"; shift 2
  log "Waiting for $container to report ready (timeout ${timeout}s)"
  local waited=0
  until podman exec "$container" "$@" &>/dev/null; do
    sleep 2; waited=$((waited + 2))
    if (( waited >= timeout )); then
      echo "Timed out waiting for $container to become ready" >&2
      podman logs --tail 40 "$container" >&2 || true
      exit 1
    fi
  done
  echo "   $container is ready."
}

container_exists() { podman container exists "$1"; }
network_exists()   { podman network exists "$1"; }

# 1. Network
log "Creating network $NETWORK"
network_exists "$NETWORK" || podman network create "$NETWORK"


log "Creating network $NETWORK"
network_exists "$NETWORK" || podman network create "$NETWORK"

# Pin the CNI conflist to version 0.4.0 (podman defaults to a newer version)
CNI_CONF_DIR="${CNI_CONF_DIR:-$HOME/.config/cni/net.d}"
CNI_CONF_FILE="$CNI_CONF_DIR/$NETWORK.conflist"
if [[ -f "$CNI_CONF_FILE" ]]; then
  jq '.cniVersion = "0.4.0"' "$CNI_CONF_FILE" > "$CNI_CONF_FILE.tmp" \
    && mv "$CNI_CONF_FILE.tmp" "$CNI_CONF_FILE"
  log "Pinned $NETWORK conflist to cniVersion 0.4.0"
else
  warn "Expected CNI conflist not found at $CNI_CONF_FILE — check network_backend and CNI_CONF_DIR"
fi

# 2. Datastores (fixed names, persistent volumes, on the network)
log "Starting datastores"

podman volume create postgres_data >/dev/null 2>&1 || true
podman volume create mysql_data    >/dev/null 2>&1 || true
podman volume create mongo_data    >/dev/null 2>&1 || true

if ! container_exists postgres-db; then
  podman run -d --name postgres-db --network "$NETWORK" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -v postgres_data:/var/lib/postgresql/data \
    --health-cmd "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB" \
    --health-interval 5s --health-timeout 3s --health-retries 10 \
    docker.io/library/postgres:16
fi

if ! container_exists mysql-db; then
  podman run -d --name mysql-db --network "$NETWORK" \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DATABASE" \
    -v mysql_data:/var/lib/mysql \
    --health-cmd "mysqladmin ping -uroot -p$MYSQL_ROOT_PASSWORD --silent" \
    --health-interval 5s --health-timeout 3s --health-retries 10 \
    docker.io/library/mysql:8.0
fi

if ! container_exists mongodb; then
  podman run -d --name mongodb --network "$NETWORK" \
    -v mongo_data:/data/db \
    --health-cmd "mongosh --quiet --eval 'db.adminCommand(\"ping\")'" \
    --health-interval 5s --health-timeout 3s --health-retries 10 \
    docker.io/library/mongo:7
fi

if ! container_exists redis; then
  podman run -d --name redis --network "$NETWORK" \
    --health-cmd "redis-cli ping" \
    --health-interval 5s --health-timeout 3s --health-retries 10 \
    docker.io/library/redis:7
fi

if ! container_exists rabbitmq; then
  podman run -d --name rabbitmq --network "$NETWORK" \
    --health-cmd "rabbitmq-diagnostics -q ping" \
    --health-interval 5s --health-timeout 3s --health-retries 10 \
    docker.io/library/rabbitmq:3-management
fi

wait_for_container_cmd postgres-db 60 pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
wait_for_container_cmd mysql-db    90 mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent
wait_for_container_cmd mongodb     60 mongosh --quiet --eval "db.adminCommand('ping')"
wait_for_container_cmd redis       30 redis-cli ping
wait_for_container_cmd rabbitmq    60 rabbitmq-diagnostics -q ping

# 3. Build images
log "Building service images"
podman build -t localhost/auth-service-image:"$TAG"         "$SERVICES_DIR/auth-service-node"
podman build -t localhost/catalog-service-image:"$TAG"      "$SERVICES_DIR/legacy-catalog-java"
podman build -t localhost/booking-service-image:"$TAG"      "$SERVICES_DIR/booking-service-python"
podman build -t localhost/analytics-service-image:"$TAG"    "$SERVICES_DIR/analytics-service-python"
podman build -t localhost/ai-insight-service-image:"$TAG"   "$SERVICES_DIR/ai-insight-service-python"
podman build -t localhost/notification-worker-image:"$TAG"  "$SERVICES_DIR/notification-worker-go"
podman build -t localhost/eventhub-frontend-image:"$TAG"    "$FRONTEND_DIR"

# 4. Application services
log "Starting ai-insight-service (no datastore dependency)"
if ! container_exists ai-insight-service-container; then
  podman run -d --name ai-insight-service-container --network "$NETWORK" \
    -p 8084:8084 \
    -e PORT=8084 \
    --health-cmd "python -c \"import socket,sys; s=socket.socket(); s.settimeout(2); sys.exit(0 if s.connect_ex(('localhost',8084))==0 else 1)\"" \
    --health-interval 5s --health-timeout 3s --health-retries 10 --health-start-period 10s \
    localhost/ai-insight-service-image:"$TAG"
fi

log "Starting auth-service (depends on postgres-db)"
if ! container_exists auth-service-container; then
  podman run -d --name auth-service-container --network "$NETWORK" \
    -p 8082:8082 \
    -e PORT=8082 \
    -e PGHOST=postgres-db -e PGPORT=5432 \
    -e PGUSER="$POSTGRES_USER" -e PGPASSWORD="$POSTGRES_PASSWORD" -e PGDATABASE="$POSTGRES_DB" \
    -e JWT_SECRET="$JWT_SECRET" \
    --health-cmd "node -e \"require('net').connect(8082,'localhost').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))\"" \
    --health-interval 5s --health-timeout 3s --health-retries 10 --health-start-period 10s \
    localhost/auth-service-image:"$TAG"
fi

log "Starting catalog-service (depends on mysql-db)"
if ! container_exists catalog-service-container; then
  podman run -d --name catalog-service-container --network "$NETWORK" \
    -p 8081:8081 \
    -e SPRING_DATASOURCE_URL="jdbc:mysql://mysql-db:3306/$MYSQL_DATABASE" \
    -e SPRING_DATASOURCE_USERNAME=root \
    -e SPRING_DATASOURCE_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    --health-cmd "bash -c '</dev/tcp/localhost/8081'" \
    --health-interval 5s --health-timeout 3s --health-retries 10 --health-start-period 20s \
    localhost/catalog-service-image:"$TAG"
fi

wait_for_port ai-insight-service 8084
wait_for_port catalog-service 8081 90

log "Starting booking-service (depends on mongodb, rabbitmq, ai-insight-service)"
if ! container_exists booking-service-container; then
  podman run -d --name booking-service-container --network "$NETWORK" \
    -p 8083:8083 \
    -e PORT=8083 \
    -e MONGO_URI="mongodb://mongodb:27017" -e MONGO_DB=eventhub_bookings \
    -e RABBITMQ_URL="amqp://guest:guest@rabbitmq:5672/" -e RABBITMQ_QUEUE=bookings \
    -e AI_INSIGHT_URL="http://ai-insight-service-container:8084" \
    --health-cmd "python -c \"import socket,sys; s=socket.socket(); s.settimeout(2); sys.exit(0 if s.connect_ex(('localhost',8083))==0 else 1)\"" \
    --health-interval 5s --health-timeout 3s --health-retries 10 --health-start-period 10s \
    localhost/booking-service-image:"$TAG"
fi

wait_for_port booking-service 8083

log "Starting analytics-service (depends on redis, booking-service, catalog-service)"
if ! container_exists analytics-service-container; then
  podman run -d --name analytics-service-container --network "$NETWORK" \
    -p 8085:8085 \
    -e PORT=8085 \
    -e REDIS_URL="redis://redis:6379/0" \
    -e BOOKING_SERVICE_URL="http://booking-service-container:8083" \
    -e CATALOG_SERVICE_URL="http://catalog-service-container:8081" \
    -e SNAPSHOT_KEY="analytics:snapshot" \
    --health-cmd "python -c \"import socket,sys; s=socket.socket(); s.settimeout(2); sys.exit(0 if s.connect_ex(('localhost',8085))==0 else 1)\"" \
    --health-interval 5s --health-timeout 3s --health-retries 10 --health-start-period 10s \
    localhost/analytics-service-image:"$TAG"
fi

log "Starting notification-worker (depends on rabbitmq)"
if ! container_exists notification-worker-container; then
  podman run -d --name notification-worker-container --network "$NETWORK" \
    -e RABBITMQ_URL="amqp://guest:guest@rabbitmq:5672/" -e RABBITMQ_QUEUE=bookings \
    --health-cmd "pgrep -f notification-worker || exit 1" \
    --health-interval 10s --health-timeout 3s --health-retries 5 --health-start-period 10s \
    localhost/notification-worker-image:"$TAG"
fi

wait_for_port analytics-service 8085

log "Starting frontend (proxies to all backend services)"
if ! container_exists frontend-container; then
  podman run -d --name frontend-container --network "$NETWORK" \
    -p 3000:80 \
    --health-cmd "wget --spider -q http://localhost:80/ || exit 1" \
    --health-interval 10s --health-timeout 3s --health-retries 5 --health-start-period 5s \
    localhost/eventhub-frontend-image:"$TAG"
fi

wait_for_port frontend 3000

# 5. Seed analytics data so the dashboard has something to show
log "Running the analytics job once"
podman run --rm --network "$NETWORK" \
  -e REDIS_URL="redis://redis:6379/0" \
  -e BOOKING_SERVICE_URL="http://booking-service-container:8083" \
  -e CATALOG_SERVICE_URL="http://catalog-service-container:8081" \
  -e SNAPSHOT_KEY="analytics:snapshot" \
  localhost/analytics-service-image:"$TAG" python job.py

log "Done. Everything is up on network '$NETWORK'."
cat <<EOF

  Frontend:   http://localhost:3000
  Auth:       http://localhost:8082
  Catalog:    http://localhost:8081
  Booking:    http://localhost:8083
  AI Insight: http://localhost:8084
  Analytics:  http://localhost:8085

EOF