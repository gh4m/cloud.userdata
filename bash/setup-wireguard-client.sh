#!/bin/bash

##
## wireguard setup
##

echo USERDATA_RUNNING $0 ${*}

WG_CLIENT_PUBLIC_KEY=$1
WG_CLIENT_VPN_CIDR=$2
WC_CLIENT_SHAREKEY_FILE=/etc/wireguard/sharekey.$(dirname ${WG_CLIENT_VPN_CIDR})

if grep "${WG_CLIENT_PUBLIC_KEY}" /etc/wireguard/wg0.conf > /dev/null
then
  echo "ERROR: client is already setup. manually remove if want to re-setup"
  exit 6
fi

cd /etc/wireguard/
umask 077 && wg genpsk > ${WC_CLIENT_SHAREKEY_FILE}

cat << EOF >> /etc/wireguard/wg0.conf
[Peer]
PublicKey = ${WG_CLIENT_PUBLIC_KEY}
PresharedKey = $(cat ${WC_CLIENT_SHAREKEY_FILE})
AllowedIPs = ${WG_CLIENT_VPN_CIDR}

EOF
