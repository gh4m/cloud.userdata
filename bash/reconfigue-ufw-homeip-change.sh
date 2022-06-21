#!/bin/bash

## setup this script in cron to run one minute after lamba runs to set home IP in DNS
## TTL on A record should be (3.5x60) 210 seconds (set in lambda code)
## 3-59/4 * * * * /root/cron-scripts/reconfigue-for-new-homeip.sh

echo USERDATA_RUNNING $0 ${*}

## DNS hostname to use to lookup home ip
fqdn_to_dig_for_home_ip=$1
ip_mask=32
home_cidr_previous_file=/var/tmp/home_cidr_previous_file.txt

home_ip_just_dug_up=$(dig +short $fqdn_to_dig_for_home_ip | tail -n1 | grep -E -o "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$")
if [[ $? -ne 0 ]];
then
  echo did not find a home ip from dig with $fqdn_to_dig_for_home_ip
  home_ip_just_dug_up=0.0.0.0
  ip_mask=0
fi

home_cidr_current_value=${home_ip_just_dug_up}/${ip_mask}
home_cidr_previous_value=$(cat $home_cidr_previous_file || echo "0.0.0.0/0")
echo $home_cidr_current_value > $home_cidr_previous_file

## did homeip change?
home_cidr_value_changed="false"
if [[ "$home_cidr_current_value" != "$home_cidr_previous_value" ]];
then
  echo home cidr has changed
  home_cidr_value_changed="true"
fi

## update ufw rules
ufw_cmd=/usr/sbin/ufw
if [[ "$home_cidr_value_changed" == "true" ]];
then
  echo updating the ufw rules for the new homeip
  ## update inbound rules
  $ufw_cmd status | grep "\s${home_cidr_previous_value}\s*$" | while read rn
  do
    echo found previous inbound ufw rule: $rn
    ## 587/tcp ALLOW 108.48.83.17
    ufw_portproto=$(echo $rn | awk '{print $1}')
    ufw_port=$(echo $ufw_portproto | awk -F/ '{print $1}')
    ufw_proto=$(echo $ufw_portproto | awk -F/ '{print $2}')
    ufw_allowdeny=$(echo $rn | awk '{print tolower($2)}')
    ## ufw allow proto tcp from 108.48.83.17/${ip_mask} to any port 587
    $ufw_cmd delete $ufw_allowdeny proto $ufw_proto from ${home_cidr_previous_value}/${ip_mask} to any port $ufw_port
    $ufw_cmd        $ufw_allowdeny proto $ufw_proto from ${home_ip_just_dug_up}/${ip_mask}      to any port $ufw_port
  done
  ## update outbound rules
  $ufw_cmd status | grep "^${home_cidr_previous_value}\s" | while read rn
  do
    echo found previous outbound ufw rule: $rn
    ## 108.48.83.17 444/tcp ALLOW OUT Anywhere
    ufw_portproto=$(echo $rn | awk '{print $2}')
    ufw_port=$(echo $ufw_portproto | awk -F/ '{print $1}')
    ufw_proto=$(echo $ufw_portproto | awk -F/ '{print $2}')
    ufw_allowdeny=$(echo $rn | awk '{print tolower($3)}')
    ## ufw allow out proto tcp to 108.48.83.17/${ip_mask} port 444
    $ufw_cmd delete $ufw_allowdeny out proto $ufw_proto to ${home_cidr_previous_value}/${ip_mask} port $ufw_port
    $ufw_cmd        $ufw_allowdeny out proto $ufw_proto to ${home_ip_just_dug_up}/${ip_mask}      port $ufw_port
  done
fi

exit 0
