if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    echo "You should pass a device (/dev/sda) and an order number (XXXX)"
    exit 1
fi

echo "Device is $1"
echo "Order is $2"
echo 
echo "IF NOT VALID HIT CTRL-C AND TRY AGAIN!"
echo "Else, press a key to continue..."
read

#We make sure the mount points are not mounted. We also delete those directory content if they exist to make sure no error wil lhappen later.
sudo umount /mnt/Insurgo
sudo umount /mnt/Public
sudo rm -rf /mnt/Public /mnt/Insurgo

#wiping disk partition table, syncing as we go
sudo dd if=/dev/zero of=$1 bs=512 count=1 conv=notrunc oflag=sync

#generating fdisk command between EOF limitators, wiping comments prior to execution
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $1
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +64M # 64 MB encrypted LUKS container
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  w # write the partition table
  q # and we're done
EOF

#LUKS container is in first partition of the disk passed in argument from command line (eg: /dev/sda)
#We create a container in partition 1 with passphrase contained in keyfile (without linefeed in file!!!)
sudo cryptsetup luksFormat --type luks1 $11 -q -v --force-password --key-file ./Insurgo_OEM_Passphrase
#We open that container with keyfile in devmapper named Insurgo
sudo cryptsetup luksOpen $11 Insurgo -q --key-file ./Insurgo_OEM_Passphrase

#We format into ext4 device that devmapped partition named Insurgo above
sudo mkfs.ext4 -F /dev/mapper/Insurgo
#We also format the second partition of passed device into ext4
sudo mkfs.ext4 -F $12

#We make sure mountpoints exist
sudo mkdir -p /mnt/Insurgo
sudo mkdir -p /mnt/Public

#We label devmapped ext4 partition Insurgo
sudo e2label /dev/mapper/Insurgo Insurgo
#We label second ext4 partition Public
sudo e2label $12 Public


sudo mount /dev/mapper/Insurgo /mnt/Insurgo
#do stuff related to order number to sdcard. I move files around from sys-usb in QubesOS so ORDER related directories here contain original firmware
sudo mkdir -p /mnt/Insurgo/$2_FirmwareFiles
sudo rsync -ah --progress ./$2/* /mnt/Insurgo/$2_FirmwareFiles/
sudo mv ./oem-provisioning.generated /mnt/Insurgo/oem-provisioning

sudo umount /mnt/Insurgo
sudo cryptsetup luksClose /dev/mapper/Insurgo

#We mount second partition prior to filling it with wanted stuff
sudo mount $12 /mnt/Public
#Here we copy isos and associated asc signed files in mountpoint
sudo rsync -ah --progress /home/user/Downloads/OEM_SDCARD_PUBLIC/*.iso* /mnt/Public/
sudo sync
sudo cp /home/user/QubesIncoming/Insurgo/Certified_QubesOS_Flashed_Heads_Firmware_From_Gitlab_CI.zip /mnt/Public/
#We unmount used mountpoint
sudo umount /mnt/Public
