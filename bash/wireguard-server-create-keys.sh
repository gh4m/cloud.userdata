#!/bin/bash

##
## wireguard server key setup
##

read -p "Creating new wireguard keys. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

cd /etc/wireguard/
rm -f privatekey publickey
umask 077 && wg genkey | tee privatekey | wg pubkey > publickey
