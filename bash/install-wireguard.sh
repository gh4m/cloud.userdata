#!/bin/bash

##
## wireguard setup
##

echo calling $0 ${*}

apt-get -y install wireguard

WG_SERVER_IP=$1
WG_NET_BLOCK=$2
WG_CLIENT_PUB_KEY=$3
WG_CLIENT_IP=$4
RANDOM_TWO_DIGITS=$((1 + $RANDOM % 9))$((1 + $RANDOM % 9))
WG_SERVER_PORT=518${RANDOM_TWO_DIGITS}
WG_SERVER_NIC_NAME=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

cd /etc/wireguard/
umask 077 && wg genkey | tee privatekey | wg pubkey > publickey
umask 077 && wg genpsk > sharekey

cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = ${WG_SERVER_IP}
PrivateKey = $(cat /etc/wireguard/privatekey)
ListenPort = ${WG_SERVER_PORT}
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -s ${WG_NET_BLOCK} -o ${WG_SERVER_NIC_NAME} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -s ${WG_NET_BLOCK} -o ${WG_SERVER_NIC_NAME} -j MASQUERADE

[Peer]
PublicKey = ${WG_CLIENT_PUB_KEY}
PresharedKey = $(cat /etc/wireguard/sharekey)
AllowedIPs = ${WG_CLIENT_IP}
EOF

systemctl enable wg-quick@wg0.service
