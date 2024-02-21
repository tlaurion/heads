cd /tmp
wget -O u-root.cpio.xz https://github.com/linuxboot/u-root-builder/releases/download/v0.0.1/u-root_amd64_all.cpio.xz
wget -O linux.tar.zst https://archlinux.org/packages/core/x86_64/linux/download/
tar -xf linux.tar.zst
#kexec load /tmp/boot/vmlinuz-linux --initrd=/tmp/boot/initramfs-linux.img --reuse-cmdline
kexec -l /tmp/boot/vmlinuz-linux --initrd=/tmp/u-root.cpio.xz --reuse-cmdline
kexec -e
