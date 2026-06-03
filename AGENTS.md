# AGENTS.md - Unitree Go2 Docker Project

> This file provides AI coding agents with project background, architecture details, build processes, and development conventions for the Unitree Go2 Docker project.

---

## Project Overview

This project provides **Docker-based development environments** for the **Unitree Go2 quadruped robot**. It supports multiple operating systems (Ubuntu, openEuler), multiple ROS distributions (AGIROS, ROS2 Foxy/Humble), and multi-architecture builds (AMD64/ARM64).

### Key Capabilities

- **Multi-OS Support**: Ubuntu 20.04/22.04 and openEuler 24.03 LTS
- **Multi-ROS Support**: AGIROS (国产机器人操作系统), ROS2 Foxy, ROS2 Humble
- **Multi-Architecture**: x86_64 (amd64) and ARM64 (aarch64)
- **Pre-configured Networking**: CycloneDDS with automatic network interface detection
- **Complete Toolchain**: Includes Unitree SDK2, Unitree ROS2, GStreamer, PyGObject

---

## Technology Stack

### Core Technologies

| Component | Description | Version/Details |
|-----------|-------------|-----------------|
| **Docker & Buildx** | Containerization and cross-platform builds | Multi-arch support via QEMU |
| **AGIROS** | Chinese ROS2 distribution (基于 ROS2) | loong distribution |
| **ROS2 Foxy** | Ubuntu 20.04 based ROS2 | For older compatibility |
| **ROS2 Humble** | Ubuntu 22.04 LTS based ROS2 | Long-term support |
| **openEuler 24.03 LTS** | Chinese open-source OS | Enterprise-grade |
| **CycloneDDS** | DDS middleware implementation | For robot communication |
| **Unitree SDK2** | Official Unitree robot SDK | Git submodule |
| **Unitree ROS2** | ROS2 interface for Unitree robots | Git submodule |

### Build Dependencies

- Docker Engine (NOT Docker Desktop)
- Docker Buildx for multi-arch builds
- QEMU for cross-architecture emulation
- Git with submodule support

---

## Project Structure

```
.
├── agiros/                          # AGIROS base image Dockerfiles
│   ├── openeuler/loong/
│   │   └── Dockerfile.agiros-multistage  # openEuler + AGIROS (stages: base/dev/desktop/desktop-full)
│   └── ubuntu/loong/
│       └── Dockerfile.agiros-multistage  # Ubuntu + AGIROS (stages: base/dev/desktop/desktop-full)
│
├── app/                             # Application Dockerfiles (FROM agiros images)
│   ├── openeuler/
│   │   └── Dockerfile.app.all       # openEuler app (stage: unitree)
│   └── ubuntu/
│       └── Dockerfile.app.all       # Ubuntu app (stages: unitree, ur5)
│
├── src/                             # Build source files and scripts
│   ├── unitree/                     # Unitree dog-bot submodule
│   ├── ur5/                         # UR5 robot arm submodules
│   ├── agiros_cyclonedds_setup.sh   # AGIROS CycloneDDS environment setup
│   ├── go2_ros2_setup.sh            # Go2-specific ROS2 network setup
│   └── docker_internal_setup.sh     # Container initialization entrypoint
│
├── .github/workflows/               # GitHub Actions CI/CD
│   └── docker-build.yml             # Multi-arch Docker build pipeline
│
├── .gitee/pipelines/                # Gitee Go CI/CD
│   └── docker-build.yml             # Gitee build pipeline
│
├── docker_build.sh                  # Unified build script (all modules)
├── docker-compose-dev.yml           # Docker Compose for development
├── docker_run.sh                    # Quick container launch script
├── README.md                        # User documentation (Chinese)
└── AGENTS.md                        # AI agent documentation
```

### Git Submodules

The project depends on two external repositories:

```
src/unitree_sdk2   → https://github.com/unitreerobotics/unitree_sdk2
src/unitree_ros2   → https://github.com/unitreerobotics/unitree_ros2
```

**IMPORTANT**: Always initialize submodules before building:

