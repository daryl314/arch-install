# Arch installation notes

## Installation of a new arch linux system

* Browse to ~/Coding/Desktop/arch on outer machine
* Run command on outer machine: python -m SimpleHTTPServer
* Get script from inner machine: wget 192.168.254.143:8000/install.sh
* Run script from inner machine: bash install.sh

## Post-installation

* Log in as daryl
* `bash postinstall.sh`

## Fetching from Gitlab

```
gitlab-fetch() {
  wget -O $1 "https://gitlab.com/daryl314/arch/raw/master/$1?private_token=vSwfe1xzGbzPbPeDNpZ7"
}
```

* `gitlab-fetch install.sh`
* `gitlab-fetch postinstall.sh`

## Arch references

* https://wiki.archlinux.org/index.php/Beginners%27_Guide
* https://github.com/helmuthdu/aui
