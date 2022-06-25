#!/bin/bash
set -eu

##
## wireguard-config-wg0-interface-as-cloudvpn-server.sh
##

set +u
! test -z "${WG_CLOUDVPN_SERVER_HOSTNAME}" || WG_CLOUDVPN_SERVER_HOSTNAME=$(hostname | awk -F. '{print $1}')
set -u
WG_CLOUDVPN_CLIENT_HOSTNAME=${WG_CLOUDVPN_SERVER_HOSTNAME} ## cloud VPN client hostname is same as the cloud VPN server hostname

WG_CLOUDVPN_SERVER_DEVICE_NAME=wg0
WG_CLOUDVPN_SERVER_DEVICE_CONFIG_FILE=/etc/wireguard/${WG_CLOUDVPN_SERVER_DEVICE_NAME}.conf
WG_CLOUDVPN_INTERNET_DEVICE_NAME=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

read -p "Configuring ${WG_CLOUDVPN_SERVER_DEVICE_CONFIG_FILE}. Will overwrite if exists. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

## go to config file dir
test -d /etc/wireguard/config || mkdir /etc/wireguard/config
cd /etc/wireguard/config

## source server config file
WG_CLOUDVPN_SERVER_CONFIG_FILE=/etc/wireguard/config/${WG_CLOUDVPN_SERVER_HOSTNAME}-server
test -f ${WG_CLOUDVPN_SERVER_CONFIG_FILE} || wget -O ${WG_CLOUDVPN_SERVER_HOSTNAME}-server https://raw.githubusercontent.com/gh4m/cloud.userdata.scripts/main/config/${WG_CLOUDVPN_SERVER_HOSTNAME}-server
. ${WG_CLOUDVPN_SERVER_CONFIG_FILE}

## source this host client config file
WG_CLOUDVPN_CLIENT_CONFIG_FILE=/etc/wireguard/config/${WG_CLOUDVPN_CLIENT_HOSTNAME}-client
test -f ${WG_CLOUDVPN_CLIENT_CONFIG_FILE} || wget -O ${WG_CLOUDVPN_CLIENT_HOSTNAME}-client https://raw.githubusercontent.com/gh4m/cloud.userdata.scripts/main/config/${WG_CLOUDVPN_CLIENT_HOSTNAME}-client
. ${WG_CLOUDVPN_CLIENT_CONFIG_FILE}

! test -z "${WG_CLOUDVPN_SERVER_LISTEN_PORT}"  || (echo "ERROR: WG_CLOUDVPN_SERVER_LISTEN_PORT  is not set" && exit 5)
! test -z "${WG_CLOUDVPN_SERVER_NETWORK_BASE}" || (echo "ERROR: WG_CLOUDVPN_SERVER_NETWORK_BASE is not set" && exit 5)
! test -z "${WG_CLOUDVPN_SERVER_NETWORK_MASK}" || (echo "ERROR: WG_CLOUDVPN_SERVER_NETWORK_MASK is not set" && exit 5)
! test -z "${WG_CLOUDVPN_SERVER_CLIENT_LIST}"  || (echo "ERROR: WG_CLOUDVPN_SERVER_CLIENT_LIST  is not set" && exit 5)
! test -z "${WG_CLOUDVPN_SERVER_IP_END}"       || (echo "ERROR: WG_CLOUDVPN_SERVER_IP_END       is not set" && exit 5)

WG_CLOUDVPN_SERVER_IP_ADDR=${WG_CLOUDVPN_SERVER_NETWORK_BASE}.${WG_CLOUDVPN_SERVER_IP_END}
WG_CLOUDVPN_SERVER_IP_CIDR=${WG_CLOUDVPN_SERVER_IP_ADDR}/${WG_CLOUDVPN_SERVER_NETWORK_MASK}
WG_CLOUDVPN_SERVER_NETWORK_CIDR=${WG_CLOUDVPN_SERVER_NETWORK_BASE}.0/${WG_CLOUDVPN_SERVER_NETWORK_MASK}
WG_CLOUDVPN_SERVER_PRIVATE_KEY_FILE=/etc/wireguard/privatekey-${WG_CLOUDVPN_SERVER_DEVICE_NAME}

## check files
test -f ${WG_CLOUDVPN_SERVER_PRIVATE_KEY_FILE} || (echo "ERROR: file ${WG_CLOUDVPN_SERVER_PRIVATE_KEY_FILE} does not exist" && exit 5)
WG_CLOUDVPN_SERVER_PRIVATE_KEY=$(cat ${WG_CLOUDVPN_SERVER_PRIVATE_KEY_FILE})

