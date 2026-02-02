# AGENTS.md - Unitree Go2 Docker Project

> 本文件为 AI Coding Agent 提供项目背景、构建流程和开发规范指引。

---

## 项目概述

本项目是用于 **Unitree Go2 四足机器狗** 开发的 Docker 镜像仓库，提供了预配置好的 ROS2/AGIROS 开发环境，支持多架构（amd64/arm64）构建。

### 主要功能

- 提供多种基础镜像：AGIROS (Ubuntu/openEuler) 和 ROS2 Foxy/Humble (Ubuntu/openEuler)
- 集成 Unitree SDK2 和 Unitree ROS2 接口
- 支持 CycloneDDS 中间件配置
- 多架构支持（x86_64 和 ARM64）

---

## 技术栈

### 核心技术


| 组件                       | 说明                            |
| -------------------------- | ------------------------------- |
| **Docker & Docker Buildx** | 容器化与跨架构构建              |
| **ROS2 Foxy/Humble**       | 机器人操作系统                  |
| **AGIROS**                 | 国产机器人操作系统（基于 ROS2） |
| **CycloneDDS**             | DDS 中间件实现                  |
| **openEuler 24.03 LTS**    | 国产开源操作系统                |
| **Ubuntu 20.04/22.04**     | 基础镜像（Jammy/Focal）         |

### 依赖的 Git 子模块

```
src/unitree_sdk2   -> https://github.com/unitreerobotics/unitree_sdk2
src/unitree_ros2   -> https://github.com/unitreerobotics/unitree_ros2
```

**重要**: 构建前必须初始化子模块：

```bash
git submodule update --init --recursive
```

---

## 项目结构

```
.
├── agiros/                          # AGIROS 相关 Dockerfile
│   ├── openeuler/
│   │   └── Dockerfile-openeuler-loong   # openEuler + AGIROS
│   └── ubuntu/
│       └── Dockerfile-jammy             # Ubuntu 22.04 + AGIROS
├── ros2/                            # ROS2 相关 Dockerfile
│   ├── openeuler/
│   │   └── Dockerfile-openeuler-humble  # openEuler + ROS2 Humble
│   └── ubuntu/
│       ├── Dockerfile-foxy              # Ubuntu 20.04 + ROS2 Foxy
│       └── Dockerfile-humble            # Ubuntu 22.04 + ROS2 Humble
├── ros1&ros2/                       # ROS1+ROS2 桥接实验性镜像
├── src/                             # 构建源文件和脚本
│   ├── tests/
│   │   └── test_gi.py               # PyGObject/GStreamer 测试
│   ├── agiros_cyclonedds_setup.sh   # AGIROS CycloneDDS 环境配置
│   ├── ros_cyclonedds_setup.sh      # ROS2 CycloneDDS 环境配置
│   ├── go2_ros2_setup.sh            # Go2 ROS2 环境配置脚本
│   └── docker_internal_setup.sh     # 容器内部初始化脚本
├── docker_build.sh                  # 主构建脚本
├── docker-compose.yml               # Docker Compose 配置
├── docker_run.sh                    # 快速运行脚本
├── TROUBLESHOOTING.md               # 故障排除指南
└── .github/workflows/               # GitHub Actions CI/CD
    └── docker-build.yml
```

---

## 构建命令

### 使用 docker_build.sh（推荐）

```bash
# 构建所有镜像
bash docker_build.sh

# 构建特定镜像
bash docker_build.sh --build agiros-openeuler
bash docker_build.sh --build ros2-humble-ubuntu

# 查看可构建的镜像列表
bash docker_build.sh --list

# 构建并推送到镜像仓库
bash docker_build.sh --all --push

# 单平台构建（本地测试）
bash docker_build.sh --build agiros-ubuntu --platform linux/amd64

# 禁用网络错误重试
bash docker_build.sh --no-retry
```

### 可用镜像名称


