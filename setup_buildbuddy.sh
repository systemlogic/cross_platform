#!/usr/bin/env bash
# Sets up BuildBuddy on-prem in Docker and keeps it running in the background.
#
# Linux (x86_64 + arm64): starts app + executor  → use --config=bb_linux
# macOS  (arm64 + x86_64): starts app only        → use --config=bb_macos
#
# Usage:
#   ./setup_buildbuddy.sh          # start / ensure running (includes metrics stack)
#   ./setup_buildbuddy.sh stop     # stop all BuildBuddy containers
#   ./setup_buildbuddy.sh status   # show container status
#   ./setup_buildbuddy.sh rm       # stop + remove all containers and local images

set -euo pipefail

# ── Images ───────────────────────────────────────────────────────────────────
APP_IMAGE="gcr.io/flame-public/buildbuddy-app-onprem:latest"
EXECUTOR_IMAGE="gcr.io/flame-public/buildbuddy-executor-onprem:latest"

PROMETHEUS_LOCAL_IMAGE="buildbuddy-prometheus:local"
GRAFANA_LOCAL_IMAGE="buildbuddy-grafana:local"

APP_NAME="buildbuddy-app"
EXECUTOR_NAME="buildbuddy-executor"
PROMETHEUS_CONTAINER="buildbuddy-prometheus"
GRAFANA_CONTAINER="buildbuddy-grafana"
NETWORK_NAME="buildbuddy-net"

GRPC_PORT=1985
HTTP_PORT=8080
MONITORING_PORT=9090
PROMETHEUS_HOST_PORT=9091
GRAFANA_PORT=3000

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_DIR="${SCRIPT_DIR}/metrics"

OS="$(uname -s)"
ARCH="$(uname -m)"

# ── Helpers ──────────────────────────────────────────────────────────────────
die() { echo "ERROR: $*" >&2; exit 1; }

ensure_network() {
    if ! docker network inspect "${NETWORK_NAME}" &>/dev/null; then
        echo "[network] Creating Docker network ${NETWORK_NAME}..."
        docker network create "${NETWORK_NAME}"
    fi
}

container_running() {
    docker ps \
        --filter "name=^/${1}$" \
        --filter "status=running" \
        --format '{{.Names}}' | grep -q "^${1}$"
}

container_exists() {
    docker ps -a \
        --filter "name=^/${1}$" \
        --format '{{.Names}}' | grep -q "^${1}$"
}

wait_for_port() {
    local port=$1 label=$2 retries=40
    echo -n "  Waiting for ${label} (port ${port}) ..."
    for _ in $(seq 1 ${retries}); do
        if nc -z localhost "${port}" 2>/dev/null; then
            echo " ready."
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " TIMEOUT."
    echo "  Check: docker logs ${APP_NAME}" >&2
    return 1
}

# ── Actions ──────────────────────────────────────────────────────────────────
start_app() {
    if container_running "${APP_NAME}"; then
        echo "[app] BuildBuddy app already running."
        # Ensure it's on the shared network (idempotent).
        docker network connect "${NETWORK_NAME}" "${APP_NAME}" 2>/dev/null || true
        return
    fi

    if container_exists "${APP_NAME}"; then
        echo "[app] Restarting stopped BuildBuddy app container..."
        docker start "${APP_NAME}"
    else
        echo "[app] Pulling ${APP_IMAGE} ..."
        docker pull "${APP_IMAGE}"
        echo "[app] Starting BuildBuddy app..."
        docker run -d \
            --name "${APP_NAME}" \
            --restart unless-stopped \
            --network "${NETWORK_NAME}" \
            -p "${GRPC_PORT}:${GRPC_PORT}" \
            -p "${HTTP_PORT}:${HTTP_PORT}" \
            -p "${MONITORING_PORT}:${MONITORING_PORT}" \
            "${APP_IMAGE}"
    fi

    # Ensure existing/restarted container is on the shared network (idempotent).
    docker network connect "${NETWORK_NAME}" "${APP_NAME}" 2>/dev/null || true

    wait_for_port "${HTTP_PORT}" "HTTP UI"
    wait_for_port "${GRPC_PORT}" "gRPC"
}

start_executor_linux() {
    if container_running "${EXECUTOR_NAME}"; then
        echo "[executor] BuildBuddy executor already running."
        return
    fi

    if container_exists "${EXECUTOR_NAME}"; then
        echo "[executor] Restarting stopped BuildBuddy executor container..."
        docker start "${EXECUTOR_NAME}"
    else
        echo "[executor] Pulling ${EXECUTOR_IMAGE} ..."
        docker pull "${EXECUTOR_IMAGE}"
        echo "[executor] Starting BuildBuddy executor (arch: ${ARCH})..."
        # Both containers share buildbuddy-net, so the app is reachable by container name.
        docker run -d \
            --name "${EXECUTOR_NAME}" \
            --restart unless-stopped \
            --privileged \
            --network "${NETWORK_NAME}" \
            -e SYS_MOUNT_INFO=1 \
            "${EXECUTOR_IMAGE}" \
            --executor.app_target=grpc://${APP_NAME}:${GRPC_PORT}
    fi
    echo "[executor] Executor started and connected to app on port ${GRPC_PORT}."
}

