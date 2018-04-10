#!/bin/bash
# install.sh
# Installs SmartNode and Transaction API on Ubuntu 16.04 LTS x64

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit -1
fi

# Remove past installation
while true; do
  if [ -d ~/.smartcash ]; then
    printf "SmartCash and SAPI already exist! The installer will delete the previous installation. Continue anyway? (Y/[n])"
    read REPLY
    if [ ${REPLY} == "Y" ] || [ ${REPLY} == "y" ]; then
      # Kill SAPI crontab, processes and delete folders for reinstall
      if [ -d ~/SAPI ]; then
        (crontab -l | grep -v "cpulimit -P /lib/systemd/system/mssql-server.service") | crontab -
        (crontab -l | grep -v "reboot systemctl start mssql-server") | crontab -
        (crontab -l | grep -v "~/SAPI/API/apimakerun.sh") | crontab -
        (crontab -l | grep -v "~/SAPI/Sync/syncmakerun.sh") | crontab -
        (crontab -l | grep -v "~/SAPI/Mssql/mssqlmakerun.sh") | crontab -
        (crontab -l | grep -v "~/SAPI/nginx/nginxmakerun.sh") | crontab -
        pIDAPI=$(ps -ef | grep "dotnet SAPI.API.dll" | awk '{print $2}')
        pIDSync=$(ps -ef | grep "dotnet SAPI.Sync.dll" | awk '{print $2}')
        kill ${pIDAPI}
        kill ${pIDSync}
        service nginx stop
        systemctl stop mssql-server
        rm -rf ~/SAPI/
        rm -rf /smartdata/
      fi

      (crontab -l | grep -v "cpulimit -P /usr/bin/smartcashd") | crontab -
      (crontab -l | grep -v "reboot smartcashd") | crontab -
      (crontab -l | grep -v "~/smartnode/makerun.sh") | crontab -
      (crontab -l | grep -v "~/smartnode/checkdaemon.sh") | crontab -
      (crontab -l | grep -v "~/smartnode/upgrade.sh") | crontab -
      (crontab -l | grep -v "~/smartnode/clearlog.sh") | crontab -
      pID=$(ps -ef | grep smartcashd | awk '{print $2}')
      kill ${pID}
      rm -rf ~/.smartcash/
      rm -rf ~/smartnode/
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

# Changing the SSH Port to a custom number is a good security measure against DDOS attacks
_currentPort=${SSH_CLIENT##* }
printf "Change SSH Port (Press Enter to keep current port $_currentPort): "
read VARIABLE
_sshPortNumber=${VARIABLE:-$_currentPort}
if ! [ "$_sshPortNumber" -ge 0 -a "$_sshPortNumber" -le 65535 ]; then
  echo "SSH Port $_sshPortNumber is invalid"
  exit 1
fi

# Get a new privatekey by going to console >> debug and typing smartnode genkey
printf "SmartNode GenKey: "
read _nodePrivateKey
if ! [[ "$_nodePrivateKey" =~ ^7[QRS][1-9A-HJ-NP-Za-km-z]{49}$ ]]; then
  echo "SmartNode GenKey $_nodePrivateKey is invalid"
  exit 1
fi

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
if ! [ -z $EMAIL ]; then
  if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
    echo "Email address $EMAIL is invalid"
    exit 1
  fi
fi

# Change the SSH port
sed -i "s/[#]\{0,1\}[ ]\{0,1\}Port [0-9]\{2,\}/Port ${_sshPortNumber}/g" /etc/ssh/sshd_config

# Firewall security measures
apt install ufw -y
ufw disable
ufw --force reset
ufw allow 9678
ufw allow "$_sshPortNumber"/tcp
ufw limit "$_sshPortNumber"/tcp
ufw logging on
ufw default deny incoming
ufw default allow outgoing

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

# Install SQL Server
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2017.list)"
add-apt-repository "${repoargs}"
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list)"
add-apt-repository "${repoargs}"
apt-get update -y
apt-get install mssql-server -y
ACCEPT_EULA=Y apt-get install mssql-tools unixodbc-dev -y

# Install .NET Core
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list'
apt-get update
apt-get install dotnet-sdk-2.1.4 -y

# Install python module need to ssl verification
apt-get install python-pyasn1 python-pyasn1-modules

