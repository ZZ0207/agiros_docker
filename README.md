
# docker-go2

The tutorial and docker image to play with Unitree Go2 quadruped robot dog.

### 1. Prepare this repo

```sh
# Remember to clone all submodules
git clone --recurse-submodules https://github.com/pengzhenghao/unitree-go2-docker.git

# Or you can clone then update submodules
git clone https://github.com/pengzhenghao/unitree-go2-docker.git
cd unitree-go2-docker
git submodule update --init --recursive
```

### 1. Install Docker Engine

Docker Engine is NOT Docker Desktop! Please do not install Docker Desktop!

To install Docker Engine, please follow: https://docs.docker.com/engine/install/ubuntu/  For me, I've done:

```sh
# Uninstall old versions:
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker Engine:
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

1.2 如果访问https://download.docker.com下载失败，替换国内源

添加 Docker 的 GPG 密钥：

```sh
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
```

更换为清华大学镜像源：

```sh
sudo nano /etc/apt/sources.list.d/docker.list
```

替换为以下内容：
deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu focal stable
保存并关闭文件。

```sh
sudo apt-get update
```

1.3 安装失败：
方案一：使用国内镜像源安装

1. 使用阿里云镜像安装 Docker
   bash

# 下载安装脚本

curl -fsSL https://get.docker.com -o get-docker.sh

# 使用阿里云镜像安装

sudo sh get-docker.sh --mirror Aliyun
或者使用中科大镜像
bash

sudo sh get-docker.sh --mirror AzureChinaCloud

2.docker 设置

After that, finish the post-installation steps: https://docs.docker.com/engine/install/linux-postinstall/
That is, run:

```sh
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
rm -rf ~/.docker  # Remove the old configuration

3. 设置 Docker 开机自启

sudo systemctl enable docker
sudo systemctl start docker
4. 设置国内镜像源:
sudo tee /etc/docker/daemon.json <<-'EOF'
{
"registry-mirrors": [
"https://docker.registry.cyou",
"https://docker-cf.registry.cyou",
"https://dockercf.jsdelivr.fyi",
"https://docker.jsdelivr.fyi",
"https://dockertest.jsdelivr.fyi",
"https://mirror.aliyuncs.com",
"https://dockerproxy.com",
"https://mirror.baidubce.com",
"https://docker.m.daocloud.io",
"https://docker.nju.edu.cn",
"https://docker.mirrors.sjtug.sjtu.edu.cn",
"https://docker.mirrors.ustc.edu.cn",
"https://mirror.iscas.ac.cn",
"https://docker.rainbond.cc",
"https://docker.mirrors.ustc.edu.cn",
"https://dockerpull.com",
"https://dockerproxy.cn",
"https://docker.m.daocloud.io"
],
"runtimes": {
"nvidia": {
"args": [],
"path": "nvidia-container-runtime"
}
}
}
EOF

重启 Docker 服务使配置生效
# 重新加载配置
sudo systemctl daemon-reload

# 重启 Docker 服务
sudo systemctl restart docker

# 检查配置是否生效
docker info


# Run to see if you can run docker without sudo:
docker run hello-world
```

**An important note: Make sure running `ifconfig` will return the real network interfaces,
e.g. `enp8s0`, `wlp7s0`, etc.
If it returns `eth0` but not your real network interface name,
you have installed Docker Desktop, not Docker Engine.
Please uninstall Docker Desktop and install Docker Engine.**

If you want to play with ROS2, you can run this to test communication between two ROS2 nodes, e.g. two containers or
host and container.

```sh
ros2 run demo_nodes_cpp talker
# You will see the message "Hello World: 1" printed out in topic /chatter

ros2 run demo_nodes_cpp listener
# You will see the message "I heard: [Hello World: 1]" printed out in topic /chatter
```

### 2. Get the Docker image

There are two ways to get the Docker image:

- Build the Docker image from the Dockerfile
- Pull the Docker image from Docker Hub

Build the Docker image from the Dockerfile:

```sh
# The build script automatically initializes git submodules
bash docker_build.sh

