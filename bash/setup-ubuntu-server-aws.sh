#!/bin/bash

##
## ubuntu AWS server basic setup
##

echo USERDATA_RUNNING $0 ${*}

apt-get -y update
apt-get -y dist-upgrade
apt-get -y autoremove

SERVER___HOSTNAME=$1
SERVER_DOMAINNAME=$2
SERVER_PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
SERVER__LOCAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
NAMESERVER_IP=169.254.169.123

sed -i "/listen_addresses =/c\ListenAddress 0.0.0.0" /etc/ssh/sshd_config

hostnamectl set-hostname ${SERVER___HOSTNAME}.${SERVER_DOMAINNAME}
echo "${SERVER__LOCAL_IP} ${SERVER___HOSTNAME}.${SERVER_DOMAINNAME}" >> /etc/hosts

timedatectl set-timezone America/New_York
timedatectl

sed -i "/pool ntp.ubuntu.com/c\server ${NAMESERVER_IP} prefer iburst minpoll 4 maxpoll 4" /etc/chrony/chrony.conf
sed -i "/pool /c\#" /etc/chrony/chrony.conf
systemctl restart chrony
