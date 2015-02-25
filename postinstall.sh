#!/bin/bash

# terminate script on errors (-ex for trace too)
set -ex

# --------------------------------------------------
# Package management
# --------------------------------------------------

# enable multilib
grep '^\[multilib\]' /etc/pacman.conf || echo "
[multilib]
Include = /etc/pacman.d/mirrorlist
" | sudo tee -a /etc/pacman.conf

# use tmpfs for compiling
sudo perl -pi -e 's/.*BUILDDIR.*/BUILDDIR=\/tmp\/builds/' /etc/makepkg.conf

# upgrade packages
sudo pacman -Syu --noconfirm

# install daemon to speed up cryptographic programs
# https://www.archlinux.org/news/gnupg-21-and-the-pacman-keyring/
sudo pacman -S --noconfirmal haveged
sudo systemctl start haveged
sudo systemctl enable haveged

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

# Save built AUR packages in pacman cache
# https://wiki.archlinux.org/index.php/yaourt#Cache
sudo perl -pi -e 's/#?EXPORT=./EXPORT=2 /' /etc/yaourtrc

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

# install powerpill to speed up downloads (and configure yaourt to use it)
package_install powerpill
echo 'PACMAN="powerpill"' | sudo tee -a /etc/yaourtrc
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
sudo reflector --verbose --country 'United States' -l 200 -p http --sort rate --save /etc/pacman.d/mirrorlist

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

# install the base Xorg packages:
package_install xorg-server xorg-server-utils xorg-xinit

# install intel video driver
# https://wiki.archlinux.org/index.php/Intel_Graphics#Installation
! ( lspci | grep -q Virtualbox ) && package_install xf86-video-intel lib32-mesa-libgl libva-intel-driver libva

# add intel initramfs settings and enable early KMS
# https://wiki.archlinux.org/index.php/Intel_Graphics#Enable_early_KMS
# https://wiki.archlinux.org/index.php/Intel_Graphics#Blank_screen_during_boot.2C_when_.22Loading_modules.22
sudo perl -pi -e 's/MODULES=".*"/MODULES="i915 intel_agp"/' /etc/mkinitcpio.conf
sudo mkinitcpio -p linux

# kernel mode settings (KMS) for external monitor during boot
# https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
#sudo perl -pi -e 's/(GRUB_CMDLINE_LINUX_DEFAULT)=".*"/$1="verbose VGA-1:1920x1080\@60.0"/' /etc/default/grub
#sudo grub-mkconfig -o /boot/grub/grub.cfg
#echo "xrandr --output VGA1 --mode 1920x1080" | sudo tee -a /usr/share/config/kdm/Xsetup

# extra fonts
# https://wiki.archlinux.org/index.php/Font_Configuration
# NOTE: don't want fonts looking like this: http://i.imgur.com/t6VQm2n.png
package_install ttf-inconsolata

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
git config --global user.email "daryl.stlaurent+github@gmail.com"
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

# zram - compressed swap in RAM
# https://wiki.archlinux.org/index.php/Maximizing_Performance#Compcache.2FZram
package_install zramswap
sudo systemctl enable zramswap

# laptop touchpad driver
# https://wiki.archlinux.org/index.php/Touchpad_Synaptics
#package_install xf86-input-synaptics

# enable auto-completion and "command not found"
package_install bash-completion pkgfile
sudo pkgfile --update

# help arch out with package installation stats
package_install pkgstats

# configure cron
# https://wiki.archlinux.org/index.php/cron
# crontab located at /var/spool/cron/daryl
package_install cronie
sudo systemctl start cronie
sudo systemctl enable cronie

