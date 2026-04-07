#!/bin/bash
#
set -e -o pipefail
. /etc/functions.sh
. /etc/gui_functions.sh
. /tmp/config

TRACE_FUNC

if [ "$CONFIG_RESTRICTED_BOOT" = y ]; then
	whiptail_error --title 'Restricted Boot Active' \
		--msgbox "Disable Restricted Boot to flash new firmware." 0 80
	exit 1
fi

UPDATE_PLAIN_EXT="$(update_plain_ext)"

while true; do
	unset menu_choice
	whiptail_type $BG_COLOR_MAIN_MENU --title "Firmware Management Menu" \
		--menu "Select the firmware function to perform\n\nRetaining settings copies existing settings to the new firmware:\n* Keeps your GPG keyring\n* Keeps changes to the default /boot device\n\nErasing settings uses the new firmware as-is:\n* Erases any existing GPG keyring\n* Restores firmware to default factory settings\n* Clears out /boot signatures\n\nIf you are just updating your firmware, you probably want to retain\nyour settings." 0 80 10 \
		'f' ' Flash the firmware with a new ROM, retain settings' \
		'c' ' Flash the firmware with a new ROM, erase settings' \
		'r' ' Rollback to previous firmware backup' \
		'x' ' Exit' \
		2>/tmp/whiptail || recovery "GUI menu failed"

	menu_choice=$(cat /tmp/whiptail)

	case "$menu_choice" in
	"x")
		exit 0
		;;
	"r")
		rollback_brand_lower="$(echo "$CONFIG_BRAND_NAME" | tr '[:upper:]' '[:lower:]')"
		rollback_dir="/boot/${rollback_brand_lower}"

		# Find the most recent backup ROM by mtime (no marker needed)
		rollback_file=""
		_rb_best=0
		for _rb_f in "${rollback_dir}"/backup_*.rom; do
			[ -f "$_rb_f" ] || continue
			_rb_mtime="$(stat -c %Y "$_rb_f" 2>/dev/null || echo 0)"
			if [ "$_rb_mtime" -gt "$_rb_best" ]; then
				_rb_best="$_rb_mtime"
				rollback_file="$_rb_f"
			fi
		done

		if [ -z "$rollback_file" ] || [ ! -f "$rollback_file" ]; then
			whiptail_error --title 'No Rollback Available' \
				--msgbox "No firmware rollback backup found.\n\nA backup is created automatically before each flash operation." 0 80
		else
			rollback_display="${rollback_file#/boot/}"
			if (whiptail_warning --title 'Rollback Firmware?' \
				--yesno "This will rollback to:\n\n$rollback_display\n\nWARNING: Current firmware will be replaced.\nDo you want to proceed?" 0 80); then
				/bin/flash.sh -c --no-backup --bypass-verify "$rollback_file"
				mount -o remount,rw /boot 2>/dev/null || true
				rm -f "$rollback_file" 2>/dev/null || true
				mount -o remount,ro /boot 2>/dev/null || true
				whiptail_type $BG_COLOR_MAIN_MENU --title 'Rollback Complete' \
					--msgbox "Rollback complete.\n\nPress Enter to reboot\n" 0 0
				/bin/reboot.sh
			fi
		fi
		;;
	f | c)
		if (whiptail_warning --title 'Flash the BIOS with a new ROM' \
			--yesno "You will need to insert a USB drive containing your BIOS image (*.zip or\n*.$UPDATE_PLAIN_EXT).\n\nAfter you select this file, this program will reflash your BIOS.\n\nDo you want to proceed?" 0 80); then
			mount_usb
			if grep -q /media /proc/mounts; then
				# 'find' parameters to match desired ROM extensions
				FIND_ROM_EXTS=(\( -name "*.$UPDATE_PLAIN_EXT" -o -type f -name "*.zip" \))
				if [ "${CONFIG_BOARD%_*}" = talos-2 ]; then
					# Show only *.tgz on talos-2 (lacks ZIP update package support)
					FIND_ROM_EXTS=(-name "*.$UPDATE_PLAIN_EXT")
				fi
				# Media errors can cause this to fail (flash drive pulled, filesystem
				# corruption, etc.)
				if ! find /media ! -path '*/\.*' -type f "${FIND_ROM_EXTS[@]}" | sort -r >/tmp/filelist.txt; then
					whiptail_error --title 'Unable to read USB drive' \
						--msgbox "The USB drive is not readable.  Check the drive, reformat, or try a
                    \ndifferent drive." 0 80
					exit 1
				fi
				file_selector "/tmp/filelist.txt" "Choose the ROM to flash"
				if [ "$FILE" == "" ]; then
					exit 1
				else
					PKG_FILE=$FILE
				fi

				# Display the package file without the "/media/" prefix
				PKG_FILE_DISPLAY="${PKG_FILE#"/media/"}"

				# Unzip the package
				PKG_EXTRACT="/tmp/flash_gui/update_package"
				rm -rf "$PKG_EXTRACT"
				mkdir -p "$PKG_EXTRACT"

				# is an update package provided?
				if [ -z "${PKG_FILE##*.zip}" ]; then
					if ! prepare_flash_image "$PKG_FILE" "$PKG_EXTRACT"; then
						whiptail_error --title 'ROM Integrity Check Failed!' \
							--msgbox "Integrity check failed in\n$PKG_FILE_DISPLAY.\n\n$PREPARED_ROM_ERROR\n\nDid not flash.\n\nPlease check your file (e.g. re-download).\n" 0 80
						exit 1
					fi
					# Continue on using the verified ROM
					ROM="$PREPARED_ROM"
				else
					# talos-2 uses a .tgz file for its "plain" update, contains other parts as well, validated against hashes under flash.sh
					# Skip prompt for hash validation for talos-2. Only method is through tgz or through bmc with individual parts
					if [ "${CONFIG_BOARD%_*}" != talos-2 ]; then
						# Though a plain ROM isn't a package, copy it to /tmp before doing
						# anything, so we can be sure the media won't disappear or fail
						# while flashing.
						if ! cp "$PKG_FILE" "$PKG_EXTRACT/"; then
							whiptail_error --title 'Failed to read ROM' \
								--msgbox "Failed to read ROM:\n$PKG_FILE_DISPLAY\n\nPlease check your file (e.g. re-download).\n" 0 0
							exit 1
						fi
						ROM="$PKG_EXTRACT/$(basename "$PKG_FILE")"
						ROM_HASH=$(sha256sum "$ROM" | awk '{print $1}')
						if ! (whiptail_error --title 'Flash ROM without integrity check?' \
							--yesno "You have provided a *.$UPDATE_PLAIN_EXT file. The integrity of the file can not be\nchecked automatically for this file type.\n\nROM: $PKG_FILE_DISPLAY\nSHA256SUM: $ROM_HASH\n\nIf you do not know how to check the file integrity yourself,\nyou should use a *.zip file instead.\n\nIf the file is damaged, you will not be able to boot anymore.\nDo you want to proceed flashing without file integrity check?" 0 0); then
							exit 1
						fi
					else
						#We are on talos-2, so we have a tgz file. We will pass it directly to flash.sh which will take care of it
						ROM="$PKG_FILE"
					fi
				fi

				# Offer to remove old backups before flashing so they are excluded
				# from the next /boot signing and do not exhaust /boot space.
				if list_old_flash_backups; then
					_cleanup_msg=""
					for _old in $OLD_FLASH_BACKUPS; do
						_cleanup_msg="${_cleanup_msg}  ${_old#/boot/}\n"
					done
					if (whiptail_warning --title 'Old Firmware Backups Found' \
						--yesno "Backups older than ${CONFIG_FLASH_BACKUP_RETENTION:-30} days:\n\n${_cleanup_msg}\nDelete to free /boot space before flashing?" 0 80); then
						mount -o remount,rw /boot 2>/dev/null || true
						for _old in $OLD_FLASH_BACKUPS; do
							rm -f "$_old" 2>/dev/null || true
						done
						mount -o remount,ro /boot 2>/dev/null || true
					fi
				fi

				if [ "$menu_choice" == "c" ]; then
					/bin/flash.sh -c "$ROM"
					# after flash, /boot signatures are now invalid so go ahead and clear them
					if ls /boot/kexec* >/dev/null 2>&1; then
						(
							mount -o remount,rw /boot 2>/dev/null
							rm /boot/kexec* 2>/dev/null
							mount -o remount,ro /boot 2>/dev/null
						)
					fi
				else
					/bin/flash.sh "$ROM"
				fi
				whiptail_type $BG_COLOR_MAIN_MENU --title 'ROM Flashed Successfully' \
					--msgbox "$PKG_FILE_DISPLAY\n\nhas been flashed successfully.\n\nPress Enter to reboot\n" 0 0
				umount /media
				/bin/reboot.sh
			fi
		fi
		;;
	esac

done
exit 0
