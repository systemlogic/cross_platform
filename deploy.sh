#!/usr/bin/env bash
# deploy.sh
#
# Builds Docker images for Bazel server targets affected by the last commit
# and deploys them as Knative services via `kn`.
#
# Usage:
#   ./deploy.sh
#   IMAGE_REGISTRY=docker.io/myuser ./deploy.sh
#   IMAGE_REGISTRY=myregistry.example.com BUILD_CONFIG=x86_64 KN_NAMESPACE=prod ./deploy.sh
#
# Environment variables:
#   IMAGE_REGISTRY   Registry prefix for Docker images
#                    Default: localhost:5001  (local registry auto-started)
#                    For real clusters set this to a reachable registry, e.g. docker.io/myuser
#   BUILD_CONFIG     Bazel platform config used to compile Linux binaries
#                    Default: arm64  (matches Docker Desktop on Apple Silicon; use x86_64 for Intel/prod)
#   KN_NAMESPACE     Kubernetes namespace for Knative services  (default: default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAZEL="${SCRIPT_DIR}/bazel"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-localhost:5001}"
BUILD_CONFIG="${BUILD_CONFIG:-arm64}"
KN_NAMESPACE="${KN_NAMESPACE:-default}"

# ── Colours ───────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log()  { echo -e "${CYAN}[deploy]${RESET} $*"; }
ok()   { echo -e "${GREEN}[deploy]${RESET} $*"; }
warn() { echo -e "${YELLOW}[deploy]${RESET} $*"; }
die()  { echo -e "${RED}[deploy]${RESET} $*" >&2; exit 1; }

# ── Prerequisite checks ────────────────────────────────────────────────────────
for cmd in docker kn; do
    command -v "$cmd" &>/dev/null || die "Required tool not found: $cmd"
done

# ── Local registry setup ──────────────────────────────────────────────────────
# If IMAGE_REGISTRY is localhost:<port>, ensure a local registry container is running.
# Knative/K8s pods can't reach the host's 'localhost', so we also derive the in-cluster
# address (host.docker.internal:<port>) used when creating/updating kn services.
KN_IMAGE_PREFIX="$IMAGE_REGISTRY"

ensure_local_registry() {
    [[ "$IMAGE_REGISTRY" != localhost:* ]] && return 0

    local port="${IMAGE_REGISTRY##*:}"
    KN_IMAGE_PREFIX="host.docker.internal:${port}"  # accessible from within K8s pods

    if docker ps --filter "name=local-registry" --filter "status=running" -q | grep -q .; then
        log "Local registry already running at ${IMAGE_REGISTRY}"
        return 0
    fi

    log "Starting local Docker registry on port ${port}..."
    docker run -d --name local-registry --restart=always \
        -p "${port}:5000" registry:2 &>/dev/null \
        || docker start local-registry &>/dev/null \
        || die "Could not start local registry on port ${port}"
    ok "Local registry started at ${IMAGE_REGISTRY}"
}

# ── Target parsing ─────────────────────────────────────────────────────────────
# Input:  //examples/go/grpc_server:server
# Sets:   SVC_NAME  SVC_LANG  SVC_PKG  SVC_TGT
parse_target() {
    local target="$1"
    local pkg="${target#//}"   # examples/go/grpc_server:server
    pkg="${pkg%:*}"            # examples/go/grpc_server
    local tgt="${target##*:}"  # server

    local lang="unknown"
    [[ "$pkg" == *"/go/"*     ]] && lang="go"
    [[ "$pkg" == *"/java/"*   ]] && lang="java"
    [[ "$pkg" == *"/python/"* ]] && lang="python"

    local leaf
    leaf="$(basename "$pkg" | tr '_' '-')"  # grpc-server

    SVC_NAME="${lang}-${leaf}"   # go-grpc-server
    SVC_LANG="$lang"
    SVC_PKG="$pkg"
    SVC_TGT="$tgt"
}

# ── Bazel build ────────────────────────────────────────────────────────────────
# For Java, build the _deploy.jar (self-contained fat JAR).
# For Go/Python, build the binary directly.
# Sets: BINARY_PATH
build_bazel_target() {
    local target="$1" lang="$2" pkg="$3" tgt="$4"

    local build_target="$target"
    [[ "$lang" == "java" ]] && build_target="${target%:*}:${tgt}_deploy.jar"

    log "Building ${build_target} (--config=${BUILD_CONFIG})..."
    "${BAZEL}" build --config="${BUILD_CONFIG}" "$build_target"

    # bazel cquery --output=files returns a path relative to the execution_root.
    # This handles platform-transition output dirs (e.g. arm64-fastbuild-ST-*).
    local execroot rel_path
    execroot="$("${BAZEL}" info execution_root 2>/dev/null)"
    rel_path="$("${BAZEL}" cquery --config="${BUILD_CONFIG}" --output=files \
        "$build_target" 2>/dev/null | head -1)"

    [[ -n "$rel_path" ]] || die "cquery returned no files for ${build_target}"
    BINARY_PATH="${execroot}/${rel_path}"
    [[ -f "$BINARY_PATH" ]] || die "Binary not found at ${BINARY_PATH}"
    log "Binary: ${BINARY_PATH}"
}

