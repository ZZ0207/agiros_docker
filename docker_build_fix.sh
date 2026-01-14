#!/bin/bash
# Fixed docker build script with retry and network error handling

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure buildx builder exists and works
if ! docker buildx inspect multiarch &>/dev/null; then
    echo "Creating buildx builder 'multiarch'..."
    docker buildx create --name multiarch --driver docker-container --use
    docker buildx inspect --bootstrap || {
        echo "Error: Failed to create buildx builder. You may need to fix Docker daemon configuration."
        echo "Run: sudo bash fix_docker_runtime.sh"
        exit 1
    }
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
    fi
fi

# Function to retry build with exponential backoff
retry_build() {
    local max_attempts=3
    local attempt=1
    local delay=5
    
    while [ $attempt -le $max_attempts ]; do
        echo "Build attempt $attempt of $max_attempts..."
        
        if docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --pull \
            --progress=plain \
            -t agiros-loong-openeuler:12.18 \
            -f agiros/openeuler/Dockerfile-openeuler-loong \
            . 2>&1 | tee /tmp/docker_build.log; then
            echo "✓ Build successful!"
            return 0
        fi
        
        # Check if it's a network error
        if grep -qE "(EOF|timeout|connection|network|short read)" /tmp/docker_build.log; then
            echo "⚠ Network error detected. Waiting ${delay}s before retry..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
            attempt=$((attempt + 1))
        else
            echo "✗ Build failed with non-network error. See log above."
            return 1
        fi
    done
    
    echo "✗ Build failed after $max_attempts attempts"
    return 1
}

# Clean buildx cache if previous build failed
echo "Cleaning buildx cache..."
docker buildx prune -f || true

# Try the build with retry
retry_build
