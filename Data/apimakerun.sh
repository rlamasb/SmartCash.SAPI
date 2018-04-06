#!/bin/bash

if ps aux | egrep '[dotnet] SAPI.API.dll' > /dev/null
then
  exit
else
  cd ~/SAPI/API/
  dotnet SAPI.API.dll > /dev/null 2>&1 & disown
fi