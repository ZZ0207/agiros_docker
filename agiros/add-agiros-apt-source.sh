#!/bin/bash

set -e

# 彩色输出定义
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_GREEN}[AGiROS仓库安装向导]${COLOR_RESET}"

# 0. 预安装所有的前置包
sudo apt update && sudo apt install -y \
  net-tools \
  wget \
  gnupg \
  curl \
  dpkg \
  fakeroot \
  devscripts \
  debhelper \
  python3-all \
  dh-python \
  
# 1. 检查架构兼容性
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64|arm64) ;;
    *) echo -e "${COLOR_RED}错误：不支持的架构 $ARCH${COLOR_RESET}"; exit 1 ;;
esac

# 2. 安装必要工具
if ! command -v gpg >/dev/null; then
    echo "安装依赖: gnupg..."
    apt-get update >/dev/null
    apt-get install -y gnupg >/dev/null
fi

# 3. 添加 GPG 密钥
echo "添加仓库签名密钥..."
if curl -sSL "http://1.94.193.239/debrepo/agiros/ubuntu2204lts/agiros.gpg" | sudo tee /usr/share/keyrings/agiros.gpg >/dev/null; then
    echo "仓库签名密钥添加成功"
else
    echo -e "${COLOR_RED}错误：密钥下载失败${COLOR_RESET}"
    exit 1
fi

# 4. 添加 APT 源
echo "配置软件仓库源..."
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    repo_arch="amd64"
elif [ "$arch" = "aarch64" ]; then
    repo_arch="arm64"
else
    echo -e "${COLOR_RED}❌ 不支持的架构: $arch${COLOR_RESET}" >&2
    exit 1
fi
echo -e "${COLOR_GREEN}✅ 检测到系统架构: $arch, 配置软件仓库源...${COLOR_RESET}"
sudo tee /etc/apt/sources.list.d/agiros.list >/dev/null <<EOL
# AGiROS官方软件仓库
deb [arch=$repo_arch signed-by=/usr/share/keyrings/agiros.gpg] http://1.94.193.239/debrepo/agiros/ubuntu2204lts jammy main
EOL

# 5. 更新缓存
echo "更新软件包列表..."
sudo apt-get update >/dev/null
if [ $? -ne 0 ]; then
    echo -e "${COLOR_RED}错误：更新软件包列表失败，请检查网络连接或仓库配置${COLOR_RESET}"
    exit 1
fi