# Install Nginx and LetsEncrypt CertBot
apt-get install nginx -y
add-apt-repository ppa:certbot/certbot -y
apt-get update -y
apt-get install python-certbot-nginx -y

# Create a directory for smartnode's cronjobs and the anti-ddos script
mkdir ~/smartnode/

# Change the directory to ~/smartnode/
cd ~/smartnode/

# Download the appropriate scripts
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/makerun.sh
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/checkdaemon.sh
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/upgrade.sh
wget https://raw.githubusercontent.com/SmartCash/smartnode/master/clearlog.sh

# Make a new directory for API
mkdir -p ~/SAPI/API

# Change the directory to ~/SAPI/API
cd ~/SAPI/API

# Download App API
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/AppAPI.zip
unzip -o AppAPI.zip

# Choose a random and secure password for db user
_sqlPassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')

# Create API appsettings.json
echo "
{
  \"SyncDb\": \"${_sqlPassword}\",
  \"rpcuser\": \"${_rpcUserName}\",
  \"rpcpass\": \"${_rpcPassword}\",
  \"Logging\": {
    \"IncludeScopes\": false,
    \"Debug\": {
      \"LogLevel\": {
        \"Default\": \"Warning\"
      }
    },
    \"Console\": {
      \"LogLevel\": {
        \"Default\": \"Warning\"
      }
    }
  }
}" > appsettings.json

# Download API script
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/apimakerun.sh

# Make a new directory for SQL sync
mkdir -p ~/SAPI/Sync

# Change the directory to ~/SAPI/Sync
cd ~/SAPI/Sync

# Download Sync script
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/syncmakerun.sh

# Download App Sync
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/AppSync.zip
unzip -o AppSync.zip

# Create Sync appsettings.json
echo "{
  \"SyncDb\": \"${_sqlPassword}\",
  \"rpcuser\": \"${_rpcUserName}\",
  \"rpcpass\": \"${_rpcPassword}\"
}" > appsettings.json

# Make a new directory for Mssql
mkdir -p ~/SAPI/Mssql

# Change the directory to ~/SAPI/Mssql
cd ~/SAPI/Mssql

# Download App Mssql
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/mssqlmakerun.sh

# Make a new directory for nginx
mkdir -p ~/SAPI/nginx

# Change the directory to ~/SAPI/nginx
cd ~/SAPI/nginx

# Download App Nginx
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/nginxmakerun.sh

# Setup SQL
MSSQL_SA_PASSWORD=$_sqlPassword \
  MSSQL_PID='express' \
  /opt/mssql/bin/mssql-conf -n setup accept-eula

# Add SQL Server tools to the path by default
echo PATH="$PATH:/opt/mssql-tools/bin" >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

# Restart SQL Server
systemctl restart mssql-server

# Connect to server and get version
counter=1
errstatus=1
while [ $counter -le 5 ] && [ $errstatus = 1 ]
do
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U SA \
    -P $_sqlPassword \
    -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

# Display error if connection failed
if [ $errstatus = 1 ]; then
  echo "Cannot connect to SQL Server, installation aborted"
  exit 1
fi

# Make a new directory for SQL
mkdir -p /smartdata/data

# Change the directory to ~/SAPI/SQL
cd /smartdata

# Download SQL data and script
wget https://s3.amazonaws.com/smartcash-files/smartdata.zip
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/script.sql
unzip -o smartdata.zip
chmod a+rxw /smartdata
chmod a+rxw /smartdata/data/

# Run SQL data script
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $_sqlPassword -i 'script.sql'