# Or with options:
bash docker_build.sh --push                    # Build and push to registry
bash docker_build.sh --no-retry                # Disable retry on network errors
bash docker_build.sh --platform linux/amd64   # Build for single platform
bash docker_build.sh --help                    # Show all options
```

**Script Features**:

- ✅ **Automatic submodule initialization**: Automatically runs `git submodule update --init --recursive`
- ✅ **Retry mechanism**: Automatically retries on network errors (3 attempts with exponential backoff)
- ✅ **Buildx management**: Automatically sets up and manages Docker Buildx builder
- ✅ **Multi-arch support**: Builds for both amd64 and arm64 by default
- ✅ **Push support**: Use `--push` flag to push to registry after build

**Note**: This repository uses git submodules for `unitree_sdk2` and `unitree_ros2`.

- **CI/CD builds** (GitHub Actions/Gitee Go) automatically fetch submodules via `submodules: recursive` in checkout action.
- **Local builds**: The `docker_build.sh` script automatically initializes submodules before building.

Pull the Docker image from Docker Hub: TODO.

### Troubleshooting

#### Buildx GPU Runtime Error

If you encounter the error:

```
ERROR: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]
```

This happens when Docker daemon is configured to use `nvidia` as default runtime but `nvidia-container-runtime` is not installed. To fix:

```sh
sudo bash fix_docker_runtime.sh
```

This script will:

- Backup your current Docker daemon configuration
- Change default runtime from `nvidia` to `runc`
- Restart Docker service
- Recreate the buildx builder

### CI/CD

This repository includes CI/CD pipeline configurations for automatic Docker image builds:

#### GitHub Actions

- **Location**: `.github/workflows/docker-build.yml` (full version with metadata) or `.github/workflows/docker-build-simple.yml` (simplified version)
- **Triggers**: Push to `master`, `main`, `dev` branches, tags starting with `v*`, or pull requests
- **Images Built**:
  - AGIROS openEuler image (multi-arch: amd64/arm64)
  - ROS2 Humble openEuler image (multi-arch: amd64/arm64)

**Setup Instructions**:

1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Add repository secrets:
   - `DOCKER_USERNAME`: Your container registry username
   - `DOCKER_PASSWORD`: Your container registry password
3. The workflow will automatically build and push images on push/PR events

**Features**:

- Automatic multi-arch builds (amd64/arm64)
- Build cache for faster subsequent builds
- Automatic tagging with branch name, commit SHA, and semantic versioning
- PR builds (without push) for testing

#### Gitee Go

- **Location**: `.gitee/pipelines/docker-build.yml`
- **Triggers**: Push to `master`, `main`, `dev` branches or tags starting with `v*`
- **Images Built**:
  - AGIROS openEuler image (multi-arch: amd64/arm64)
  - ROS2 Humble openEuler image (multi-arch: amd64/arm64)

**Setup Instructions**:

1. Go to your Gitee repository → Settings → Gitee Go
2. Enable Gitee Go and configure the pipeline
3. Add environment variables:
   - `DOCKER_USERNAME`: Your container registry username
   - `DOCKER_PASSWORD`: Your container registry password
4. The pipeline will automatically build and push images on push/PR events

### openEuler + ROS 2 Humble (multi-arch)

This repo also includes an openEuler-based ROS 2 Humble Dockerfile (built from source):

- `ros2/openeuler/Dockerfile-openeuler-humble`

Build a multi-arch image (requires Docker Buildx):

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t unitree-go2:humble-openeuler \
  -f ros2/openeuler/Dockerfile-openeuler-humble \
  .
```

If `rosdep` cannot resolve dependencies on your openEuler release, try overriding the OS mapping:

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ROSDEP_OS_OVERRIDE=centos:8 \
  --build-arg ROSDEP_ALLOW_FAIL=1 \
  -t unitree-go2:humble-openeuler \
  -f ros2/openeuler/Dockerfile-openeuler-humble \
  .
```

# 安装 QEMU 用户模式模拟
sudo apt-get install qemu-user-static binfmt-support

# 注册 RISC-V 二进制格式
docker run --privileged --rm tonistiigi/binfmt --install riscv64

# 构建 RISC-V 镜像
docker buildx build \
  --platform linux/riscv64 \
  --build-arg LOCAL_IMAGE="openeuler-24.03-lts" \
  --build-arg TARGETARCH=riscv64 \
  --target base \
  -t agiros:openeuler-riscv64-base \
  -f Dockerfile.agiros-riscv64 .

# 或构建完整版本（跳过 AGIROS 特定包）
docker buildx build \
  --platform linux/riscv64 \
  --build-arg LOCAL_IMAGE="openeuler-24.03-lts" \
  --build-arg TARGETARCH=riscv64 \
  --target dev \
  -t agiros:openeuler-riscv64-dev \
  -f Dockerfile.agiros-riscv64 .


在 Git 中，下载（克隆/更新）子模块的指定分支代码，有几种常见情况和方法：

## 1. 添加子模块时指定分支

```sh
git submodule add -b <分支名> <仓库URL> <本地路径>
```

例如：
```sh
git submodule add -b develop https://github.com/example/repo.git libs/repo
```

## 2. 已添加子模块，切换到指定分支

进入子模块目录并切换分支：

```sh
cd path/to/submodule
git fetch
git checkout <分支名>
git pull origin <分支名>
cd -
```

然后更新主仓库的记录：
```sh
git add path/to/submodule
git commit -m "Update submodule to branch <分支名>"
```

## 3. 更新所有子模块到配置的分支

在 `.gitmodules` 文件中为子模块指定分支：

```ini
[submodule "libs/repo"]
    path = libs/repo
    url = https://github.com/example/repo.git
    branch = develop