| 镜像名称             | Dockerfile 路径                               |
| -------------------- | --------------------------------------------- |
| `agiros-openeuler`   | `agiros/openeuler/Dockerfile-openeuler-loong` |
| `agiros-ubuntu`      | `agiros/ubuntu/Dockerfile-jammy`              |
| `ros2-openeuler`     | `ros2/openeuler/Dockerfile-openeuler-humble`  |
| `ros2-foxy-ubuntu`   | `ros2/ubuntu/Dockerfile-foxy`                 |
| `ros2-humble-ubuntu` | `ros2/ubuntu/Dockerfile-humble`               |

### 手动使用 Docker Buildx

```bash
# 创建 buildx 构建器
docker buildx create --name multiarch --driver docker-container --use

# 构建多架构镜像
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t unitree-go2:agiros-openeuler \
  -f agiros/openeuler/Dockerfile-openeuler-loong \
  --push .

# 本地单架构加载（--load 仅支持单平台）
docker buildx build \
  --platform linux/amd64 \
  -t unitree-go2:test \
  -f agiros/openeuler/Dockerfile-openeuler-loong \
  --load .
```

---

## 运行容器

### 使用 docker-compose

```bash
# 启动容器
docker compose up -d

# 进入容器交互模式
docker compose run --rm go2 bash
```

### 使用 docker_run.sh（快速方式）

```bash
bash docker_run.sh
```

### 手动运行

```bash
docker run -it --rm \
  --privileged \
  --network host \
  --ipc host \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e GO2_NETWORK_INTERFACE=enp118s0 \
  -v ./src:/app/src \
  unitree-go2-docker:latest bash
```

---

## 代码风格与开发规范

### Dockerfile 规范

1. **使用 `SHELL ["/bin/bash", "-c"]`** 确保支持管道和重定向
2. **使用 `set -euxo pipefail`** 在 RUN 指令中启用严格模式
3. **多行命令使用 `&&` 连接** 减少层数
4. **清理缓存** 每个 RUN 末尾清理 apt/dnf 缓存
5. **使用 `--no-install-recommends`** 最小化镜像体积

### 子模块处理规范

所有 Dockerfile 必须包含子模块自动初始化逻辑：

```dockerfile
RUN set -euxo pipefail; \
    if [ ! -f "unitree_sdk2/CMakeLists.txt" ]; then \
      echo "⚠ unitree_sdk2 submodule not found, initializing..."; \
      if [ -f ".gitmodules" ]; then \
        git submodule update --init --recursive unitree_sdk2 || \
        (echo "⚠ Git submodule init failed, cloning directly..." && \
         rm -rf unitree_sdk2 && \
         git clone --depth 1 https://github.com/unitreerobotics/unitree_sdk2.git unitree_sdk2); \
      else \
        echo "⚠ .gitmodules not found, cloning directly..."; \
        rm -rf unitree_sdk2; \
        git clone --depth 1 https://github.com/unitreerobotics/unitree_sdk2.git unitree_sdk2; \
      fi; \
    fi
```

### ARM64 特殊处理

Ubuntu ROS2 镜像需要特殊的 ARM64 库路径修复：

```dockerfile
# 修复 ROS aarch64 包库路径问题
RUN set -euxo pipefail; \
    if [ "$(uname -m)" = "aarch64" ]; then \
        ARCH_LIB_DIR="/opt/ros/humble/lib/aarch64-linux-gnu"; \
        # 创建符号链接修复库路径
        ln -sf "aarch64-linux-gnu/libXXX.so" "/opt/ros/humble/lib/libXXX.so"; \
    fi
```

---

## 测试策略

### 自动化测试

项目包含简单的 Python 测试文件：

```bash
# 测试 PyGObject/GStreamer 安装
python3 src/tests/test_gi.py
```

该测试验证：

- `gi` 模块可导入
- GStreamer 1.0 可用
- 可获取 GStreamer 版本信息

### 手动测试建议

1. **ROS2 通信测试**:

   ```bash
   # 终端 1
   ros2 run demo_nodes_cpp talker

   # 终端 2
   ros2 run demo_nodes_cpp listener
   ```
2. **CycloneDDS 配置验证**:

   ```bash
   # 检查 RMW 实现
   echo $RMW_IMPLEMENTATION  # 应输出 rmw_cyclonedds_cpp

   # 检查网络接口配置
   echo $CYCLONEDDS_URI
   ```

