#!/bin/bash

##
## ufw - wireguard + dnsproxy
##

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

ufw --force reset
ufw --force enable
ufw logging low
ufw default allow routed
ufw allow proto tcp from ${HOME_FQDN_IP_ADDR}/32 to any port ssh
ufw status verbose

## setup files for homeip cron script
echo "${HOME_FQDN_IP_ADDR}/32" > /var/tmp/home_cidr_previous_file.txt
echo "${HOME_FQDN_IP_ADDR}" > /var/tmp/home__ip__previous_file.txt
