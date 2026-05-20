#!/bin/bash
# =============================================================================
# AGIROS Loong Multistage Build & Push Script
# =============================================================================
# Usage:
#   ./build.sh                                # Build all stages locally
#   ./build.sh base                           # Build base only
#   ./build.sh base,desktop-full              # Build multiple specific targets
#   ./build.sh dev                            # Build base + dev
#   TARGET=base,desktop-full ./build.sh       # Via env var
#
# Push to Harbor (requires login):
#   ./build.sh --push base
#   ./build.sh --push --platform linux/amd64,linux/arm64 base,desktop-full
#   PUSH=true TARGET=desktop-full ./build.sh
#
# Env vars:
#   REGISTRY        Harbor registry (default: docker.agiros.org.cn)
#   PLATFORMS       Comma-separated platforms (default: current arch)
#   PUSH            Set to "true" to push to registry
#   PUSH_TAG        Tag override (default: latest)
#   BUILDKIT_JOBS   Max parallel build steps (default: auto)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 计算到仓库根目录的相对路径
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile.agiros-multistage"
ALL_TARGETS=("base" "dev" "desktop" "desktop-full")

# --- Configuration ---
REGISTRY="${REGISTRY:-docker.agiros.org.cn}"
REPO="${REGISTRY}/agiros/agiros-loong-ubuntu"
PLATFORMS="${PLATFORMS:-}"
PUSH="${PUSH:-false}"
PUSH_TAG="${PUSH_TAG:-latest}"
BUILDKIT_JOBS="${BUILDKIT_JOBS:-}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }
info()  { echo -e "${CYAN}[.]${NC} $*"; }

# -----------------------------------------------------------------------------
# Parse CLI args
# -----------------------------------------------------------------------------
TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --push)       PUSH=true; shift ;;
        --platform)   PLATFORMS="$2"; shift 2 ;;
        --tag)        PUSH_TAG="$2"; shift 2 ;;
        *)            TARGET="$1"; shift ;;
    esac
done

TARGET="${TARGET:-}"

# -----------------------------------------------------------------------------
# Prerequisites check
# -----------------------------------------------------------------------------
check_prereqs() {
    if [ ! -f "${DOCKERFILE}" ]; then
        err "Dockerfile not found: ${DOCKERFILE}"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        err "docker not found in PATH"
        exit 1
    fi

}

# -----------------------------------------------------------------------------
# Resolve targets — parse comma-separated list, validate, order by dependency
# -----------------------------------------------------------------------------
resolve_targets() {
    local raw="$1"
    local -n result=$2
    result=()

    if [ -z "${raw}" ]; then
        result=("${ALL_TARGETS[@]}")
        return
    fi

    # Parse comma-separated
    IFS=',' read -ra selected <<< "${raw}"
    for t in "${selected[@]}"; do
        t=$(echo "$t" | xargs)  # trim whitespace
        local valid=false
        for valid_t in "${ALL_TARGETS[@]}"; do
            if [ "$t" = "$valid_t" ]; then
                valid=true
                break
            fi
        done
        if [ "$valid" = false ]; then
            err "Invalid target: $t (valid: ${ALL_TARGETS[*]})"
            exit 1
        fi
        result+=("$t")
    done

    # Deduplicate while preserving order
    local -A seen
    local deduped=()
    for t in "${result[@]}"; do
        if [ -z "${seen[$t]:-}" ]; then
            deduped+=("$t")
            seen[$t]=1
        fi
    done
    result=("${deduped[@]}")
}

# -----------------------------------------------------------------------------
# Check that CA cert is installed (for push mode)
# -----------------------------------------------------------------------------
ensure_ca_cert() {
    local cert_src="/etc/docker/certs.d/${REGISTRY}/ca.crt"
    if [ -f "${cert_src}" ]; then
        return 0
    fi
    err "Harbor CA cert not found at ${cert_src}"
    err ""
    err "  sudo mkdir -p /etc/docker/certs.d/${REGISTRY}"
    err "  sudo cp <harbor-ca.crt> /etc/docker/certs.d/${REGISTRY}/ca.crt"
    err ""
    exit 1
}