```bash
git submodule update --init --recursive
```

---

## Build System

### Available Docker Images (Modules)

| Module | Dockerfile | Stages | Default Stage |
|--------|-----------|--------|---------------|
| `agiros-ubuntu` | `agiros/ubuntu/loong/Dockerfile.agiros-multistage` | base, dev, desktop, desktop-full | desktop-full |
| `agiros-openeuler` | `agiros/openeuler/loong/Dockerfile.agiros-multistage` | base, dev, desktop, desktop-full | desktop-full |
| `app-ubuntu` | `app/ubuntu/Dockerfile.app.all` | unitree, ur5 | unitree |
| `app-openeuler` | `app/openeuler/Dockerfile.app.all` | unitree | unitree |

The `agiros-*` modules are base images with 4 stages (inheritance chain: base → dev → desktop → desktop-full).
The `app-*` modules are application images that `FROM` the agiros base images for specific robot platforms.

### Build Commands

#### Using docker_build.sh (Recommended)

```bash
# Build all modules (default stages)
bash docker_build.sh

# List available modules and stages
bash docker_build.sh --list

# Build specific module
bash docker_build.sh --module agiros-ubuntu

# Build specific module + stage
bash docker_build.sh --module app-ubuntu --stage unitree

# Build a stage across all modules that support it
bash docker_build.sh --stage base

# Single-platform local build (faster)
bash docker_build.sh --module agiros-ubuntu --platform linux/amd64

# Push to registry (multi-arch)
bash docker_build.sh --module app-ubuntu --platform linux/amd64,linux/arm64 --push

# Custom tag and build args
bash docker_build.sh --module app-ubuntu --tag 2606 --build-arg PARALLEL_JOBS=8

# Disable retry on network errors
bash docker_build.sh --module agiros-ubuntu --no-retry
```

#### Manual Docker Buildx

```bash
# Create multi-arch builder
docker buildx create --name multiarch --driver docker-container --use

# Build multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t unitree-go2:agiros-openeuler \
  -f agiros/openeuler/Dockerfile-openeuler-loong \
  --push .

# Local single-arch build (with --load)
docker buildx build \
  --platform linux/amd64 \
  -t unitree-go2:test \
  -f agiros/openeuler/Dockerfile-openeuler-loong \
  --load .
```

### Build Script Features

- ✅ **Automatic submodule initialization**: Runs `git submodule update --init --recursive`
- ✅ **Retry mechanism**: 3 attempts with exponential backoff for network errors
- ✅ **Automatic binfmt setup**: Configures QEMU for cross-arch builds
- ✅ **Buildx management**: Creates/manages `multiarch` builder automatically
- ✅ **Registry push support**: `--push` flag for CI/CD integration

---

## Dockerfile Conventions

### Shell Configuration

All Dockerfiles use bash with strict error handling:

```dockerfile
# Ubuntu
SHELL ["/bin/bash", "-c"]

# openEuler (more strict)
SHELL ["/bin/bash", "-e", "-u", "-o", "pipefail", "-c"]
```

### RUN Instruction Best Practices

```dockerfile
# Use set -euxo pipefail for strict mode
RUN set -euxo pipefail; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      package1 package2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
```

### Submodule Handling Pattern

Every Dockerfile must include this pattern for resilient submodule handling:

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

### ARM64 Library Path Fixes

Ubuntu ROS2 images need special ARM64 handling:

```dockerfile
# Fix ROS aarch64 package library path issues
RUN set -euxo pipefail; \
    if [ "$(uname -m)" = "aarch64" ]; then \
        ARCH_LIB_DIR="/opt/ros/humble/lib/aarch64-linux-gnu"; \
        # Create symlinks to fix library paths
        find "${ARCH_LIB_DIR}" -maxdepth 1 -name "*.so" -type f | while read -r lib; do \
            lib_name=$(basename "$lib"); \
            target="/opt/ros/humble/lib/$lib_name"; \
            if [ ! -e "$target" ]; then \
                ln -sf "aarch64-linux-gnu/$lib_name" "$target"; \
            fi; \
        done; \
    fi
```

