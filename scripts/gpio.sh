#!/bin/bash

h=`hostname`

while true
do
  res=`raspi-gpio get 17 | awk -F " " '{print $3}' | awk -F "=" '{print $2}'`
  if [ $res == "1" ]
  then
    /home/pi/curl.sh $h 2>&1
    sleep 0.5
  fi
sleep 0.1
done
