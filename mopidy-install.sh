#!/bin/bash
set -e

# A utility script to install mopidy (spotify) and rompr
#
# Usage: 
# > ./mopidy-install.sh <spotify username> <spotify password> <spotify client id> <spotify client secret>"
# Get client id and secret at https://www.mopidy.com/authenticate/#spotify"

spotify_username=$1
spotify_password=$2
spotify_client_id=$3
spotify_client_secret=$4

if [ -z $spotify_client_id ]; then
  echo "usage:"
  echo "  > ./mopidy-install.sh <spotify username> <spotify password> <spotify client id> <spotify client secret>"
  echo "  Get client id and secret at https://www.mopidy.com/authenticate/#spotify"
  exit
fi

# Install mopidy
# https://www.mopidy.com/
# https://github.com/mopidy/mopidy-spotify

echo "Install mopidy"
sudo wget -q -O - https://apt.mopidy.com/mopidy.gpg | sudo apt-key add -
sudo wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/jessie.list
sudo apt-get update
sudo apt-get -y install mopidy mopidy-spotify
mkdir -p $HOME/.config/mopidy

sudo -u mopidy cat >/etc/mopidy/mopidy.conf<<EOL
[core]
cache_dir = /var/cache/mopidy
config_dir = /etc/mopidy
data_dir = /var/lib/mopidy

[logging]
config_file = /etc/mopidy/logging.conf
debug_file = /var/log/mopidy/mopidy-debug.log

[local]
media_dir = /var/lib/mopidy/media

[m3u]
playlists_dir = /var/lib/mopidy/playlists

[mpd]
hostname = :: 

[spotify]
username = $spotify_username
password = $spotify_password
enabled = true
bitrate = 320
timeout = 10
client_id = $spotify_client_id
client_secret = $spotify_client_secret

[audio]
output = alsasink device=hw:0,0
EOL

sudo dpkg-reconfigure mopidy
sudo service mopidy restart
echo "Install mopidy - done"


# Install rompr (frontend)
# https://sourceforge.net/projects/rompr/?source=navbar

echo "Install rompr"
home="/home/web"
rompr_dir="$home/rompr"
sudo mkdir -p $rompr_dir
sudo chown -R www-data $home
sudo chgrp -R www-data $home
wget https://downloads.sourceforge.net/project/rompr/rompr-1.08.zip -O $rompr_dir/rompr.zip
unzip $rompr_dir/rompr.zip -d $home
rm $rompr_dir/rompr.zip
sudo chmod -R ugo+rw $rompr_dir/prefs
sudo chmod -R ugo+rw $rompr_dir/albumart

sudo apt-get -y install nginx php7.0-curl php7.0-sqlite imagemagick php7.0-json php7.0-fpm php7.0-xml php7.0-mbstring

sudo bash -c "cat >/etc/nginx/sites-available/default<<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    root $home;
    index index.php index.html index.htm;
    # Make site accessible from http://localhost/
    server_name localhost;
    # This section can be copied into an existing default setup
    location /rompr {
        allow all;
        index index.php;
        client_max_body_size 32M;
        location ~ \.php {
            try_files \\\$uri =404;
            fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \\\$request_filename;
            include /etc/nginx/fastcgi_params;
            fastcgi_read_timeout 600;
        }
        error_page 404 = /rompr/404.php;
        try_files \\\$uri \\\$uri/ =404;
        location ~ /rompr/albumart/* {
            expires -1s;
        }
    }
}
EOL"

function update_config() {
    local php_conf=/etc/php/7.0/fpm/php.ini
    local variable=$1
    local value=$2
    sed -i 's/^#'"$variable"'=.*/'"$variable"'='"$value"'/' $php_conf
}

update_config "allow_url_fopen" "On"
update_config "post_max_size" "32M"
update_config "upload_max_filesize" "32M"
update_config "memory_limit" "256M"
update_config "max_execution_time" "300"
echo "Install rompr - done"

# Set pwm mode 2, the audio is hissing otherwise.
pwm=`cat /boot/config.txt | grep "audio_pwm_mode"`
if [ -z $pwm ]; then
  sudo echo "audio_pwm_mode=2" >> /boot/config.txt
  echo "Please reboot"
fi

echo "Restart services"
sudo service php7.0-fpm restart
sudo service nginx restart

echo "Installation done!"
echo "http://localhost/rompr"

