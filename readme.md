![ArchlinuxARM logo](assets/alarm.png)

# Prebuilt images and build instructions for the OrangePi Zero Plus
These images have been created using the [respective scripts](https://github.com/alessandroberna/archlinuxarm-orangepizeroplus/tree/main/scripts), with a freshly compiled U-boot and ArchLinuxARM's mainline `linux-aarch64` kernel.

Two kinds of images are available:
- The EXT4 image simply uses a single partition that spans the whole drive.
- The F2FS image has a 256MB EXT4 `/boot` partition since U-Boot doesn't support this filesystem. LZ4 compression has been enabled; it should improve the I/O performance with a minimal overhead

Apart from adjusting the mount options and adopting Armbian's sensible defaults, no further modifications have been made, in line with ArchLinux's KISS philosophy.
The default ArchLinux ARM userspace configuration is thus kept, which means:
- The default root password is root
- A normal user account named alarm is set up, with the password alarm
- sshd started (note: system key generation may take a few moments on first boot)
- Packages in the base group, kernel firmware and utilities, openssh, and haveged are installed
- haveged is started to provide entropy
- systemd-networkd DHCP configurations for eth0 and en* ethernet devices
- systemd-resolved management of resolv.conf
- systemd-timesyncd NTP management

With that said, you may want to consider enabling ZRAM and storing logs on system RAM, in order to prolong the life of your SD card

After booting, you can log into the system either by using the serial port or via SSH as the alarm user.
After logging in, initialize the pacman keyring and populate the Arch Linux ARM package signing keys:
```
pacman-key --init
pacman-key --populate archlinuxarm
```
The images won't be updated frequently; simply run `pacman -Syu` after installing to account for that

## Quick install:
### Linux / OSX CLI
- Download an image [from the releases page](https://github.com/alessandroberna/archlinuxarm-orangepizeroplus/releases/tag/latest)
`wget https://github.com/alessandroberna/archlinuxarm-orangepizeroplus/releases/download/latest/ext4.img.xz`
- Unpack it: `xz -dv ext4.img.xz`
- Write the image to your SD Card:
    ```
    # dd if='filename'.img of=/dev/sdX bs=1M status=progress 
    ```
- Resize the root partition:
    You need to delete the last partition and create a new one in its place, starting at sector `2048` and spanning the whole drive.
    You can then use `resize2fs` for ext4 or `resize.f2fs` for F2FS

    EXT4:
    ```
    #   echo 'type=83, start=2048, bootable' | sfdisk /dev/sdX
    #   resize2fs /dev/sdX
    ```

    F2FS:
    ```
    #   echo ", +" | sfdisk -N 2 /dev/sdX
    #   resize.f2fs /dev/sdX
    ```
    > Running the sfdisk commands on the wrong drive will lead to data loss

    > On OS X replace `/dev/sdX` with `/dev/rdiskX`
    > https://daoyuan.li/solution-dd-too-slow-on-mac-os-x/

### Cross Platform GUI
After downloading the image, you can use a tool like [Etcher](https://etcher.balena.io/)

## Manual Building:
Refer to [this file](manualBuild.md)