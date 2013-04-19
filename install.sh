#!/bin/bash

# https://wiki.archlinux.org/index.php/Beginners%27_Guide

# terminate script on errors (-ex for trace too)
set -e

# -------------------------------------------------- 
# Partitioning
# -------------------------------------------------- 

# display partition table(s)
lsblk | grep '^sd' | cut -c 1-3 | xargs -i parted /dev/{} print

# assume first sdx drive for now
DRIVE=/dev/`lsblk | grep '^sd' | head -n 1 | cut -c 1-3`

# assume first ext4 partition is root, last ext4 partition is home
ROOT_PART=`parted "$DRIVE" print | grep ext4 | head -n 1 | cut -c 2`
HOME_PART=`parted "$DRIVE" print | grep ext4 | tail -n 1 | cut -c 2`

# prompt for root and home partitions
read -e -p "Root partition: " -i "$DRIVE$ROOT" ROOT
read -e -p "Home partition: " -i "$DRIVE$HOME" HOME

# set up mounts
echo -e "\nMounting / to $ROOT\nMounting /home to $HOME\n\n"
mount "$DRIVE$ROOT_PART" /mnt
mkdir /mnt/home
mount "$DRIVE$HOME_PART" /mnt/home

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

# generate fstab
genfstab -U -p /mnt >> /mnt/etc/fstab

# prompt user that this looks kosher
cat /mnt/etc/fstab
read -p "Press Ctrl-C if this doesn't look okay..."

# chroot into new system
arch-chroot /mnt

# -------------------------------------------------- 
# Configure system
# -------------------------------------------------- 
