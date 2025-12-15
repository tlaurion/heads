#!/bin/bash
#
# Run Heads build in Docker using the latest published image
# This is suitable for development and testing with the most up-to-date environment
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOCKER_IMAGE="tlaurion/heads-dev-env:latest"
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

# Handle help request
for arg in "$@"; do
	if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
		usage
		exit 0
	fi
done

echo "Using the latest Docker image: ${DOCKER_IMAGE}"

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
