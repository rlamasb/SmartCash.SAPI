#!/bin/bash

if ps aux | egrep '[dotnet] SAPI.Sync.dll' > /dev/null
then
  exit
else
  cd ~/SAPI/Sync/
  dotnet SAPI.Sync.dll > /dev/null 2>&1 & disown
fi