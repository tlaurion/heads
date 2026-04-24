#!/bin/bash
# Boot from signed ISO file on USB media
#
# ============================================================================
# Supported boot parameters by distribution (researched from initramfs code)
# ============================================================================
# All params passed unconditionally - ISO initrd uses what it needs, ignores rest.
#
# DEBIAN LIVE-BOOT (Debian/Ubuntu/Kali/MX/PureOS/Kicksecure):
#   findiso=/path/to.iso      - Scan all disks for ISO path
#   fromiso=/dev/sdXN/path   - Mount from specific block device
#   iso-scan/filename=/path  - Search for ISO by filename
#   live-media=removable     - Restrict to removable USB
#   live-media-path=/live  - Override default /live path
#   boot=live              - Activate Debian live-boot
#   boot=casper           - Activate Ubuntu casper (alias for boot=live)
#   persistence           - Enable persistence (labeled partition)
#   nopersistence         - Disable persistence
#   overlay-size=2G       - Set tmpfs overlay size
#   toram                 - Copy entire media to RAM before boot
#
# ARCH LINUX (archiso):
#   img_dev=/dev/disk/by-uuid/UUID - Block device containing ISO
#   img_loop=/path/to.iso    - Path to ISO on that device
#   archisobasedir=arch     - Base directory on ISO (default: arch)
#   archisolabel=LABEL      - ISO volume label to search for
#
# RED HAT / FEDORA (Anaconda):
#   inst.stage2=hd:LABEL  - Installer stage2 location (DVD/ISO)
#   inst.repo=             - Installer repository
#   live-media=removable  - Live media detection
#   boot=live             - Fedora Live media
#
# NIXOS:
#   iso-scan/filename=/path - Loopback ISO path
#   nixos=               - Path to NixOS configuration
#   copytoram            - Copy SquashFS to RAM
#   root=live:LABEL     - Live root by label
#
# DRACUT (Fedora/RHEL/CentOS):
#   live-media=removable  - Live media detection
#   rd.live.image        - Live image boot
#   rd.live.squashimg=  - SquashFS location
#
# ============================================================================
# Flow:
# 1. Mount ISO as loopback
# 2. Check *.cfg for boot methods (simple detection)
# 3. If not found, unpack initramfs (complex detection)
# 4. Warn if unsupported, but don't block (let user try)
# 5. Check FS support from initramfs
# ============================================================================
#
# USB filesystems supported by Heads: ext4, vfat, exfat, xfs
#
set -e -o pipefail
. /etc/functions.sh
. /etc/gui_functions.sh
. /tmp/config

TRACE_FUNC

MOUNTED_ISO_PATH="$1"
ISO_PATH="$2"
DEV="$3"

STATUS "Verifying ISO"
# Verify the signature on the hashes
ISOSIG="$MOUNTED_ISO_PATH.sig"
if ! [ -r "$ISOSIG" ]; then
	ISOSIG="$MOUNTED_ISO_PATH.asc"
fi

ISO_PATH="${ISO_PATH##/}"

if [ -r "$ISOSIG" ]; then
	# Signature found, verify it
	gpgv.sh --homedir=/etc/distro/ "$ISOSIG" "$MOUNTED_ISO_PATH" ||
		DIE 'ISO signature failed'
	STATUS_OK "ISO signature verified"
else
	# No signature found, prompt user with warning
	WARN "No signature found for ISO"
	if [ -x /bin/whiptail ]; then
		if ! whiptail_warning --title 'UNSIGNED ISO WARNING' --yesno \
			"WARNING: UNSIGNED ISO DETECTED\n\nThe selected ISO file:\n$MOUNTED_ISO_PATH\n\nDoes not have a detached signature (.sig or .asc file).\n\n\nThis means the integrity and authenticity of the ISO cannot be verified.\nBooting unsigned ISOs is potentially unsafe.\n\nDo you want to proceed with booting this unsigned ISO?" \
			0 80; then
			DIE "Unsigned ISO boot cancelled by user"
		fi
	else
		WARN "The selected ISO file does not have a detached signature"
		WARN "Integrity and authenticity of the ISO cannot be verified"
		WARN "Booting unsigned ISOs is potentially unsafe"
		INPUT "Do you want to proceed anyway? (y/N):" -n 1 response
		if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
			DIE "Unsigned ISO boot cancelled by user"
		fi
	fi
	NOTE "Proceeding with unsigned ISO boot"
fi

