#!/bin/bash
set -eux

##
## AWS EC2 user data script to setup wireguard cloudvpn server (ubuntu 22.04)
##

####----------------------------------------------------------------
####----------------------------------------------------------------
####----------------------------------------------------------------


## select cloudvpn server hostname to configure
## localvpn server hostname will be same (with different domain name)
WG_CLOUDVPN_WGS1_HOSTNAME=

## FQDN to use for finding home isp ip address
WG_HOME_LAN_PUBL_FQDN=

## AWS ACCT SPECIFIC INFO (these vars only used in code below)
AWS_ACCT_ONE_ID=
AWS_ACCT_TWO_ID=
AWS_ACCT_ONE_DOMAIN_NAME=
AWS_ACCT_TWO_DOMAIN_NAME=
AWS_ACCT_ONE_ZONEID_PRIVATE=
AWS_ACCT_TWO_ZONEID_PRIVATE=
AWS_ACCT_ONE_ZONEID_PUBLIC=
AWS_ACCT_TWO_ZONEID_PUBLIC=

####----------------------------------------------------------------
####----------------------------------------------------------------
####----------------------------------------------------------------

## AWS SNS URL
if curl -s http://169.254.169.254/latest/meta-data/iam/info | grep ${AWS_ACCT_ONE_ID} &> /dev/null
then
  AWS_SNS_ARN="arn:aws:sns:us-east-1:${AWS_ACCT_ONE_ID}:SendEmail"
  WG_CLOUDVPN_WGS1_DOMAIN_NAME=${AWS_ACCT_ONE_DOMAIN_NAME}
  AWS_ROUTE53_ZONEID_PRIVATE=${AWS_ACCT_ONE_ZONEID_PRIVATE}
  AWS_ROUTE53_ZONEID_PUBLIC=${AWS_ACCT_ONE_ZONEID_PUBLIC}
fi
if curl -s http://169.254.169.254/latest/meta-data/iam/info | grep ${AWS_ACCT_TWO_ID} &> /dev/null
then
  AWS_SNS_ARN="arn:aws:sns:us-east-1:${AWS_ACCT_TWO_ID}:SendEmail"
  WG_CLOUDVPN_WGS1_DOMAIN_NAME=${AWS_ACCT_TWO_DOMAIN_NAME}
  AWS_ROUTE53_ZONEID_PRIVATE=${AWS_ACCT_TWO_ZONEID_PRIVATE}
  AWS_ROUTE53_ZONEID_PUBLIC=${AWS_ACCT_TWO_ZONEID_PUBLIC}
fi

## userdata directory (other userdata scripts hardcode USERDATA_* var & path, keep in sync)
USERDATA_PATH=/root/userdata
USERDATA_BASH=${USERDATA_PATH}/bash
USERDATA_CONFIG=${USERDATA_PATH}/config
mkdir ${USERDATA_PATH}
git clone https://github.com/gh4m/cloud.userdata.scripts.git ${USERDATA_PATH}

