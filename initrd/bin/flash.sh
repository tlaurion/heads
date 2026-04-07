#!/bin/bash
set -e -o pipefail
. /etc/functions.sh
. /tmp/config

echo

TRACE_FUNC

case "$CONFIG_FLASH_OPTIONS" in
  "" )
    DIE "ERROR: No flash options have been configured!\n\nEach board requires specific CONFIG_FLASH_OPTIONS options configured. It's unsafe to flash without them.\n\nAborting."
  ;;
  * )
    DEBUG "Flash options detected: $CONFIG_FLASH_OPTIONS"
    INFO "Board $CONFIG_BOARD detected with flash options configured. Continuing..."
  ;;
esac

flash_status() { STATUS "$*"; }
flash_status_ok() { STATUS_OK "$*"; }

check_spi_wp() {
  TRACE_FUNC
  local wp_out wp_rc wp_opts
  STATUS "Checking SPI write protection status..."
  wp_opts="${CONFIG_FLASH_OPTIONS#flashprog}"
  wp_opts="${wp_opts//--progress/}"
  wp_rc=0
  wp_out=$(flashprog wp status $wp_opts 2>&1) || wp_rc=$?
  LOG "SPI WP status output: $wp_out"
  if [ "$wp_rc" -ne 0 ]; then
    DEBUG "WP status not available for this programmer (rc=$wp_rc)"
    STATUS_OK "Write protection status not available for this programmer"
    return 0
  fi
  if echo "$wp_out" | grep -q "Protection mode: disabled"; then
    DEBUG "SPI write protection: all regions unlocked"
    STATUS_OK "All SPI regions are write-unlocked"
    return 0
  fi
  DEBUG "SPI write protection: ACTIVE on one or more regions"
  return 1
}

flash_rom() {
  TRACE_FUNC
  ROM=$1
  if [ "$READ" -eq 1 ]; then
    flash_status "Reading current firmware to $ROM..."
    $CONFIG_FLASH_OPTIONS -r "${ROM}" \
    || recovery "Backup to $ROM failed"
    flash_status_ok "Firmware read complete: $ROM"
  else
    cp "$ROM" "/tmp/${CONFIG_BOARD}.rom"
    sha256sum "/tmp/${CONFIG_BOARD}.rom"

    if ! check_spi_wp; then
      WARN "SPI write protection is ACTIVE on one or more regions."
      WARN "The flash write may fail or only partially succeed."
      WARN "Check the region list above before proceeding."
    fi

    if [ "$CLEAN" -eq 0 ]; then
      DEBUG "Preserving existing config in ROM"
      preserve_rom "/tmp/${CONFIG_BOARD}.rom" \
      || recovery "$ROM: Config preservation failed"
    else
      DEBUG "Clean flash: skipping config preservation"
    fi

    if cbfs.sh -r serial_number > /tmp/serial 2>/dev/null; then
      STATUS "Persisting system serial"
      cbfs.sh -o "/tmp/${CONFIG_BOARD}.rom" -d serial_number 2>/dev/null || true
      cbfs.sh -o "/tmp/${CONFIG_BOARD}.rom" -a serial_number -f /tmp/serial
    fi

    if [ "$CONFIG_BOARD" = "librem_l1um" ]; then
      STATUS "Persisting PCHSTRP9"
      $CONFIG_FLASH_OPTIONS -r /tmp/ifd.bin --ifd -i fd >/dev/null 2>&1 \
      || DIE "Failed to read flash descriptor"
      dd if=/tmp/ifd.bin bs=1 count=4 skip=292 of=/tmp/pchstrp9.bin >/dev/null 2>&1
      dd if=/tmp/pchstrp9.bin bs=1 count=4 seek=292 of="/tmp/${CONFIG_BOARD}.rom" conv=notrunc >/dev/null 2>&1
    fi

    if [ "$SAVE_BACKUP" -eq 1 ]; then
      DEBUG "Rollback backup enabled - saving current firmware before write"
      local brand_lower backup_dir backup_ts backup_file
      brand_lower="$(echo "$CONFIG_BRAND_NAME" | tr '[:upper:]' '[:lower:]')"
      backup_dir="/boot/${brand_lower}"
      backup_ts="$(date +%Y%m%d%H%M%S 2>/dev/null || echo "unknown")"
      backup_file="${backup_dir}/backup_${CONFIG_BOARD}_${backup_ts}.rom"
      flash_status "Saving rollback backup to $backup_file..."
      if grep -q " /boot " /proc/mounts 2>/dev/null; then
        mount -o remount,rw /boot 2>/dev/null || true
        mkdir -p "$backup_dir" 2>/dev/null || true
        if $CONFIG_FLASH_OPTIONS -r "$backup_file" 2>&1; then
          flash_status_ok "Rollback backup saved: $backup_file"
          DEBUG "Backup written: $backup_file"
        else
          WARN "Rollback backup failed - proceeding without backup"
        fi
        mount -o remount,ro /boot 2>/dev/null || true
      else
        WARN "/boot is not mounted - rollback backup skipped"
      fi
    else
      DEBUG "Rollback backup disabled (SAVE_BACKUP=0)"
    fi

    WARN "Do not power off computer. Updating firmware, this will take a few minutes"
    flash_status "Writing firmware..."
    if [ "$NOVERIFY" -eq 1 ]; then
      NOTE "--bypass-verify active: skipping post-write verification"
      $CONFIG_FLASH_OPTIONS -w "/tmp/${CONFIG_BOARD}.rom" --noverify 2>&1 \
        || recovery "$ROM: Flash failed"
    else
      $CONFIG_FLASH_OPTIONS -w "/tmp/${CONFIG_BOARD}.rom" 2>&1 \
        || recovery "$ROM: Flash failed"
    fi
    flash_status_ok "Firmware write complete"
  fi
}

