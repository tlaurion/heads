#!/bin/bash
. /etc/luks-functions

enable_usb
enable_usb_storage
prepare_thumb_drive /dev/sda 25 "test"
mount-usb
