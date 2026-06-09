#!/bin/bash
# Run the app development container.
# Uses the tag built by:
#   ./docker_build.sh --module app-ubuntu --stage unitree
#
# Example:
#   ./app/ubuntu/docker_run_app_dev.sh

set -euo pipefail

IMAGE_TAG="${1:-app-ubuntu-unitree:2606}"

docker run -it \
  -e DISPLAY="${DISPLAY:-:0}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --network host \
  --privileged \
  "${IMAGE_TAG}" \
  /bin/bash