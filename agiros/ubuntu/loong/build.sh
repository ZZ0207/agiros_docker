#!/bin/bash
# =============================================================================
# AGIROS Loong Multistage Build & Push Script
# =============================================================================
# Usage:
#   ./build.sh                                # Build all stages locally
#   ./build.sh base                           # Build base only
#   ./build.sh dev                            # Build base + dev
#   ./build.sh desktop-full                   # Build all stages
#   TARGET=desktop ./build.sh                 # Via env var
#
# Push to Harbor (requires login):
#   ./build.sh --push base
#   ./build.sh --push --platform linux/amd64,linux/arm64 desktop-full
#   PUSH=true TARGET=desktop-full ./build.sh
#
# Env vars:
#   REGISTRY        Harbor registry (default: docker.agiros.org.cn)
#   PLATFORMS       Comma-separated platforms (default: current arch)
#   PUSH            Set to "true" to push to registry
#   PUSH_TAG         Tag override (default: latest, or branch name)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile.agiros-multistage"
TARGETS=("base" "dev" "desktop" "desktop-full")

# --- Configuration ---
REGISTRY="${REGISTRY:-docker.agiros.org.cn}"
REPO="${REGISTRY}/agiros/agiros-loong-ubuntu"
PLATFORMS="${PLATFORMS:-}"
PUSH="${PUSH:-false}"
PUSH_TAG="${PUSH_TAG:-latest}"

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
PARAMS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --push)
            PUSH=true
            shift
            ;;
        --platform)
            PLATFORMS="$2"
            shift 2
            ;;
        --tag)
            PUSH_TAG="$2"
            shift 2
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Env var overrides CLI positional
TARGET="${TARGET:-${TARGET:-}}"

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
        # Check Harbor cert trust
        local cert_dir="/etc/docker/certs.d/${REGISTRY}"
        if [ ! -f "${cert_dir}/ca.crt" ]; then
            warn "Harbor CA cert not found at ${cert_dir}/ca.crt"
            warn "If the registry uses a self-signed cert, install it first:"
            warn "  sudo mkdir -p ${cert_dir}"
            warn "  sudo cp <harbor-ca.crt> ${cert_dir}/ca.crt"
        fi

        # Check login
        if ! docker info 2>/dev/null | grep -q "${REGISTRY}"; then
            info "Not logged in to ${REGISTRY}"
            info "Run: docker login ${REGISTRY}"
            info ""
        fi
    fi
}

# -----------------------------------------------------------------------------
# Setup buildx builder for multi-arch push (docker-container driver)
# -----------------------------------------------------------------------------
setup_builder() {
    local builder_name="agiros-loong-builder"

    if docker buildx ls | grep -q "${builder_name}"; then
        info "Buildx builder '${builder_name}' already exists, reusing"
        docker buildx use "${builder_name}"
    else
        log "Creating buildx builder '${builder_name}' (docker-container driver)"
        docker buildx create \
            --name "${builder_name}" \
            --driver docker-container \
            --use

        # Inject Harbor CA cert into builder container
        local cert_src="/etc/docker/certs.d/${REGISTRY}/ca.crt"
        if [ -f "${cert_src}" ]; then
            sleep 2  # wait for builder container to start
            local container=$(docker ps --filter "name=buildx_buildkit_${builder_name}" --format "{{.Names}}" | head -1)
            if [ -n "${container}" ]; then
                docker exec "${container}" mkdir -p /etc/buildkit/certs
                docker cp "${cert_src}" "${container}:/etc/buildkit/certs/harbor-ca.crt"
                docker exec "${container}" chmod 644 /etc/buildkit/certs/harbor-ca.crt
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
        # --- Push mode: use buildx with remote tag ---
        setup_builder

        local buildx_args=(
            --file "${DOCKERFILE}"
            --target "${stage}"
            --tag "${push_tag}"
        )

        if [ -n "${PLATFORMS}" ]; then
            buildx_args+=(--platform "${PLATFORMS}")
        fi

        # buildkitd config for isolated builder
        local buildkitd_config="/tmp/buildkitd-agiros.toml"
        printf '[registry."%s"]\n  http = false\n  insecure = false\n  ca = ["/etc/buildkit/certs/harbor-ca.crt"]\n' \
            "${REGISTRY}" > "${buildkitd_config}"

        log "Pushing to: ${push_tag}"
        docker buildx build \
            "${buildx_args[@]}" \
            --push \
            .

        log "Pushed: ${push_tag}"
    else
        # --- Local mode: plain docker build ---
        local tag_args=(-t "${local_tag}")
        if [ -n "${PLATFORMS}" ]; then
            tag_args+=(--platform "${PLATFORMS}")
        fi

        docker build \
            -f "${DOCKERFILE}" \
            --target "${stage}" \
            "${tag_args[@]}" \
            .

        log "Built: ${local_tag}"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    check_prereqs

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  AGIROS Loong Multistage Build${NC}"
    echo -e "${GREEN}============================================${NC}"
    info "Dockerfile : ${DOCKERFILE}"
    info "Target     : ${TARGET:-all}"
    info "Platforms  : ${PLATFORMS:-default (current arch)}"
    info "Push       : ${PUSH}"
    if [ "$PUSH" = "true" ]; then
        info "Registry   : ${REGISTRY}"
        info "Repo       : ${REPO}-<stage>"
        info "Tag        : ${PUSH_TAG}"
    fi
    echo ""

    if [ -n "${TARGET}" ]; then
        for stage in "${TARGETS[@]}"; do
            build_stage "${stage}"
            if [ "${stage}" = "${TARGET}" ]; then
                break
            fi
        done
    else
        for stage in "${TARGETS[@]}"; do
            build_stage "${stage}"
        done
    fi

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
