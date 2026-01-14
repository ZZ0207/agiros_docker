# docker-go2

The tutorial and docker image to play with Unitree Go2 quadruped robot dog.

### 1. Prepare this repo

```bash
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

```bash
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
```bash
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
```

更换为清华大学镜像源：
```bash
sudo nano /etc/apt/sources.list.d/docker.list
```
替换为以下内容：
deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu focal stable
保存并关闭文件。
```bash
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

```bash
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

```bash
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

```bash
bash docker_build.sh
```

Pull the Docker image from Docker Hub: TODO.

### Troubleshooting

#### Buildx GPU Runtime Error

If you encounter the error:
```
ERROR: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]
```

This happens when Docker daemon is configured to use `nvidia` as default runtime but `nvidia-container-runtime` is not installed. To fix:

```bash
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

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t unitree-go2:humble-openeuler \
  -f ros2/openeuler/Dockerfile-openeuler-humble \
  .
```

If `rosdep` cannot resolve dependencies on your openEuler release, try overriding the OS mapping:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ROSDEP_OS_OVERRIDE=centos:8 \
  --build-arg ROSDEP_ALLOW_FAIL=1 \
  -t unitree-go2:humble-openeuler \
  -f ros2/openeuler/Dockerfile-openeuler-humble \
  .
```