---

## CI/CD 配置

### GitHub Actions

**配置文件**: `.github/workflows/docker-build.yml`

**触发条件**:

- Push 到 master/main/dev 分支
- Tag 推送（v* 格式）
- Pull Request
- 手动触发（workflow_dispatch）

**构建矩阵**:

- AGIROS openEuler (linux/amd64, linux/arm64)
- ROS2 Humble openEuler (linux/amd64, linux/arm64)
- AGIROS Ubuntu (linux/amd64, linux/arm64)
- ROS2 Foxy Ubuntu (linux/amd64, linux/arm64)
- ROS2 Humble Ubuntu (linux/amd64, linux/arm64)

**所需 Secrets**:

- `DOCKER_USERNAME`: 镜像仓库用户名
- `DOCKER_PASSWORD`: 镜像仓库密码

### Gitee Go

**配置文件**: `.gitee/pipelines/docker-build.yml`

功能与 GitHub Actions 类似，支持在 Gitee 平台进行镜像构建。

---

## 故障排除

### 常见构建错误

#### 1. 网络错误（`short read: expected X bytes`）

**原因**: 基础镜像下载中断

**解决**:

```bash
# 清理缓存并重试
docker buildx prune -f
bash docker_build.sh
```

#### 2. GPU Runtime 错误

**错误信息**:

```
ERROR: could not select device driver "" with capabilities: [[gpu]]
```

**解决**:

```bash
sudo bash fix_docker_runtime.sh
```

#### 3. 子模块缺失

**错误信息**: `unitree_sdk2/CMakeLists.txt not found`

**解决**:

```bash
git submodule update --init --recursive
```

#### 4. ntpdate 权限错误（容器内）

**说明**: ntpdate 在容器中可能因权限问题失败，但通常不影响 AGIROS 安装

**解决**: Dockerfile 已处理此情况，继续后续步骤

### 调试技巧

1. **查看构建日志**:

   ```bash
   docker buildx build --progress=plain ... 2>&1 | tee build.log
   ```
2. **进入失败的构建阶段**:

   ```bash
   # 使用 --target 构建到特定阶段
   docker buildx build --target <stage_name> ...
   ```

---

## 安全注意事项

1. **容器以 privileged 模式运行** - 需要访问主机网络和设备
2. **网络模式为 host** - 用于与机器人直接通信
3. **镜像仓库凭证** - 通过 GitHub/Gitee Secrets 管理
4. **子模块来源** - 依赖外部 GitHub 仓库，构建时自动克隆

---

## 网络配置

### 关键环境变量


| 变量                    | 说明                 | 示例                 |
| ----------------------- | -------------------- | -------------------- |
| `GO2_NETWORK_INTERFACE` | 机器人通信网卡       | `enp118s0`           |
| `CYCLONEDDS_URI`        | DDS 配置（自动生成） | XML 格式             |
| `RMW_IMPLEMENTATION`    | RMW 实现             | `rmw_cyclonedds_cpp` |

### CycloneDDS 配置

通过脚本自动配置：

```bash
export CYCLONEDDS_URI="<CycloneDDS><Domain><General><Interfaces>
  <NetworkInterface name=\"${GO2_NETWORK_INTERFACE}\" priority=\"default\" multicast=\"default\" />
</Interfaces></General></Domain></CycloneDDS>"
```

---

## 镜像仓库

**默认仓库**: 阿里云容器镜像服务（ACR）

```
crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com/jhaiq/
```

**镜像列表**:

- `agiros_docker` - AGIROS openEuler
- `agiros_docker-ubuntu` - AGIROS Ubuntu
- `ros2-humble-openeuler` - ROS2 Humble openEuler
- `ros2-foxy-ubuntu` - ROS2 Foxy Ubuntu
- `ros2-humble-ubuntu` - ROS2 Humble Ubuntu

---

## 相关文档

- [README.md](README.md) - 用户入门指南
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 详细故障排除
- Unitree SDK2: https://github.com/unitreerobotics/unitree_sdk2
- Unitree ROS2: https://github.com/unitreerobotics/unitree_ros2