# Complete wallet Sync
counter=1
blocktotal=$(curl -s https://explorer3.smartcash.cc/api/getblockcount)
echo "Total blocks to sync: $blocktotal"
re='^[0-9]+$'
while [ $counter -le 60 ]; do
  currentblock=$(smartcash-cli getblockcount)
  if ! [[ $currentblock =~ $re ]]; then
    echo $currentblock
  else
    if [ $currentblock -ge $blocktotal ]; then
      counter=61
    fi;

    echo "Waiting for wallet to sync..."
    echo "$currentblock" of "$blocktotal" blocks
  fi
  sleep 30s
  ((counter++))
done
echo "Finished syncing blocks"

# Create a cronjob to keep smartcashd cpu usage below 40%
if ! crontab -l | grep "cpulimit -P /usr/bin/smartcashd"; then
  (crontab -l ; echo "@reboot cpulimit -P /usr/bin/smartcashd -l 40") | crontab -
fi

# Create a cronjob to keep mssql-server cpu usage below 40%
if ! crontab -l | grep "cpulimit -P /lib/systemd/system/mssql-server.service"; then
  (crontab -l ; echo "@reboot cpulimit -P /lib/systemd/system/mssql-server.service -l 40") | crontab -
fi

# Create a cronjob for making sure smartcashd runs after reboot
if ! crontab -l | grep "@reboot smartcashd"; then
  (crontab -l ; echo "@reboot smartcashd") | crontab -
fi

# Create a cronjob for making sure mssql-server runs after reboot
if ! crontab -l | grep "@reboot systemctl start mssql-server"; then
  (crontab -l ; echo "@reboot systemctl start mssql-server") | crontab -
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

# Create a cronjob for making sure web api is always running
if ! crontab -l | grep "~/SAPI/API/apimakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/API/apimakerun.sh") | crontab -
fi

# Create a cronjob for making sure syncmakerun is always running
if ! crontab -l | grep "~/SAPI/Sync/syncmakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/Sync/syncmakerun.sh") | crontab -
fi

# Create a cronjob for making sure mssqlmakerun is always running
if ! crontab -l | grep "~/SAPI/Mssql/mssqlmakerun.sh"; then
  (crontab -l ; echo "*/5 * * * * ~/SAPI/Mssql/mssqlmakerun.sh") | crontab -
fi

# Create a cronjob for making sure nginx is always running
if ! crontab -l | grep "~/SAPI/nginx/nginxmakerun.sh"; then
  (crontab -l ; echo "*/5 * * * * ~/SAPI/nginx/nginxmakerun.sh") | crontab -
fi

# Give execute permission to the cron scripts
chmod 0700 ~/smartnode/makerun.sh
chmod 0700 ~/smartnode/checkdaemon.sh
chmod 0700 ~/smartnode/upgrade.sh
chmod 0700 ~/smartnode/clearlog.sh
chmod 0700 ~/SAPI/API/apimakerun.sh
chmod 0700 ~/SAPI/Sync/syncmakerun.sh
chmod 0700 ~/SAPI/Mssql/mssqlmakerun.sh
chmod 0700 ~/SAPI/nginx/nginxmakerun.sh

# Run API, Sync, Mssql and nginx script
bash ~/SAPI/API/apimakerun.sh
bash ~/SAPI/Sync/syncmakerun.sh
bash ~/SAPI/Mssql/mssqlmakerun.sh
bash ~/SAPI/nginx/nginxmakerun.sh

# Configure Nginx
cd /etc/nginx/sites-available
mv default backup-default
echo "##
# Transaction API configuration
##
# IP Request Rate Limit (10 requests per second)
limit_req_zone \$binary_remote_addr zone=one:10m rate=10r/s;
# IP Connections Limit (10 connections)
limit_conn_zone \$binary_remote_addr zone=addr:10m;
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  # Server name to be replaced
  server_name _;
  # Drop slow connections
  client_body_timeout 5s;
  client_header_timeout 5s;
  # Proxy to Transaction API
  location / {
    limit_req zone=one burst=5 nodelay;
    limit_conn addr 10;
    proxy_http_version 1.1;
    proxy_pass http://localhost:5000;
    proxy_pass_header Server;
    proxy_set_header Connection keep-alive';
    proxy_set_header Host \$http_host;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
  }
}" > default

# Configure LetsEncrypt SSL
sed -i -e "s/server_name _/server_name $DOMAIN www.$DOMAIN/g" default
service nginx restart
if [ -z $EMAIL ]; then
  certbot --nginx --agree-tos --non-interactive --redirect --staple-ocsp --register-unsafely-without-email -d "$DOMAIN" -d www."$DOMAIN"
else
  certbot --nginx --agree-tos --non-interactive --redirect --staple-ocsp -m "$EMAIL" --no-eff-email -d "$DOMAIN" -d www."$DOMAIN"
fi
service nginx restart

# Allow HTTPS traffic (443)
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Reboot the server
reboot