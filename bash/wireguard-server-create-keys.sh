#!/bin/bash

##
## wireguard server key setup
##

cd /etc/wireguard/
rm -f privatekey publickey
umask 077 && wg genkey | tee privatekey | wg pubkey > publickey
