#!/bin/bash
# update-sapi.sh
# Updates Transaction API on Ubuntu 16.04 LTS x64

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit -1
fi

if ! [ -d ~/SAPI/API ]; then
  echo "SAPI must be installed in your server"
fi

# Kill SAPI crontab, processes and delete folders for update
(crontab -l | grep -v "~/SAPI/API/apimakerun.sh") | crontab -
(crontab -l | grep -v "~/SAPI/Sync/syncmakerun.sh") | crontab -
pIDAPI=$(ps -ef | grep "dotnet SAPI.API.dll" | awk '{print $2}')
pIDSync=$(ps -ef | grep "dotnet SAPI.Sync.dll" | awk '{print $2}')
kill ${pIDAPI}
kill ${pIDSync}

# Update App API
cd ~/SAPI/API
mv appsettings.json ../
rm -rf *
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/AppAPI.zip
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/apimakerun.sh
unzip -o AppAPI.zip
mv ../appsettings.json .

# Update App Sync
cd ~/SAPI/Sync
mv appsettings.json ../
rm -rf *
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/AppSync.zip
wget https://raw.githubusercontent.com/rlamasb/SmartCash.SAPI/master/Data/syncmakerun.sh
unzip -o AppSync.zip
mv ../appsettings.json .

# Create a cronjob for making sure web api is always running
if ! crontab -l | grep "~/SAPI/API/apimakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/API/apimakerun.sh") | crontab -
fi

# Create a cronjob for making sure syncmakerun is always running
if ! crontab -l | grep "~/SAPI/Sync/syncmakerun.sh"; then
  (crontab -l ; echo "* * * * * ~/SAPI/Sync/syncmakerun.sh") | crontab -
  (crontab -l ; echo "* * * * * sleep 30 && ~/SAPI/Sync/syncmakerun.sh") | crontab -
fi

# Give execute permission to the cron scripts
chmod 0700 ~/SAPI/API/apimakerun.sh
chmod 0700 ~/SAPI/Sync/syncmakerun.sh

# Run API and Sync
bash ~/SAPI/API/apimakerun.sh
bash ~/SAPI/Sync/syncmakerun.sh