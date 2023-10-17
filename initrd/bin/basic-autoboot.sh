#!/bin/bash
set -o pipefail

. /etc/functions

BOOT_MENU_OPTIONS=/tmp/basic-autoboot-options

DO_WITH_DEBUG scan_boot_options /boot "grub.cfg" "$BOOT_MENU_OPTIONS"
if [ -s "$BOOT_MENU_OPTIONS" ]; then
	kexec-boot -b /boot -e "$(head -1 "$BOOT_MENU_OPTIONS")"
fi
