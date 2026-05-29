







# 创建 buildx 实例（如果还没有）
docker buildx create --use --name multiarch-builder || docker buildx use multiarch-builder

# 构建并推送到仓库（多架构）
docker buildx build \
    -f app/ubuntu/Dockerfile.app.all \
    --platform linux/amd64,linux/arm64 \
    -t docker.agiros.org.cn/agiros/agiros-unitree-app:loong-2606 \
    --push \
    .