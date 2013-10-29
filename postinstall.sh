#!/bin/bash

# terminate script on errors (-ex for trace too)
set -ex

# -------------------------------------------------- 
# Setup
# -------------------------------------------------- 

# upgrade packages (ordinarily 'pacman -Syu', but binaries were moved - may not be needed with newer iso images)
#  https://www.archlinux.org/news/binaries-move-to-usrbin-requiring-update-intervention/
#pacman -Syu --ignore filesystem,bash
#pacman -S bash
#pacman -Su
pacman -Syu

# create user account (daryl in group users)
useradd -m -g users -s /bin/bash daryl
passwd daryl

# install alsa utilities and unmute sound channels
pacman -S alsa-utils
amixer sset Master unmute

# initialize sound system for virtualbox
if lspci | grep -q VirtualBox
then 
  alsactl init # returns an error
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
if lspci | grep -q VirtualBox
then
  pacman -S virtualbox-guest-utils
  modprobe -a vboxguest vboxsf vboxvideo
  echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
  echo "/usr/bin/VBoxClient-all" > /home/daryl/.xinitrc
  systemctl enable vboxservice.service
  groupadd vboxsf # returns an error - already exists
  gpasswd -a daryl vboxsf
fi

# install basic vesa video driver
# see instructions for getting acceleration working:
#   https://wiki.archlinux.org/index.php/Xorg#Driver_installation
if ! lspci | grep -q VirtualBox
then
  pacman -S xf86-video-vesa
fi

# -------------------------------------------------- 
# Package management
# --------------------------------------------------

# Prerequisites for building yaourt (base devel + dependencies listed in build file)
pacman -S base-devel yajl diffutils

# Install sudo and add 'daryl' to sudoers
pacman -S sudo
echo "
# allow daryl to run sudo
daryl ALL=(ALL) ALL" >> /etc/sudoers

# Function to build and install packages from the AUR (as user instead of root)
aur_build() {
  for PKG in $1; do
    su - daryl -c "
      [[ ! -d build ]] && mkdir build
      cd build
      curl -o $PKG.tar.gz https://aur.archlinux.org/packages/${PKG:0:2}/$PKG/$PKG.tar.gz
      tar zxvf $PKG.tar.gz
      rm $PKG.tar.gz
      cd $PKG
      makepkg -csi --noconfirm
    "
  done
}

# Build and install yaourt
aur_build "package-query yaourt"

# Function to install packages without confirmation (can AUR and main packages be combined in a single command?).  Will this handle multiple nonquoted packages, or do I have to rework this??
package_install() {
  yaourt -S --noconfirm $@
}

# Function to remove packages (without confirmation??)
package_remove() {
  yaourt -Rcsn --noconfirm $@
}

# -------------------------------------------------- 
# Desktop environment setup
# -------------------------------------------------- 

# install dependencies
# pacman -S phonon-gstreamer mesa-libgl ttf-bitstream-vera
pacman -S phonon-vlc mesa-libgl ttf-bitstream-vera

# install meta-packages
#pacman -S kde-meta-kdeaccessibility
pacman -S kde-meta-kdeadmin
pacman -S kde-meta-kdeartwork
pacman -S kde-meta-kdebase
#pacman -S kde-meta-kdeedu
#pacman -S kde-meta-kdegames
pacman -S kde-meta-kdegraphics
pacman -S kde-meta-kdemultimedia
pacman -S kde-meta-kdenetwork
#pacman -S kde-meta-kdepim
pacman -S kde-meta-kdeplasma-addons
pacman -S kde-meta-kdesdk
#pacman -S kde-meta-kdetoys
pacman -S kde-meta-kdeutils
pacman -S kde-meta-kdewebdev
pacman -S kde-wallpapers

# enable autologin with kde
systemctl enable kdm