# make server mountpoints
sudo mkdir -p /mnt/server
sudo mkdir -p /mnt/server-local
sudo chown daryl /mnt/*
sudo chgrp users /mnt/*

# add network hosts
if ! grep -q server /etc/hosts
then echo "
# additional network hosts
192.168.254.1   router
192.168.254.20  server
192.168.254.20  local.darylstlaurent.com
192.168.254.20  wiki.local.darylstlaurent.com
192.168.254.20  todo.local.darylstlaurent.com
192.168.254.20  gtd.local.darylstlaurent.com

# redirect www.kateanddaryl.com for testing
# 192.168.254.20  www.kateanddaryl.com" | sudo tee -a  /etc/hosts
fi

# webdav setup
package_install davfs2
mkdir -p ~/owncloud
sudo usermod -a -G network daryl
if ! grep -q owncloud /etc/fstab
then echo "
# owncloud configuration
https://darylstlaurent.com:443/owncloud/files/webdav.php /home/daryl/owncloud davfs user,noauto,uid=daryl,file_mode=600,dir_mode=700 0 1
" | sudo tee -a /etc/fstab
fi

# change default behavior of function keys on apple keyboard
# https://wiki.archlinux.org/index.php/Apple_Keyboard
echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode
echo options hid_apple fnmode=2 | sudo tee /etc/modprobe.d/hid_apple.conf
sudo perl -pi -e 's/FILES=".*"/FILES="\/etc\/modprobe.d\/hid_apple.conf"/' /etc/mkinitcpio.conf
sudo mkinitcpio -p linux

# ignore lid events
# https://wiki.archlinux.org/index.php/Power_Management
#sudo perl -pi -e 's/#?HandleLidSwitch.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
#sudo systemctl restart systemd-logind

# time synchronization
package_install ntp
sudo timedatectl set-ntp 1

# prevent excessive laptop hard drive spindown
# https://wiki.archlinux.org/index.php/Laptop#Hard_drive_spin_down_problem
#echo 'ACTION=="add", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", RUN+="/usr/bin/hdparm -B 254 /dev/$kernel"' | sudo tee /etc/udev/rules.d/75-hdparm.rules

# tune swap and cache usage
# http://rudd-o.com/linux-and-free-software/tales-from-responsivenessland-why-linux-feels-slow-and-how-to-fix-that
# https://wiki.archlinux.org/index.php/Swap#Swappiness
#echo "#System booster
#vm.swappiness=1
#vm.vfs_cache_pressure=50
#" | sudo tee /etc/sysctl.d/99-sysctl.conf

# install bluetooth stack
# https://wiki.archlinux.org/index.php/bluetooth
package_install bluez bluez-utils
sudo modprobe btusb
sudo systemctl start bluetooth
sudo systemctl enable bluetooth
echo '# Set bluetooth power up for dongle
ACTION=="add", KERNEL=="hci1", RUN+="/usr/bin/hciconfig hci1 up"
' | sudo tee "/etc/udev/rules.d/10-local.rules"

# printer driver (print to pdf)
# https://wiki.archlinux.org/index.php/CUPS#PDF_virtual_printer
package_install cups-pdf                     # install driver
sudo groupadd -f printadmin                  # create printer admin group
sudo groupadd -f lp                          # create printing group
sudo gpasswd -a daryl printadmin             # add to admin group
sudo gpasswd -a daryl lp                     # add to printing group
sudo perl -pi -e 's/#?(^SystemGroup.*)/$1 printadmin/' /etc/cups/cups-files.conf
sudo perl -pi -e 's/#?Out.*/Out \${HOME}/' /etc/cups/cups-pdf.conf
sudo systemctl start org.cups.cupsd.service  # start service
sudo systemctl enable org.cups.cupsd.service # autostart service
sudo lpadmin -p Virtual_PDF_Printer -D "Virtual PDF Printer" -v cups-pdf:/ -E -P /usr/share/cups/model/CUPS-PDF.ppd

# install 'locate' command and perform initial scan (will be updated automatically in future)
package_install mlocate
sudo updatedb

# htop - advanced process monitor
package_install htop lsof strace

# ncdu - console-based interactive du (like filelight)
package_install ncdu

# iotop - top equivalent for I/O
package_install iotop

# enable TRIM for SSDs
# https://wiki.archlinux.org/index.php/Solid_State_Drives#TRIM
sudo systemctl start fstrim.timer
sudo systemctl enable fstrim.timer

