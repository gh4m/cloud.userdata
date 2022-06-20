#!/bin/bash

##
## dnscrypt setup
##

## setup as last in cloud userdata

echo USERDATA_RUNNING $0 ${*}

SET_AD_BLOCKING=$1
DNSCRYPT_PROXY_VER=2.1.1  ## https://github.com/DNSCrypt/dnscrypt-proxy/releases/latest
DNSCRYPT_PROXY_PATH=/opt/dnscrypt-proxy
DNSCRYPT_PROXY_TOML_FILE_NAME=dnscrypt-proxy.toml
DNSCRYPT_PROXY_TOML_FILE_PATH=${DNSCRYPT_PROXY_PATH}/${DNSCRYPT_PROXY_TOML_FILE_NAME}

mkdir ${DNSCRYPT_PROXY_PATH}
cd ${DNSCRYPT_PROXY_PATH}
wget https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/${DNSCRYPT_PROXY_VER}/dnscrypt-proxy-linux_x86_64-${DNSCRYPT_PROXY_VER}.tar.gz

systemctl stop systemd-resolved
systemctl disable systemd-resolved

echo "nameserver 127.0.0.1" > /etc/resolv.conf
echo "options edns0" >> /etc/resolv.conf

tar xvf dnscrypt-proxy-linux_x86_64-${DNSCRYPT_PROXY_VER}.tar.gz
mv linux-x86_64/* .
rmdir linux-x86_64/

cp ${DNSCRYPT_PROXY_PATH}/example-${DNSCRYPT_PROXY_TOML_FILE_NAME} ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/listen_addresses = \['127.0.0.1:53'\]/c\listen_addresses = \['0.0.0.0:53'\]" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/require_dnssec =/c\require_dnssec = true" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/log_level = 2/c\log_level = 2" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/file = 'query.log'/c\file = 'query.log'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/file = 'nx.log'/c\file = 'nx.log'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/log_file = 'dnscrypt-proxy.log'/c\log_file = 'dnscrypt-proxy.log'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}

if [ "${SET_AD_BLOCKING}" == "YES" ]
then
  DNSCRYPT_PROXY_BLOCKLIST_SCRIPT=${DNSCRYPT_PROXY_PATH}/generate-domains-blocklist.py
  DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF=${DNSCRYPT_PROXY_PATH}/domains-blocklist.conf
  cp ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF} ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF}.orig
  echo "https://dblw.oisd.nl/" > ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF}
  echo "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >> ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF}
  ## For automated background updates, the script can be run as a cron job
  (crontab -l 2>/dev/null; echo "25 4 * * * python3 ${DNSCRYPT_PROXY_BLOCKLIST_SCRIPT} -c ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF} -o ${DNSCRYPT_PROXY_PATH}/blocked-names.txt") | crontab -
  sed -i "/blocked_names_file =/c\blocked_names_file = 'blocked-names.txt'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
  sed -i "/log_file = 'blocked-names.log'/c\log_file = 'blocked-names.log'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
fi

./dnscrypt-proxy -service install
systemctl enable dnscrypt-proxy.service
systemctl stop dnscrypt-proxy.service
