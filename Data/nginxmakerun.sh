#!/bin/bash

if ps -A | grep nginx > /dev/null
then
  exit
else
  service nginx start > /dev/null 2>&1 & disown
fi
