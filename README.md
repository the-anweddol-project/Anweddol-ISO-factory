# Anweddol container ISO factory
---

This script creates functional and up-to-date live debian images that [Anweddol servers](https://github.com/the-anweddol-project/Anweddol-server) will be using for containers.

## Requirements

This script is made to operate on Debian environments.
**Note that others distros aren't tested yet since the result image is a debian itself.**

You need these packages installed on the machine : 

 - debootstrap 
 - squashfs-tools 
 - xorriso isolinux 
 - syslinux-efi 
 - grub-pc-bin 
 - grub-efi-amd64-bin 
 - grub-efi-ia32-bin 
 - mtools 
 - dosfstools

Install them with your package manager.

## Usage

Just run the `make_iso.sh` script : 

```
$ sudo bash make_iso.sh
```

Once the script is finished, you will retrieve the created ISO in the `result` folder, with its checksums.

## Recommendations

While made to operate on Debian environments, it is recommended to run this script in an isolated environment (VM or chroot), to avoid potential system information leak.

## License

This software is under the GNU general public license v3, available under any later version.

This is free software: you are free to change and redistribute it. There is NO WARRANTY, to the extent permitted by law.

## Developer / Maintainer

- Darnethal0z ([GitHub profile](https://github.com/Darnethal0z))

*Copyright 2023 The Anweddol project*
