#!/bin/bash
set -e

echo "Please close all Chromium before update"
read -p "Press enter to continue"

# Config file of profile 1
pref_file=~/.config/chromium/Profile\ 1/Preferences

# Add flash exception
tmp=`jq '.profile.content_settings.exceptions.plugins += {"www.svt.se,*":{"last_modified":"13160911332033404","setting":1}}' "$pref_file"`
echo $tmp > "$pref_file"

echo "Config updated"
