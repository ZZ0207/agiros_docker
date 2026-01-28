#!/bin/bash
# Docker build script with submodule support, retry mechanism, and multi-arch support
# Supports building all Dockerfiles for both ARM and x86 architectures
# Usage: ./docker_build.sh [OPTIONS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
PUSH=false
RETRY=true
PLATFORMS="linux/amd64,linux/arm64"
IMAGE_TAG="12.18"
BUILD_ALL=false
BUILD_SPECIFIC=""
REGISTRY_BASE="crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com/jhaiq"

# Define all Dockerfiles and their corresponding image names
declare -A DOCKERFILES=(
    ["agiros-openeuler"]="agiros/openeuler/Dockerfile-openeuler-loong"
    ["agiros-ubuntu"]="agiros/ubuntu/Dockerfile-jammy"
    ["ros2-openeuler"]="ros2/openeuler/Dockerfile-openeuler-humble"
    ["ros2-foxy-ubuntu"]="ros2/ubuntu/Dockerfile-foxy"
    ["ros2-humble-ubuntu"]="ros2/ubuntu/Dockerfile-humble"
)

declare -A IMAGE_NAMES=(
    ["agiros-openeuler"]="agiros-loong-openeuler"
    ["agiros-ubuntu"]="agiros-ubuntu-jammy"
    ["ros2-openeuler"]="ros2-humble-openeuler"
    ["ros2-foxy-ubuntu"]="ros2-foxy-ubuntu"
    ["ros2-humble-ubuntu"]="ros2-humble-ubuntu"
)

declare -A REGISTRY_IMAGES=(
    ["agiros-openeuler"]="${REGISTRY_BASE}/agiros_docker"
    ["agiros-ubuntu"]="${REGISTRY_BASE}/agiros_docker-ubuntu"
    ["ros2-openeuler"]="${REGISTRY_BASE}/ros2-humble-openeuler"
    ["ros2-foxy-ubuntu"]="${REGISTRY_BASE}/ros2-foxy-ubuntu"
    ["ros2-humble-ubuntu"]="${REGISTRY_BASE}/ros2-humble-ubuntu"
)

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
        --all)
            BUILD_ALL=true
            shift
            ;;
        --build)
            BUILD_SPECIFIC="$2"
            shift 2
            ;;
        --list)
            echo "Available Dockerfiles:"
            for key in "${!DOCKERFILES[@]}"; do
                echo "  $key: ${DOCKERFILES[$key]}"
            done
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all                  Build all Dockerfiles"
            echo "  --build NAME           Build specific Dockerfile (use --list to see available names)"
            echo "  --push                 Push image to registry after build"
            echo "  --no-retry             Disable retry on network errors"
            echo "  --platform PLATFORMS   Set build platforms (default: linux/amd64,linux/arm64)"
            echo "                         Options: linux/amd64, linux/arm64, or both (comma-separated)"
            echo "  --tag TAG              Set image tag (default: 12.18)"
            echo "  --list                 List all available Dockerfiles"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --all                                    # Build all Dockerfiles for both architectures"
            echo "  $0 --build agiros-ubuntu                    # Build only AGIROS Ubuntu"
            echo "  $0 --build agiros-ubuntu --platform linux/amd64  # Build only for x86"
            echo "  $0 --all --platform linux/arm64             # Build all for ARM only"
            echo "  $0 --build ros2-humble-ubuntu --push        # Build and push ROS2 Humble Ubuntu"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If no build target specified, default to building all
if [ "$BUILD_ALL" = false ] && [ -z "$BUILD_SPECIFIC" ]; then
    BUILD_ALL=true
fi

# Validate build target if specified
if [ -n "$BUILD_SPECIFIC" ]; then
    if [ -z "${DOCKERFILES[$BUILD_SPECIFIC]}" ]; then
        echo "Error: Unknown build target: $BUILD_SPECIFIC"
        echo "Use --list to see available targets"
        exit 1
    fi
fi

