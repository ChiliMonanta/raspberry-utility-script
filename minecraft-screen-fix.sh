#!/bin/bash
set -e

# Fix for screen out of sync
sudo sed -i -e 's/#disable_overscan=1/disable_overscan=1/g' /boot/config.txt 
echo "Please reboot"
