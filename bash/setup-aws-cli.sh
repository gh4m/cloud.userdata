#!/bin/bash

##
## instal aws cli
##

echo USERDATA_RUNNING $0 ${*}

$APT_GET_CMD -qq update
dpkg -s unzip   &> /dev/null || $APT_GET_CMD install unzip
uname -a | grep x86_64  && ( ls awscliv2.zip &> /dev/null || curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" )
uname -a | grep aarch64 && ( ls awscliv2.zip &> /dev/null || curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" )
ls -d ./aws/    &> /dev/null || unzip awscliv2.zip
aws --version   &> /dev/null || ./aws/install
