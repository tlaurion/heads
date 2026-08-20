#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/boot/grub"
touch "$tmpdir/boot/vmlinuz" "$tmpdir/boot/initrd" \
	"$tmpdir/boot/xen.gz" "$tmpdir/boot/dom0-vmlinuz" \
	"$tmpdir/boot/dom0-initrd"

printf '%s\n' \
	'menuentry "root boot" {' \
	' linux /boot/vmlinuz root=/dev/test' \
	' initrd /boot/initrd' \
	'}' \
	'menuentry "root xen" {' \
	' multiboot /boot/xen.gz placeholder' \
	' module /boot/dom0-vmlinuz root=/dev/test' \
	' module --nounzip /boot/dom0-initrd' \
	'}' >"$tmpdir/boot/grub/grub.cfg"

printf '%s\n' \
	'DEBUG() { :; }' \
	'DIE() { echo "$*" >&2; exit 1; }' >"$tmpdir/functions.sh"

sed "s|^\. /etc/functions.sh$|. $tmpdir/functions.sh|" \
	"$repo_root/initrd/bin/kexec-parse-boot.sh" >"$tmpdir/kexec-parse-boot.sh"
chmod +x "$tmpdir/kexec-parse-boot.sh"

entry=$("$tmpdir/kexec-parse-boot.sh" "$tmpdir/boot" \
	"$tmpdir/boot/grub/grub.cfg")

case "$entry" in
*'|kernel /vmlinuz|initrd /initrd|append root=/dev/test'*) ;;
*)
	echo "Unexpected parsed entry: $entry" >&2
	exit 1
	;;
esac

case "$entry" in
*'|kernel /xen.gz placeholder|module /dom0-vmlinuz root=/dev/test|module /dom0-initrd'*) ;;
*)
	echo "Unexpected parsed Xen entry: $entry" >&2
	exit 1
	;;
esac

echo "Root-filesystem /boot path tests passed"
