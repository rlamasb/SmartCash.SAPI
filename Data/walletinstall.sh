#!/bin/bash
# install.sh
# Installs smartnode on Ubuntu 16.04 LTS x64
# ATTENTION: The anti-ddos part will disable http, https and dns ports.

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit -1
fi

while true; do
 if [ -d ~/.smartcash ]; then
   printf "~/.smartcash/ already exists! The installer will delete this folder. Continue anyway?(Y/n)"
   read REPLY
   if [ ${REPLY} == "Y" ]; then
      pID=$(ps -ef | grep smartcashd | awk '{print $2}')
      kill ${pID}
      rm -rf ~/.smartcash/
      break
   else
      if [ ${REPLY} == "n" ]; then
        exit
      fi
   fi
 else
   break
 fi
done

# Warning that the script will reboot the server
echo "WARNING: This script will reboot the server when it's finished."
printf "Press Ctrl+C to cancel or Enter to continue: "
read IGNORE

cd

# The RPC node will only accept connections from your localhost
_rpcUserName=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12 ; echo '')

# Choose a random and secure password for the RPC
_rpcPassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')

# Get the IP address of your vps which will be hosting the smartnode
_nodeIpAddress=$(ip route get 1 | awk '{print $NF;exit}')

# Make a new directory for smartcash daemon
mkdir ~/.smartcash/
touch ~/.smartcash/smartcash.conf

# Change the directory to ~/.smartcash
cd ~/.smartcash/

# Create the initial smartcash.conf file
echo "rpcuser=${_rpcUserName}
rpcpassword=${_rpcPassword}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=64
txindex=1
" > smartcash.conf

# Dowload bootstrap
echo downloading bootstrap
wget https://smartcash.cc/txindexstrap.zip

cd

# Install smartcashd using apt-get
apt-get update -y
apt-get install software-properties-common -y
add-apt-repository ppa:smartcash/ppa -y && apt update -y && apt install smartcashd -y && smartcashd

# Create a directory for smartnode's cronjobs and the anti-ddos script
rm -r smartnode
mkdir smartnode

# Change the directory to ~/smartnode/
cd ~/smartnode/

# Download the appropriate scripts
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/makerun.sh
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/checkdaemon.sh
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/upgrade.sh
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/clearlog.sh

# Create a cronjob for making sure smartcashd runs after reboot
if ! crontab -l | grep "@reboot smartcashd"; then
  (crontab -l ; echo "@reboot smartcashd") | crontab -
fi

# Create a cronjob for making sure smartcashd is always running
if ! crontab -l | grep "~/smartnode/makerun.sh"; then
  (crontab -l ; echo "*/5 * * * * ~/smartnode/makerun.sh") | crontab -
fi

# Create a cronjob for making sure the daemon is never stuck
if ! crontab -l | grep "~/smartnode/checkdaemon.sh"; then
  (crontab -l ; echo "*/30 * * * * ~/smartnode/checkdaemon.sh") | crontab -
fi

# Create a cronjob for making sure smartcashd is always up-to-date
if ! crontab -l | grep "~/smartnode/upgrade.sh"; then
  (crontab -l ; echo "0 0 */1 * * ~/smartnode/upgrade.sh") | crontab -
fi

# Create a cronjob for clearing the log file
if ! crontab -l | grep "~/smartnode/clearlog.sh"; then
  (crontab -l ; echo "0 0 */2 * * ~/smartnode/clearlog.sh") | crontab -
fi

# Give execute permission to the cron scripts
chmod 0700 ./makerun.sh
chmod 0700 ./checkdaemon.sh
chmod 0700 ./upgrade.sh
chmod 0700 ./clearlog.sh


