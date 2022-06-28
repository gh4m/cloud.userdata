#!/bin/bash
set -eux
# -x needed for seeing lines for RTNETLINK answers: File exists errors

##
## wireguard-postupdown.sh
##

WG_POST_UPDOWN_TYPE_ERR_MSG="two arguments required. 1st must be [cloud]. 2nd must be [up|down]"
set +u
WG_POST_UPDOWN_TYPE=$1
WG_POST_UPDOWN_ACTION=$2
! test -z "${WG_POST_UPDOWN_TYPE}"   || (echo "${WG_POST_UPDOWN_TYPE_ERR_MSG}" && exit 5)
! test -z "${WG_POST_UPDOWN_ACTION}" || (echo "${WG_POST_UPDOWN_TYPE_ERR_MSG}" && exit 5)
set -u
if [[ "$#" -ne 2 ]]; then
	echo "${WG_POST_UPDOWN_TYPE_ERR_MSG}"
fi
if echo ${WG_POST_UPDOWN_TYPE} | egrep -v '^cloud$' > /dev/null
then
    echo "${WG_POST_UPDOWN_TYPE_ERR_MSG}"
    exit 5
fi
if echo ${WG_POST_UPDOWN_ACTION} | egrep -v '^up$|^down$' > /dev/null
then
    echo "${WG_POST_UPDOWN_TYPE_ERR_MSG}"
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
	IPTABLE_ACTION_FLAG="${IPTABLE_ACTION_FLAG}"
	UFW_ACTION=""
	FIREWALLD_RULE_ACTION="--add-rule"
	FIREWALLD_PORT_ACTION="--add-port"
else
	IPTABLE_ACTION_FLAG="${IPTABLE_ACTION_FLAG}"
	UFW_ACTION="delete"
	FIREWALLD_RULE_ACTION="--remove-rule"
	FIREWALLD_PORT_ACTION="--remove-port"
fi

if [[ "${WG_POST_UPDOWN_TYPE}" == "cloud" ]]
then

	## check for needed config vars
	set +u
	! test -z "${WG_CLOUDVPN_SERVER_NETWORK_CIDR}" || (echo "ERROR: WG_CLOUDVPN_SERVER_NETWORK_CIDR is not set" && exit 5)
	! test -z "${WG_CLOUDVPN_SERVER_LISTEN_PORT}" || (echo "ERROR: WG_CLOUDVPN_SERVER_LISTEN_PORT is not set" && exit 5)
	! test -z "${WG_CLOUDVPN_SERVER_DEVICE_NAME}" || (echo "ERROR: WG_CLOUDVPN_SERVER_DEVICE_NAME is not set" && exit 5)
	! test -z "${WG_CLOUDVPN_INTERNET_DEVICE_NAME}" || (echo "ERROR: WG_CLOUDVPN_INTERNET_DEVICE_NAME is not set" && exit 5)
	! test -z "${HOME_FQDN}" || (echo "ERROR: HOME_FQDN is not set" && exit 5)
	set -u

	## home host setup
	HOME_FQDN_IP_ADDR=$(dig +short ${HOME_FQDN} | tail -n1 | grep -E -o "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$")
	echo "${HOME_FQDN_IP_ADDR} ${HOME_FQDN}" >> /etc/hosts

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
		ufw ${UFW_ACTION} --force reset
		ufw ${UFW_ACTION} --force enable
		ufw ${UFW_ACTION} logging low
		ufw ${UFW_ACTION} default allow routed
		ufw ${UFW_ACTION} allow proto tcp from ${WG_CLOUDVPN_SERVER_NETWORK_CIDR} to any port domain
		ufw ${UFW_ACTION} allow proto udp from ${WG_CLOUDVPN_SERVER_NETWORK_CIDR} to any port domain
		ufw ${UFW_ACTION} allow proto tcp from ${WG_CLOUDVPN_SERVER_NETWORK_CIDR} to any port ssh
		ufw ${UFW_ACTION} allow proto tcp from ${HOME_FQDN_IP_ADDR}/32 to any port ssh
		ufw ${UFW_ACTION} allow ${WG_CLOUDVPN_SERVER_LISTEN_PORT}/udp
		ufw ${UFW_ACTION} allow out on ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} to 8.8.8.8 port 53 proto any ## dnscrypt bootstrap_resolver
		ufw ${UFW_ACTION} allow out on ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} to 1.1.1.1 port 53 proto any ## dnscrypt bootstrap_resolver
		ufw ${UFW_ACTION} deny out on ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} to any port 53 proto any
		ufw ${UFW_ACTION} deny out on ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} to any port 853 proto any
		ufw ${UFW_ACTION} deny out on ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} to any port 5353 proto any
		if [[ "${WG_POST_UPDOWN_ACTION}" == "down" ]]
		then
			ufw allow proto tcp from ${HOME_FQDN_IP_ADDR}/32 to any port ssh
		fi
		ufw ${UFW_ACTION} status verbose
		## setup files for homeip cron script
		echo "${HOME_FQDN_IP_ADDR}/32" > /var/tmp/home_cidr_previous_file.txt
		echo "${HOME_FQDN_IP_ADDR}" > /var/tmp/home__ip__previous_file.txt
	fi

	##
	## iptables routing setup
	##

	## forward and route wg packets
	iptables ${IPTABLE_ACTION_FLAG} FORWARD -i ${WG_CLOUDVPN_SERVER_DEVICE_NAME} -j ACCEPT
	iptables ${IPTABLE_ACTION_FLAG} FORWARD -o ${WG_CLOUDVPN_SERVER_DEVICE_NAME} -j ACCEPT
	iptables -t nat ${IPTABLE_ACTION_FLAG} POSTROUTING -s ${WG_CLOUDVPN_SERVER_NETWORK_CIDR} -o ${WG_CLOUDVPN_INTERNET_DEVICE_NAME} -j MASQUERADE

fi
