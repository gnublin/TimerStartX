#!/bin/bash

host_name=`hostname`
nu=${#host_name}

already=`ps faux | grep "[ssh] -R" | grep -v SCREEN | wc -l`

if [ $already -gt 1 ]
then
	echo "${date} - already monted"
else
	/usr/bin/screen  -dmS rSSH bash -c "ssh -R 598$nu:localhost:22 rescue"
	sleep 10
fi
