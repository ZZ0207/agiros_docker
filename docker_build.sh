#!/bin/bash
# Docker build script with submodule support, retry mechanism, and multi-arch support
# Usage: ./docker_build.sh [--push] [--no-retry] [--platform PLATFORMS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
PUSH=false
RETRY=true
PLATFORMS="linux/amd64,linux/arm64"
IMAGE_TAG="12.18"
DOCKERFILE="agiros/openeuler/Dockerfile-openeuler-loong"
IMAGE_NAME="agiros-loong-openeuler"
REGISTRY_IMAGE="crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com/jhaiq/agiros_docker"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --no-retry)
            RETRY=false
            shift
            ;;
        --platform)
            PLATFORMS="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --file)
            DOCKERFILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --push              Push image to registry after build"
            echo "  --no-retry          Disable retry on network errors"
            echo "  --platform PLATFORMS Set build platforms (default: linux/amd64,linux/arm64)"
            echo "  --tag TAG           Set image tag (default: 12.18)"
            echo "  --file DOCKERFILE   Set Dockerfile path (default: agiros/openeuler/Dockerfile-openeuler-loong)"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "=== Docker Build Script ==="
echo "Platforms: $PLATFORMS"
echo "Dockerfile: $DOCKERFILE"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Push to registry: $PUSH"
echo ""

# Step 1: Initialize git submodules
echo "Step 1: Initializing git submodules..."
if [ -f .gitmodules ]; then
    if git submodule status | grep -q "^\-"; then
        echo "Initializing submodules..."
        git submodule update --init --recursive
        echo "✓ Submodules initialized"
    else
        echo "✓ Submodules already initialized"
    fi
else
    echo "⚠ No .gitmodules file found, skipping submodule initialization"
fi

# Step 2: Ensure buildx builder exists and works
echo ""
echo "Step 2: Setting up Docker Buildx..."
setup_buildx() {
    if ! docker buildx inspect multiarch &>/dev/null; then
        echo "Creating buildx builder 'multiarch'..."
        docker buildx create --name multiarch --driver docker-container --use
        docker buildx inspect --bootstrap || {
            echo "Error: Failed to create buildx builder. You may need to fix Docker daemon configuration."
            echo "Run: sudo bash fix_docker_runtime.sh"
            exit 1
        }
        echo "✓ Buildx builder created"
    else
        docker buildx use multiarch
        # Try to bootstrap to check if it works
        if ! docker buildx inspect --bootstrap &>/dev/null; then
            echo "Warning: Builder exists but failed to start. Recreating..."
            docker buildx rm multiarch
            docker buildx create --name multiarch --driver docker-container --use
            docker buildx inspect --bootstrap || {
                echo "Error: Failed to recreate buildx builder. You may need to fix Docker daemon configuration."
                echo "Run: sudo bash fix_docker_runtime.sh"
                exit 1
            }
            echo "✓ Buildx builder recreated"
        else
            echo "✓ Using existing buildx builder"
        fi
    fi
}
setup_buildx

# Step 3: Build function with retry mechanism
echo ""
echo "Step 3: Building Docker image..."
build_image() {
    local build_args=(
        "buildx" "build"
        "--platform" "$PLATFORMS"
        "--progress=plain"
        "-t" "${IMAGE_NAME}:${IMAGE_TAG}"
        "-f" "$DOCKERFILE"
    )
    
    if [ "$PUSH" = true ]; then
        build_args+=(
            "--push"
            "-t" "${REGISTRY_IMAGE}:${IMAGE_TAG}"
            "-t" "${REGISTRY_IMAGE}:latest"
        )
    else
        build_args+=("--load")
    fi
    
    build_args+=(".")
    
    docker "${build_args[@]}"
}

# Retry function for network errors
retry_build() {
    local max_attempts=3
    local attempt=1
    local delay=5
    local log_file="/tmp/docker_build_$(date +%s).log"
    
    while [ $attempt -le $max_attempts ]; do
        echo ""
        echo "Build attempt $attempt of $max_attempts..."
        
        if build_image 2>&1 | tee "$log_file"; then
            echo ""
            echo "✓ Build successful!"
            rm -f "$log_file"
            return 0
        fi
        
        # Check if it's a network error
        if grep -qE "(EOF|timeout|connection|network|short read|failed to fetch)" "$log_file"; then
            if [ "$RETRY" = true ] && [ $attempt -lt $max_attempts ]; then
                echo ""
                echo "⚠ Network error detected. Waiting ${delay}s before retry..."
                sleep $delay
                delay=$((delay * 2))  # Exponential backoff
                attempt=$((attempt + 1))
                echo "Cleaning buildx cache before retry..."
                docker buildx prune -f || true
            else
                echo ""
                echo "✗ Build failed with network error after $attempt attempt(s)"
                rm -f "$log_file"
                return 1
            fi
        else
            echo ""
            echo "✗ Build failed with non-network error. See log: $log_file"
            return 1
        fi
    done
    
    echo ""
    echo "✗ Build failed after $max_attempts attempts"
    rm -f "$log_file"
    return 1
}

# Clean buildx cache before building
echo "Cleaning buildx cache..."
docker buildx prune -f || true

# Build with or without retry
if [ "$RETRY" = true ]; then
    retry_build
else
    build_image
fi

# Step 4: Login to registry if pushing
if [ "$PUSH" = true ]; then
    echo ""
    echo "Step 4: Image pushed to registry"
    echo "Registry: ${REGISTRY_IMAGE}"
    echo "Tags: ${IMAGE_TAG}, latest"
else
    echo ""
    echo "Step 4: Image built locally"
    echo "To push to registry, run: $0 --push"
fi

echo ""
echo "=== Build Complete ==="
