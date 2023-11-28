mount-usb --mode rw
dd if=/dev/zero of=/tmp/disk8gb.raw bs=1M count=8k
cryptsetup luksFormat /tmp/disk8gb.raw
cryptsetup reencrypt /tmp/disk8gb.raw --disable-locks --force-offline-reencrypt --debug | tee /media/ram_reencrypt.log