---

## Runtime Configuration

### Container Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GO2_NETWORK_INTERFACE` | Network interface for robot communication | `enp118s0` |
| `CYCLONEDDS_URI` | DDS configuration (auto-generated) | XML format |
| `RMW_IMPLEMENTATION` | RMW implementation | `rmw_cyclonedds_cpp` |
| `ROS_DISTRO` | ROS distribution | `humble`, `foxy`, `loong` |

### CycloneDDS Configuration

The `go2_ros2_setup.sh` script configures CycloneDDS for Go2 communication:

```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="<CycloneDDS><Domain><General><Interfaces>
  <NetworkInterface name=\"${GO2_NETWORK_INTERFACE}\" priority=\"default\" multicast=\"default\" />
</Interfaces></General></Domain></CycloneDDS>"
```

### Docker Compose Configuration

```yaml
services:
  go2:
    image: unitree-go2-docker:latest
    privileged: true        # Required for device access
    network_mode: "host"    # Required for DDS multicast
    ipc: "host"             # Required for shared memory
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - GO2_NETWORK_INTERFACE=enp118s0
    volumes:
      - ./src:/app/src
```

**Note**: `privileged`, `network_mode: host`, and `ipc: host` are required for proper robot communication.

---

## CI/CD Configuration

### GitHub Actions

**File**: `.github/workflows/docker-build.yml`

**Triggers**:
- Push to `master`, `main`, `dev` branches
- Tags starting with `v*`
- Pull requests
- Manual trigger (workflow_dispatch)

**Build Matrix**:
- AGIROS openEuler (linux/amd64, linux/arm64)
- AGIROS Ubuntu (linux/amd64, linux/arm64)
- ROS2 Humble openEuler (linux/amd64, linux/arm64)
- ROS2 Foxy Ubuntu (linux/amd64, linux/arm64)
- ROS2 Humble Ubuntu (linux/amd64, linux/arm64)

**Required Secrets**:
- `DOCKER_USERNAME`: Container registry username
- `DOCKER_PASSWORD`: Container registry password/token

### Gitee Go

**File**: `.gitee/pipelines/docker-build.yml`

Similar to GitHub Actions but for Gitee platform. Currently builds:
- AGIROS openEuler image
- ROS2 Humble openEuler image

---

## Testing Strategy

### Automated Tests

The project includes a simple Python test for GStreamer/PyGObject:

```bash
# Run inside container
python3 /root/src/tests/test_gi.py
```

**Test file**: `src/tests/test_gi.py`

This test validates:
- `gi` module can be imported
- GStreamer 1.0 is available
- Version information can be retrieved

### Manual Testing

After building, verify ROS2 communication:

```bash
# Terminal 1 (Talker)
ros2 run demo_nodes_cpp talker

# Terminal 2 (Listener)
ros2 run demo_nodes_cpp listener
```

Verify CycloneDDS configuration:

```bash
# Check RMW implementation
echo $RMW_IMPLEMENTATION  # Should output: rmw_cyclonedds_cpp

# Check network interface
echo $GO2_NETWORK_INTERFACE
```

---

## Development Workflow

### Local Development

1. **Clone with submodules**:
   ```bash
   git clone --recurse-submodules https://github.com/pengzhenghao/unitree-go2-docker.git
   cd unitree-go2-docker
   ```

2. **Build the image**:
   ```bash
   bash docker_build.sh --module agiros-ubuntu --platform linux/amd64
   ```

3. **Run the container**:
   ```bash
   docker compose run --rm go2 bash
   # OR
   bash docker_run.sh
   ```

4. **Develop inside container**:
   - Your local `src/` is mounted to `/app/src`
   - ROS environment is auto-sourced via `/etc/bashrc`

### Adding New Dockerfiles

1. Create Dockerfile in appropriate subdirectory (`agiros/` or `app/`)
2. Add entry to `docker_build.sh` in three places:
   - `MODULES` associative array (module name → Dockerfile path)
   - `MODULE_STAGES` associative array (module name → comma-separated stages)
   - `MODULE_DEFAULT_STAGE` associative array (module name → default stage)
