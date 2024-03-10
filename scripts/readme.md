These scripts create ArchLinuxARM images for the OrangePi Zero+
They have no error checking and are based on various assumptions that must be met in order for them to work:
1. The scripts must be run as root.
2. All necessary executables must be installed.
3. The scripts should be run in a directory containing the ArchLinuxARM tarball and a compiled u-boot for the Opi0+.
4. `/dev/loop0` and `/dev/loop1` must not be in use.
5. The scripts may fail if `/tmp` is not on a tmpfs, `losetup`/`mount` commands might get executed while changes are still being synced to the underlying storage.
These scripts were hacked togheter to simplify testing, they have been posted to provide some insight on how the images were created, however they *will require modifications in order to work on other machines*. 
Consider running commands individually to adapt to your environment and monitor potential issues.