echo "=== Docker Build Script ==="
echo "Platforms: $PLATFORMS"
echo "Build mode: $([ "$BUILD_ALL" = true ] && echo "All Dockerfiles" || echo "Specific: $BUILD_SPECIFIC")"
echo "Image tag: $IMAGE_TAG"
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
build_image() {
    local dockerfile_key="$1"
    local dockerfile="${DOCKERFILES[$dockerfile_key]}"
    local image_name="${IMAGE_NAMES[$dockerfile_key]}"
    local registry_image="${REGISTRY_IMAGES[$dockerfile_key]}"
    
    echo ""
    echo "=========================================="
    echo "Building: $dockerfile_key"
    echo "Dockerfile: $dockerfile"
    echo "Image: ${image_name}:${IMAGE_TAG}"
    echo "Platforms: $PLATFORMS"
    echo "=========================================="
    
    local build_args=(
        "buildx" "build"
        "--platform" "$PLATFORMS"
        "--progress=plain"
        "-t" "${image_name}:${IMAGE_TAG}"
        "-f" "$dockerfile"
    )
    
    if [ "$PUSH" = true ]; then
        build_args+=(
            "--push"
            "-t" "${registry_image}:${IMAGE_TAG}"
            "-t" "${registry_image}:latest"
        )
    else
        # For local builds, check if multiple platforms are specified
        local platform_count=$(echo "$PLATFORMS" | tr ',' '\n' | wc -l)
        if [ "$platform_count" -gt 1 ]; then
            # Multiple platforms: build for first platform only (--load limitation)
            local first_platform=$(echo "$PLATFORMS" | cut -d',' -f1 | xargs)
            build_args[2]="--platform"
            build_args[3]="$first_platform"
            build_args+=("--load")
            echo "⚠️  Note: --load only supports single platform. Building for $first_platform only."
            echo "   To build for all platforms, use --push or specify a single platform with --platform"
        else
            # Single platform: normal build
            build_args+=("--load")
        fi
    fi
    
    build_args+=(".")
    
    # Execute build and capture exit code
    if docker "${build_args[@]}"; then
        return 0
    else
        return 1
    fi
}

# Retry function for network errors
retry_build() {
    local dockerfile_key="$1"
    local max_attempts=3
    local attempt=1
    local delay=5
    local log_file="/tmp/docker_build_${dockerfile_key}_$(date +%s).log"
    
    while [ $attempt -le $max_attempts ]; do
        echo ""
        echo "Build attempt $attempt of $max_attempts for $dockerfile_key..."
        
        if build_image "$dockerfile_key" 2>&1 | tee "$log_file"; then
            echo ""
            echo "✓ Build successful for $dockerfile_key!"
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
                echo "✗ Build failed with network error after $attempt attempt(s) for $dockerfile_key"
                rm -f "$log_file"
                return 1
            fi
        else
            echo ""
            echo "✗ Build failed with non-network error for $dockerfile_key. See log: $log_file"
            return 1
        fi
    done
    
    echo ""
    echo "✗ Build failed after $max_attempts attempts for $dockerfile_key"
    rm -f "$log_file"
    return 1
}

# Clean buildx cache before building
echo "Cleaning buildx cache..."
docker buildx prune -f || true

# Step 3: Build images
echo ""
echo "Step 3: Building Docker image(s)..."

# Determine which images to build
declare -a build_targets
if [ "$BUILD_ALL" = true ]; then
    for key in "${!DOCKERFILES[@]}"; do
        build_targets+=("$key")
    done
else
    build_targets+=("$BUILD_SPECIFIC")
fi

# Build each target
total=${#build_targets[@]}
current=0
failed_builds=()
successful_builds=()

for target in "${build_targets[@]}"; do
    current=$((current + 1))
    echo ""
    echo "[$current/$total] Processing: $target"
    
    if [ "$RETRY" = true ]; then
        if retry_build "$target"; then
            successful_builds+=("$target")
        else
            failed_builds+=("$target")
        fi
    else
        if build_image "$target"; then
            successful_builds+=("$target")
        else
            failed_builds+=("$target")
        fi
    fi
done

# Step 4: Summary
echo ""
echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo "Total targets: $total"
echo "Successful: ${#successful_builds[@]}"
echo "Failed: ${#failed_builds[@]}"
echo ""

if [ ${#successful_builds[@]} -gt 0 ]; then
    echo "✓ Successfully built:"
    for target in "${successful_builds[@]}"; do
        image_name="${IMAGE_NAMES[$target]}"
        echo "  - $target (${image_name}:${IMAGE_TAG})"
        if [ "$PUSH" = true ]; then
            registry_image="${REGISTRY_IMAGES[$target]}"
            echo "    Pushed to: ${registry_image}:${IMAGE_TAG}, ${registry_image}:latest"
        fi
    done
    echo ""
fi

if [ ${#failed_builds[@]} -gt 0 ]; then
    echo "✗ Failed builds:"
    for target in "${failed_builds[@]}"; do
        echo "  - $target"
    done
    echo ""
    exit 1
fi

echo "=== Build Complete ==="
