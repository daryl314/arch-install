#!/bin/bash

# terminate script on errors (-ex for trace too)
set -ex

# -------------------------------------------------- 
# Package management
# --------------------------------------------------

# upgrade packages
sudo pacman -Syu --noconfirm

# Prerequisites for building yaourt (base devel + dependencies listed in build file)
sudo pacman -S --noconfirm base-devel yajl diffutils

# Function to build and install packages from the AUR (as user instead of root)
aur_build() {
  for PKG in $1; do
    [[ ! -d /tmp/build ]] && mkdir /tmp/build
    cd /tmp/build
    curl -o $PKG.tar.gz https://aur.archlinux.org/packages/${PKG:0:2}/$PKG/$PKG.tar.gz
    tar zxvf $PKG.tar.gz
    rm $PKG.tar.gz
    cd $PKG
    makepkg -csi --noconfirm
  done
}

# Build and install yaourt
aur_build "package-query yaourt"

failure_notify() {
  echo ""
  echo -e "\e[1;31mPackage installation failed: $@\e[0m"
  read -e -sn 1 -p "Press any key to continue..."
}

# Function to install packages without confirmation
package_install() {
#  /bin/rm -rf /tmp/* /tmp/.* &>/dev/null # clear tmp folder
  yaourt -S --noconfirm $@ || failure_notify $@
}

# Function to remove packages (without confirmation??)
package_remove() {
  yaourt -Rcsn --noconfirm $@
}

# -------------------------------------------------- 
# Virtualbox guest additions setup
# --------------------------------------------------

# setup is required for later sections

# set up virtualbox guest additions 
# https://wiki.archlinux.org/index.php/VirtualBox#Arch_Linux_as_a_guest_in_a_Virtual_Machine
if lspci | grep -q VirtualBox
then
  package_install virtualbox-guest-utils
  sudo modprobe -a vboxguest vboxsf vboxvideo
  sudo echo -e "vboxguest\nvboxsf\nvboxvideo" | sudo tee -a /etc/modules-load.d/virtualbox.conf
  echo "/usr/bin/VBoxClient-all" > /home/daryl/.xinitrc
  sudo systemctl enable vboxservice.service
  [ grep -q vboxsf /etc/group ] && sudo groupadd vboxsf
  sudo gpasswd -a daryl vboxsf
fi

# virtualbox shared folder mounting
if lspci | grep -q VirtualBox
then 
  sudo mkdir /mnt/daryl
  sudo mount -t vboxsf daryl /mnt/daryl
  echo "
# virtualbox shared folder
daryl                                           /mnt/daryl      vboxsf          defaults,uid=`id -u`   0 0
" | sudo tee -a /etc/fstab
fi

# -------------------------------------------------- 
# Graphics setup
# -------------------------------------------------- 

# add font rendering repositories
# https://wiki.archlinux.org/index.php/Infinality-bundle%2Bfonts
echo "
[infinality-bundle]
Server = http://ibn.net63.net/infinality-bundle/\$arch" | sudo tee -a /etc/pacman.conf 
[[ `uname -m` == x86_64 ]] && echo "
[infinality-bundle-multilib]
Server = http://ibn.net63.net/infinality-bundle-multilib/\$arch" | sudo tee -a /etc/pacman.conf
echo "
[infinality-bundle-fonts]
Server = http://ibn.net63.net/infinality-bundle-fonts" | sudo tee -a /etc/pacman.conf

# set up font rendering
# needs to be before xorg to avoid conflicts
sudo pacman-key -r 962DDE58
sudo pacman-key --lsign-key 962DDE58
sudo pacman -Syyu
package_install infinality-bundle ibfonts-meta-extended
[[ `uname -m` == x86_64 ]] && package_install infinality-bundle-multilib 

# install the base Xorg packages:
package_install xorg-server xorg-server-utils xorg-xinit

# install mesa for 3D support:
package_install mesa

# install basic vesa video driver
# see instructions for getting acceleration working:
#   https://wiki.archlinux.org/index.php/Xorg#Driver_installation
if ! lspci | grep -q VirtualBox
then
  package_install xf86-video-vesa
fi

# extra fonts
package_install t1-inconsolata-zi4-ibx

