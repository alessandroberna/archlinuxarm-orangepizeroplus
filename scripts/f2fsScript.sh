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
# - run in a folder containing Armbian and AlARM images, along with a compiled u-boot for the Opi0+.
# - /dev/loop0 and /dev/loop1 must not be in use
# - (may fail if /tmp is not on tmpfs, losetup/mount commands might get executed while changes are still being synced to the underlying storage)
# YMMV, you might be better off running the individual commands one by one, adapting them to your environment and looking at their output to catch potential issues

# create the .img file and open it as a loop device
dd if=/dev/zero bs=1 count=0 seek=1600M of=/tmp/f2fs.img
losetup /dev/loop1 /tmp/f2fs.img

# write the bootloader to the start of the image
dd if=u-boot-sunxi-with-spl.bin of=/dev/loop1 bs=1024 seek=8
# create the partition table
# u-boot cannot boot from f2fs, an ext4 boot part is needed
echo -e 'start=2048, size=+256M, type=L, bootable\nstart=526336, type=L' | sfdisk --no-reread /dev/loop1

# remount the loop device to make the changes visible
losetup -d /dev/loop1
sleep 1
losetup -P /dev/loop1 /tmp/f2fs.img

# format new parts
mkfs.ext4 /dev/loop1p1
mkfs.f2fs -l ArchLinuxARM -O extra_attr,inode_checksum,sb_checksum,compression  /dev/loop1p2

# f2fs compression does not expose additional freespace and is only useful for improving read speeds and reducing flash wear
# i think that a sensible approach would be to select a fast (the fastest!) encryption algorithm in order to still get some of the benefits without overloading the OPI's weak cpu
mount -o compress_algorithm=lz4,compress_chksum,gc_merge,lazytime /dev/loop1p2 /mnt/copyto
mkdir /mnt/copyto/boot
mount /dev/loop1p1 /mnt/copyto/boot
# extract alarm tarball
bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt/copyto

# add boot config
# TODO: this one needs testing too!
mkdir /mnt/copyto/boot/extlinux
UUID2=$(blkid -s UUID -o value /dev/loop1p2)
echo "TIMEOUT 1
DEFAULT default
MENU TITLE Boot menu

LABEL default
        MENU LABEL Default
        LINUX /Image
        INITRD /initramfs-linux.img
        FDT /dtbs/allwinner/sun50i-h5-orangepi-zero-plus.dtb
        APPEND root=UUID=$UUID2 rw rootflags=atgc,gc_merge,compress_chksum,compress_algorithm=lz4,lazytime rootwait console=tty0 console=ttyS0,115200n8" >> /mnt/copyto/boot/extlinux/extlinux.conf

# populate fstab
UUID=$(blkid -s UUID -o value /dev/loop1p1)
echo "UUID=$UUID2 / f2fs compress_algorithm=lz4,compress_chksum,gc_merge,atgc,lazytime 0 1" | tee /mnt/copyto/etc/fstab
echo "UUID=$UUID /boot ext4 defaults,noatime,commit=600,errors=remount-ro 0 1" | tee -a /mnt/copyto/etc/fstab
echo "tmpfs /tmp tmpfs defaults,nosuid 0 0" | tee -a /mnt/copyto/etc/fstab

# sync writes
umount -R /mnt/copyto
