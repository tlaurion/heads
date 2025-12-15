#!/bin/bash
#
# Run Heads build in Docker using the CircleCI image version for reproducible builds
# This script extracts the Docker image from .circleci/config.yml to match CircleCI builds exactly
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE=".circleci/config.yml"
readonly COMMON_SH="${SCRIPT_DIR}/docker/common.sh"

if [ ! -f "${COMMON_SH}" ]; then
	echo "Error: ${COMMON_SH} not found" >&2
	exit 1
fi

# shellcheck source=/dev/null
source "${COMMON_SH}"

# ============================================================================
# FUNCTIONS
# ============================================================================

usage() {
	cat << EOF
Usage: $0 [OPTIONS] -- [COMMAND]

Options:
  CPUS=N              Set the number of CPUs
  V=1                 Enable verbose mode
  -h, --help          Display this help message

Command:
  The command to run inside the Docker container (e.g., make BOARD=BOARD_NAME)

Examples:
  $0 make BOARD=qemu-coreboot-fbwhiptail-tpm2
  $0 make BOARD=t440p V=1

For more advanced QEMU testing options, refer to targets/qemu.md and boards/qemu-*/*.config
EOF
}

# ============================================================================
# MAIN
# ============================================================================

DOCKER_IMAGE=$(grep -oP '^\s*-?\s*image:\s*\K(tlaurion/heads-dev-env:[^\s]+)' "${CONFIG_FILE}" | head -n 1)

if [ -z "${DOCKER_IMAGE}" ]; then
	echo "Error: Docker image not found in ${CONFIG_FILE}" >&2
	exit 1
fi

echo "Using CircleCI Docker image: ${DOCKER_IMAGE}"

# Handle Ctrl-C gracefully
trap "echo 'Script interrupted. Exiting...'; exit 130" SIGINT

# Kill processes using USB devices
kill_usb_processes

# Display usage information
cat << EOF

----
Usage reminder: The minimal command is 'make BOARD=XYZ', where additional
options, including 'V=1' or 'CPUS=N' are optional.

For more advanced QEMU testing options, refer to:
  - targets/qemu.md
  - boards/qemu-*/*.config

Type 'exit' within the Docker container to return to the host.
----

EOF

# Build Docker options and execute
run_docker "${DOCKER_IMAGE}" "$@"
