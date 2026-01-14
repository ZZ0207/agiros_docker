#!/bin/bash
# Fix Docker daemon configuration to use default runtime instead of nvidia
# This script requires sudo privileges

set -e

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_JSON="${DAEMON_JSON}.backup.$(date +%Y%m%d_%H%M%S)"

echo "Backing up current Docker daemon configuration..."
sudo cp "${DAEMON_JSON}" "${BACKUP_JSON}"

echo "Modifying Docker daemon configuration..."
# Use jq if available, otherwise use sed
if command -v jq &> /dev/null; then
    sudo jq 'del(.default-runtime) | .default-runtime = "runc"' "${DAEMON_JSON}" > /tmp/daemon.json.new
    sudo mv /tmp/daemon.json.new "${DAEMON_JSON}"
else
    # Fallback: use sed to comment out or remove default-runtime
    sudo sed -i 's/"default-runtime": "nvidia"/"default-runtime": "runc"/' "${DAEMON_JSON}"
fi

echo "Restarting Docker service..."
sudo systemctl restart docker

echo "Waiting for Docker to be ready..."
sleep 3

echo "Verifying Docker is running..."
docker info > /dev/null && echo "✓ Docker is running" || echo "✗ Docker failed to start"

echo "Recreating buildx builder..."
docker buildx rm multiarch 2>/dev/null || true
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap

echo "Done! Docker daemon configuration has been updated."
echo "Backup saved to: ${BACKUP_JSON}"
