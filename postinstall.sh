#!/bin/bash

# terminate script on errors (-ex for trace too)
set -ex

# -------------------------------------------------- 
# Setup
# -------------------------------------------------- 

# upgrade packages
#  https://www.archlinux.org/news/binaries-move-to-usrbin-requiring-update-intervention/
pacman -Syu --noconfirm

# create user account (daryl in group users)
useradd -m -g users -G wheel -s /bin/bash daryl
passwd daryl

# -------------------------------------------------- 
# Package management
# --------------------------------------------------

# Prerequisites for building yaourt (base devel + dependencies listed in build file)
pacman -S --noconfirm base-devel yajl diffutils

# Install sudo and add 'daryl' to sudoers
# !requiretty needed for noninteractive package building
pacman -S --noconfirm sudo

# Uncomment to allow members of group wheel to execute any command
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers

# This config is especially helpful for those using terminal multiplexers like screen, tmux, or ratpoison, and those using sudo from scripts/cronjobs:
echo "
Defaults !requiretty, !tty_tickets, !umask
Defaults visiblepw, path_info, insults, lecture=always
Defaults loglinelen=0, logfile =/var/log/sudo.log, log_year, log_host, syslog=auth
Defaults passwd_tries=3, passwd_timeout=1
Defaults env_reset, always_set_home, set_home, set_logname
Defaults timestamp_timeout=300
" >> /etc/sudoers

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
# Graphics setup
# -------------------------------------------------- 

# install the base Xorg packages:
package_install xorg-server xorg-server-utils xorg-xinit

# install mesa for 3D support:
package_install mesa

# set up virtualbox guest additions 
# https://wiki.archlinux.org/index.php/VirtualBox#Arch_Linux_as_a_guest_in_a_Virtual_Machine
if lspci | grep -q VirtualBox
then
  package_install virtualbox-guest-utils
  modprobe -a vboxguest vboxsf vboxvideo
  echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
  echo "/usr/bin/VBoxClient-all" > /home/daryl/.xinitrc
  systemctl enable vboxservice.service
  [ grep -q vboxsf /etc/group ] && groupadd vboxsf
  gpasswd -a daryl vboxsf
fi

# install basic vesa video driver
# see instructions for getting acceleration working:
#   https://wiki.archlinux.org/index.php/Xorg#Driver_installation
if ! lspci | grep -q VirtualBox
then
  package_install xf86-video-vesa
fi

# --------------------------------------------------
# KDE
# -------------------------------------------------- 

# install dependencies (kde devs suggest gstreamer over vlc)
package_install phonon-gstreamer mesa-libgl ttf-bitstream-vera

# install kde
# list of all packages w/ descriptions: https://www.archlinux.org/groups/x86_64/kde/
package_install `pacman -Sg kde | grep -vF -e kdeaccessibility- -e kdeedu- -e kdegames- -e kdepim- -e kdetoys-`

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
package_install caledonia-bundle                  # caledonia kde theme
package_install yakuake                           # dropdown terminal
package_install yakuake-skin-plasma-oxygen-panel  # oxygen theme for yakuake
package_install wicd-kde                          # network manager (needed?)

# configure startup of kde (probably can eliminate xinitrc...)
#config_xinitrc "startkde"
systemctl enable kdm

#Abstraction for enumerating power devices, listening to device events and querying history and statistics
# http://upower.freedesktop.org/
# do i want this?  can cause slow dialog boxes: https://wiki.archlinux.org/index.php/KDE#Dolphin_and_File_Dialogs_are_extremely_slow_to_start_everytime
#system_ctl enable upower

# increase number of nepomuk watched files (from arch kde wiki page)
echo "fs.inotify.max_user_watches = 524288" >> /etc/sysctl.d/99-inotify.conf

# pulseaudio (was in aui script.  do i even use pulseaudio??)
# https://wiki.archlinux.org/index.php/KDE#Sound_problems_under_KDE
#echo "load-module module-device-manager" >> /etc/pulse/default.pa

# speed up application startup (from arch kde wiki page)
mkdir -p ~/.compose-cache

# common theming with gtk apps
package_install kde-gtk-config
package_install oxygen-gtk2 oxygen-gtk3 qtcurve-gtk2 qtcurve-kde4

# qtcurve themes
curl -o Sweet.tar.gz http://kde-look.org/CONTENT/content-files/144205-Sweet.tar.gz
curl -o Kawai.tar.gz http://kde-look.org/CONTENT/content-files/141920-Kawai.tar.gz
tar zxvf Sweet.tar.gz
tar zxvf Kawai.tar.gz
rm Sweet.tar.gz
rm Kawai.tar.gz
mkdir -p /home/daryl/.kde4/share/apps/color-schemes
mv Sweet/*.colors /home/daryl/.kde4/share/apps/color-schemes
mv Kawai/*.colors /home/daryl/.kde4/share/apps/color-schemes
mkdir -p /home/daryl/.kde4/share/apps/QtCurve
mv Sweet/Sweet.qtcurve /home/daryl/.kde4/share/apps/QtCurve
mv Kawai/Kawai.qtcurve /home/daryl/.kde4/share/apps/QtCurve
chown -R daryl:users /home/daryl/.kde4
rm -fr Kawai Sweet