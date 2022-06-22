#!/bin/bash
set -eux

## setup/reconfig FW for vpn ssh access
## setup as cron to maintain VPN server access to host
## wget https://raw.githubusercontent.com/gh4m/cloud.userdata/main/bash/reconfigue-ufw-vpn-change.sh
## */4 * * * * /path/to/reconfigue-ufw-vpn-change.sh <VPN FQDN>

echo USERDATA_RUNNING $0 ${*}

not_found_text="VPN_NOT_FOUND"
ufw_cmd=/usr/sbin/ufw

## vpn hostname for access passed to script
fqdn_to_dig_for_vpn_ip=$1
ip_mask=/32
vpn_cidr_previous_file=/var/tmp/vpn_cidr_previous_${fqdn_to_dig_for_vpn_ip}.txt
vpn__ip__previous_file=/var/tmp/vpn__ip__previous_${fqdn_to_dig_for_vpn_ip}.txt
test -f $vpn_cidr_previous_file || echo "${not_found_text}" > $vpn_cidr_previous_file
test -f $vpn__ip__previous_file || echo "${not_found_text}" > $vpn_cidr_previous_file

vpn__ip__just_dug_up=$(dig +short $fqdn_to_dig_for_vpn_ip | tail -n1 | grep -E -o "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$")
if [[ $? -ne 0 ]];
then
  echo did not find a vpn ip from dig with $fqdn_to_dig_for_vpn_ip
  vpn__ip__just_dug_up="${not_found_text}"
  ip_mask=
fi

vpn_cidr_current__value=${vpn__ip__just_dug_up}${ip_mask}
vpn__ip__current__value=${vpn__ip__just_dug_up}
vpn_cidr_previous_value=$(cat $vpn_cidr_previous_file)
vpn__ip__previous_value=$(cat $vpn__ip__previous_file)

## did vpnip change?
if [[ "$vpn_cidr_current__value" == "$vpn_cidr_previous_value" ]];
then
  echo vpn cidr has not changed
  exit 0
fi

## update ufw rules if changed
if [[ "$vpn_cidr_previous_value" != "${not_found_text}" && "$vpn_cidr_current__value" != "${not_found_text}" ]];
then
  echo updating the ufw rules for the new vpnip
  ## update inbound rules
  $ufw_cmd status | grep "\s${vpn__ip__previous_value}\s*$" | egrep '^22/tcp' | while read rn
  do
    echo found previous inbound ufw rule: $rn
    if [[ "$vpn_cidr_previous_value" == "Anywhere" ]]
    then
      vpn_cidr_previous_value="0.0.0.0/0"
    fi
    if [[ "$vpn_cidr_current__value" == "Anywhere" ]]
    then
      vpn_cidr_current__value="0.0.0.0/0"
    fi
    ## 587/tcp ALLOW 108.48.83.17
    ufw_portproto=$(echo $rn | awk '{print $1}')
    ufw_port=$(echo $ufw_portproto | awk -F/ '{print $1}')
    ufw_proto=$(echo $ufw_portproto | awk -F/ '{print $2}')
    ufw_allowdeny=$(echo $rn | awk '{print tolower($2)}')
    ## ufw allow proto tcp from 108.48.83.17/${ip_mask} to any port 587
    $ufw_cmd delete $ufw_allowdeny proto $ufw_proto from ${vpn_cidr_previous_value} to any port $ufw_port
    $ufw_cmd        $ufw_allowdeny proto $ufw_proto from ${vpn_cidr_current__value} to any port $ufw_port
  done
fi

## add new fw rule
if [[ "$vpn_cidr_previous_value" == "${not_found_text}" ]];
then
    $ufw_cmd allow proto tcp from ${vpn_cidr_current__value} to any port ssh
fi

## remove obsolete fw rule
if [[ "$vpn_cidr_current__value" == "${not_found_text}" ]];
then
    $ufw_cmd delete allow proto tcp from ${vpn_cidr_previous_value} to any port ssh
fi

## update files
echo $vpn_cidr_current__value > $vpn_cidr_previous_file
echo $vpn__ip__current__value > $vpn__ip__previous_file

exit 0
