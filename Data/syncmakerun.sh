#!/bin/bash

if ps -A | grep SAPI.Sync.dll > /dev/null
then
  exit
else
  cd
  cd SAPI/Sync/
  dotnet SAPI.Sync.dll &
fi
