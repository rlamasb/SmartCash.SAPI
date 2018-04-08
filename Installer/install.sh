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
    if [ ${REPLY} == "Y" ] || [ ${REPLY} == "y" ]; then
      # Kill SAPI crontab, processes and delete folders for reinstall
      if [ -d ~/SAPI ]; then
        (crontab -l | grep -v "~/SAPI/API/apimakerun.sh") | crontab -
        (crontab -l | grep -v "~/SAPI/Sync/syncmakerun.sh") | crontab -
        (crontab -l | grep -v "~/SAPI/Mssql/mssqlmakerun.sh") | crontab -
        (crontab -l | grep -v "~/SAPI/nginx/nginxmakerun.sh") | crontab -
        (crontab -l | grep -v "reboot systemctl start mssql-server") | crontab -
        pIDAPI=$(ps -ef | grep "dotnet SAPI.API.dll" | awk '{print $2}')
        pIDSync=$(ps -ef | grep "dotnet SAPI.Sync.dll" | awk '{print $2}')
        kill ${pIDAPI}
        kill ${pIDSync}
        service nginx stop
        systemctl stop mssql-server
        rm -rf ~/SAPI/
        rm -rf /smartdata/
      fi

      pID=$(ps -ef | grep smartcashd | awk '{print $2}')
      kill ${pID}
      rm -rf ~/.smartcash/
      break
    else
      if [ ${REPLY} == "N" ] || [ ${REPLY} == "n" ]; then
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

# Get the IP address of your vps which will be hosting the smartnode
_nodeIpAddress=$(ip route get 1 | awk '{print $NF;exit}')

cd
# Changing the SSH Port to a custom number is a good security measure against DDOS attacks
printf "Custom SSH Port(Enter to ignore): "
read VARIABLE
_sshPortNumber=${VARIABLE:-22}

# Get a new privatekey by going to console >> debug and typing smartnode genkey
printf "SmartNode GenKey: "
read _nodePrivateKey

# Ask if wants to install Transaction API
printf "Do you wish to install and run Transaction API (Y/n)? "
read API
if [ "$API" = "Y" ] || [ "$API" = "y" ]; then
  # Get domain name for Lets Encrypt script
  echo "LetsEncrypt SSL certbot is used to generate a SSL certificate for your domain"
  printf "Enter API domain name without www prefix (ex: smartcashapi.cc): "
  read DOMAIN
  if [ "$(getent hosts $DOMAIN | awk '{ print $1 }')" != "$_nodeIpAddress" ]; then
    echo "DNS A Record for $DOMAIN must set to your server IP address $_nodeIpAddress"
    exit 1
  fi
  if [ "$(getent hosts www.$DOMAIN | awk '{ print $1 }')" != "$_nodeIpAddress" ]; then
    echo "DNS A Record for www.$DOMAIN must set to your server IP address $_nodeIpAddress"
    exit 1
  fi

  # Get email address for Lets Encrypt script
  printf "Enter email for SSL registration (recommended) or press Enter to continue without email: "
  read EMAIL
  if [ -z $EMAIL ]; then
    :
  else
    if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
      :
    else
      echo "Email address $EMAIL is invalid"
      exit 1
    fi
  fi
fi

# The RPC node will only accept connections from your localhost
_rpcUserName=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12 ; echo '')

# Choose a random and secure password for the RPC
_rpcPassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')

# Make a new directory for smartcash daemon
mkdir ~/.smartcash/

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
maxconnections=12
txindex=1
smartnode=1
externalip=${_nodeIpAddress}:9678
smartnodeprivkey=${_nodePrivateKey}
" > smartcash.conf

# Download bootstrap
wget https://smartcash.cc/txindexstrap.zip
apt-get install unzip -y
unzip -o txindexstrap.zip

cd

# Install smartcashd using apt-get
apt-get update -y
apt-get install software-properties-common -y
add-apt-repository ppa:smartcash/ppa -y && apt update -y && apt install smartcashd -y && smartcashd

# Create a directory for smartnode's cronjobs and the anti-ddos script
rm -r ~/smartnode/
mkdir ~/smartnode/

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

# Create a cronjob to keep smartcashd cpu usage below 40%
if ! crontab -l | grep "cpulimit -P /usr/bin/smartcashd"; then
  (crontab -l ; echo "@reboot cpulimit -P /usr/bin/smartcashd -l 40") | crontab -
fi

# Create a cronjob to keep mssql-server cpu usage below 40%
if ! crontab -l | grep "cpulimit -P /lib/systemd/system/mssql-server.service"; then
  (crontab -l ; echo "@reboot cpulimit -P /lib/systemd/system/mssql-server.service -l 40") | crontab -
fi

# Give execute permission to the cron scripts
chmod 0700 ./makerun.sh
chmod 0700 ./checkdaemon.sh
chmod 0700 ./upgrade.sh
chmod 0700 ./clearlog.sh

# Change the SSH port
sed -i "s/[#]\{0,1\}[ ]\{0,1\}Port [0-9]\{2,\}/Port ${_sshPortNumber}/g" /etc/ssh/sshd_config

# Firewall security measures
apt install ufw -y
ufw disable
ufw allow 9678
ufw allow 80
ufw allow "$_sshPortNumber"/tcp
ufw limit "$_sshPortNumber"/tcp
ufw logging on
ufw default deny incoming
ufw default allow outgoing

if [ "$API" = "Y" ] || [ "$API" = "y" ]; then
  ## Run Transaction API installer script
  cd
  wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Installer/install-sapi.sh
  bash install-sapi.sh $_rpcUserName $_rpcPassword $DOMAIN $EMAIL
else
  # Enable firewall
  ufw --force enable

  # Reboot the server
  reboot
fi