## bring down wireguard interface
if [[ -f ${WG_CLOUDVPN_SERVER_DEVICE_CONFIG_FILE} ]]
then
  wg-quick down ${WG_CLOUDVPN_SERVER_DEVICE_NAME} || echo "${WG_CLOUDVPN_SERVER_DEVICE_NAME} is already down"
fi

cd /etc/wireguard/

cat << EOF > ${WG_CLOUDVPN_SERVER_DEVICE_CONFIG_FILE}
[Interface]
Address = ${WG_CLOUDVPN_SERVER_IP_CIDR}
PrivateKey = ${WG_CLOUDVPN_SERVER_PRIVATE_KEY}
ListenPort = ${WG_CLOUDVPN_SERVER_LISTEN_PORT}
PostUp   = iptables -A FORWARD -i ${WG_CLOUDVPN_SERVER_DEVICE_NAME} -j ACCEPT
PostUp   = iptables -A FORWARD -o ${WG_CLOUDVPN_SERVER_DEVICE_NAME} -j ACCEPT
PostDown = iptables -D FORWARD -i ${WG_CLOUDVPN_SERVER_DEVICE_NAME} -j ACCEPT
PostDown = iptables -D FORWARD -o ${WG_CLOUDVPN_SERVER_DEVICE_NAME} -j ACCEPT
PostUp   = iptables -t nat -A POSTROUTING -s ${WG_CLOUDVPN_SERVER_NETWORK_CIDR} -o ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s ${WG_CLOUDVPN_SERVER_NETWORK_CIDR} -o ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} -j MASQUERADE

EOF

## loop through setup each cloud client peer
for WG_CLOUDVPN_SERVER_CLIENT in ${WG_CLOUDVPN_SERVER_CLIENT_LIST}
do
  ## source this host client config file
  WG_CLOUDVPN_SERVER_CLIENT_CONFIG_FILE=/etc/wireguard/config/${WG_CLOUDVPN_SERVER_CLIENT}-client
  test -f ${WG_CLOUDVPN_SERVER_CLIENT_CONFIG_FILE} || (echo "ERROR: file ${WG_CLOUDVPN_SERVER_CLIENT_CONFIG_FILE} does not exist" && exit 5)
  . ${WG_CLOUDVPN_SERVER_CLIENT_CONFIG_FILE}
  WG_CLOUDVPN_SERVER_CLIENT_IP_ADDR=${WG_CLOUDVPN_SERVER_NETWORK_BASE}.${WG_CLOUDVPN_CLIENT_IP_END}
  WG_CLOUDVPN_SERVER_CLIENT_IP_CIDR=${WG_CLOUDVPN_SERVER_CLIENT_IP_ADDR}/32
  WG_CLOUDVPN_SERVER_CLIENT_PUBLIC_KEY=${WG_CLOUDVPN_CLIENT_PUBLIC_KEY}
  WG_CLOUDVPN_SERVER_CLIENT_PRESHARE_KEY_FILE=/etc/wireguard/sharekey-cloudvpn-${WG_CLOUDVPN_SERVER_CLIENT_IP_ADDR}
  ## if preshare key not exist, create one
  if [[ ! -f ${WG_CLOUDVPN_SERVER_CLIENT_PRESHARE_KEY_FILE} ]]
  then
    umask 077 && wg genpsk > ${WG_CLOUDVPN_SERVER_CLIENT_PRESHARE_KEY_FILE}
  fi
  WG_CLOUDVPN_SERVER_CLIENT_PRESHARE_KEY=$(cat ${WG_CLOUDVPN_SERVER_CLIENT_PRESHARE_KEY_FILE})
cat << EOF >> ${WG_CLOUDVPN_SERVER_DEVICE_CONFIG_FILE}
[Peer]
PublicKey = ${WG_CLOUDVPN_SERVER_CLIENT_PUBLIC_KEY}
PresharedKey = ${WG_CLOUDVPN_SERVER_CLIENT_PRESHARE_KEY}
AllowedIPs = ${WG_CLOUDVPN_SERVER_CLIENT_IP_CIDR}

EOF

done

## bring up wireguard interface (except on initial setup launch)
set +u
! test -z "${WG_SKIP_UP}" || wg-quick up ${WG_CLOUDVPN_SERVER_DEVICE_NAME}
set -u
