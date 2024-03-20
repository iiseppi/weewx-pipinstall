#
# this script installs weewx v5 via pip
# as well as nginx, hooking the two together
# so that the weewx web will be at http://x.x.x.x/weewx

#------------- START EDITING HERE -------------------------

RUN_AS_VAGRANT_PROVISIONER=0
INSTALL_BELCHERTOWN_SKIN=0

#-------------- STOP EDITING HERE -------------------------

# the Vagrantfile sets privileged: false
# so we need to use sudo occasionally here
# but fortunately this os has vagrant sudo-enabled

if [ "x${RUN_AS_VAGRANT_PROVISIONER}" = "x1" ]
then
  WEEWXUSER="vagrant"
else
  WEEWXUSER=${USER}
fi
echo "...setting up to run as user ${WEEWXUSER}..."

echo "...installing packages..."
sudo apt-get update \
    && sudo apt-get install -y python3-pip python3-venv \
          sqlite3 wget rsyslog vim sudo libopenjp2-7

echo "...installing weewx..."
python3 -m venv /home/${WEEWXUSER}/weewx-venv \
    && source /home/${WEEWXUSER}/weewx-venv/bin/activate \
    && pip3 install wheel \
    && pip3 install weewx \
    && weectl station create --no-prompt \
    && sed -i -e s:debug\ =\ 0:debug\ =\ 1: ~/weewx-data/weewx.conf 

if [ "x${INSTALL_BELCHERTOWN_SKIN}" = "x1" ]
then
  echo "...installing belchertown skin..."
  sudo apt-get install -y git
  git clone https://github.com/poblabs/weewx-belchertown.git
  weectl extension install -y weewx-belchertown
fi

# install the rsyslogd hook and reset the logging daemon
echo "...setting up rsyslogd..."
sudo cp /home/${WEEWXUSER}/weewx-data/util/rsyslog.d/weewx.conf /etc/rsyslog.d/weewx.conf \
    && sudo systemctl restart rsyslog

# install and configure nginx and connect it to weewx
echo "...integrating weewx and nginx setups..."
sudo apt-get install -y nginx
sudo mkdir /var/www/html/weewx
sudo chown ${WEEWXUSER}:${WEEWXUSER} /var/www/html/weewx
ln -s /var/www/html/weewx /home/${WEEWXUSER}/weewx-data/public_html

# set up logrotate to match
echo "...setting up logrotate..."
sudo cp /home/${WEEWXUSER}/weewx-data/util/logrotate.d/weewx /etc/logrotate.d/weewx

# set up systemd and start weewx up
echo "...setting up systemd..."
sudo sh /home/${WEEWXUSER}/weewx-data/scripts/setup-daemon.sh

echo "...starting weewx..."
sudo systemctl start weewx