build_metrics_images() {
    echo "[metrics] Building Prometheus image..."
    docker build -t "${PROMETHEUS_LOCAL_IMAGE}" "${METRICS_DIR}" -f "${METRICS_DIR}/Dockerfile" --quiet
    echo "[metrics] Building Grafana image..."
    docker build -t "${GRAFANA_LOCAL_IMAGE}" "${METRICS_DIR}" -f "${METRICS_DIR}/Dockerfile.grafana" --quiet
}

start_metrics() {
    build_metrics_images

    if container_running "${PROMETHEUS_CONTAINER}"; then
        echo "[prometheus] Already running."
    elif container_exists "${PROMETHEUS_CONTAINER}"; then
        echo "[prometheus] Restarting stopped container..."
        docker start "${PROMETHEUS_CONTAINER}"
    else
        echo "[prometheus] Starting Prometheus..."
        docker run -d \
            --name "${PROMETHEUS_CONTAINER}" \
            --restart unless-stopped \
            --network "${NETWORK_NAME}" \
            -p "${PROMETHEUS_HOST_PORT}:9090" \
            "${PROMETHEUS_LOCAL_IMAGE}"
    fi
    docker network connect "${NETWORK_NAME}" "${PROMETHEUS_CONTAINER}" 2>/dev/null || true

    if container_running "${GRAFANA_CONTAINER}"; then
        echo "[grafana] Already running."
    elif container_exists "${GRAFANA_CONTAINER}"; then
        echo "[grafana] Restarting stopped container..."
        docker start "${GRAFANA_CONTAINER}"
    else
        echo "[grafana] Starting Grafana..."
        docker run -d \
            --name "${GRAFANA_CONTAINER}" \
            --restart unless-stopped \
            --network "${NETWORK_NAME}" \
            -p "${GRAFANA_PORT}:3000" \
            "${GRAFANA_LOCAL_IMAGE}"
    fi
    docker network connect "${NETWORK_NAME}" "${GRAFANA_CONTAINER}" 2>/dev/null || true

    wait_for_port "${GRAFANA_PORT}" "Grafana"
}

do_stop() {
    for name in "${APP_NAME}" "${EXECUTOR_NAME}" "${PROMETHEUS_CONTAINER}" "${GRAFANA_CONTAINER}"; do
        if container_running "${name}"; then
            echo "Stopping ${name}..."
            docker stop "${name}"
        fi
    done
    echo "Done."
}

do_rm() {
    do_stop
    for name in "${APP_NAME}" "${EXECUTOR_NAME}" "${PROMETHEUS_CONTAINER}" "${GRAFANA_CONTAINER}"; do
        if container_exists "${name}"; then
            echo "Removing container ${name}..."
            docker rm "${name}"
        fi
    done
    for image in "${PROMETHEUS_LOCAL_IMAGE}" "${GRAFANA_LOCAL_IMAGE}"; do
        if docker image inspect "${image}" &>/dev/null; then
            echo "Removing image ${image}..."
            docker rmi "${image}"
        fi
    done
    echo "Done."
}

do_status() {
    echo "=== BuildBuddy container status ==="
    docker ps -a \
        --filter "name=buildbuddy" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "=== Local metrics images ==="
    docker images --filter "reference=buildbuddy-prometheus" --filter "reference=buildbuddy-grafana" \
        --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
}

# ── Main ─────────────────────────────────────────────────────────────────────
command -v docker &>/dev/null || die "Docker is not installed or not in PATH."

CMD="${1:-start}"

case "${CMD}" in
    stop)   do_stop;   exit 0 ;;
    status) do_status; exit 0 ;;
    rm)     do_rm;     exit 0 ;;
    start)  ;;
    *) die "Unknown command '${CMD}'. Usage: $0 [start|stop|status|rm]" ;;
esac

echo "=== BuildBuddy on-prem setup (OS: ${OS}, arch: ${ARCH}) ==="

ensure_network
start_app

if [[ "${OS}" == "Linux" ]]; then
    start_executor_linux
fi

start_metrics

echo ""
echo "BuildBuddy is running."
echo "  Web UI        : http://localhost:${HTTP_PORT}"
echo "  gRPC          : grpc://localhost:${GRPC_PORT}"
echo "  Raw metrics   : http://localhost:${MONITORING_PORT}/metrics"
echo "  Prometheus    : http://localhost:${PROMETHEUS_HOST_PORT}"
echo "  Grafana       : http://localhost:${GRAFANA_PORT}  (admin / admin)"
echo ""
if [[ "${OS}" == "Linux" ]]; then
    echo "Use in Bazel (Linux — cache + RBE):"
    echo "  bazel build --config=bb_linux <target>"
else
    echo "Use in Bazel (macOS — cache only):"
    echo "  bazel build --config=bb_macos <target>"
fi
