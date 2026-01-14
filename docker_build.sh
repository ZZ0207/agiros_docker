#!/bin/bash
# docker build -t unitree-go2-docker:latest . --no-cache --progress=plain


docker buildx build --platform linux/amd64,linux/arm64 -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
# docker buildx build --platform linux/amd64 --load -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .

# cd /home/jhq/work/code/docker_ws/unitree_go2_docker/unitree-go2-docker && docker buildx build --platform linux/amd64,linux/arm64 -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong . --progress=plain --pull --no-cache

# docker buildx build --platform linux/amd64,linux/arm64 --push -t <registry>/<repo>:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .

docker buildx build --platform linux/amd64,linux/arm64 --push -t  crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com/jhaiq/agiros_docker:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
docker login --username=j67850 crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com