#!/bin/bash

# terminate script on errors (-ex for trace too)
set -ex

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

