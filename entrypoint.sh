#!/bin/bash
set -e

# Print debug info
echo "Starting with user: $(whoami)"

# Run the command
exec "$@"