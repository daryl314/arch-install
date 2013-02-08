#!/bin/bash

# terminate script on errors (-ex for trace too)
set -e

# display partition table
parted -l

# capture defaults
DRIVE=`parted -l | grep -Po '/dev/sd\w'`
ROOT=`parted -l | grep ext4 | head -n 1 | cut -c 2`
HOME=`parted -l | grep ext4 | tail -n 1 | cut -c 2`

# prompt for root and home partitions
read -e -p "Root partition: " -i "$DRIVE$ROOT" ROOT
read -e -p "Home partition: " -i "$DRIVE$HOME" HOME

# set up mounts
echo -e "\nMounting / to $ROOT\nMounting /home to $HOME\n\n"
