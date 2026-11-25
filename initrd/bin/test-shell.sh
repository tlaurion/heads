#!/bin/bash
# Test-only boot script for QEMU board configurations. It deliberately bypasses
# the GUI and authenticated recovery flow so serial automation can run commands
# in the built initrd. Production boards must not select this script.
set -e

export PS1='heads-test> '
printf '\nHEADS_TEST_SHELL_READY\n' >/dev/ttyS0
exec /bin/bash </dev/ttyS0 >/dev/ttyS0 2>&1
