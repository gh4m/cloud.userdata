#!/bin/bash
set -eu

##
## wireguard-config-wgs1-interface-as-cloudvpn-server.sh
##

set +u
! test -z "${WG_CLOUDVPN_WGS1_HOSTNAME}" || WG_CLOUDVPN_WGS1_HOSTNAME=$(hostname | awk -F. '{print $1}')
set -u
## LOCALVPN WGC0 hostname (the vpn server on local network) 
## is same as the hostname for the CLOUDVPN WGS1 (on VPS cloud provider)
## the DOMAIN_NAME differs local vs cloud
WG_LOCALVPN_WGC0_HOSTNAME=${WG_CLOUDVPN_WGS1_HOSTNAME}

WG_CLOUDVPN_WGS1_DEVICE_NAME=wgs1
WG_CLOUDVPN_WGS1_CONFIG_FILE=/etc/wireguard/${WG_CLOUDVPN_WGS1_DEVICE_NAME}.conf
WG_CLOUDVPN_ETH0_DEVICE_NAME=$(ip route | grep -v " wg[a-z][0-9]" | grep ^default | awk '{print $5}')

read -p "Configuring ${WG_CLOUDVPN_WGS1_CONFIG_FILE}. Will overwrite if exists. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

## go to config file dir
test -d /etc/wireguard/config || mkdir /etc/wireguard/config
cd /etc/wireguard/config

## userdata directory (the VPS launch userdata script hardcodes USERDATA_* var & path, keep in sync)
USERDATA_PATH=/root/userdata
USERDATA_BASH=${USERDATA_PATH}/bash
USERDATA_CONFIG=${USERDATA_PATH}/config

## source the server's variable file
WG_CLOUDVPN_WGS1_VARIABLE_FILE=/etc/wireguard/config/${WG_CLOUDVPN_WGS1_HOSTNAME}-server
## get latest from USERDATA_CONFIG
cp -f ${USERDATA_CONFIG}/${WG_CLOUDVPN_WGS1_HOSTNAME}-server ${WG_CLOUDVPN_WGS1_VARIABLE_FILE}
. ${WG_CLOUDVPN_WGS1_VARIABLE_FILE}

## source the client's variable file
WG_LOCALVPN_WGC0_VARIABLE_FILE=/etc/wireguard/config/${WG_LOCALVPN_WGC0_HOSTNAME}-client
## get latest from USERDATA_CONFIG
cp -f ${USERDATA_CONFIG}/${WG_LOCALVPN_WGC0_HOSTNAME}-client ${WG_LOCALVPN_WGC0_VARIABLE_FILE}
. ${WG_LOCALVPN_WGC0_VARIABLE_FILE}

## test for vars set by config files
set +u
! test -z "${WG_CLOUDVPN_WGS1_LISTEN_PORT}" || (echo "ERROR: WG_CLOUDVPN_WGS1_LISTEN_PORT is not set" && exit 5)
! test -z "${WG_CLOUDVPN_WGS1_NET_BASE}"    || (echo "ERROR: WG_CLOUDVPN_WGS1_NET_BASE    is not set" && exit 5)
! test -z "${WG_CLOUDVPN_WGS1_NET_MASK}"    || (echo "ERROR: WG_CLOUDVPN_WGS1_NET_MASK    is not set" && exit 5)
! test -z "${WG_CLOUDVPN_WGS1_IP_END}"      || (echo "ERROR: WG_CLOUDVPN_WGS1_IP_END      is not set" && exit 5)
! test -z "${WG_CLOUDVPN_WGS1_CLIENT_LIST}" || (echo "ERROR: WG_CLOUDVPN_WGS1_CLIENT_LIST is not set" && exit 5)
set -u

## bring down wireguard interface
if [[ -f ${WG_CLOUDVPN_WGS1_CONFIG_FILE} ]]
then
  wg-quick down ${WG_CLOUDVPN_WGS1_DEVICE_NAME} || echo "${WG_CLOUDVPN_WGS1_DEVICE_NAME} is already down"
fi

## set vars for script
WG_CLOUDVPN_WGS1_IP_ADDR=${WG_CLOUDVPN_WGS1_NET_BASE}.${WG_CLOUDVPN_WGS1_IP_END}
WG_CLOUDVPN_WGS1_IP_CIDR=${WG_CLOUDVPN_WGS1_IP_ADDR}/32
WG_CLOUDVPN_WGS1_NET_CIDR=${WG_CLOUDVPN_WGS1_NET_BASE}.0/${WG_CLOUDVPN_WGS1_NET_MASK}
WG_CLOUDVPN_WGS1_PRIVATE_KEY_FILE=/etc/wireguard/privatekey-${WG_CLOUDVPN_WGS1_DEVICE_NAME}

