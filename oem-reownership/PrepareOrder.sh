#This script will process ORDERS. One laptop equals one order, and the ORDER is uniquely identifiable and corresponds to website order.
#It takes into consideration that we are under a QubesOS AppVM:
# - ch341 external programmer is already attached to this AppVM
# - That sdcard to be prepared is attached to this AppVM
#   - That ISO images to be copied to the SDCARD are under ~/Downloads/OEM_SDCARD_PUBLIC
#   - That GitLabCI dowloaded QubesOS_Certified branch artifact is dowloaded and stored under
#     - TODO: insert glue to download latest verified GitLabCi build's artifact, now statically
while true; do
  echo "Enter ORDER number associated with hardware to prepare:"
  read ORDER
  
  TOP_BACKEDUP_AND_FLASHED=0
  while [ $TOP_BACKEDUP_AND_FLASHED != 1 ]; do
    echo "Launching ./top.sh script"
    ./top.sh
    if [ $? -eq 0 ]; then
      TOP_BACKEDUP_AND_FLASHED=1
      echo "Backup and flashing of top SPI flash successful."
    fi
  done

  echo -e "Change clip to bottom SPI flash chip and press enter\n"
  read

  BOTTOM_BACKEDUP_AND_FLASHED=0
  while [ $BOTTOM_BACKEDUP_AND_FLASHED != 1 ]; do
    ./bottom_EN25QH64.sh  || ./bottom_MX25L6405.sh
    if [ $? -eq 0 ]; then
      BOTTOM_BACKEDUP_AND_FLASHED=1
    fi
  done

  mkdir -p $ORDER
  mv *.rom $ORDER/

  echo "Provisioning random secrets to be stored under sdcard /oem-provisioning..."
  ./generate_diceware-eom-provisioning.sh

  while [ $(ls $1) != $1 ]; do
    echo "Make sure sdcard/usb drive was to this AppVM and is available into device: $1"
  done
  ./InsurgoSDCARD_prep.sh "$1" "$ORDER"

done    


