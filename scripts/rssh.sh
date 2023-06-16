#!/bin/bash

host_name=`hostname`
nu=${#host_name}
/usr/bin/screen  -dmS rSSH bash -c "ssh -R 598$nu:localhost:22 rescue"