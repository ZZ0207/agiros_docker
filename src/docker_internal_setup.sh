#!/bin/bash
set -e

# Source the ROS environment
source ${ROS_INSTALL_BASE}/setup.bash

# Print an initialization message
echo "Docker container initialized successfully. ROS2 environment is now set up."

# Execute the command passed as arguments (e.g., bash)
exec "$@"