STATUS "Mounting ISO and booting"
mount -t iso9660 -o loop $MOUNTED_ISO_PATH /boot ||
	DIE '$MOUNTED_ISO_PATH: Unable to mount /boot'

DEV_UUID=$(blkid $DEV | tail -1 | tr " " "\n" | grep UUID | cut -d\" -f2)

if [ -d "/boot/install.amd" ] || [ -d "/boot/install" ]; then
	if [ -f "/boot/install.amd/vmlinuz" ] || [ -f "/boot/install/vmlinuz" ]; then
		WARN "Installer ISO detected - may not boot from USB file"
		NOTE "Write to USB with dd if issues: sudo cp image.iso /dev/sdX"
	fi
fi

# Scan an initrd for supported filesystems and boot mechanisms.
# This function unpacks the initrd and searches for:
# - Kernel modules (*.ko/*.ko.xz) -> supported filesystems
# - Scripts and configs (*.sh, *.conf, init, scripts/*) -> boot mechanisms
#
# Supported filesystems detected: ext4, vfat, exfat, ntfs, btrfs, xfs
# Supported boot mechanisms detected: iso-scan, live-media, boot-live,
#   casper, nixos, anaconda, overlay, toram, device
#
# Results are stored in global variables:
# - supported_fses: Space-separated list of supported filesystem types
# - supported_boot: Space-separated list of supported boot mechanisms
scan_initramfs() {
	local path="$1"
	local tmpdir=""
	local boot_content=""

	[ -r "$path" ] || return 1

	tmpdir=$(mktemp -d)
	/bin/bash /bin/unpack_initramfs.sh "$path" "$tmpdir" 2>/dev/null || true

	if [ -d "$tmpdir" ] && [ "$(ls -A "$tmpdir" 2>/dev/null)" ]; then
		while read ko; do
			name=$(basename "$ko")
			case "$name" in
			ext4*) supported_fses="${supported_fses}ext4 " ;;
			vfat* | msdos*) supported_fses="${supported_fses}vfat " ;;
			exfat*) supported_fses="${supported_fses}exfat " ;;
			xfs*) supported_fses="${supported_fses}xfs " ;;
			esac
		done < <(find "$tmpdir" -type f \( -name "*.ko" -o -name "*.ko.xz" \) 2>/dev/null)

		boot_content=$(find "$tmpdir" -type f \( -name "*.sh" -o -name "*.conf" -o -name "*.cfg" -o -name "init" -o -name "*.txt" -o -path "*/scripts/*" -o -path "*/conf/*" \) -print 2>/dev/null | xargs cat 2>/dev/null) || boot_content=""
		rm -rf "$tmpdir"
	else
		rm -rf "$tmpdir"
		boot_content=$(strings "$path" 2>/dev/null) || true
	fi

	for pattern in "iso.scan|findiso" "live.media|live-media" "boot=live|rd.live.image|rd.live.squash" "boot.casper|casper" "nixos" "inst.stage2|inst.repo" "overlay|overlayfs" "toram" "CDLABEL|img_dev|check_dev"; do
		case "$pattern" in
		iso.scan|findiso) label="iso-scan" ;;
		live.media|live-media) label="live-media" ;;
		boot=live|rd.live.image|rd.live.squash) label="boot-live" ;;
		boot.casper|casper) label="casper" ;;
		nixos) label="nixos" ;;
		inst.stage2|inst.repo) label="anaconda" ;;
		overlay|overlayfs) label="overlay" ;;
		toram) label="toram" ;;
		CDLABEL|img_dev|check_dev) label="device" ;;
		esac
		echo "$boot_content" | grep -qEi "$pattern" &&
			supported_boot="${supported_boot}${label} " || true
	done
}

