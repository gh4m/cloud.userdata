#!/bin/bash

##
## ufw - wireguard + dnsproxy
##

WG_NET_BLOCK=$1
WG_SERVER_PORT=$2

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

ufw --force reset && \
ufw --force enable && \
ufw default allow routed && \
ufw allow proto tcp from ${WG_NET_BLOCK} to any port domain && \
ufw allow proto udp from ${WG_NET_BLOCK} to any port domain && \
ufw allow proto tcp from 0.0.0.0/0 to any port ssh && \
ufw allow proto udp from 0.0.0.0/0 to any port ${WG_SERVER_PORT} && \
ufw status verbose
