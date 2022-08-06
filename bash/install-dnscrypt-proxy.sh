#!/bin/bash

##
## dnscrypt setup
##

## setup as last in cloud userdata

DNSCRYPT_PROXY_VER=2.1.1  ## https://github.com/DNSCrypt/dnscrypt-proxy/releases/latest
DNSCRYPT_PROXY_PATH=/opt/dnscrypt-proxy
DNSCRYPT_PROXY_TOML_FILE_NAME=dnscrypt-proxy.toml
DNSCRYPT_PROXY_TOML_FILE_PATH=${DNSCRYPT_PROXY_PATH}/${DNSCRYPT_PROXY_TOML_FILE_NAME}

mkdir ${DNSCRYPT_PROXY_PATH}
cd ${DNSCRYPT_PROXY_PATH}
wget https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/${DNSCRYPT_PROXY_VER}/dnscrypt-proxy-linux_x86_64-${DNSCRYPT_PROXY_VER}.tar.gz
wget https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/utils/generate-domains-blocklist/generate-domains-blocklist.py

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
sed -i "/netprobe_address =/c\netprobe_address = '8.8.8.8:53'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
## set bootstrap 
sed -i "/bootstrap_resolvers =/c\bootstrap_resolvers = ['8.8.8.8:53','1.1.1.1:53']" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
## prevent bootstrap from user queries
sed -i "/disabled_server_names =/c\disabled_server_names = ['google', 'google-ipv6','cloudflare','cloudflare-ipv6']" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
## random pick from upper half
sed -i "/lb_strategy =/c\lb_strategy = 'ph'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/cache_min_ttl =/c\cache_min_ttl = 1800" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/cache_max_ttl =/c\cache_max_ttl = 3600" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/cache_neg_min_ttl =/c\cache_neg_min_ttl = 15" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
sed -i "/cache_neg_min_ttl =/c\cache_neg_min_ttl = 120" ${DNSCRYPT_PROXY_TOML_FILE_PATH}

if [ "${WG_CLOUDVPN_WGS1_DNSCRYPT_PROXY_BLOCKING}" == "YES" ]
then
  DNSCRYPT_PROXY_BLOCKLIST_SCRIPT=${DNSCRYPT_PROXY_PATH}/generate-domains-blocklist.py
  DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF=${DNSCRYPT_PROXY_PATH}/domains-blocklist.conf
  DNSCRYPT_PROXY_BLOCKED_NAMES_CONF=${DNSCRYPT_PROXY_PATH}/blocked-names.txt
  DNSCRYPT_PROXY_ALLOWED_NAMES_CONF=${DNSCRYPT_PROXY_PATH}/allowed-names.txt
  DNSCRYPT_PROXY_TIME_RESTRICTED_CONF=${DNSCRYPT_PROXY_PATH}/domains-time-restricted.txt
  touch ${DNSCRYPT_PROXY_TIME_RESTRICTED_CONF}
  DNSCRYPT_PROXY_ALLOW_LIST_CONF=${DNSCRYPT_PROXY_PATH}/domains-allowlist.txt
  touch ${DNSCRYPT_PROXY_ALLOW_LIST_CONF}
  echo "https://dblw.oisd.nl/" > ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF}
  echo "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >> ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF}
  echo "spot.im" > ${DNSCRYPT_PROXY_ALLOWED_NAMES_CONF}
  sed -i "/blocked_names_file =/c\blocked_names_file = 'blocked-names.txt'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
  sed -i "/log_file = 'blocked-names.log'/c\log_file = 'blocked-names.log'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
  sed -i "/allowed_names_file = 'allowed-names.txt'/c\allowed_names_file = 'allowed-names.txt'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
  sed -i "/log_file = 'allowed-names.log'/c\log_file = 'allowed-names.log'" ${DNSCRYPT_PROXY_TOML_FILE_PATH}
  ## For automated background updates, the script can be run as a cron job
  DNSCRYPT_PROXY_BLOCKLIST_RUNCMD="python3 ${DNSCRYPT_PROXY_BLOCKLIST_SCRIPT} -c ${DNSCRYPT_PROXY_BLOCKLIST_DOMAIN_CONF} -o ${DNSCRYPT_PROXY_BLOCKED_NAMES_CONF} -r ${DNSCRYPT_PROXY_TIME_RESTRICTED_CONF} -a ${DNSCRYPT_PROXY_ALLOW_LIST_CONF}"
  set +e
  (crontab -l 2>/dev/null; echo "25 4 * * * ${DNSCRYPT_PROXY_BLOCKLIST_RUNCMD}") | crontab -
  (crontab -l 2>/dev/null; echo "30 4 * * * systemctl restart dnscrypt-proxy.service") | crontab -
  set -e
  ## setup DNSCRYPT_PROXY_BLOCKED_NAMES_CONF before reboot
  ${DNSCRYPT_PROXY_BLOCKLIST_RUNCMD}
fi

systemctl stop systemd-resolved
systemctl disable systemd-resolved

/bin/rm -f /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf
echo "options edns0" >> /etc/resolv.conf

./dnscrypt-proxy -service install
systemctl stop dnscrypt-proxy.service
systemctl enable dnscrypt-proxy.service