## Downloaded files
SCRIPT_SETUP_OS_NAME=setup-ubuntu-server-aws.sh
SCRIPT_SETUP_OS_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_OS_NAME}
SCRIPT_SETUP_AWSCLI_NAME=setup-aws-cli.sh
SCRIPT_SETUP_AWSCLI_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_AWSCLI_NAME}
SCRIPT_SETUP_DNS_NAME=setup-server-aws-dns.sh
SCRIPT_SETUP_DNS_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_DNS_NAME}
SCRIPT_SETUP_CLOUDVPN_WGS1_CONFIG_NAME=wireguard-config-wgs1-interface-as-cloudvpn-server.sh
SCRIPT_SETUP_CLOUDVPN_WGS1_CONFIG_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_CLOUDVPN_WGS1_CONFIG_NAME}
SCRIPT_SETUP_CLOUDVPN_WGS1_KEYS_NAME=wireguard-config-wgs1-interface-create-new-keys.sh
SCRIPT_SETUP_CLOUDVPN_WGS1_KEYS_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_CLOUDVPN_WGS1_KEYS_NAME}
SCRIPT_GET_OS_FINGERPRINT_NAME=get-server-ssh-fingerprint-aws.sh
SCRIPT_GET_OS_FINGERPRINT_PATH=${USERDATA_BASH}/${SCRIPT_GET_OS_FINGERPRINT_NAME}
SCRIPT_SETUP_DNSCRYPT_PROXY_NAME=install-dnscrypt-proxy.sh
SCRIPT_SETUP_DNSCRYPT_PROXY_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_DNSCRYPT_PROXY_NAME}
SCRIPT_SETUP_FIREWALL_NAME=setup-ubuntu-server-firewall-wireguard.sh
SCRIPT_SETUP_FIREWALL_PATH=${USERDATA_BASH}/${SCRIPT_SETUP_FIREWALL_NAME}
SCRIPT_CRON_FIREWALL_HOMEFIOS_CHANGE_NAME=reconfigue-ufw-homeip-change.sh
SCRIPT_CRON_FIREWALL_HOMEFIOS_CHANGE_PATH=${USERDATA_BASH}/${SCRIPT_CRON_FIREWALL_HOMEFIOS_CHANGE_NAME}

## server basic setup
. ${SCRIPT_SETUP_OS_PATH}

## instal aws cli
. ${SCRIPT_SETUP_AWSCLI_PATH}

## setup aws dns records (script needs args as it will be setup as cron)
. ${SCRIPT_SETUP_DNS_PATH} ${WG_CLOUDVPN_WGS1_HOSTNAME} ${WG_CLOUDVPN_WGS1_DOMAIN_NAME} ${AWS_ROUTE53_ZONEID_PRIVATE} ${AWS_ROUTE53_ZONEID_PUBLIC}

## wireguard server setup (wireguard config & key scripts designed to be run manually)
$APT_GET_CMD install wireguard
. ${SCRIPT_SETUP_CLOUDVPN_WGS1_KEYS_PATH} <<<"y" ## script can be manually run
WG_QUICKUP_SKIP=YES . ${SCRIPT_SETUP_CLOUDVPN_WGS1_CONFIG_PATH} <<<"y" ## script can be manually run
systemctl enable wg-quick@${WG_CLOUDVPN_WGS1_DEVICE_NAME}.service
cp ${SCRIPT_SETUP_CLOUDVPN_WGS1_KEYS_PATH}   /etc/wireguard/ && chmod +x /etc/wireguard/${SCRIPT_SETUP_CLOUDVPN_WGS1_KEYS_NAME}
cp ${SCRIPT_SETUP_CLOUDVPN_WGS1_CONFIG_PATH} /etc/wireguard/ && chmod +x /etc/wireguard/${SCRIPT_SETUP_CLOUDVPN_WGS1_CONFIG_NAME}

## AWS ssh server fingerprint
. ${SCRIPT_GET_OS_FINGERPRINT_PATH}

## dnscrypt-proxy setup
## -- DNS will not work till reboot after running this script -- ##
. ${SCRIPT_SETUP_DNSCRYPT_PROXY_PATH}

## ufw (basic launch firewall setup)
## -- this FW script cannot rely on a working DNS -- ##
. ${SCRIPT_SETUP_FIREWALL_PATH}

## setup crons
## -- add to crontab just before reboot as not run during initial launch -- ##
set +e
(crontab -l 2>/dev/null; echo "*/4 * * * * ${SCRIPT_SETUP_DNS_PATH} ${WG_CLOUDVPN_WGS1_HOSTNAME} ${WG_CLOUDVPN_WGS1_DOMAIN_NAME} ${AWS_ROUTE53_ZONEID_PRIVATE} ${AWS_ROUTE53_ZONEID_PUBLIC}") | crontab -
(crontab -l 2>/dev/null; echo "3-59/4 * * * * ${SCRIPT_CRON_FIREWALL_HOMEFIOS_CHANGE_PATH} ${WG_HOME_LAN_PUBL_FQDN}") | crontab -
set -e

shutdown -r now
