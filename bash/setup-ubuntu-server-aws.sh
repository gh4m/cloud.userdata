#!/bin/bash

##
## ubuntu AWS server basic setup
##

snap list | grep ^amazon-ssm-agent && snap remove amazon-ssm-agent

APT_DPKG_VAR="DEBIAN_FRONTEND=noninteractive"
APT_DPKG_OPT="-o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\""
APT_GET_CMD="eval $APT_DPKG_VAR apt-get -y $APT_DPKG_OPT"

$APT_GET_CMD update
$APT_GET_CMD dist-upgrade
$APT_GET_CMD autoremove

WG_CLOUDVPN_WGS1_FQDN=${WG_CLOUDVPN_WGS1_HOSTNAME}.${WG_CLOUDVPN_WGS1_DOMAIN_NAME}
WG_CLOUDVPN_PUBL_IP_ADDR=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
WG_CLOUDVPN_PRIV_IP_ADDR=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
WG_CLOUDVPN_ETH0_DNS_IP_ADDR=169.254.169.123

## sshd on ipv4 only
sed -i "/ListenAddress 0.0.0.0/c\ListenAddress 0.0.0.0" /etc/ssh/sshd_config

## hostname setup
hostnamectl set-hostname ${WG_CLOUDVPN_WGS1_FQDN}
echo "${WG_CLOUDVPN_PRIV_IP_ADDR} ${WG_CLOUDVPN_WGS1_FQDN}" >> /etc/hosts
## home host setup
WG_HOMEFIOS_PUBL_IP_ADDR=$(dig +short ${WG_HOMEFIOS_ETH0_FQDN} | tail -n1 | grep -E -o "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$")
echo "${WG_HOMEFIOS_PUBL_IP_ADDR} ${WG_HOMEFIOS_ETH0_FQDN}" >> /etc/hosts

timedatectl set-timezone America/New_York

sed -i "/pool ntp.ubuntu.com/c\server ${WG_CLOUDVPN_ETH0_DNS_IP_ADDR} prefer iburst minpoll 4 maxpoll 4" /etc/chrony/chrony.conf
sed -i "/pool /c\#" /etc/chrony/chrony.conf
systemctl restart chrony