# Detect if the mounted ISO is an installer ISO (not a live/bootable ISO).
# Installer ISOs (like Debian DVD installer) do not support booting from
# ISO file on USB - they only work with physical CD/DVD or PXE boot.
#
# Detection checks for:
# - /boot/install* directory (installer content)
# - /boot/isolinux or /boot/grub (boot configs, but no live boot)
# - /boot/install.amd/vmlinuz and initrd.gz (installer kernel/initrd)
#
# Detect boot mechanisms supported by the ISO's initrd.
# This function:
# 1. Parses all *.cfg files to find initrd paths
# 2. For each initrd, calls scan_initramfs() to extract supported features
# 3. Outputs two lines: "fs:..." and "boot:..." with detected support
#
# This is the primary detection method - scanning initrd content directly
# provides the most accurate picture of what the ISO can do.
detect_initrd_boot_support() {
	local supported_fses=""
	local supported_boot=""
	local initrd_paths=""

	for cfg in $(find /boot -name '*.cfg' -type f 2>/dev/null); do
		[ -r "$cfg" ] || continue
		while IFS= read -r entry; do
			[ -z "$entry" ] && continue
			initrd_field=$(echo "$entry" | tr '|' '\n' | grep '^initrd' | tail -1) || continue
			[ -z "$initrd_field" ] && continue
			initrd_val=$(echo "$initrd_field" | sed 's/^initrd //') || continue
			[ -z "$initrd_val" ] && continue
			for init in $(echo "$initrd_val" | tr ',' ' '); do
				[ -z "$init" ] && continue
				case " $initrd_paths " in
				*" $init "*) continue ;;
				esac
				initrd_paths="${initrd_paths}${init} "
			done
		done < <(/bin/bash /bin/kexec-parse-boot.sh /boot "$cfg" 2>/dev/null || true)
	done

	[ -z "$initrd_paths" ] && return 0

	for ipath in $initrd_paths; do
		full_path="/boot/${ipath#/}"
		[ -r "$full_path" ] && scan_initramfs "$full_path"
	done

	[ -n "$supported_fses" ] && echo "fs:$supported_fses"
	[ -n "$supported_boot" ] && echo "boot:$supported_boot"
	return 0
}

# Fallback detection: scan *.cfg files for boot parameters.
# This is used when initrd detection fails or yields no results.
# It greps through boot config files (GRUB, syslinux, ISOLINUX) for
# known boot parameters that indicate ISO-on-USB support.
#
# This method is less accurate than initrd scanning but can provide
# hints when initrd extraction fails.
extract_boot_params_from_cfg() {
	for cfg in $(find /boot -name '*.cfg' -type f 2>/dev/null); do
		[ -r "$cfg" ] || continue
		if ! grep -qE '^[^#]*(linux|menuentry|label|append)[[:space:]]' "$cfg" 2>/dev/null; then
			continue
		fi
		local boot_params=""
		while IFS= read -r line; do
			case "$line" in
			*boot=live* | *rd.live.image* | *rd.live.squashimg=*)
				if ! echo "$boot_params" | grep -q "boot-live"; then
					boot_params="${boot_params}boot-live "
				fi
				;;
			*iso-scan/filename=* | *findiso=*)
				if ! echo "$boot_params" | grep -q "iso-scan"; then
					boot_params="${boot_params}iso-scan "
				fi
				;;
			*live-media=* | *live.media=*)
				if ! echo "$boot_params" | grep -q "live-media"; then
					boot_params="${boot_params}live-media "
				fi
				;;
			*boot=casper* | *casper*)
				if ! echo "$boot_params" | grep -q "casper"; then
					boot_params="${boot_params}casper "
				fi
				;;
			*inst.stage2=* | *inst.repo=*)
				if ! echo "$boot_params" | grep -q "anaconda"; then
					boot_params="${boot_params}anaconda "
				fi
				;;
			*nixos*)
				if ! echo "$boot_params" | grep -q "nixos"; then
					boot_params="${boot_params}nixos "
				fi
				;;
			*overlay=* | *overlayfs*)
				if ! echo "$boot_params" | grep -q "overlay"; then
					boot_params="${boot_params}overlay "
				fi
				;;
			*toram*)
				if ! echo "$boot_params" | grep -q "toram"; then
					boot_params="${boot_params}toram "
				fi
				;;
			*CDLABEL=* | *img_dev=* | *check_dev*)
				if ! echo "$boot_params" | grep -q "device"; then
					boot_params="${boot_params}device "
				fi
				;;
			esac
		done <"$cfg"
		[ -n "$boot_params" ] && echo "cfg:$boot_params" && return 0
	done
	return 1
}

# ============================================================================
# Boot detection flow
# Step 1: Check *.cfg for boot methods (simple)
# Step 2: If not found, unpack initramfs and check init scripts (complex)
# Step 3: Warn if unsupported
# Step 4: Check FS support from initramfs
# ============================================================================

STATUS "Detecting boot method from *.cfg..."
SETE="set +e"
$SETE

CFG_BOOT=$(extract_boot_params_from_cfg 2>/dev/null | grep "^cfg:" | sed 's/^cfg://') || CFG_BOOT=""
DEBUG "CFG_BOOT from *.cfg: '$CFG_BOOT'"

