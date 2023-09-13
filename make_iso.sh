#!/bin/bash

# This is the Anweddol container ISO generation script.
# Inspired from https://www.willhaley.com/blog/custom-debian-live-environment/
# Refer to all the comments below to learn more.

if [ `/bin/id -u` -ne 0 ]; then

    echo "This script must be run as root"
    exit

fi

echo "
┏┓        ┓ ┓  ┓  ┳┏┓┏┓  ┏┓          
┣┫┏┓┓┏┏┏┓┏┫┏┫┏┓┃  ┃┗┓┃┃  ┣ ┏┓┏╋┏┓┏┓┓┏
┛┗┛┗┗┻┛┗ ┗┻┗┻┗┛┗  ┻┗┛┗┛  ┻ ┗┻┗┗┗┛┛ ┗┫
----------------------------------- ┛

"

# Define work folder paths
bootstrap_path=$(pwd)/bootstrap
resources_path=$(pwd)/resources
result_path=$(pwd)/result
container_debian_base_path=$(pwd)/container_debian_base
minbase_debian_path=$(pwd)/minbase_debian

# Set the /sbin folder on PATH to avoid 'not found' problems on debian
export PATH=$PATH:/usr/sbin/

if [ ! -d $container_debian_base_path ]; then
    mkdir -p $container_debian_base_path

    if [ -d $minbase_debian_path ]; then 
        # If the minbase debian path exists, copy its content on the container debian base
        cp -R $minbase_debian_path/* $container_debian_base_path/
    
    else
        mkdir -p $container_debian_base_path
        mkdir -p $minbase_debian_path

    	# Download the minbase debian from US mirror (change it to a closer one if needed)
    	debootstrap --arch=amd64 --variant=minbase bullseye $container_debian_base_path http://ftp.us.debian.org/debian/
        
        # Make a backup of the downloaded minbase
        cp -R $container_debian_base_path/* $minbase_debian_path/

    fi

    # Administrate the container debian base
    chroot $container_debian_base_path /bin/bash -c "apt update && apt upgrade -y && \
        apt install --no-install-recommends \
            linux-image-amd64 \
            live-boot \
            systemd-sysv \
            network-manager \
            net-tools \
            curl \
            iputils-ping \
            iproute2 \
            openssl \
            openssh-client \
            openssh-server \
            blackbox \
            xserver-xorg-core \
            xserver-xorg \
            xinit \
            xterm \
            sudo \
            vim \
            nano -y && \
        apt clean && \
        echo 'anweddol-container' > ./etc/hostname && \
        useradd -c 'Anweddol container endpoint user' -G sudo -m endpoint && \
        printf 'endpoint\nendpoint' | passwd endpoint && \
        history -c"

fi

# Clean and recreate the result folder
rm -rf $result_path
mkdir -p $result_path

# Clean and recreate the bootstrap folder
rm -rf $bootstrap_path
mkdir -p $bootstrap_path

# Copy the administrated container debian base in the chroot
cp -aR $container_debian_base_path $bootstrap_path/chroot/

# Update the bootstrap chroot
chroot $bootstrap_path/chroot /bin/bash -c "apt update && apt upgrade -y && \
	rm -rf /etc/ssh/ssh_host_* && ssh-keygen -A && \
	apt clean"

# Create build folders
mkdir -p $bootstrap_path/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp}

# Copy nessessary files on the chroot (Do not change the sed '26i': 
# statement is on line 26 to prevent being overrided by others statements)
cp $resources_path/anweddol_container_setup.sh $bootstrap_path/chroot/bin/
chmod +x $bootstrap_path/chroot/bin/anweddol_container_setup.sh

cp $resources_path/WELCOME.txt $bootstrap_path/chroot/etc/

sed -i "26i endpoint ALL=(ALL:ALL) NOPASSWD:/bin/anweddol_container_setup.sh" $bootstrap_path/chroot/etc/sudoers
# The container `/etc/hosts` file needs to be modified manually
sed -i "1i 127.0.0.1  anweddol-container\n::1        anweddol-container" $bootstrap_path/chroot/etc/hosts

# Make a squashed filesystem of the previously administrated chroot 
mksquashfs $bootstrap_path/chroot $bootstrap_path/staging/live/filesystem.squashfs -e boot

# Copy kernel and initramfs files from the chroot to the live folder
cp $bootstrap_path/chroot/boot/vmlinuz-* $bootstrap_path/staging/live/vmlinuz
cp $bootstrap_path/chroot/boot/initrd.img-* $bootstrap_path/staging/live/initrd

# Copy the boot loader menus files on bootstrap staging folder
cp $resources_path/isolinux.cfg $bootstrap_path/staging/isolinux/isolinux.cfg
cp $resources_path/grub.cfg $bootstrap_path/staging/boot/grub/grub.cfg
cp $bootstrap_path/staging/boot/grub/grub.cfg $bootstrap_path/staging/EFI/BOOT/
cp $resources_path/grub-embed.cfg $bootstrap_path/tmp/grub-embed.cfg

# Copy required boot files on bootstrap staging folder
cp /usr/lib/ISOLINUX/isolinux.bin $bootstrap_path/staging/isolinux/
cp /usr/lib/syslinux/modules/bios/* $bootstrap_path/staging/isolinux/
cp -r /usr/lib/grub/x86_64-efi/* $bootstrap_path/staging/boot/grub/x86_64-efi/

# Generate GRUB images
grub-mkstandalone -O i386-efi \
    --modules="part_gpt part_msdos fat iso9660" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --output="$bootstrap_path/staging/EFI/BOOT/BOOTIA32.EFI" \
    "boot/grub/grub.cfg=$bootstrap_path/tmp/grub-embed.cfg"
grub-mkstandalone -O x86_64-efi \
    --modules="part_gpt part_msdos fat iso9660" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --output="$bootstrap_path/staging/EFI/BOOT/BOOTx64.EFI" \
    "boot/grub/grub.cfg=$bootstrap_path/tmp/grub-embed.cfg"

# Create FAT16 boot disk image
(cd $bootstrap_path/staging && \
    dd if=/dev/zero of=efiboot.img bs=1M count=20 && \
    mkfs.vfat efiboot.img && \
    mmd -i efiboot.img ::/EFI ::/EFI/BOOT && \
    mcopy -vi efiboot.img \
        $bootstrap_path/staging/EFI/BOOT/BOOTIA32.EFI \
        $bootstrap_path/staging/EFI/BOOT/BOOTx64.EFI \
        $bootstrap_path/staging/boot/grub/grub.cfg \
        ::/EFI/BOOT/
)

# Generate the final bootable ISO
xorriso -as mkisofs -iso-level 3 -o $result_path/anweddol_container.iso -full-iso9660-filenames \
    -volid "ANWDL_CONTAINER_DEBIAN" --mbr-force-bootable -partition_offset 16 \
    -joliet -joliet-long -rational-rock \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-boot isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table --eltorito-catalog isolinux/isolinux.cat \
    -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot -isohybrid-gpt-basdat \
    -append_partition 2 $(uuidgen | awk '{print toupper($0)}') $bootstrap_path/staging/efiboot.img \
    "$bootstrap_path/staging"

# Compute the checksum of the generated ISO
md5sum --tag $result_path/anweddol_container.iso > $result_path/md5sum.txt
sha256sum --tag $result_path/anweddol_container.iso > $result_path/sha256sum.txt

# Update or create the version file content
if [ ! -f $result_path/version.txt ]; then
    echo "1" > $result_path/version.txt

else 
    echo $(($(head -n 1 $result_path/version.txt) + 1)) > $result_path/version.txt

fi