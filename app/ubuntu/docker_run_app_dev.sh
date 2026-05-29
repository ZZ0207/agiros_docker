

# docker run -it \
#   -e DISPLAY=$DISPLAY \
#   -v /tmp/.X11-unix:/tmp/.X11-unix \
#   -v /home/jhq/work/code/docker_ws/unitree_go2_docker/unitree-go2-docker/app_ws:/workspace/app \
#   --network host \
#   --name agiros_loong_app_dev \
#   --privileged \
#   agiros:loong-base-dev /bin/bash


# ##app 构建命令
# docker buildx build \
#     --platform linux/amd64,linux/arm64 \
#     --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
#     --build-arg GIT_COMMIT="$(git rev-parse --short HEAD)" \
#     -t docker.agiros.org.cn/agiros/agiros-unitree-app:loong-2606 \
#     --push \
#     .

# ##agiros  riscv64 构建命令
# cd ~/work/code/docker_ws/unitree_go2_docker/unitree-go2-docker

# docker buildx use agiros-builder

# docker buildx build \
#   --build-arg LOCAL_IMAGE="localhost:5000/openeuler/openeuler" \
#   --build-arg OPENEULER_TAG="24.03-lts-riscv64" \
#   --build-arg TARGETARCH=riscv64 \
#   --target base \
#   -t agiros:openeuler-riscv64-base \
#   --load \
#   -f agiros/openeuler/loong/Dockerfile.agiros-multistage .