3. Add corresponding entry to `.github/workflows/docker-build.yml`
4. Update this AGENTS.md with new module details

---

## Troubleshooting

### Common Build Errors

#### 1. Network Error: `short read: expected X bytes`

**Cause**: Base image download interrupted

**Fix**:
```bash
docker buildx prune -f
bash docker_build.sh
```

#### 2. GPU Runtime Error

**Error**:
```
ERROR: could not select device driver "" with capabilities: [[gpu]]
```

**Cause**: Docker daemon configured for nvidia runtime but nvidia-container-runtime not installed

**Fix**:
```bash
sudo bash fix_docker_runtime.sh
```

This script:
- Backs up current Docker daemon config
- Changes default runtime from `nvidia` to `runc`
- Restarts Docker service
- Recreates buildx builder

#### 3. Submodule Missing

**Error**: `unitree_sdk2/CMakeLists.txt not found`

**Fix**:
```bash
git submodule update --init --recursive
```

#### 4. ntpdate Permission Error (Container)

**Note**: ntpdate may fail in containers due to permissions, but this typically doesn't affect AGIROS installation. The Dockerfile handles this gracefully.

### ARM64 Specific Issues

#### Library Path Problems

If you see linker errors on ARM64:

```bash
# Inside container, check library paths
find /opt/ros/humble -name "*.so" | grep -E "(aarch64|builtin_interfaces)"

# Verify symlinks
ls -la /opt/ros/humble/lib/*.so | head -20
```

The Dockerfiles include multiple ARM64 library path fixes. If issues persist, check:
1. Library files exist in `/opt/ros/humble/lib/aarch64-linux-gnu/`
2. Symlinks are created in `/opt/ros/humble/lib/`
3. `LD_LIBRARY_PATH` includes both paths

---

## Security Considerations

### Container Privileges

- **Privileged mode**: Required for host network and device access
- **Host network**: Required for DDS multicast communication with robot
- **Host IPC**: Required for shared memory transport

These are necessary for robot communication but limit container isolation.

### Network Security

- CycloneDDS uses multicast for discovery
- Ensure network interface `GO2_NETWORK_INTERFACE` is correctly set
- Container binds to host network stack

### Registry Credentials

- Credentials stored in GitHub/Gitee Secrets
- Use short-lived tokens when possible
- Never commit credentials to repository

---

## Image Registry

**Default Registry**: Alibaba Cloud Container Registry (ACR)

```
crpi-6q1jqce6oh00ahfb.cn-beijing.personal.cr.aliyuncs.com/jhaiq/
```

**Available Images**:

| Image | Repository Path |
|-------|-----------------|
| AGIROS openEuler | `agiros_docker` |
| AGIROS Ubuntu | `agiros_docker-ubuntu` |
| ROS2 Humble openEuler | `ros2-humble-openeuler` |
| ROS2 Foxy Ubuntu | `ros2-foxy-ubuntu` |
| ROS2 Humble Ubuntu | `ros2-humble-ubuntu` |

---

## Additional Resources

- **README.md**: User-facing documentation (Chinese)
- **TROUBLESHOOTING.md**: Detailed error fixes and network debugging
- **Unitree SDK2**: https://github.com/unitreerobotics/unitree_sdk2
- **Unitree ROS2**: https://github.com/unitreerobotics/unitree_ros2
- **openEuler ROS Guide**: https://docs.openeuler.org/zh/docs/24.03_LTS_SP3/tools/application/ros/

---

## Maintenance Notes

- **Submodules**: May need periodic updates via `git submodule update --remote`
- **Base Images**: openEuler and Ubuntu base images update regularly; consider pinning specific versions for reproducibility
- **ROS Packages**: AGIROS packages hosted on Chinese mirrors; may need updates if URLs change
- **Build Cache**: CI/CD uses inline cache for ACR compatibility

---

*Last updated: 2026-06-03*
