#!/bin/bash

##
## ufw - wireguard + dnsproxy
##

echo USERDATA_RUNNING $0 ${*}

WG_NETWORK_VPN_CIDR=$1
WG_SERVER_PORT=$2
WG_SERVER_NIC_NAME=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

ufw --force reset
ufw --force enable
ufw logging low
ufw default allow routed
ufw allow proto tcp from ${WG_NETWORK_VPN_CIDR} to any port domain
ufw allow proto udp from ${WG_NETWORK_VPN_CIDR} to any port domain
ufw allow proto tcp from 0.0.0.0/0 to any port ssh
ufw allow ${WG_SERVER_PORT}/udp
ufw allow out on ${WG_SERVER_NIC_NAME} to 8.8.8.8 port 53 proto any
ufw allow out on ${WG_SERVER_NIC_NAME} to 1.1.1.1 port 53 proto any
ufw deny out on ${WG_SERVER_NIC_NAME} to any port 53 proto any
ufw deny out on ${WG_SERVER_NIC_NAME} to any port 853 proto any
ufw deny out on ${WG_SERVER_NIC_NAME} to any port 5353 proto any
ufw status verbose