# change IO scheduler for SSDs
# https://wiki.archlinux.org/index.php/Solid_State_Drives#I.2FO_Scheduler
echo '# set deadline scheduler for non-rotating disks
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"
' | sudo tee /etc/udev/rules.d/60-schedulers.rules

# --------------------------------------------------
# KDE
# --------------------------------------------------

# install dependencies
package_install ttf-bitstream-vera

# install kde using meta packages to facilitate upgrades
# list of all packages w/ descriptions: https://www.archlinux.org/groups/x86_64/kde/
# remove group name from each line
# remove selected meta-packages from list
package_install `pacman -Sg kde-meta | \
  sed 's/kde-meta //' | \
  grep -v \
    -e ^kde-meta-kdeaccessibility \
    -e ^kde-meta-kdeedu \
    -e ^kde-meta-kdegames \
    -e ^kde-meta-kdepim \
    -e ^kde-meta-kdetoys`

# switch to plasma 5
sudo pacman -Su sddm sddm-kcm
sudo pacman -Rc kdebase-workspace
sudo pacman -Su plasma-meta
package_install libappindicator-gtk2 libappindicator-gtk3 sni-qt lib32-sni-qt

# set up common directories (downloads, music, documents, etc)
# https://wiki.archlinux.org/index.php/Xdg_user_directories
# not sure if i want/need this??
package_install xdg-user-dirs

# install additional packages
package_install kde-telepathy-meta                # chat program (use instead of kopete)
package_install digikam kipi-plugins              # kde photo manager
package_install k3b cdrdao dvd+rw-tools           # cd/dvd burning
package_install yakuake                           # dropdown terminal
package_install yakuake-skin-plasma-oxygen-panel  # oxygen theme for yakuake
package_install plasma-nm                         # KDE front end to NetworkManager
package_install kcmsystemd                        # system settings: systemd management
package_install kdiff3                            # file diff viewers
package_install avidemux-qt                       # video editor
package_install ksuperkey                         # allow binding to meta key
package_install bluedevil                         # bluetooth control

# configure startup of sddm
sudo systemctl enable sddm
echo "[Autologin]
Relogin=false
Session=plasma.desktop
User=daryl
" | sudo tee /etc/sddm.conf

# enable NetworkManager service
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

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

# wallpaper links
! ( lspci | grep VirtualBox ) && sudo ln -fs ~/dotfiles/wallpaper/CaledoniaWallpapers/* /usr/share/wallpapers/
! ( lspci | grep VirtualBox ) && sudo ln -fs ~/dotfiles/wallpaper/Vanilla-1920x1080.jpg /usr/share/wallpapers/
! ( lspci | grep VirtualBox ) && sudo ln -fs ~/dotfiles/wallpaper/zen_stones_background-wallpaper-1920x1080.jpg /usr/share/wallpapers/

# disable debug output logging
if ! grep -q QT_LOGGING_RULES /etc/environment
then echo "QT_LOGGING_RULES='*.debug=false'" | sudo tee -a /etc/environment
fi

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

# octave and some additional packages
package_install octave octave-image octave-statistics octave-io

# --------------------------------------------------
# Programming tools
# --------------------------------------------------

# vim
# https://wiki.archlinux.org/index.php/Vim
package_install gvim ctags

# git tools
package_install git-cola yelp-tools giggle

# tmux
# https://wiki.archlinux.org/index.php/Tmux
package_install tmux xclip tmuxinator

# ruby
# https://wiki.archlinux.org/index.php/ruby
package_install ruby
package_install ruby-rest-client
gem install pry-rescue pry-nav           # debugging tools
gem install pry-stack_explorer           # must be installed separately to avoid conflicts
gem install evernote-thrift              # for Evernote backup script

# python packages
package_install python-yaml

# markdown to html
package_install markdown python-markdown elinks

# atom text editor
package_install atom-editor-bin

# --------------------------------------------------
# System tools
# --------------------------------------------------

# ecryptfs
# https://wiki.archlinux.org/index.php/ECryptfs
package_install ecryptfs-utils
sudo modprobe ecryptfs

# encfs
# https://wiki.archlinux.org/index.php/EncFS
package_install encfs

# sshfs
# https://wiki.archlinux.org/index.php/sshfs
package_install sshfs

# backup utilities
package_install rsync rsnapshot rdiff-backup

# package management
package_install octopi

# conky
# https://wiki.archlinux.org/index.php/conky
package_install conky

# gparted
package_install gparted dosfstools

# xmonad
# https://wiki.archlinux.org/index.php/xmonad
#package_install xmonad xmonad-contrib xorg-server-xephyr xorg-xdpyinfo hsetroot trayer xscreensaver dmenu xmobar xdotool

# FTP server
package_install vsftpd
sudo perl -pi -e 's/anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd.conf
sudo perl -pi -e 's/#?local_enable=.*/local_enable=YES/' /etc/vsftpd.conf
sudo perl -pi -e 's/#?write_enable=.*/write_enable=YES/' /etc/vsftpd.conf
sudo systemctl enable vsftpd.service

