#!/bin/bash

# terminate script on errors (-ex for trace too)
set -ex

# -------------------------------------------------- 
# Setup
# -------------------------------------------------- 

# upgrade packages (ordinarily 'pacman -Syu', but binaries were moved - may not be needed with newer iso images)
#  https://www.archlinux.org/news/binaries-move-to-usrbin-requiring-update-intervention/
pacman -Syu --ignore filesystem,bash
pacman -S bash
pacman -Su

# create user account (daryl in group users)
useradd -m -g users -s /bin/bash daryl
passwd daryl

# install alsa utilities and unmute sound channels
pacman -S alsa-utils
amixer sset Master unmute

# initialize sound system for virtualbox
if lspci | grep -q Virtualbox
then alsactl init
fi


# -------------------------------------------------- 
# Graphics setup
# -------------------------------------------------- 

# install the base Xorg packages:
pacman -S xorg-server xorg-server-utils xorg-xinit

# install mesa for 3D support:
pacman -S mesa

# set up virtualbox guest additions 
# https://wiki.archlinux.org/index.php/VirtualBox#Arch_Linux_as_a_guest_in_a_Virtual_Machine
if lspci | grep -q Virtualbox
then
  pacman -S virtualbox-guest-utils
  modprobe -a vboxguest vboxsf vboxvideo
  echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
  echo "/usr/bin/VBoxClient-all" > /home/daryl/.xinitrc
fi

# install basic vesa video driver
# see instructions for getting acceleration working:
#   https://wiki.archlinux.org/index.php/Xorg#Driver_installation
if ! lspci | grep -q Virtualbox
then
  pacman -S xf86-video-vesa
fi

# -------------------------------------------------- 
# Desktop environment setup
# -------------------------------------------------- 

# install kde with meta-packages
pacman -S kde-meta

# enable autologin with kde
systemctl enable kdm