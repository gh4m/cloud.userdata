#!/bin/bash

##
## wireguard setup
##

echo USERDATA_RUNNING $0 ${*}

wg > /dev/null 2> /dev/null || $APT_GET_CMD install wireguard

WG_SERVER_VPN_CIDR=$1
WG_NETWORK_VPN_CIDR=$2
RANDOM_TWO_DIGITS=$((1 + $RANDOM % 9))$((1 + $RANDOM % 9))
WG_SERVER_PORT=518${RANDOM_TWO_DIGITS}
WG_SERVER_NIC_NAME=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

cd /etc/wireguard/
umask 077 && wg genkey | tee privatekey | wg pubkey > publickey

cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = ${WG_SERVER_VPN_CIDR}
PrivateKey = $(cat /etc/wireguard/privatekey)
ListenPort = ${WG_SERVER_PORT}
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -s ${WG_NETWORK_VPN_CIDR} -o ${WG_SERVER_NIC_NAME} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -s ${WG_NETWORK_VPN_CIDR} -o ${WG_SERVER_NIC_NAME} -j MASQUERADE

EOF

systemctl enable wg-quick@wg0.service
