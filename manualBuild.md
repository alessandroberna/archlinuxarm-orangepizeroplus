# Build Instructions
These instructions have been written for hosts running ArchLinux, if you are using a different distribution, package names may vary.

You may find u-boot dependencies for your distro [here](https://docs.u-boot.org/en/v2021.04/build/gcc.html).

## U-Boot
You can either use my [prebuilt image]() or build it yourself
To cross compile for ARM64, you'll need to install the package `aarch64-linux-gnu-gcc`
###  Build TF-A
In order to build U-Boot for 64-bit boards Arm Trusted Firmware must be built first
```
git clone https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git
cd trusted-firmware-a
make CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50i_a64 DEBUG=1
export BL31=$(pwd)/build/sun50i_a64/debug/bl31.bin
```

### Build Crust
This is an optional component needed to make use of the the integrated OpenRISC System Control Processor, used for power management

You'll need an OpenRISC compiler: `pacman -S or1k-elf-gcc`
```
git clone https://github.com/crust-firmware/crust.git
cd crust
make orangepi_zero_plus_defconfig
make CROSS_COMPILE=or1k-elf- scp
export SCP=$(pwd)/build/scp/scp.bin
```
> had to edit the build command from `make CROSS_COMPILE=or1k-none-elf- scp` to `make CROSS_COMPILE=or1k-elf- scp`

### Build u-boot
install dependencies: `pacman -S swig`
```
git clone https://source.denx.de/u-boot/u-boot.git --depth 1 --branch v2024.01
cd u-boot
make orangepi_zero_plus_defconfig
CROSS_COMPILE=aarch64-linux-gnu- CONFIG_CMD_BOOTZ=y make -j$(nproc)
```
> The released versions are available as tags which use the naming scheme: v\<year\>.\<month\>

> edit the git clone command to clone the latest stable release

## Write the bootloader to the SD Card
`dd if=u-boot-sunxi-with-spl.bin of=${card} bs=1024 seek=8`

## Partition the SD Card
Create an MBR partition table with the tool of your choice.
Your partition(s) should start at sector 2048.
If you are going to use EXT4, create just one partition spanning the whole drive.
Else if you are going a filesystem that U-Boot does not support (e.g. F2FS) you'll need a separate EXT4 /boot partition

Example fdisk command:
``` bash
(
echo n      # Add a new partition
echo        # Partition type (default: primary)
echo        # Partition number (default: 1)
echo 2048   # First sector
echo +256M  # Last sector (default: varies)
echo n      # Add a new partition
echo        # Part type
echo        # Part number
echo x      # First sector
echo        # Last sector
echo a      # Toggle a bootable flag
echo 1      # on the first Partition
echo w      # Write changes
) | fdisk /dev/sdX
```
> If you want to create more than 4 partitions, there's an experimental (and rather convoluted) way to use a GPT partition table, refer to [here](https://linux-sunxi.org/Bootable_SD_card#GPT_.28experimental.29)
## Root filesystem
Download and extract the root filesystem:
```
wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
mount /dev/sdX /mnt
bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt/
```
## Bootloader configuration
U-boot supports booting from boot scripts or from extlinux.conf files
### Boot scripts
Install `uboot-tools`, in ArchLinux `pacman -S uboot-tools`
Create `boot.cmd` file in `/mnt/boot` dir.
```
if test -n ${distro_bootpart}; then setenv bootpart ${distro_bootpart}; else setenv bootpart 1; fi
part uuid ${devtype} ${devnum}:${bootpart} uuid
setenv bootargs console=${console} root=PARTUUID=${uuid} rw rootwait

if load ${devtype} ${devnum}:${bootpart} ${kernel_addr_r} /boot/Image; then
  if load ${devtype} ${devnum}:${bootpart} ${fdt_addr_r} /boot/dtbs/${fdtfile}; then
    if load ${devtype} ${devnum}:${bootpart} ${ramdisk_addr_r} /boot/initramfs-linux.img; then
      booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r};
    else
      booti ${kernel_addr_r} - ${fdt_addr_r};
    fi;
  fi;
fi
```
> This script is based on the now removed OrangePi page on the [ArchWiki]().
>
>`Zimage` is no longer present inside ArchLinuxARM's `linux-aarch64` package and thus the `bootz` command no longer works.
I thus replaced `bootz` with `booti` and `load ... /boot/zImage;` with `load ... /boot/Image;`

> Edit line 3 if you need to add kernel parameters

Then compile your boot script:
```
mkimage -C none -A arm64 -T script -d /mnt/boot/boot.cmd /mnt/boot/boot.scr
```
### extlinux.conf
Create an `extlinux` folder inside `/mnt/boot` and an `extlinux.conf` file inside of it.
```
mkdir /mnt/boot/extlinux
touch /mnt/boot/extlinux/extlinux.conf
```
This file uses a similar format to the [syslinux format documented on ArchWiki](https://wiki.archlinux.org/title/Syslinux#Configuration).

Sample configuration:
```
TIMEOUT 1
DEFAULT default
MENU TITLE Boot menu

LABEL default
        MENU LABEL Default
        LINUX /Image
        INITRD /initramfs-linux.img
        FDT /dtbs/allwinner/sun50i-h5-orangepi-zero-plus.dtb
        APPEND root=/dev/disk/by-id/mmc-SC16G_0xa3223e42-part1 rw console=tty0 console=ttyS0,115200n8
```
> Multiple boot options can be defined, to choose one you'll need to use the Pi's serial port
>
> Sample config:
> ```
> TIMEOUT 100
> DEFAULT default
> MENU TITLE Boot menu
>
> LABEL default
>         MENU LABEL Default
>         LINUX /Image
>         INITRD /initramfs-linux.img
>         FDT /dtbs/allwinner/sun50i-h5-orangepi-zero-plus.dtb
>         APPEND root=/dev/disk/by-id/mmc-SC16G_0xa3223e42-part1 rw console=tty0 console=ttyS0,115200n8
>
> LABEL armbian kernel
>         MENU LABEL Armbian
>         LINUX ../../boot.armbi/Image
>         INITRD ../../boot.armbi/initrd.img
>         FDT /boot.armbi/dtb/allwinner/sun50i-h5-orangepi-zero-plus.dtb
>         APPEND root=/dev/disk/by-id/mmc-SC16G_0xa3223e42-part1 rw console=tty0 console=ttyS0,115200n8
>
> LABEL exit
>         MENU LABEL Local boot script (boot.scr)
>         LOCALBOOT 1
> ```
## Final Steps
You can now unmount your SD card and insert it in the pi.
Since the official tarball has been used, your Pi will use ArchLinuxARM's default userspace configuration, which means:
- Default root password is root
- A normal user account named alarm is set up, with the password alarm
- Packages in the base group, kernel firmware and utilities, openssh, and haveged are installed
- sshd started (note: system key generation may take a few moments on first boot)
- haveged started to provide entropy
- systemd-networkd DHCP configurations for eth0 and en* ethernet devices
- systemd-resolved management of resolv.conf
- systemd-timesyncd NTP management

After logging in, either using serial or ssh(using the default user alarm) you should initialize the pacman keyring and populate the Arch Linux ARM package signing keys:
```
pacman-key --init
pacman-key --populate archlinuxarm
```
