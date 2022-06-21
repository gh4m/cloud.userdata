#!/bin/bash

##
## wireguard setup
##

echo USERDATA_RUNNING $0 ${*}

WG_CLIENT_PUB_KEY=$1
WG_CLIENT_IP=$2
WC_CLIENT_SHARE_FILE=/etc/wireguard/sharekey.$(dirname ${WG_CLIENT_IP})

cd /etc/wireguard/
umask 077 && wg genpsk > ${WC_CLIENT_SHARE_FILE}

cat << EOF >> /etc/wireguard/wg0.conf
[Peer]
PublicKey = ${WG_CLIENT_PUB_KEY}
PresharedKey = $(cat ${WC_CLIENT_SHARE_FILE})
AllowedIPs = ${WG_CLIENT_IP}

EOF
