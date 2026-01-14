# 故障排除指南

## 网络错误修复

### 错误1: `short read: expected X bytes but got Y: unexpected EOF`

**原因**: 下载基础镜像时网络中断，导致镜像文件不完整。

**解决方案**:
1. **清理缓存并重试**:
   ```bash
   docker buildx prune -f
   docker buildx build --platform linux/amd64,linux/arm64 --pull -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
   ```

2. **使用修复脚本**（推荐）:
   ```bash
   bash docker_build_fix.sh
   ```
   该脚本会自动重试，并处理网络错误。

3. **手动清理并重新拉取镜像**:
   ```bash
   docker buildx prune -a -f
   docker pull openeuler/openeuler:24.03-lts
   ```

### 错误2: `failed to fetch anonymous token: EOF`

**原因**: 无法访问 Docker Hub 获取认证 token（网络问题或访问受限）。

**解决方案**:

1. **移除 syntax 行**（如果不需要高级特性）:
   编辑 `Dockerfile-openeuler-loong`，注释掉或删除第一行:
   ```dockerfile
   # syntax=docker/dockerfile:1.4
   ```
   这会让 Docker 使用标准语法，不需要从 Docker Hub 拉取语法定义。

2. **配置 Docker 镜像加速器**（已配置，但 buildx 可能未使用）:
   确保 `/etc/docker/daemon.json` 包含镜像加速器:
   ```json
   {
     "registry-mirrors": [
       "https://esu7eujw.mirror.aliyuncs.com",
       "https://docker.mirrors.ustc.edu.cn"
     ]
   }
   ```
   然后重启 Docker:
   ```bash
   sudo systemctl restart docker
   ```

3. **使用代理**（如果有）:
   ```bash
   export HTTP_PROXY=http://your-proxy:port
   export HTTPS_PROXY=http://your-proxy:port
   docker buildx build ...
   ```

4. **分平台构建**（如果多架构构建失败）:
   ```bash
   # 只构建 amd64
   docker buildx build --platform linux/amd64 --load -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
   ```

### 错误3: `nvidia-container-runtime: executable file not found`

**原因**: Docker daemon 配置了 nvidia runtime，但系统未安装。

**解决方案**:
```bash
sudo bash fix_docker_runtime.sh
```

## 最佳实践

1. **使用修复脚本**: `bash docker_build_fix.sh` 会自动处理常见的网络错误。

2. **分步构建**: 如果网络不稳定，可以先构建单个平台:
   ```bash
   docker buildx build --platform linux/amd64 --load -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
   ```

3. **使用缓存**: 构建时保留缓存可以加速后续构建:
   ```bash
   docker buildx build --platform linux/amd64,linux/arm64 --cache-from type=local,src=/tmp/.buildx-cache --cache-to type=local,dest=/tmp/.buildx-cache -t agiros-loong-openeuler:12.18 -f agiros/openeuler/Dockerfile-openeuler-loong .
   ```

4. **检查网络连接**:
   ```bash
   # 测试 Docker Hub 连接
   curl -I https://registry-1.docker.io/v2/
   
   # 测试镜像拉取
   docker pull openeuler/openeuler:24.03-lts
   ```
