#!/bin/bash -e

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit -1
fi

########################### DB INSTALL ######################################################
echo "$(tput setaf 3) Start installing Data Base $(tput sgr 0)"

# Use the following variables to control your install:


# The RPC node will only accept connections from your localhost
_rpcUserName=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12 ; echo '')

# Choose a random and secure password for the RPC
_rpcPassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')

# Choose a random and secure password for db user
MSSQL_SA_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')


cd ~/
mkdir SAPI
cd SAPI
mkdir Sync
cd Sync
wget http://smartcashstorage.blob.core.windows.net/temp/AppSync.zip

touch ~/SAPI/Sync/appsettings.json

echo "{
  \"SyncDb\": \"${MSSQL_SA_PASSWORD}\",
  \"rpcuser\": \"${_rpcUserName}\",
  \"rpcpass\": \"${_rpcPassword}\"
}" > ~/SAPI/Sync/appsettings.json

# Product ID of the version of SQL server you're installing
# Must be evaluation, developer, express, web, standard, enterprise, or your 25 digit product key
# Defaults to developer
MSSQL_PID='express'

# Install SQL Server Agent (recommended)
SQL_INSTALL_AGENT='y'

# Install SQL Server Full Text Search (optional)
# SQL_INSTALL_FULLTEXT='y'

# Create an additional user with sysadmin privileges (optional)
# SQL_INSTALL_USER='<Username>'
# SQL_INSTALL_USER_PASSWORD='<YourStrong!Passw0rd>'

if [ -z $MSSQL_SA_PASSWORD ]
then
  echo "Environment variable MSSQL_SA_PASSWORD must be set for unattended install"
  exit 1
fi

echo "Adding Microsoft repositories..."
sudo curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2017.list)"
sudo add-apt-repository "${repoargs}"
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list)"
sudo add-apt-repository "${repoargs}"

echo Running apt-get update -y...
sudo apt-get update -y

echo Installing SQL Server...
sudo apt-get install -y mssql-server

echo Running mssql-conf setup...
sudo MSSQL_SA_PASSWORD=$MSSQL_SA_PASSWORD \
     MSSQL_PID=$MSSQL_PID \
     /opt/mssql/bin/mssql-conf -n setup accept-eula

echo Installing mssql-tools and unixODBC developer...
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

# Add SQL Server tools to the path by default:
echo Adding SQL Server tools to your path...
echo PATH="$PATH:/opt/mssql-tools/bin" >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

# Configure firewall to allow TCP port 1433:
echo "Configuring UFW to allow traffic on port 1433..."
sudo ufw allow 1433/tcp
sudo ufw reload

# Optional example of post-installation configuration.
# Trace flags 1204 and 1222 are for deadlock tracing.
# echo Setting trace flags...
# sudo /opt/mssql/bin/mssql-conf traceflag 1204 1222 on

# Restart SQL Server after installing:
echo "Restarting SQL Server..."
sudo systemctl restart mssql-server

# Connect to server and get the version:
counter=1
errstatus=1
while [ $counter -le 5 ] && [ $errstatus = 1 ]
do
  echo "Waiting for SQL Server to start..."
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U SA \
    -P $MSSQL_SA_PASSWORD \
    -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

# Display error if connection failed:
if [ $errstatus = 1 ]
then
  echo Cannot connect to SQL Server, installation aborted
  exit $errstatus
fi

#Prepare files

mkdir /smartdata

cd /smartdata

apt install unzip

wget http://smartcashstorage.blob.core.windows.net/temp/smartdata.zip

wget http://smartcashstorage.blob.core.windows.net/temp/script.sql

unzip -o -d /smartdata /smartdata/smartdata.zip 

cd /smartdata

chmod a+rxw /smartdata/

chmod a+rxw /smartdata/data/

/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -i 'script.sql'

echo -e "${GREEM}Done Installing Data Base!${NC}"

echo "$(tput setaf 2) Done Installing Data Base $(tput sgr 0)"
########################### DB INSTALL ######################################################

echo "..."
########################### WALLET INSTALL ##################################################
echo "$(tput setaf 3) Start installing Wallet $(tput sgr 0)"

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
#echo "WARNING: This script will reboot the server when it's finished."
#printf "Press Ctrl+C to cancel or Enter to continue: "
#read IGNORE

cd

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
unzip -o txindexstrap.zip

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

#Sync wallet
counter=1
blocktotal=$(curl -s https://explorer3.smartcash.cc/api/getblockcount)
echo $blocktotal
re='^[0-9]+$'
while [ $counter -le 60 ]
do
	currentblock=$(smartcash-cli getblockcount) 

	if ! [[ $currentblock =~ $re ]] ; then
		echo $currentblock
	else
		if [ $currentblock -ge $blocktotal ];
		then
		    counter=61
		fi;

		echo "Waiting for wallet to sync..."
		echo "$currentblock" of "$blocktotal" blocks

	fi

	sleep 30s
  
  
  ((counter++))
done

echo "$(tput setaf 2) Done syncing blocks $(tput sgr 0)"

#Install .NET Core for Ubuntu
echo "Install .NET Core for Ubuntu"

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list'
sudo apt-get update

sudo apt-get install -y dotnet-sdk-2.1.4

dotnet --version

cd

cd SAPI/Sync/

unzip AppSync.zip


wget http://smartcashstorage.blob.core.windows.net/temp/syncmakerun.sh

# Create a cronjob for making sure smartcashd is always running
if ! crontab -l | grep "~/SAPI/Sync/syncmakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/Sync/syncmakerun.sh") | crontab -
fi

chmod 0700 ~/SAPI/Sync/syncmakerun.sh


dotnet SAPI.Sync.dll &

echo "$(tput setaf 2) Done Installing Wallet and Sync Service $(tput sgr 0)"
########################### WALLET INSTALL ##################################################

echo "..."
########################### API INSTALL ##################################################
echo "$(tput setaf 3) Start installing Api Service $(tput sgr 0)"

cd 
cd SAPI
mkdir API
cd API

wget http://smartcashstorage.blob.core.windows.net/temp/AppApi.zip

unzip AppApi.zip

echo "
{
  \"SyncDb\": \"${MSSQL_SA_PASSWORD}\",
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
}" > ~/SAPI/API/appsettings.json



sudo apt install -y apache2
sudo apt install -y sysfsutils
#Setup reverse proxy.
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_balancer
sudo a2enmod lbmethod_byrequests
sudo systemctl restart apache2
 
 

echo "
<VirtualHost *:80>
ProxyPreserveHost On
ProxyRequests Off
ServerName sapi.smartcash.cc
ServerAlias sapi.smartcash.cc
DocumentRoot /SAPI/API
ProxyPass / http://localhost:5000/
ProxyPassReverse / http://localhost:5000/
</VirtualHost>
" > /etc/apache2/sites-enabled/000-default.conf

cd
cd SAPI/API
dotnet SAPI.API.dll &

echo "$(tput setaf 2) Done Installing Api Service $(tput sgr 0)"
########################### API INSTALL ##################################################


