# Daryl's desktop installation scripts

## Installation of a new arch linux system

* Browse to ~/Coding/desktop_install/arch on outer machine
* Run command on outer machine: python -m SimpleHTTPServer
* Get script from inner machine: wget 192.168.254.143:8000/install.sh
* Run script from inner machine: bash install.sh

## Fetching from Gitlab

* ```wget -O install.sh https://gitlab.com/daryl314/desktop-installers/raw/master/arch/install.sh?private_token=vSwfe1xzGbzPbPeDNpZ7```
* ```wget -O postinstall.sh https://gitlab.com/daryl314/desktop-installers/raw/master/arch/postinstall.sh?private_token=vSwfe1xzGbzPbPeDNpZ7```

## Arch references

* https://wiki.archlinux.org/index.php/Beginners%27_Guide
* https://github.com/helmuthdu/aui
