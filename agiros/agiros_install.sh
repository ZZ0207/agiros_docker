##用于在ubuntu的基础docker镜像中验证相关的安装命令
#!/bin/bash
set -euxo pipefail

# 设置时区
echo 'Asia/Shanghai' > /etc/timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
apt-get update
apt-get install -q -y --no-install-recommends tzdata
rm -rf /var/lib/apt/lists/*

# 安装依赖
apt-get update
apt-get install -q -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    gnupg2
rm -rf /var/lib/apt/lists/*

# 设置参数
ROS_DISTRO="${ROS_DISTRO:-loong}"
AGIROS_INSTALL_BASE="${AGIROS_INSTALL_BASE:-/opt/agiros/${ROS_DISTRO}}"
AGIROS_INSTALL_URL="${AGIROS_INSTALL_URL:-http://repo.agiros.org.cn/debrepo/agiros/ubuntu2204lts/2606/install.sh}"

# 下载并修改脚本
curl -fsSL "${AGIROS_INSTALL_URL}" -o install.sh
chmod +x install.sh
sed -i 's#</dev/tty#</dev/stdin#g' install.sh

# 创建输入文件
cat > /tmp/input.txt << 'EOF'
1
n
y
y
EOF

# 使用 script 创建伪终端，并从文件读取输入
script -q -c "bash ./install.sh" /dev/null < /tmp/input.txt

# 输出安装日志
echo "=== AGIROS Installation Log (exit code: $INSTALL_EXIT) ==="
cat /tmp/install.log
echo "=== End of AGIROS Installation Log ==="

# 检查安装结果（处理 ntpdate 错误）
if [ $INSTALL_EXIT -ne 0 ]; then
    if grep -q "Can't adjust the time of day: Operation not permitted" /tmp/install.log; then
        echo "⚠ ntpdate error detected (non-fatal in containers), checking if AGIROS was installed..."
        if [ -d "${AGIROS_INSTALL_BASE}" ] || [ -d "/opt/agiros" ]; then
            echo "✓ AGIROS appears to be installed despite ntpdate error"
        else
            echo "✗ AGIROS installation failed"
            exit 1
        fi
    else
        echo "✗ AGIROS installation failed with exit code $INSTALL_EXIT"
        exit 1
    fi
fi

# 清理临时文件
rm -f install.sh

# 保留安装日志
cp /tmp/install.log /var/log/agiros_install.log

echo "✓ AGIROS installation completed successfully"

echo "✓ Check AGIROS install "
# 检查安装目录
if [ -d "/opt/agiros" ]; then
    echo "✓ AGIROS found in /opt/agiros"
    ls -la /opt/agiros/
    
    # 查找 setup.bash
    SETUP_FILE=$(find /opt/agiros -name "setup.bash" 2>/dev/null | head -1)
    if [ -n "$SETUP_FILE" ]; then
        echo "✓ Setup file found: $SETUP_FILE"
        echo "Run: source $SETUP_FILE"
    fi
else
    echo "✗ AGIROS not found in /opt/agiros"
    echo "Checking installation log..."
    
    if [ -f "/tmp/install.log" ]; then
        echo "=== Last 20 lines of install log ==="
        tail -20 /tmp/install.log
    fi
fi

# 检查 ROS 相关命令
if command -v agiros &> /dev/null; then
    echo "✓ agiros command found"
    ros2 --version
else
    echo "⚠ agiros command not found in PATH"
fi
