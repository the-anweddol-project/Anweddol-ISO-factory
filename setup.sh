#!/bin/bash

# Install every needed components
apt install \
	debootstrap \
	squashfs-tools \
	xorriso \
	isolinux \
	syslinux-efi \
	grub-pc-bin \
	grub-efi-amd64-bin \
	grub-efi-ia32-bin \
	mtools \
	dosfstools -y \
