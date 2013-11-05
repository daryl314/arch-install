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
    [[ ! -d build ]] && mkdir build
    cd build
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

# Function to install packages without confirmation (can AUR and main packages be combined in a single command?).  Will this handle multiple nonquoted packages, or do I have to rework this??
package_install() {
  yaourt -S --noconfirm $@ || failure_notify $@
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
  sudo modprobe -a vboxguest vboxsf vboxvideo
  sudo echo -e "vboxguest\nvboxsf\nvboxvideo" | sudo tee -a /etc/modules-load.d/virtualbox.conf
  echo "/usr/bin/VBoxClient-all" > /home/daryl/.xinitrc
  sudo systemctl enable vboxservice.service
  [ grep -q vboxsf /etc/group ] && sudo groupadd vboxsf
  sudo gpasswd -a daryl vboxsf
fi

# install basic vesa video driver
# see instructions for getting acceleration working:
#   https://wiki.archlinux.org/index.php/Xorg#Driver_installation
if ! lspci | grep -q VirtualBox
then
  package_install xf86-video-vesa
fi

# -------------------------------------------------- 
# Common setup
# --------------------------------------------------

#Abstraction for enumerating power devices, listening to device events and querying history and statistics
# http://upower.freedesktop.org/
# do i want this?  can cause slow dialog boxes: https://wiki.archlinux.org/index.php/KDE#Dolphin_and_File_Dialogs_are_extremely_slow_to_start_everytime
# https://wiki.archlinux.org/index.php/Systemd#Power_management
#system_ctl enable upower

# extra fonts
package_install ttf-inconsolata ttf-win7-fonts

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
package_install caledonia-bundle                  # caledonia kde theme
package_install yakuake                           # dropdown terminal
package_install yakuake-skin-plasma-oxygen-panel  # oxygen theme for yakuake
package_install wicd-kde                          # network manager (needed?)

# configure startup of kde
systemctl enable kdm

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

# --------------------------------------------------
# E17
# -------------------------------------------------- 

# install base E17 packages
package_install enlightenment17                 # E17
package_install gvfs                            # Gnome virtual filesystem
package_install xdg-user-dirs                   # Common directories
package_install leafpad epdfview                # Editor and PDF viewer
package_install lxappearance                    # GTK theme switcher 
package_install ttf-bitstream-vera ttf-dejavu   # Fonts
package_install gnome-defaults-list             # Default file associations for gnome

# config xinitrc (can probably ignore if using kdm)
#config_xinitrc "enlightenment_start"

# network management
# conflicts with openresolv, so raises an error...
#package_install connman
#systemctl enable connman

# install and enable lxdm unless kdm is already installed
pacman -Qs kdebase-workspace > dev/null || package_install lxdm
pacman -Qs kdebase-workspace > dev/null || sudo systemctl enable lxdm

# install miscellaneous apps
package_install dmenu           # dynamic menu manager
package_install viewnior        # image viewer
package_install gmrun           # lightweight application runner
package_install pcmanfm         # file manager
package_install terminology     # terminal application
package_install scrot           # screenshot tool
package_install squeeze-git     # archive manager (install fails)
package_install thunar tumbler  # file manager and thumbnail service
package_install tint2           # system panel/taskbar
package_install volwheel        # volume tray icon
package_install xfburn          # cd/dvd burning tool
package_install xcompmgr        # compositing window manager
package_install transset-df     # enable transparency for xcompmgr
package_install zathura         # document viewer

# install icon themes
package_install elementary-xfce-icons
package_install moka-icon-theme-git

# install gtk themes (clean up this list if i don't like them all - slow)
package_install xfce-theme-greybird-git
package_install gtk-theme-numix-git
package_install gtk-theme-orion-git

# install themes
# https://wiki.archlinux.org/index.php/Enlightenment#Installing_themes
wget http://exchange.enlightenment.org/theme/get/304 -O ~/.e/e/themes/simply-white.edj
wget http://exchange.enlightenment.org/theme/get/294 -O ~/.e/e/themes/cerium.edj
wget http://exchange.enlightenment.org/theme/get/274 -O ~/.e/e/themes/cthulhain.edj