```

然后执行：
```sh
git submodule update --remote
```

这会将子模块更新到指定分支的最新提交。

## 4. 克隆主仓库时同时初始化子模块的指定分支

```sh
git clone --recurse-submodules -b <主仓库分支> <主仓库URL>
```

如果子模块已在 `.gitmodules` 中配置了分支，会自动拉取对应分支。

## 5. 更新单个子模块到指定分支

```sh
git submodule update --remote -- <子模块路径>
```

例如：
```sh
git submodule update --remote -- libs/repo
```

## 注意事项

- `git submodule update --remote` 会拉取子模块配置分支的**最新提交**，不一定与主仓库的某次提交对应
- 子模块默认处于 "detached HEAD" 状态，建议在子模块内创建并切换到自己的分支进行开发
- 使用 `git submodule set-branch` 可以修改已存在的子模块的分支配置：

```sh
git submodule set-branch --branch <分支名> -- <子模块路径>
```

这样下次执行 `git submodule update --remote` 时就会使用新配置的分支。


**构建多架构镜像错误**:本地 Docker daemon 信任了 docker.agiros.org.cn（通过 insecure-registries 或证书），但 buildx 创建的 buildkit 容器 是隔离的，它有自己的网络环境和证书信任链，不信任这个自签名证书。


jhq in ~/work/code/docker_ws/unitree_go2_docker/unitree-go2-docker on 2606 ● ● ● λ docker buildx build \
    -f app/ubuntu/Dockerfile.app.all \
    --platform linux/amd64,linux/arm64 \
    -t docker.agiros.org.cn/agiros/agiros-unitree-app:loong-2606 \
    --push \
    .
[+] Building 6.4s (4/4) FINISHED                                                                                        docker-container:multiarch-builder
 => [internal] booting buildkit                                                                                                                       6.0s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                    4.0s
 => => creating container buildx_buildkit_multiarch-builder0                                                                                          2.0s
 => [internal] load build definition from Dockerfile.app.all                                                                                          0.1s
 => => transferring dockerfile: 4.86kB                                                                                                                0.0s
 => ERROR [linux/amd64 internal] load metadata for docker.agiros.org.cn/agiros/agiros-loong-ubuntu-desktop:2606                                       0.0s
 => ERROR [linux/arm64 internal] load metadata for docker.agiros.org.cn/agiros/agiros-loong-ubuntu-desktop:2606                                       0.0s
------
 > [linux/amd64 internal] load metadata for docker.agiros.org.cn/agiros/agiros-loong-ubuntu-desktop:2606:
------
------
 > [linux/arm64 internal] load metadata for docker.agiros.org.cn/agiros/agiros-loong-ubuntu-desktop:2606:
------
Dockerfile.app.all:18
--------------------
  16 |     # Stage 1: BASE (最小运行环境)
  17 |     # =============================================================================
  18 | >>> FROM docker.agiros.org.cn/${ROS_PREFIX}/${ROS_PREFIX}-${ROS_DISTRO}-${OS}-desktop:${IMAGE_TAG} AS base
  19 |     
  20 |     SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
--------------------
ERROR: failed to solve: docker.agiros.org.cn/agiros/agiros-loong-ubuntu-desktop:2606: failed to resolve source metadata for docker.agiros.org.cn/agiros/agiros-loong-ubuntu-desktop:2606: failed to do request: Head "https://docker.agiros.org.cn/v2/agiros/agiros-loong-ubuntu-desktop/manifests/2606": tls: failed to verify certificate: x509: certificate signed by unknown authority
jhq in ~/work/code/docker_ws/unitree_go2_docker/unitree-go2-docker on 2606 ● ● ● λ

# 1. 确保本地 Docker 已配置 insecure-registry
cat /etc/docker/daemon.json

# 2. 创建 buildkit 配置
mkdir -p ~/.config/buildkit
cat > ~/.config/buildkit/buildkitd.toml <<'EOF'
[registry."docker.agiros.org.cn"]
  http = false
  insecure = true
EOF

# 3. 重新创建 builder
docker buildx rm multiarch-builder 2>/dev/null
docker buildx create --use --name multiarch-builder \
    --config ~/.config/buildkit/buildkitd.toml

# 4. 验证 builder 配置
docker buildx inspect multiarch-builder

# 5. 构建
docker buildx build \
    -f app/ubuntu/Dockerfile.app.all \
    --platform linux/amd64,linux/arm64 \
    -t docker.agiros.org.cn/agiros/agiros-unitree-app:loong-2606 \
    --push \
    .