## check files
test -f ${WG_CLOUDVPN_WGS1_PRIVATE_KEY_FILE} || (echo "ERROR: file ${WG_CLOUDVPN_WGS1_PRIVATE_KEY_FILE} does not exist" && exit 5)
WG_CLOUDVPN_WGS1_PRIVATE_KEY=$(cat ${WG_CLOUDVPN_WGS1_PRIVATE_KEY_FILE})

cd /etc/wireguard/

WG_POST_UPDOWN_TYPE=cloud
WG_POST_UPDOWN_CONFIG_FILE=/etc/wireguard/config/wireguard-postupdown.config.${WG_POST_UPDOWN_TYPE}
WG_POST_UPDOWN_CONFIG_SCRIPT=/etc/wireguard/config/wireguard-postupdown.sh
## get latest from USERDATA_CONFIG
cp ${USERDATA_CONFIG}/wireguard-postupdown.sh ${WG_POST_UPDOWN_CONFIG_SCRIPT}
rm -f ${WG_POST_UPDOWN_CONFIG_FILE}
echo "WG_CLOUDVPN_WGS1_NET_CIDR=$WG_CLOUDVPN_WGS1_NET_CIDR" >> ${WG_POST_UPDOWN_CONFIG_FILE}
echo "WG_CLOUDVPN_WGS1_LISTEN_PORT=$WG_CLOUDVPN_WGS1_LISTEN_PORT" >> ${WG_POST_UPDOWN_CONFIG_FILE}
echo "WG_CLOUDVPN_ETH0_DEVICE_NAME=$WG_CLOUDVPN_ETH0_DEVICE_NAME" >> ${WG_POST_UPDOWN_CONFIG_FILE}

cat << EOF > ${WG_CLOUDVPN_WGS1_CONFIG_FILE}
[Interface]
Address = ${WG_CLOUDVPN_WGS1_IP_CIDR}
PrivateKey = ${WG_CLOUDVPN_WGS1_PRIVATE_KEY}
ListenPort = ${WG_CLOUDVPN_WGS1_LISTEN_PORT}
PostUp   = ${WG_POST_UPDOWN_CONFIG_SCRIPT} ${WG_POST_UPDOWN_TYPE} up
PostDown = ${WG_POST_UPDOWN_CONFIG_SCRIPT} ${WG_POST_UPDOWN_TYPE} down

EOF

## loop through setup each cloud client peer (CLOUDVPN will only have one)
for WG_CLOUDVPN_WGS1_CLIENT in ${WG_CLOUDVPN_WGS1_CLIENT_LIST}
do
  ## source this host client config file
  WG_CLOUDVPN_WGS1_CLIENT_VARIABLE_FILE=/etc/wireguard/config/${WG_CLOUDVPN_WGS1_CLIENT}-client
  test -f ${WG_CLOUDVPN_WGS1_CLIENT_VARIABLE_FILE} || (echo "ERROR: file ${WG_CLOUDVPN_WGS1_CLIENT_VARIABLE_FILE} does not exist" && exit 5)
  . ${WG_CLOUDVPN_WGS1_CLIENT_VARIABLE_FILE}
  WG_CLOUDVPN_WGS1_CLIENT_IP_ADDR=${WG_CLOUDVPN_WGS1_NET_BASE}.${WG_CLOUDVPN_WGS1_CLIENT_IP_END}
  WG_CLOUDVPN_WGS1_CLIENT_IP_CIDR=${WG_CLOUDVPN_WGS1_CLIENT_IP_ADDR}/32
  WG_CLOUDVPN_WGS1_CLIENT_PUBLIC_KEY=${WG_CLOUDVPN_WGS1_CLIENT_PUBLIC_KEY}
  WG_CLOUDVPN_WGS1_CLIENT_PRESHARE_KEY_FILE=/etc/wireguard/sharekey-cloudvpn-${WG_CLOUDVPN_WGS1_CLIENT_IP_ADDR}
  ## if preshare key not exist, create one
  if [[ ! -f ${WG_CLOUDVPN_WGS1_CLIENT_PRESHARE_KEY_FILE} ]]
  then
    umask 077 && wg genpsk > ${WG_CLOUDVPN_WGS1_CLIENT_PRESHARE_KEY_FILE}
  fi
  WG_CLOUDVPN_WGS1_CLIENT_PRESHARE_KEY=$(cat ${WG_CLOUDVPN_WGS1_CLIENT_PRESHARE_KEY_FILE})
cat << EOF >> ${WG_CLOUDVPN_WGS1_CONFIG_FILE}
[Peer]
PublicKey = ${WG_CLOUDVPN_WGS1_CLIENT_PUBLIC_KEY}
PresharedKey = ${WG_CLOUDVPN_WGS1_CLIENT_PRESHARE_KEY}
AllowedIPs = ${WG_CLOUDVPN_WGS1_CLIENT_IP_CIDR}

EOF

done

## bring up wireguard interface (except on the initial VPS launch)
set +u
! test -z "${WG_QUICKUP_SKIP}" || wg-quick up ${WG_CLOUDVPN_WGS1_DEVICE_NAME}
set -u
