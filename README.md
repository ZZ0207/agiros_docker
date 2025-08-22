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

# Reboot your computer
sudo reboot

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

