#!/bin/bash
set -eu

##
## wireguard wgc0 key setup
##

WG_CLOUDVPN_WGS1_DEVICE_NAME=wgs1

read -p "Creating new wireguard public/private keys for ${WG_CLOUDVPN_WGS1_DEVICE_NAME}. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

cd /etc/wireguard/
rm -f privatekey-${WG_CLOUDVPN_WGS1_DEVICE_NAME} publickey-${WG_CLOUDVPN_WGS1_DEVICE_NAME}
umask 077 && wg genkey | tee privatekey-${WG_CLOUDVPN_WGS1_DEVICE_NAME} | wg pubkey > publickey-${WG_CLOUDVPN_WGS1_DEVICE_NAME}
