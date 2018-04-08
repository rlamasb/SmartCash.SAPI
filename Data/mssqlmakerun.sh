#!/bin/bash

if ps -A | grep sqlservr > /dev/null
then
  exit
else
  systemctl start mssql-server > /dev/null 2>&1 & disown
fi
