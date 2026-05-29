







# # 创建 buildx 实例（如果还没有）
# docker buildx create --use --name multiarch-builder || docker buildx use multiarch-builder

# # 构建并推送到仓库（多架构）
# docker buildx build \
#     -f app/ubuntu/Dockerfile.app.all \
#     --platform linux/amd64,linux/arm64 \
#     -t docker.agiros.org.cn/agiros/agiros-unitree-app:loong-2606 \
#     --push \
#     .

# 制定标签
# docker buildx build \
#     --platform linux/amd64,linux/arm64,linux/riscv64,linux/loongarch64 \
#     --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
#     --build-arg GIT_COMMIT="$(git rev-parse --short HEAD)" \
#     --build-arg VERSION="24.03-LTS" \
#     --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
#     -t docker.agiros.org.cn/agiros/openeuler:24.03 \
#     --push \
#     .


docker buildx build \
    --platform linux/amd64 \
    --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg GIT_COMMIT="$(git rev-parse --short HEAD)" \
    -f app/ubuntu/Dockerfile.app.all \
    --platform linux/amd64 \
    -t docker.agiros.org.cn/agiros/agiros-unitree-app:loong-2606 \
    --push \
    .