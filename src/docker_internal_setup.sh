#!/bin/bash
set -e

# Smart ROS environment detection
# Try AGIROS first, then fall back to standard ROS2
if [ -f "/opt/agiros/humble/setup.bash" ]; then
    ROS_SETUP_PATH="/opt/agiros/humble/setup.bash"
    ROS_TYPE="AGIROS"
elif [ -f "/opt/ros/humble/setup.bash" ]; then
    ROS_SETUP_PATH="/opt/ros/humble/setup.bash"
    ROS_TYPE="ROS2 Humble"
elif [ -f "${ROS_INSTALL_BASE}/setup.bash" ]; then
    ROS_SETUP_PATH="${ROS_INSTALL_BASE}/setup.bash"
    ROS_TYPE="ROS (from ROS_INSTALL_BASE)"
else
    echo "⚠️ Warning: Could not find ROS setup.bash file"
    echo "Searched locations:"
    echo "  - /opt/agiros/humble/setup.bash"
    echo "  - /opt/ros/humble/setup.bash"
    echo "  - ${ROS_INSTALL_BASE}/setup.bash"
    ROS_SETUP_PATH=""
    ROS_TYPE="None"
fi

# Source the ROS environment if found
if [ -n "$ROS_SETUP_PATH" ]; then
    source "$ROS_SETUP_PATH"
    echo "✅ Docker container initialized successfully. $ROS_TYPE environment is now set up."
else
    echo "⚠️ Running without ROS environment"
fi

# Execute the command passed as arguments (e.g., bash)
exec "$@"