if [ -z "$CFG_BOOT" ]; then
	STATUS "Checking initramfs for boot methods..."
	tmp_support=$(detect_initrd_boot_support 2>/dev/null) || tmp_support=""
	INITRD_BOOT=$(echo "$tmp_support" | grep "^boot:" | sed 's/^boot://') || INITRD_BOOT=""
	SUPPORTED_FSES=$(echo "$tmp_support" | grep "^fs:" | sed 's/^fs://') || SUPPORTED_FSES=""
	DEBUG "INITRD_BOOT: '$INITRD_BOOT'"
	DEBUG "SUPPORTED_FSES: '$SUPPORTED_FSES'"
	DETECTED_METHODS="$INITRD_BOOT"
else
	DETECTED_METHODS="$CFG_BOOT"
fi

set -e

DEBUG "DETECTED_METHODS='$DETECTED_METHODS'"

if [ -z "$DETECTED_METHODS" ]; then
	WARN "No supported boot method detected from *.cfg or initramfs"
	if [ -x /bin/whiptail ]; then
		if ! whiptail_warning --title 'ISO BOOT NOT SUPPORTED' --yesno \
			"This ISO does not support booting from ISO file on USB.\n\nNo supported boot method detected in *.cfg or initramfs.\n\nTo use this ISO:\n- Linux: sudo cp image.iso /dev/sdX\n- Windows/Mac: Use Rufus DD mode\n\nDo you want to try anyway?" \
			0 80; then
			DIE "ISO boot cancelled - no supported boot method"
		fi
	else
		INPUT "No boot method detected. Try anyway? [y/N]:" -n 1 response
		[ "$response" != "y" ] && [ "$response" != "Y" ] && DIE "ISO boot cancelled"
	fi
fi

DEV_FSTYPE=$(blkid "$DEV" 2>/dev/null | tail -1 | grep -oE 'TYPE="[^"]+"' | sed 's/TYPE="//;s/"$//') || DEV_FSTYPE=""
DEBUG "USB device filesystem: '$DEV_FSTYPE'"

if [ -n "$SUPPORTED_FSES" ] && [ -n "$DEV_FSTYPE" ]; then
	if ! echo "$SUPPORTED_FSES" | grep -qw "$DEV_FSTYPE" 2>/dev/null; then
		WARN "USB filesystem ($DEV_FSTYPE) may not be supported by ISO initrd"
		DEBUG "Supported filesystems: $SUPPORTED_FSES"
	fi || true
fi

# ============================================================================
# Boot parameter injection
# ============================================================================
# Inject minimal boot-from-ISO parameters. The ISO's initrd will use
# whichever parameters it understands and ignore the rest.
#
# We inject iso-scan/filename as the primary parameter - this is
# the most widely supported boot-from-ISO parameter across distros.
# Other parameters (findiso, fromiso, img_dev, etc.) are injected
# as fallback for distros that need them.
# ============================================================================

ISO_DEV="/dev/disk/by-uuid/$DEV_UUID"
ISO_PATH_ABS="/$ISO_PATH"

ADD="fromiso=/dev/disk/by-uuid/$DEV_UUID/$ISO_PATH img_dev=/dev/disk/by-uuid/$DEV_UUID iso-scan/filename=/${ISO_PATH} img_loop=$ISO_PATH iso=$DEV_UUID/$ISO_PATH"
REMOVE=""

paramsdir="/media/kexec_iso/$ISO_PATH"
check_config $paramsdir

ADD_FILE=/tmp/kexec/kexec_iso_add.txt
if [ -r $ADD_FILE ]; then
	NEW_ADD=$(cat $ADD_FILE)
	ADD=$(eval "echo \"$NEW_ADD\"")
fi
DEBUG "Overriding ISO kernel arguments with additions: $ADD"

REMOVE_FILE=/tmp/kexec/kexec_iso_remove.txt
if [ -r $REMOVE_FILE ]; then
	NEW_REMOVE=$(cat $REMOVE_FILE)
	REMOVE=$(eval "echo \"$NEW_REMOVE\"")
fi
DEBUG "Overriding ISO kernel arguments with suppressions: $REMOVE"

# Call kexec and indicate that hashes have been verified
DO_WITH_DEBUG kexec-select-boot.sh -b /boot -d /media -p "$paramsdir" \
	-a "$ADD" -r "$REMOVE" -c "*.cfg" -u -i

DIE "Something failed in selecting boot"
