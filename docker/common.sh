#!/bin/bash
# Shared helpers for Heads Docker wrapper scripts

set -euo pipefail

# Kill GPG toolstack related processes using USB devices
kill_usb_processes() {
	if [ ! -d "/dev/bus/usb" ]; then
		return 0
	fi

	if sudo lsof /dev/bus/usb/00*/0* 2>/dev/null | \
	   awk 'NR>1 {print $2}' | \
	   xargs -r ps -p | \
	   grep -E 'scdaemon|pcscd' >/dev/null 2>&1; then
		echo "Killing GPG toolstack related processes using USB devices..."
		sudo lsof /dev/bus/usb/00*/0* 2>/dev/null | \
			awk 'NR>1 {print $2}' | \
			xargs -r ps -p | \
			grep -E 'scdaemon|pcscd' | \
			awk '{print $1}' | \
			xargs -r sudo kill -9
	fi
}

# Build Docker run options based on available host capabilities
build_docker_opts() {
	local opts="-e DISPLAY=${DISPLAY} --network host --rm -ti"

	# Add USB device if available
	if [ -d "/dev/bus/usb" ]; then
		opts="${opts} --device=/dev/bus/usb:/dev/bus/usb"
		echo "--->Launching container with access to host's USB buses..." >&2
	else
		echo "--->Launching container without access to host's USB buses..." >&2
	fi

	# Add KVM device if available
	if [ -e "/dev/kvm" ]; then
		opts="${opts} --device=/dev/kvm:/dev/kvm"
	fi

	# Add X11 display support only if the socket directory exists
	if [ -d "/tmp/.X11-unix" ]; then
		opts="${opts} -v /tmp/.X11-unix:/tmp/.X11-unix"
	else
		echo "--->Host is missing /tmp/.X11-unix; X11 display forwarding will be skipped." >&2
	fi

	# If HEADS_X11_XAUTH=1, mount the user's Xauthority for setups that require MIT-MAGIC-COOKIE
	if [ "${HEADS_X11_XAUTH:-0}" != "0" ]; then
		if [ -f "${HOME}/.Xauthority" ]; then
			opts="${opts} -v ${HOME}/.Xauthority:/root/.Xauthority:ro"
		else
			echo "--->HEADS_X11_XAUTH=1 set but ${HOME}/.Xauthority not found; X11 auth may still fail." >&2
		fi
	fi

	# If host xhost does not list LOCAL, warn the user about enabling access
	if command -v xhost >/dev/null 2>&1 && ! xhost | grep -q "LOCAL:"; then
		echo "--->X11 auth may be strict; run 'xhost +SI:localuser:root' on the host or set HEADS_X11_XAUTH=1" >&2
	fi

	echo "${opts}"
}

# Common run helper
run_docker() {
	local image="$1"
	shift
	local opts workdir
	opts=$(build_docker_opts)
	workdir="$(pwd)"

	# Show the expanded docker command for transparency
	echo "---> docker run ${opts} -v ${workdir}:${workdir} -w ${workdir} ${image} -- $*" >&2

	# shellcheck disable=SC2086
	exec docker run ${opts} -v "${workdir}:${workdir}" -w "${workdir}" "${image}" -- "$@"
}
