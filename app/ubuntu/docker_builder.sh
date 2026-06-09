#!/bin/bash
# Wrapper for backward compatibility.
# Use the unified build script at project root instead:
#
#   ./docker_build.sh --module app-ubuntu --stage unitree
#
set -euo pipefail
cd "$(dirname "$(dirname "$(dirname "$0")")")"
exec ./docker_build.sh --module app-ubuntu "$@"