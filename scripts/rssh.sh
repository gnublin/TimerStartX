#!/bin/bash

host_name=`hostname`
nu=${#host_name}


while true
do
  already=`ps faux | grep "[ssh] -R" | grep -v SCREEN | wc -l`
  
  process=`ps -ef | grep -v grep | grep SCREEN`
  screen_pid=$(echo $process | awk '{print $2}')
  
  already=${#process}
  if [ $already -ge 1 ]
  then
    echo "$(date) - already monted - pid $screen_pid"
  else
    /usr/bin/screen  -dmS rSSH bash -c "ssh -R 598$nu:localhost:22 debian@ks02.openux.org"
  fi
  sleep 10
done

