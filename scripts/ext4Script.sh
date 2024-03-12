#!/bin/bash

# Copyright (c) 2024 Alessandro Bernardello <github.aleberna@erine.eu>
# ---------------------------------------------------------------------
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# This script creates an ArchLinuxARM image for the OrangePi Zero+
# It has no error checking and has various assumptions about its running environment that must be met:
# - running as root
# - all needed executables are installed
# - run in a directory containing the ArchLinuxARM tarball and a compiled u-boot for the Opi0+.
# - /dev/loop1 must not be in use
# - (may fail if /tmp is not on tmpfs, losetup/mount commands might get executed while changes are still being synced to the underlying storage)
# YMMV, you might be better off running the individual commands one by one, adapting them to your environment and looking at their output to catch potential issues

# create the .img file and open it as a loop device
dd if=/dev/zero bs=1 count=0 seek=1330M of=/tmp/ext4.img
losetup /dev/loop1 /tmp/ext4.img

# write the bootloader to the start of the image
dd if=u-boot-sunxi-with-spl.bin of=/dev/loop1 bs=1024 seek=8    
# create the partition table
echo -e 'start=2048, type=L, bootable' | sfdisk --no-reread /dev/loop1
# remount the loop device to make the changes visible
losetup -d /dev/loop1

losetup -P /dev/loop1 /tmp/ext4.img

# format the new part and mount it
mkfs.ext4 /dev/loop1p1
mount /dev/loop1p1 /mnt/copyto
# extract alarm tarball
bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt/copyto

# add boot.cmd script
# TODO: test the new bootargs
echo "if test -n \${distro_bootpart}; then setenv bootpart \${distro_bootpart}; else setenv bootpart 1; fi
part uuid \${devtype} \${devnum}:\${bootpart} uuid
setenv bootargs console=\${console} root=PARTUUID=\${uuid} rw rootwait rootflags=lazytime,commit=600

if load \${devtype} \${devnum}:\${bootpart} \${kernel_addr_r} /boot/Image; then
  if load \${devtype} \${devnum}:\${bootpart} \${fdt_addr_r} /boot/dtbs/\${fdtfile}; then
    if load \${devtype} \${devnum}:\${bootpart} \${ramdisk_addr_r} /boot/initramfs-linux.img; then
      booti \${kernel_addr_r} \${ramdisk_addr_r}:\${filesize} \${fdt_addr_r};
    else
      booti \${kernel_addr_r} - \${fdt_addr_r};
    fi;
  fi;
fi" >> /mnt/copyto/boot/boot.cmd
# compile boot script
mkimage -C none -A arm64 -T script -d /mnt/copyto/boot/boot.cmd /mnt/copyto/boot/boot.scr

# add fstab entries
UUID=$(blkid -s UUID -o value /dev/loop1p1)
echo "UUID=$UUID / ext4 defaults,lazytime,commit=600,errors=remount-ro 0 1" | tee -a /mnt/copyto/etc/fstab
echo "tmpfs /tmp tmpfs defaults,nosuid 0 0" | tee -a /mnt/copyto/etc/fstab

# sync writes
umount /mnt/copyto