# ── Dockerfile generation ──────────────────────────────────────────────────────
write_dockerfile() {
    local dir="$1" lang="$2"

    case "$lang" in
        go)
            # pure=on → fully static binary; runs from scratch with no runtime deps
            cat > "${dir}/Dockerfile" <<'EOF'
FROM scratch
COPY binary /server
EXPOSE 50051
ENTRYPOINT ["/server"]
EOF
            ;;
        java)
            cat > "${dir}/Dockerfile" <<'EOF'
FROM eclipse-temurin:21-jre-alpine
COPY binary /app/server.jar
EXPOSE 50051
ENTRYPOINT ["java", "-jar", "/app/server.jar"]
EOF
            ;;
        python)
            cat > "${dir}/Dockerfile" <<'EOF'
FROM python:3.12-alpine
COPY binary /app/server
RUN chmod +x /app/server
EXPOSE 50051
ENTRYPOINT ["/app/server"]
EOF
            ;;
        *)
            die "No Dockerfile template for language: ${lang}"
            ;;
    esac
}

# ── Docker image build + push ──────────────────────────────────────────────────
build_and_push_image() {
    local image="$1" binary_path="$2" lang="$3"

    local tmpdir
    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf ${tmpdir}" RETURN

    cp "$binary_path" "${tmpdir}/binary"
    write_dockerfile "$tmpdir" "$lang"

    # Derive linux platform from BUILD_CONFIG
    local platform="linux/amd64"
    [[ "$BUILD_CONFIG" == arm64 || "$BUILD_CONFIG" == aarch64 ]] && platform="linux/arm64"

    log "Building Docker image ${image} (platform=${platform})..."
    docker build --platform "$platform" -t "$image" "$tmpdir"
    ok "Image built: ${image}"

    log "Pushing ${image}..."
    docker push "$image"
    ok "Pushed: ${image}"
}

# ── Knative service deploy ─────────────────────────────────────────────────────
deploy_service() {
    local svc="$1" image="$2"

    # gRPC over h2c (cleartext HTTP/2) — required for gRPC Knative services
    local port_arg="h2c:50051"

    if kn service describe "$svc" --namespace "$KN_NAMESPACE" &>/dev/null 2>&1; then
        log "Updating Knative service '${svc}'..."
        kn service update "$svc" \
            --image "$image" \
            --namespace "$KN_NAMESPACE"
    else
        log "Creating Knative service '${svc}'..."
        kn service create "$svc" \
            --image "$image" \
            --port "$port_arg" \
            --namespace "$KN_NAMESPACE"
    fi

    ok "Service '${svc}' deployed. URL:"
    kn service describe "$svc" --namespace "$KN_NAMESPACE" \
        --output jsonpath='{.status.url}' 2>/dev/null && echo
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    log "IMAGE_REGISTRY=${IMAGE_REGISTRY}  BUILD_CONFIG=${BUILD_CONFIG}  KN_NAMESPACE=${KN_NAMESPACE}"

    log "Reading affected server targets..."
    mapfile -t TARGETS < <(
        "${SCRIPT_DIR}/affected_server_targets.sh" 2>&1 \
            | grep -E '^\s+//examples/' \
            | sed 's/^[[:space:]]*//'
    )

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        warn "No affected server targets — nothing to deploy."
        exit 0
    fi

    log "Affected targets (${#TARGETS[@]}): ${TARGETS[*]}"
    ensure_local_registry

    for target in "${TARGETS[@]}"; do
        echo ""
        parse_target "$target"
        log "=== ${target}  →  service: ${SVC_NAME}  lang: ${SVC_LANG} ==="

        build_bazel_target "$target" "$SVC_LANG" "$SVC_PKG" "$SVC_TGT"

        local push_image="${IMAGE_REGISTRY}/${SVC_NAME}:latest"
        local kn_image="${KN_IMAGE_PREFIX}/${SVC_NAME}:latest"

        build_and_push_image "$push_image" "$BINARY_PATH" "$SVC_LANG"
        deploy_service "$SVC_NAME" "$kn_image"
    done

    echo ""
    ok "All deployments complete."
    log "Services:"
    kn service list --namespace "$KN_NAMESPACE" 2>/dev/null || true
}

main "$@"
