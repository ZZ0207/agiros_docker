#!/bin/bash
# =============================================================================
# AGIROS Loong Multistage Build Script
# =============================================================================
# Usage:
#   ./build.sh                          # Build all stages
#   ./build.sh base                     # Build base only
#   ./build.sh dev                      # Build base + dev
#   ./build.sh desktop-full             # Build all stages
#   TARGET=desktop ./build.sh           # Via env var
#
# Multi-arch:
#   PLATFORMS=linux/amd64,linux/arm64 ./build.sh desktop-full
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile.agiros-multistage"
TARGETS=("base" "dev" "desktop" "desktop-full")
TARGET="${TARGET:-${1:-}}"
PLATFORMS="${PLATFORMS:-}"
PUSH="${PUSH:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# -----------------------------------------------------------------------------
# Build a single stage
# -----------------------------------------------------------------------------
build_stage() {
    local stage="$1"
    local tag="agiros:loong-${stage}"

    log "Building stage: ${stage} -> ${tag}"

    local build_args=(
        build
        -f "${DOCKERFILE}"
        --target "${stage}"
        -t "${tag}"
    )

    if [ -n "${PLATFORMS}" ]; then
        build_args+=(--platform "${PLATFORMS}")
        # For multi-arch, use buildx
        docker buildx "${build_args[@]}" .
    else
        docker "${build_args[@]}" .
    fi

    log "Stage ${stage} built successfully: ${tag}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    if [ ! -f "${DOCKERFILE}" ]; then
        err "Dockerfile not found: ${DOCKERFILE}"
        exit 1
    fi

    log "AGIROS Loong Multistage Build"
    log "Dockerfile: ${DOCKERFILE}"

    if [ -n "${TARGET}" ]; then
        # Build up to the specified target
        for stage in "${TARGETS[@]}"; do
            build_stage "${stage}"
            if [ "${stage}" = "${TARGET}" ]; then
                break
            fi
        done
    else
        # Build all stages
        for stage in "${TARGETS[@]}"; do
            build_stage "${stage}"
        done
    fi

    log "Build complete."
    log ""
    log "Run with docker compose:"
    log "  cd ${SCRIPT_DIR}"
    log "  TARGET=<stage> docker compose -f docker-compose.agiros.yml up -d"
}

main "$@"
