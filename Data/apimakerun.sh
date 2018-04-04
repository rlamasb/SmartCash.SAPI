#!/bin/bash

if ps aux | egrep '[dotnet] SAPI.API.dll' > /dev/null
then
  exit
else
  cd
  cd ~/SAPI/API/
  dotnet SAPI.API.dll &
fi