# colorize diff output
package_install colordiff

# S.M.A.R.T. hard drive diagnostics
# https://wiki.archlinux.org/index.php/S.M.A.R.T.
package_install smartmontools gsmartcontrol

# Power management
# https://wiki.archlinux.org/index.php/Power_saving
# https://wiki.archlinux.org/index.php/TLP
package_install tlp
sudo systemctl enable tlp
sudo systemctl enable tlp-sleep.service

# verynice (runaway process helper)
# https://wiki.archlinux.org/index.php/VeryNice
package_install verynice
sudo systemctl enable verynice.service

# bittorrent sync
package_install btsync
systemctl --user start btsync
systemctl --user enable btsync

# --------------------------------------------------
# Other applications
# --------------------------------------------------

# web browsers
package_install google-chrome firefox flashplugin kpartsplugin icedtea-web

# sqlite
package_install sqlite sqliteman

# coffeescript
package_install coffee-script

# wine/PlayOnLinux
# https://wiki.archlinux.org/index.php/wine
package_install playonlinux wine-mono wine_gecko samba libxml2

# VLC
# https://wiki.archlinux.org/index.php/VLC_media_player
package_install vlc

# calibre
package_install calibre

# shotwell
package_install shotwell

# aftershot pro
package_install aftershotpro

# mozilla thunderbird
package_install thunderbird

# crashplan
package_install crashplan
sudo systemctl start crashplan.service
sudo systemctl enable crashplan.service

# virtualbox
# https://wiki.archlinux.org/index.php/VirtualBox
package_install virtualbox virtualbox-ext-oracle virtualbox-host-modules
echo "# virtualbox kernel modules
vboxdrv
vboxnetadp
vboxnetflt
vboxpci" | sudo tee /etc/modules-load.d/virtualbox.conf
sudo gpasswd -a daryl vboxusers
sudo modprobe vboxdrv
sudo modprobe vboxnetadp
sudo modprobe vboxnetflt
sudo modprobe vboxpci

# dropbox
# https://wiki.archlinux.org/index.php/dropbox
# NOTE: for some reason the default doesn't work to start dropbox after a reboot.
# I checked the "start on startup" box in the dropbox settings and added the
# killall line to the postconnect script to avoid duplicates
package_install dropbox
echo "#!/usr/bin/env bash
killall dropbox
su -c 'DISPLAY=:0 /usr/bin/dbus-launch dropboxd &' daryl" | sudo tee /etc/wicd/scripts/postconnect/dropbox
echo "#!/usr/bin/env bash
killall dropbox" | sudo tee /etc/wicd/scripts/postdisconnect/dropbox
sudo chmod +x /etc/wicd/scripts/postconnect/dropbox
sudo chmod +x /etc/wicd/scripts/postdisconnect/dropbox

# vmware viewer (requires 32-bit building code)
package_install gcc-multilib vmware-view-client

# splashtop streamer
package_install splashtop-streamer

# nixnote (evernote client)
package_install nixnote

# pdf editor
package_install masterpdfeditor

# --------------------------------------------------
# Games
# --------------------------------------------------