# windows 7 fonts
sudo mkdir /usr/share/fonts/win7
if lspci | grep -q VirtualBox 
then 
  sudo cp /mnt/daryl/Backups/Software/Windows\ Software/Windows\ 7\ Fonts/* /usr/share/fonts/win7
else
  sudo cp /home/daryl/Backups/Software/Windows\ Software/Windows\ 7\ Fonts/* /usr/share/fonts/win7
fi
sudo fc-cache -vf
sudo mkfontscale
sudo mkfontdir

# -------------------------------------------------- 
# Audio setup
# -------------------------------------------------- 

# install alsa utilities and unmute sound channels
package_install alsa-utils
amixer sset Master unmute

# initialize sound system for virtualbox
if lspci | grep -q VirtualBox
then 
  alsactl init || true # prevent error return code from stopping script
fi

# -------------------------------------------------- 
# Dotfile setup
# --------------------------------------------------

# Install git
package_install git tk
git config --global user.name "Daryl St. Laurent"
git config --global user.email "daryl.stlaurent@gmail.com"
git config --global color.ui true

# Install ssh
package_install openssh

# Copy ssh keys from shared folder
if lspci | grep -q VirtualBox
then
  mkdir -p ~/.ssh
  sudo cp /mnt/daryl/Private/.ssh/id_rsa /home/daryl/.ssh/
  sudo cp /mnt/daryl/Private/.ssh/id_rsa.pub /home/daryl/.ssh/
  sudo chown daryl:users /home/daryl/.ssh/id_rsa*
fi

# Script to pull dotfiles repository from gitlab
if lspci | grep -q VirtualBox
then
  echo "
    ssh-keyscan -H gitlab.com >> ~/.ssh/known_hosts
    git clone git@gitlab.com:daryl314/dotfiles.git
    source dotfiles/make_links
  " > ~/pull_dotfiles.sh
fi

# -------------------------------------------------- 
# Common setup
# --------------------------------------------------

#Abstraction for enumerating power devices, listening to device events and querying history and statistics
# http://upower.freedesktop.org/
# do i want this?  can cause slow dialog boxes: https://wiki.archlinux.org/index.php/KDE#Dolphin_and_File_Dialogs_are_extremely_slow_to_start_everytime
# https://wiki.archlinux.org/index.php/Systemd#Power_management
#system_ctl enable upower

# readahead - improve boot time
# https://wiki.archlinux.org/index.php/Improve_Boot_Performance#Readahead
sudo systemctl enable systemd-readahead-collect systemd-readahead-replay

# zram - compressed swap in RAM
# https://wiki.archlinux.org/index.php/Maximizing_Performance#Compcache.2FZram
package_install zramswap
sudo systemctl enable zramswap

# laptop touchpad driver
# https://wiki.archlinux.org/index.php/Touchpad_Synaptics
package_install xf86-input-synaptics

# enable auto-completion and "command not found"
package_install bash-completion pkgfile
sudo pkgfile --update

# --------------------------------------------------
# KDE
# -------------------------------------------------- 

# install dependencies (kde devs suggest gstreamer over vlc)
package_install phonon-gstreamer mesa-libgl ttf-bitstream-vera

# install kde excluding the initial 'kde ' from each line and removing selected packages from list
# list of all packages w/ descriptions: https://www.archlinux.org/groups/x86_64/kde/
package_install `pacman -Sg kde | \
  cut -c 5- | \
  grep -v \
    -e ^kdeaccessibility \
    -e ^kdeedu \
    -e ^kdegames \
    -e ^kdepim \
    -e ^kdetoys`

# remove some packages from base install
package_remove kdemultimedia-kscd kdemultimedia-juk kdebase-kwrite kdebase-konqueror

# switch from kopete to telepathy (new KDE default chat application)
package_install kde-telepathy-meta
package_remove kdenetwork-kopete

# set up common directories (downloads, music, documents, etc)
# https://wiki.archlinux.org/index.php/Xdg_user_directories
# not sure if i want/need this??
package_install xdg-user-dirs

# install additional packages
package_install digikam kipi-plugins              # kde photo manager
package_install k3b cdrdao dvd+rw-tools           # cd/dvd burning
package_install yakuake                           # dropdown terminal
package_install yakuake-skin-plasma-oxygen-panel  # oxygen theme for yakuake
package_install wicd-kde                          # network manager (needed?)

# configure startup of kde
sudo systemctl enable kdm

# increase number of nepomuk watched files (from arch kde wiki page)
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.d/99-inotify.conf

# pulseaudio (was in aui script.  do i even use pulseaudio??)
# https://wiki.archlinux.org/index.php/KDE#Sound_problems_under_KDE
#echo "load-module module-device-manager" >> /etc/pulse/default.pa

# speed up application startup (from arch kde wiki page)
mkdir -p ~/.compose-cache

# common theming with gtk apps
package_install kde-gtk-config
package_install oxygen-gtk2 oxygen-gtk3 qtcurve-gtk2 qtcurve-kde4

# --------------------------------------------------
# Math software
# -------------------------------------------------- 

# install scipy stack
package_install python-matplotlib python-numpy python-scipy python-sympy python-nose
package_install ipython python-jinja python-tornado # ipython and ipython notebook
package_install python-pygments python-pyqt4 python-pyzmq python-sip # qtconsole dependencies
package_install python-pandas # needs to be compiled

# additional python packages
package_install python-requests

# need a web browser
package_install google-chrome 

# chrome font fix for bold fonts
# https://bbs.archlinux.org/viewtopic.php?pid=1344172#p1344172
mkdir -p /home/daryl/.config/fontconfig
echo "<?xml version='1.0'?><!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <match target='pattern'>
    <edit name='dpi' mode='assign'>
      <double>72</double>
    </edit>
  </match>
</fontconfig>
" > /home/daryl/.config/fontconfig/fonts.conf

# --------------------------------------------------
# Other software
# -------------------------------------------------- 

# vim
# https://wiki.archlinux.org/index.php/Vim
package_install gvim ctags

# git tools
package_install git-cola yelp-tools giggle-git

# tmux
# https://wiki.archlinux.org/index.php/Tmux
package_install tmux xclip xtmuxinator

# install 'locate' command and perform initial scan (will be updated automatically in future)
package_install mlocate
sudo updatedb

# ruby
# https://wiki.archlinux.org/index.php/ruby
package_install ruby

# xmonad
# https://wiki.archlinux.org/index.php/xmonad
package_install xmonad xmonad-contrib xorg-server-xephyr xorg-xdpyinfo hsetroot trayer xscreensaver dmenu xmobar xdotool

