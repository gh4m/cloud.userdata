#!/bin/bash

##
## ubuntu AWS server basic setup
##

echo USERDATA_RUNNING $0 ${*}

snap list | grep ^amazon-ssm-agent && snap remove amazon-ssm-agent

APT_DPKG_VAR="DEBIAN_FRONTEND=noninteractive"
APT_DPKG_OPT="-o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\""
APT_GET_CMD="eval $APT_DPKG_VAR apt-get -y $APT_DPKG_OPT"

$APT_GET_CMD update
$APT_GET_CMD dist-upgrade
$APT_GET_CMD autoremove

WG_SERVER_HOSTNAME=$1
WG_SERVER_DOMAIN=$2
HOME_FQDN=$3
WG_SERVER_FQDN=${WG_SERVER_HOSTNAME}.${WG_SERVER_DOMAIN}
WG_SERVER_PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
WG_SERVER_LOCAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
NAMESERVER_IP=169.254.169.123

## sshd on ipv4 only
sed -i "/ListenAddress 0.0.0.0/c\ListenAddress 0.0.0.0" /etc/ssh/sshd_config

## hostname setup
hostnamectl set-hostname ${WG_SERVER_FQDN}
echo "${WG_SERVER_LOCAL_IP} ${WG_SERVER_FQDN}" >> /etc/hosts

timedatectl set-timezone America/New_York
timedatectl

sed -i "/pool ntp.ubuntu.com/c\server ${NAMESERVER_IP} prefer iburst minpoll 4 maxpoll 4" /etc/chrony/chrony.conf
sed -i "/pool /c\#" /etc/chrony/chrony.conf
systemctl restart chrony

## setup reconfig script for home ip change
SERVER_RECONFIG_SCRIPTNAME=reconfigue-ufw-homeip-change.sh
SERVER_RECONFIG_SCRIPTPATH=${DOWNLOAD_PATH}/${SERVER_RECONFIG_SCRIPTNAME}
wget -O ${SERVER_RECONFIG_SCRIPTPATH} https://raw.githubusercontent.com/gh4m/cloud.userdata/main/bash/${SERVER_RECONFIG_SCRIPTNAME}
chmod +x ${SERVER_RECONFIG_SCRIPTPATH}
set +e
(crontab -l 2>/dev/null; echo "3-59/4 * * * * ${SERVER_RECONFIG_SCRIPTPATH} ${HOME_FQDN}") | crontab -
crontab -l
set -e
