#!/bin/bash

##
## wireguard setup
##

echo USERDATA_RUNNING $0 ${*}

WG_CLIENT_PUB_KEY=$1
WG_CLIENT_IP=$2

cd /etc/wireguard/
umask 077 && wg genpsk > sharekey.${WG_CLIENT_IP}

cat << EOF >> /etc/wireguard/wg0.conf
[Peer]
PublicKey = ${WG_CLIENT_PUB_KEY}
PresharedKey = $(cat /etc/wireguard/sharekey.${WG_CLIENT_IP})
AllowedIPs = ${WG_CLIENT_IP}

EOF
