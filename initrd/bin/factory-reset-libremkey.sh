#!/bin/sh
#
set -e -o pipefail
. /etc/functions
. /tmp/config

if (whiptail $CONFIG_WARNING_BG_COLOR --clear --title 'Factory Reset and reownership of USB security dongle' \
  --yesno "You are about to factory reset your USB security dongle!\n\nThis will:\n 1. Wipe all PRIVATE keys that were previously kept inside USB security dongle\n 2. Set default key size to 4096 bits (maximum)\n 3. Set two passphrases to interact with the card:\n  3(a): An Administrator PIN to manage the card\n  3(b): A User passphrase (PIN) used everytime you sign\n   encrypt/decrypt content\n4. Generate new Encryption, Signing and Authentication keys\n  inside your USB security dongle\n5. Export associated public key into mounted /media/gpg_keys/, replace the\n  one being present and trusted inside running BIOS, and reflash\n  ROM with resulting image.\n\nAs a result, the running BIOS will be modified. Would you like to continue?" 30 90) then

  mount-usb || die "Unable to mount USB device."
  #Copy generated public key, private_subkey, trustdb and artifacts to external media for backup:
  mount -o remount,rw /media || die "Unable to remount /media into read/write mode. Is the device write-protected?"
  
  #TODO: Circumvent permission bug with mkdir and chmod permitting to use gpg --home=/media/gpg_keys directly. 
  #Cannot create a new gpg homedir with right permissions nor chmod 700 that directory.
  #Meanwhile, we reuse /.gnupg by temporarely deleting it's existing content.
  rm -rf .gnupg/* 2> /dev/null || true 2> /dev/null
  killall gpg-agent gpg scdaemon 2> /dev/null || true 2> /dev/null
 
  if [ -z "$oem_usb_security_dongle_Admin_PIN" ] || [ -z "$oem_usb_security_dongle_User_PIN" ]; then
    #Setting new passwords
    oem_usb_security_dongle_user_pass1=1
    oem_usb_security_dongle_user_pass2=2
    oem_usb_security_dongle_admin_pass1=3
    oem_usb_security_dongle_admin_pass2=4
  else
    oem_usb_security_dongle_user_pass1=$(echo -n "$oem_usb_security_dongle_User_PIN")
    oem_usb_security_dongle_user_pass2=$(echo -n "$oem_usb_security_dongle_User_PIN")
    oem_usb_security_dongle_admin_pass1=$(echo -n "$oem_usb_security_dongle_Admin_PIN")
    oem_usb_security_dongle_admin_pass2=$(echo -n "$oem_usb_security_dongle_Admin_PIN")
  fi

  while [[ "$oem_usb_security_dongle_user_pass1" != "$oem_usb_security_dongle_user_pass2" ]] || [[ ${#oem_usb_security_dongle_user_pass1} -lt 6 || ${#oem_usb_security_dongle_user_pass1} -gt 20 ]];do
  {
    echo -e "\nChoose your new USB security dongle's User PIN. You will type this when using USB security dongle (signing files, encrypting emails and files).\nIt needs to be a least 6 but not more then 20 characters:"
    read -s oem_usb_security_dongle_user_pass1
    echo -e "\nRetype user passphrase:"
    read -s oem_usb_security_dongle_user_pass2
    if [[ "$oem_usb_security_dongle_user_pass1" != "$oem_usb_security_dongle_user_pass2" ]]; then echo "Passwords typed were different."; fi
  };done
  oem_usb_security_dongle_user_pass=$oem_usb_security_dongle_user_pass1

  while [[ "$oem_usb_security_dongle_admin_pass1" != "$oem_usb_security_dongle_admin_pass2" ]] || [[ ${#oem_usb_security_dongle_admin_pass1} -lt 8 || ${#oem_usb_security_dongle_admin_pass1} -gt 20 ]]; do
  {
    echo -e "\nChoose your new USB security dongle's Admin PIN. You will type this when managing the USB security dongle (HOTP sealing, managing key, etc).\nIt needs to be a least 8 but not more then 20 characters:"
    read -s oem_usb_security_dongle_admin_pass1
    echo -e "\nRetype your new USB security dongle's Admin PIN:"
    read -s oem_usb_security_dongle_admin_pass2
  };done
  oem_usb_security_dongle_admin_pass=$oem_usb_security_dongle_admin_pass1

  echo -e "\n\n"
  echo -e "Next, we will generate a GPG keypair identifiable by the template:"
  echo -e "Real Name (Comment) email@address.org"
  
  oem_usb_security_dongle_real_name=$(echo -n "$oem_usb_security_dongle_real_name")
  while [[ ${#oem_usb_security_dongle_real_name} -lt 5 ]]; do
  {
    echo -e "\nEnter desired GPG real name (At least 5 characters long):"
    read -r oem_usb_security_dongle_real_name
  };done

  oem_usb_security_dongle_email_address=$(echo -n "$oem_usb_security_dongle_email")
  while ! $(expr "$oem_usb_security_dongle_email_address" : '.*@' >/dev/null); do
  {
    echo -e "\nEnter desired GPG email (email@adress.org):"
    read -r oem_usb_security_dongle_email_address
  };done
  
  oem_usb_security_dongle_comment=$(echo -n "$oem_usb_security_dongle_comment")
  while [[ ${#oem_usb_security_dongle_comment} -gt 60 ]] || [[ -z "$oem_usb_security_dongle_comment" ]]; do
  {
    echo -e "\nEnter desired GPG comment (distinguishes this key from others with same name and email address. Must be smaller then 60 characters):"
    read -r oem_usb_security_dongle_comment
  };done

  #Copy generated public key, private_subkey, trustdb and artifacts to external media for backup:
  mount -o remount,rw /media || die "Unable to remount /media into read/write mode. Is the device write protected?" 

  #backup existing /media/gpg_keys directory
  if [ -d /media/gpg_keys ];then
    newdir="/media/gpg_keys-$(date '+%Y-%m-%d-%H_%M_%S')"
    echo "Backing up /media/gpg_keys into $newdir"
    mv /media/gpg_keys "$newdir" || die "Moving old gpg_keys directory into $newdir failed."
  fi

  mkdir -p /media/gpg_keys

  #Generate Encryption, Signing and Authentication keys
  whiptail --clear --title 'USB security dongle GPG key generation' --msgbox \
  "Generating 4096 bits for encryption, signing and authentication keys.\nPLEASE BE PATIENT! This step takes around 15 minutes.\n\nHit Enter to continue" 30 90

  confirm_gpg_card

  #Factory reset GPG card
  {
    echo admin
    echo factory-reset
    echo y
    echo yes
  } | gpg --command-fd=0 --status-fd=1 --pinentry-mode=loopback --card-edit --home=/.gnupg/ || die "Factory resetting the USB security dongle failed."

  #Setting new admin and user passwords in GPG card
  {
    echo admin
    echo passwd
    echo 1
    echo 123456 #Default user password after factory reset of card
    echo "$oem_usb_security_dongle_user_pass"
    echo "$oem_usb_security_dongle_user_pass"
    echo 3
    echo 12345678 #Default administrator password after factory reset of card
    echo "$oem_usb_security_dongle_admin_pass"
    echo "$oem_usb_security_dongle_admin_pass"
    echo Q
  } | gpg --command-fd=0 --status-fd=2 --pinentry-mode=loopback --card-edit --home=/.gnupg/ || die "Setting new GPG admin and user PINs in USB security dongle failed."

  #Set GPG card key attributes key sizes to 4096 bits
  {
    echo admin
    echo key-attr
    echo 1 # RSA
    echo 4096 #Signing key size set to maximum supported by SmartCard
    echo "$oem_usb_security_dongle_admin_pass"
    echo 1 # RSA
    echo 4096 #Encryption key size set to maximum supported by SmartCard
    echo "$oem_usb_security_dongle_admin_pass"
    echo 1 # RSA
    echo 4096 #Authentication key size set to maximum supported by SmartCard
    echo "$oem_usb_security_dongle_admin_pass"
  } | gpg --command-fd=0 --status-fd=2 --pinentry-mode=loopback --card-edit --home=/.gnupg/ || die "Setting key attributed to RSA 4096 bits in USB security dongle failed."

  {
    echo admin
    echo generate
    echo n
    echo "$oem_usb_security_dongle_admin_pass"
    echo "$oem_usb_security_dongle_user_pass"
    echo 1y
    echo "$oem_usb_security_dongle_real_name"
    echo "$oem_usb_security_dongle_email_address"
    echo "$oem_usb_security_dongle_comment"
  } | gpg --command-fd=0 --status-fd=2 --pinentry-mode=loopback --card-edit --home=/.gnupg/ || die "Setting GPG real name, GPG email and GPG comment failed."

  #Export and inject public key and trustdb export into extracted rom with current user keys being wiped
  rom=/tmp/gpg-gui.rom
  #remove invalid signsignature file
  mount -o remount,rw /boot
  rm -f /boot/kexec.sig
  mount -o remount,ro /boot

  gpg --home=/.gnupg/ --export --armor "$oem_usb_security_dongle_email_address"  > /media/gpg_keys/public.key || die "Exporting public key to /media/gpg_keys/public.key failed."
  cp -rf /.gnupg/openpgp-revocs.d/* /media/gpg_keys/ 2> /dev/null || die "Copying revocation certificated into /media/gpg_keys/ failed."
  cp -rf /.gnupg/private-keys-v1.d/* /media/gpg_keys/ 2> /dev/null || die "Copying secring exported keys to /media/gpg_keys/ failed." 
  cp -rf /.gnupg/pubring.* /.gnupg/trustdb.gpg /media/gpg_keys/ 2> /dev/null || die "Copying public keyring into /media/gpg_keys/ failed."

  #Flush changes to external media
  mount -o remount,ro /media

  #Read rom
  /bin/flash.sh -r $rom || die "Flashing back $rom including your newly generated and exported public key failed."

  #delete previously injected public.key
  if (cbfs -o $rom -l | grep -q "heads/initrd/.gnupg/keys/public.key"); then
    cbfs -o $rom -d "heads/initrd/.gnupg/keys/public.key" || die "Deleting old public key from running rom backup failed."
  fi
  
  #delete previously injected GPG1 and GPG2 pubrings
  if (cbfs -o $rom -l | grep -q "heads/initrd/.gnupg/pubring.kbx"); then
    cbfs -o $rom -d "heads/initrd/.gnupg/pubring.kbx" || die "Deleting old public keyring from running rom backup failed."
    if (cbfs -o $rom -l | grep -q "heads/initrd/.gnupg/pubring.gpg"); then
      cbfs -o $rom -d "heads/initrd/.gnupg/pubring.gpg" || die "Deleting old and deprecated public keyring from running rom backup failed."
      if [ -e /.gnupg/pubring.gpg ];then
        rm /.gnupg/pubring.gpg
      fi
    fi
  fi
  #delete previously injected trustdb
  if (cbfs -o $rom -l | grep -q "heads/initrd/.gnupg/trustdb.gpg") then
    cbfs -o $rom -d "heads/initrd/.gnupg/trustdb.gpg" || die "Deleting old trust database from running rom backup failed."
  fi
  #Remove old method of exporting/importing owner trust exported file
  if (cbfs -o $rom -l | grep -q "heads/initrd/.gnupg/otrust.txt") then
    cbfs -o $rom -d "heads/initrd/.gnupg/otrust.txt" || die "Deleting old and depracated trust database export failed."
  fi

  #Insert public key in armored form and trustdb ultimately trusting user's key into reproducible rom:
  cbfs -o "$rom" -a "heads/initrd/.gnupg/pubring.kbx" -f /.gnupg/pubring.kbx || die "Inserting public keyring in runnning rom backup failed."
  cbfs -o "$rom" -a "heads/initrd/.gnupg/trustdb.gpg" -f /.gnupg/trustdb.gpg || die "Inserting trust databse in running rom backup failed."

  if (whiptail --title 'Flash ROM?' \
    --yesno "This will replace your old ROM with $rom\n\nDo you want to proceed?" 16 90) then
    /bin/flash.sh $rom
    whiptail --title 'ROM Flashed Successfully' \
      --msgbox "New $rom flashed successfully.\n\nIf your keys have changed, be sure to re-sign all files in /boot\nafter you reboot.\n\nPress Enter to continue" 16 60
    if [ -s /boot/oem ];then
      mount -o remount,rw /boot
      echo "gpg_factory_resetted" >> /boot/oem
      mount -o remount,ro /boot
    fi
    mount -o remount,ro /media
  else
      exit 0
  fi

  whiptail $CONFIG_WARNING_BG_COLOR --clear --title 'WARNING: Reboot required' --msgbox \
    "A reboot is required.\n\n Your firmware has been reflashed with your own public key and trust\n database included.\n\n Since this step changes the firmware, Heads react as expected:\n It will ask you to reseal TOTP/HOTP (seal BIOS integrity),\n take /boot integrity measures and sign them with your freshly\n factory resetted USB security dongle (OpenPGP card) and its associated user password (PIN).\nThis is normal.\nHit Enter to reboot." 30 90
  /bin/reboot
fi
