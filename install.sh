#!/bin/bash

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
ROOT=`parted "$DRIVE" print | grep ext4 | head -n 1 | cut -c 2`
HOME=`parted "$DRIVE" print | grep ext4 | tail -n 1 | cut -c 2`

# prompt for root and home partitions
read -e -p "Root partition: " -i "$DRIVE$ROOT" ROOT
read -e -p "Home partition: " -i "$DRIVE$HOME" HOME

# set up mounts
echo -e "\nMounting / to $ROOT\nMounting /home to $HOME\n\n"
