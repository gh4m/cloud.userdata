#!/bin/bash
set -eux
# -x needed for seeing error lines causing RTNETLINK answers: File exists errors

##
## wireguard-postupdown.sh ## run this script instead of wg-quick up ##
##

WG_POST_UPDOWN_ERR_MSG="two arguments required. 1st must be [cloud]. 2nd must be [up|down]"
set +u
WG_POST_UPDOWN_TYPE=$1
WG_POST_UPDOWN_ACTION=$2
! test -z "${WG_POST_UPDOWN_TYPE}"   || (echo "${WG_POST_UPDOWN_ERR_MSG}" && exit 5)
! test -z "${WG_POST_UPDOWN_ACTION}" || (echo "${WG_POST_UPDOWN_ERR_MSG}" && exit 5)
set -u
if [[ "$#" -ne 2 ]]; then
	echo "${WG_POST_UPDOWN_ERR_MSG}"
fi
if echo ${WG_POST_UPDOWN_TYPE} | egrep -v '^cloud$' > /dev/null
then
    echo "${WG_POST_UPDOWN_ERR_MSG}"
    exit 5
fi
if echo ${WG_POST_UPDOWN_ACTION} | egrep -v '^up$|^down$' > /dev/null
then
    echo "${WG_POST_UPDOWN_ERR_MSG}"
    exit 5
fi
echo "WG_POST_UPDOWN_TYPE=${WG_POST_UPDOWN_TYPE}"
echo "WG_POST_UPDOWN_ACTION=${WG_POST_UPDOWN_ACTION}"

## check which firewall
FW_IS_UWF="true"
FW_IS_FIREWALLD="true"
systemctl status ufw 2> /dev/null > /dev/null || FW_IS_UWF="false"
systemctl status firewalld 2> /dev/null > /dev/null || FW_IS_FIREWALLD="false"
echo "FW_IS_UWF=${FW_IS_UWF}"
echo "FW_IS_FIREWALLD=${FW_IS_FIREWALLD}"

## source config data
WG_POST_UPDOWN_CONFIG_FILE=/etc/wireguard/config/wireguard-postupdown.config.${WG_POST_UPDOWN_TYPE}
test -f ${WG_POST_UPDOWN_CONFIG_FILE} || (echo "ERROR: file ${WG_POST_UPDOWN_CONFIG_FILE} does not exist" && exit 5)
. ${WG_POST_UPDOWN_CONFIG_FILE}

## set up/down flags
if [[ "${WG_POST_UPDOWN_ACTION}" == "up" ]]
then
	IPTABLE_ACTION_FLAG="-A"
	FIREWALLD_RULE_ACTION="--add-rule"
	FIREWALLD_PORT_ACTION="--add-port"
else
	IPTABLE_ACTION_FLAG="-D"
	FIREWALLD_RULE_ACTION="--remove-rule"
	FIREWALLD_PORT_ACTION="--remove-port"
fi

if [[ "${WG_POST_UPDOWN_TYPE}" == "cloud" ]]
then

	## check for needed config vars
	set +u
	! test -z "${WG_CLOUDVPN_WGS1_NET_CIDR}"    || (echo "ERROR: WG_CLOUDVPN_WGS1_NET_CIDR    is not set" && exit 5)
	! test -z "${WG_CLOUDVPN_WGS1_LISTEN_PORT}" || (echo "ERROR: WG_CLOUDVPN_WGS1_LISTEN_PORT is not set" && exit 5)
	! test -z "${WG_CLOUDVPN_ETH0_DEVICE_NAME}" || (echo "ERROR: WG_CLOUDVPN_ETH0_DEVICE_NAME is not set" && exit 5)
	set -u

	##
	## iptables firewall setup
	##

	if [[ "${FW_IS_FIREWALLD}" == "true" ]]
	then
		echo "ERROR: Server firewalld commands not setup"
		exit 6
	fi

	if [[ "${FW_IS_UWF}" == "true" ]]
	then

		ufw --force reset
		ufw --force enable
		ufw logging low

		if [[ "${WG_POST_UPDOWN_ACTION}" == "up" ]]
		then
			ufw default allow routed
			## inbound rules
			ufw allow proto tcp from ${WG_CLOUDVPN_WGS1_NET_CIDR} to any port domain
			ufw allow proto udp from ${WG_CLOUDVPN_WGS1_NET_CIDR} to any port domain
			ufw allow proto tcp from ${WG_CLOUDVPN_WGS1_NET_CIDR} to any port ssh
			ufw allow ${WG_CLOUDVPN_WGS1_LISTEN_PORT}/udp
			## outbound rules
			ufw allow out on ${WG_CLOUDVPN_ETH0_DEVICE_NAME} to 8.8.8.8 port 53   proto any ## dnscrypt bootstrap_resolver
			ufw allow out on ${WG_CLOUDVPN_ETH0_DEVICE_NAME} to 1.1.1.1 port 53   proto any ## dnscrypt bootstrap_resolver
			ufw deny  out on ${WG_CLOUDVPN_ETH0_DEVICE_NAME} to any     port 53   proto any
			ufw deny  out on ${WG_CLOUDVPN_ETH0_DEVICE_NAME} to any     port 853  proto any
			ufw deny  out on ${WG_CLOUDVPN_ETH0_DEVICE_NAME} to any     port 5353 proto any
			ufw deny  out on ${WG_CLOUDVPN_ETH0_DEVICE_NAME} to any     port 5355 proto any
		fi

		## allow in ssh regardless of wg up or down
		ufw allow proto tcp from 0.0.0.0/0 to any port ssh
		## setup files for homeip adjust cron script
		rm -f /var/tmp/home_cidr_previous_file.txt
		rm -f /var/tmp/home__ip__previous_file.txt

		## list fw
		ufw status verbose

	fi

	##
	## iptables routing setup
	##

	WG_CLOUDVPN_ETH0_IP_ADDR=$(ip ad show dev ${WG_CLOUDVPN_ETH0_DEVICE_NAME} | grep "inet " | awk '{print $2}' | awk -F/ '{print $1}')
	
	## packet in (source) from WG_CLOUDVPN_WGS1_NET_CIDR out through WG_CLOUDVPN_ETH0_DEVICE_NAME normal network to anywhere (no -d argument)
	iptables -t nat ${IPTABLE_ACTION_FLAG} POSTROUTING -s ${WG_CLOUDVPN_WGS1_NET_CIDR} -o ${WG_CLOUDVPN_ETH0_DEVICE_NAME} -j SNAT --to-source ${WG_CLOUDVPN_ETH0_IP_ADDR}
	
fi
