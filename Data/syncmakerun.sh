#!/bin/bash

if ps aux | egrep '[dotnet] SAPI.Sync.dll' > /dev/null
then
  echo "exit"
  exit
else
  echo "run"
  cd ~/SAPI/Sync/
  dotnet SAPI.Sync.dll &
fi