CLEAN=0
READ=0
NOVERIFY=0
SAVE_BACKUP=1
ROM=""

if [ "$CONFIG_FLASH_NO_VERIFY" = "y" ]; then
  NOVERIFY=1
  DEBUG "CONFIG_FLASH_NO_VERIFY=y: post-write verification disabled by config"
fi

if [ "$CONFIG_FLASH_SAVE_BACKUP" = "n" ]; then
  SAVE_BACKUP=0
  DEBUG "CONFIG_FLASH_SAVE_BACKUP=n: rollback backup disabled by config"
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -c)               CLEAN=1      ; shift ;;
    -r)               READ=1       ; shift ;;
    --bypass-verify)  NOVERIFY=1   ; shift ;;
    --save-backup)    SAVE_BACKUP=1 ; shift ;;
    --no-backup)      SAVE_BACKUP=0 ; shift ;;
    -*) DIE "Unknown flag: $1\nUsage: $0 [-c|-r] [--bypass-verify] [--save-backup|--no-backup] <path/to/image.(rom|zip|tgz)>" ;;
    *)  ROM="$1" ; shift ; break ;;
  esac
done

DEBUG "Flags: CLEAN=$CLEAN READ=$READ NOVERIFY=$NOVERIFY SAVE_BACKUP=$SAVE_BACKUP"

if [ -z "$ROM" ]; then
  DIE "Usage: $0 [-c|-r] [--bypass-verify] [--save-backup|--no-backup] <path/to/image.(rom|zip|tgz)>

  (no flags)       Flash firmware, retaining GPG keyring and /boot device settings
  -c               Flash firmware, erasing all settings (factory reset)
  -r               Read/backup current firmware to the specified path
  --bypass-verify  Skip flashprog post-write verification (faster, use with care)
                   Also enabled persistently by CONFIG_FLASH_NO_VERIFY=y
  --save-backup    Force rollback backup even if CONFIG_FLASH_SAVE_BACKUP=n
  --no-backup      Suppress rollback backup (used during rollback to avoid saving
                   the firmware being reverted)

Supported image formats:
  .rom  Plain ROM image - flashed directly
  .zip  Update package - extracted and sha256sum.txt integrity check applied
  .tgz  Talos-2 multi-component archive - sha256sum.txt integrity check applied"
fi

if [ "$READ" -eq 1 ]; then
  touch "$ROM"
  flash_rom "$ROM"
else
  if [ ! -e "$ROM" ]; then
    DIE "ROM file not found: $ROM"
  fi
  case "${ROM##*.}" in
  zip|tgz)
    DEBUG "Package format detected: ${ROM##*.} - running prepare_flash_image"
    if ! prepare_flash_image "$ROM"; then
      DIE "$PREPARED_ROM_ERROR"
    fi
    flash_rom "$PREPARED_ROM"
    ;;
  *)
    DEBUG "Plain ROM or pre-built image: flashing directly"
    flash_rom "$ROM"
    ;;
  esac
fi

rm -f /tmp/flash.sh.bak

exit 0
