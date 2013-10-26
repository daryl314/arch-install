#!/bin/bash

# terminate script on errors (-ex for trace too)
set -e

# -------------------------------------------------- 
# Settings
# -------------------------------------------------- 

# hostname
HN=daryl-arch 

# locale
LOCALE_UTF8=en_US.UTF-8

# -------------------------------------------------- 
# Utilities
# -------------------------------------------------- 

# run a command in chroot environment
arch_chroot() {
  arch-chroot /mnt /bin/bash -c "${1}"
}

# -------------------------------------------------- 
# Partitioning
# -------------------------------------------------- 

# display partition table(s)
lsblk | grep '^sd' | cut -c 1-3 | xargs -i parted /dev/{} print

# assume first sdx drive for user prompt
DRIVE=/dev/`lsblk | grep '^sd' | head -n 1 | cut -c 1-3`

# assume first ext4 partition is root, last ext4 partition is home
ROOT_PART=`parted "$DRIVE" print | grep ext4 | head -n 1 | cut -c 2`
HOME_PART=`parted "$DRIVE" print | grep ext4 | tail -n 1 | cut -c 2`
SWAP_PART=`parted "$DRIVE" print | grep swap | tail -n 1 | cut -c 2`

# prompt for root, home, and swap partitions
read -e -p "Root partition: " -i "$DRIVE$ROOT_PART" ROOT
read -e -p "Home partition: " -i "$DRIVE$HOME_PART" HOME
read -e -p "Swap partition: " -i "$DRIVE$SWAP_PART" SWAP

# set up mounts
echo -e "\nMounting / to $ROOT\nMounting /home to $HOME\n\n"
mount "$ROOT" /mnt
mkdir -p /mnt/home
mount "$HOME" /mnt/home
swapon "$SWAP"

# -------------------------------------------------- 
# Set up pacman mirrors
# -------------------------------------------------- 

#wget "https://www.archlinux.org/mirrorlist/?country=US&protocol=http&ip_version=4" \
#  -O /etc/pacman.d/mirrorlist
#cat /etc/pacman.d/mirrorlist | sed "s/#Server/Server/" > /etc/pacman.d/mirrorlist


# -------------------------------------------------- 
# Install base system
# -------------------------------------------------- 

# install packages
pacstrap /mnt base

# generate fstab (using > instead of >> to prevent duplicate entries)
genfstab -U -p /mnt > /mnt/etc/fstab

# prompt user that this looks kosher
cat /mnt/etc/fstab
read -p "Press Ctrl-C if this doesn't look okay..."


# -------------------------------------------------- 
# Configure system
# --------------------------------------------------

# set locale
echo 'LANG="'$LOCALE_UTF8'"' > /mnt/etc/locale.conf
arch_chroot "sed -i '/'${LOCALE_UTF8}'/s/^#//' /etc/locale.gen"
arch_chroot "locale-gen"

# set time zone
arch_chroot "ln -s /usr/share/zoneinfo/America/New_York /etc/localtime"

# set hardware clock to UTC
arch_chroot "hwclock --systohc --utc"

# set hostname
echo "$HN" > /mnt/etc/hostname
arch_chroot "sed -i '/127.0.0.1/s/$/ '${HN}'/' /etc/hosts"
arch_chroot "sed -i '/::1/s/$/ '${HN}'/' /etc/hosts"

# enable networking (will need to add wireless later)
arch_chroot "systemctl enable dhcpcd.service"

# set root password
arch_chroot "passwd"

# install bootloader
pacstrap /mnt grub
arch_chroot "grub-install --target=i386-pc --recheck ${DRIVE}"
arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

# unmount and reboot
umount /mnt/home
umount /mnt
reboot