# -----------------------------------------------------------------------------
# Setup buildx builder for multi-arch push (docker-container driver + cert inject)
# -----------------------------------------------------------------------------
setup_multiarch_builder() {
    local builder_name="agiros-loong-multiarch"

    if docker buildx ls 2>/dev/null | grep -q "${builder_name}"; then
        docker buildx use "${builder_name}" 2>/dev/null || true
    else
        ensure_ca_cert
        log "Creating buildx builder '${builder_name}' (docker-container, network=host)"
        docker buildx create \
            --name "${builder_name}" \
            --driver docker-container \
            --driver-opt network=host \
            --use
    fi

    # Bootstrap to start the buildkit container (handles new + previously-created but inactive)
    docker buildx inspect --bootstrap "${builder_name}" > /dev/null 2>&1

    # Inject CA cert into builder's system trust store (skip if already injected)
    local cid
    cid=$(docker ps --filter "name=buildx_buildkit_${builder_name}" --format "{{.Names}}" | head -1)
    if [ -z "${cid}" ]; then
        err "Builder container not found — cannot inject CA cert"
        exit 1
    fi

    if docker exec "$cid" grep -q "Harbor" /etc/ssl/certs/ca-certificates.crt 2>/dev/null; then
        log "Harbor CA cert already present in builder"
    else
        local cert_src="/etc/docker/certs.d/${REGISTRY}/ca.crt"
        docker exec -i "$cid" tee -a /etc/ssl/certs/ca-certificates.crt < "${cert_src}" > /dev/null
        log "Harbor CA cert injected into builder"
    fi
}

# -----------------------------------------------------------------------------
# Build a single stage
# -----------------------------------------------------------------------------
build_stage() {
    local stage="$1"
    local local_tag="agiros:loong-${stage}"
    local push_tag="${REPO}-${stage}:${PUSH_TAG}"

    log "Building stage: ${stage}"

    if [ "$PUSH" = "true" ]; then
        if [ -n "${PLATFORMS}" ]; then
            # Multi-arch: needs docker-container driver + QEMU + cert injection
            setup_multiarch_builder
            local args=(
                --file "${DOCKERFILE}"
                --target "${stage}"
                --tag "${push_tag}"
                --platform "${PLATFORMS}"
            )
        else
            # Single-arch: use docker driver (reads /etc/docker/certs.d/ natively)
            ensure_ca_cert
            local args=(
                --file "${DOCKERFILE}"
                --target "${stage}"
                --tag "${push_tag}"
            )
            # Ensure buildx uses the default docker driver
            docker buildx use default 2>/dev/null || true
        fi

        log "Pushing to: ${push_tag}"
        docker buildx build "${args[@]}" --push "${REPO_ROOT}"
        log "Pushed: ${push_tag}"
    else
        local args=(-f "${DOCKERFILE}" --target "${stage}" -t "${local_tag}")
        [ -n "${PLATFORMS}" ] && args+=(--platform "${PLATFORMS}")

        docker build "${args[@]}" "${REPO_ROOT}"
        log "Built: ${local_tag}"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    check_prereqs

    local targets=()
    resolve_targets "${TARGET}" targets

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  AGIROS Loong Multistage Build${NC}"
    echo -e "${GREEN}============================================${NC}"
    info "Dockerfile : ${DOCKERFILE}"
    info "Targets    : ${targets[*]}"
    info "Platforms  : ${PLATFORMS:-default (current arch)}"
    info "Push       : ${PUSH}"
    [ "$PUSH" = "true" ] && info "Registry   : ${REPO}-<stage>:${PUSH_TAG}"
    echo ""

    for stage in "${targets[@]}"; do
        build_stage "${stage}"
    done

    echo ""
    log "Done."
    if [ "$PUSH" = "false" ]; then
        log ""
        log "Run with docker compose:"
        log "  cd ${SCRIPT_DIR}"
        log "  TARGET=<stage> docker compose -f docker-compose.agiros.yml up -d"
    fi
}

main "$@"
