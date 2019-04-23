#!/bin/bash
# 0- To use this script, install diceware first
# sudo dnf install diceware -y
# sudo apt-get install diceware -y
#
# Then 
# 1- Run this script with ./generate_diceware-eom-provisioning.sh 
# 2- Edit ./oem-provisioning.generated so all variiables are provisioned
# 3- Mount USB drive to /media ( eg. sudo mount /dev/sdb1 /media )
# 4- Copy the file on USB drive ( eg. sudo cp /oem-provisioning.generated /media/oem-provisioning )
# 5- Unmount USB drive to flush changes ( eg. sudo umount /media ) 
# 6- Boot your newly received hardware with USB drive connected.
# 7- Enjoy!
#
while [[ ${#oem_gpg_Admin_PIN} -lt 8 || ${#oem_gpg_Admin_PIN} -gt 20 ]];do
  oem_gpg_Admin_PIN=$(diceware -d " " -n 2)
done
echo "oem_gpg_Admin_PIN=$oem_gpg_Admin_PIN" > ./oem-provisioning.generated
while [[ ${#oem_gpg_User_PIN} -lt 6 || ${#oem_gpg_User_PIN} -gt 20 ]];do
  oem_gpg_User_PIN=$(diceware -d " " -n 2)
done
echo "oem_gpg_User_PIN=$oem_gpg_User_PIN" >> ./oem-provisioning.generated
echo "oem_gpg_real_name=" >> ./oem-provisioning.generated
echo "oem_gpg_email=" >> ./oem-provisioning.generated
echo "oem_gpg_comment=" >> ./oem-provisioning.generated
echo "oem_luks_actual_Disk_Recovery_Key=" >> ./oem-provisioning.generated
echo "oem_luks_new_Disk_Recovery_Key=$(diceware -d " " -n 5)" >> ./oem-provisioning.generated
echo "oem_luks_Disk_Unlock_Key=$(diceware -d " " -n 3)" >> ./oem-provisioning.generated
echo "oem_TPM_Owner_Password=$oem_gpg_Admin_PIN" >> ./oem-provisioning.generated
