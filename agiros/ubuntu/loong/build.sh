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

    if [ "$PUSH" = "true" ]; then
        local cert_dir="/etc/docker/certs.d/${REGISTRY}"
        if [ ! -f "${cert_dir}/ca.crt" ]; then
            warn "Harbor CA cert not found at ${cert_dir}/ca.crt"
            warn "Install it first:"
            warn "  sudo mkdir -p ${cert_dir}"
            warn "  sudo cp <harbor-ca.crt> ${cert_dir}/ca.crt"
        fi
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
# Setup buildx builder for multi-arch push
# -----------------------------------------------------------------------------
setup_builder() {
    local builder_name="agiros-loong-builder"

    if docker buildx ls 2>/dev/null | grep -q "${builder_name}"; then
        docker buildx use "${builder_name}" 2>/dev/null || true
    else
        log "Creating buildx builder '${builder_name}' (docker-container driver)"
        docker buildx create \
            --name "${builder_name}" \
            --driver docker-container \
            --driver-opt network=host \
            --use

        # Inject Harbor CA cert into builder's system trust store
        local cert_src="/etc/docker/certs.d/${REGISTRY}/ca.crt"
        if [ -f "${cert_src}" ]; then
            sleep 2
            local cid
            cid=$(docker ps --filter "name=buildx_buildkit_${builder_name}" --format "{{.Names}}" | head -1)
            if [ -n "${cid}" ]; then
                docker exec -i "$cid" tee -a /etc/ssl/certs/ca-certificates.crt < "${cert_src}" > /dev/null
                log "Harbor CA cert injected into builder"
            fi
        fi
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
        setup_builder

        local args=(
            --file "${DOCKERFILE}"
            --target "${stage}"
            --tag "${push_tag}"
        )
        [ -n "${PLATFORMS}" ] && args+=(--platform "${PLATFORMS}")

        log "Pushing to: ${push_tag}"
        docker buildx build "${args[@]}" --push .
        log "Pushed: ${push_tag}"
    else
        local args=(-f "${DOCKERFILE}" --target "${stage}" -t "${local_tag}")
        [ -n "${PLATFORMS}" ] && args+=(--platform "${PLATFORMS}")

        docker build "${args[@]}" .
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

    # Setup builder once for push mode (inject cert before building)
    if [ "$PUSH" = "true" ]; then
        setup_builder
    fi

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
