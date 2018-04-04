#!/bin/bash
# install-sapi.sh
# Installs Transaction API on Ubuntu 16.04 LTS x64

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit -1
fi

# Choose a random and secure password for db user
_sqlPassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')

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

# Install Nginx and LetsEncrypt CertBot
apt-get install nginx -y
add-apt-repository ppa:certbot/certbot -y
apt-get update -y
apt-get install python-certbot-nginx -y

# Make a new directory for API
mkdir -p ~/SAPI/API

# Change the directory to ~/SAPI/API
cd ~/SAPI/API

# Download App API
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/AppAPI.zip
unzip -o AppAPI.zip

# Create API appsettings.json
echo "
{
  \"SyncDb\": \"${_sqlPassword}\",
  \"rpcuser\": \"${1}\",
  \"rpcpass\": \"${2}\",
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

# Download App Sync
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/AppSync.zip
unzip -o AppSync.zip

# Create Sync appsettings.json
echo "{
  \"SyncDb\": \"${_sqlPassword}\",
  \"rpcuser\": \"${1}\",
  \"rpcpass\": \"${2}\"
}" > appsettings.json

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

# Download Sync script
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/syncmakerun.sh

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
while [ $counter -le 60 ]
do
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

# Run Sync
cd ~/SAPI/Sync/
dotnet SAPI.Sync.dll &

# Run API
cd ~/SAPI/API/
dotnet SAPI.API.dll &

# Create a cronjob for making sure web api is always running
if ! crontab -l | grep "~/SAPI/API/apimakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/API/apimakerun.sh") | crontab -
fi

# Create a cronjob for making sure syncmakerun is always running
if ! crontab -l | grep "~/SAPI/Sync/syncmakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/Sync/syncmakerun.sh") | crontab -
fi

# Give execute permission to the cron scripts
chmod 0700 ~/SAPI/API/apimakerun.sh
chmod 0700 ~/SAPI/Sync/syncmakerun.sh

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
		proxy_set_header Connection 'upgrade';
		proxy_set_header Host \$http_host;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_redirect off;
	}
}" > default

# Configure LetsEncrypt SSL
service nginx restart
sed -i -e "s/server_name _/server_name $3 www.$3/g" default
if [ -z $4 ]; then
  certbot --nginx --agree-tos --non-interactive --redirect --staple-ocsp --register-unsafely-without-email -d "$3" -d www."$3"
else
  certbot --nginx --agree-tos --non-interactive --redirect --staple-ocsp -m "$4" --no-eff-email -d "$3" -d www."$3"
fi
service nginx restart

# Allow HTTPS traffic (443)
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Reboot the server
reboot