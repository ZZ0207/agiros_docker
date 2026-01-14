#!/bin/bash
# docker build -t unitree-go2-docker:latest . --no-cache --progress=plain

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

docker buildx build --platform linux/amd64,linux/arm64 -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
# docker buildx build --platform linux/amd64 --load -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .

# cd /home/jhq/work/code/docker_ws/unitree_go2_docker/unitree-go2-docker && docker buildx build --platform linux/amd64,linux/arm64 -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong . --progress=plain --pull --no-cache

# docker buildx build --platform linux/amd64,linux/arm64 --push -t <registry>/<repo>:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .

docker buildx build --platform linux/amd64,linux/arm64 --push -t  crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com/jhaiq/agiros_docker:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
docker login --username=j67850 crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com