#!/bin/bash
set -eux

## setup this script in cron to run one minute after lamba runs to set/update home IP in AWS DNS
## TTL on A record should be (3.5x60) 210 seconds (set in lambda code)
## 3-59/4 * * * * /<PATH>/reconfigue-for-new-homeip.sh

ufw_cmd=/usr/sbin/ufw

## DNS hostname to use to lookup home ip
fqdn_to_dig_for_home_ip=$1
ip_mask=/32
home_cidr_previous_file=/var/tmp/home_cidr_previous_file.txt
home__ip__previous_file=/var/tmp/home__ip__previous_file.txt
test -f $home_cidr_previous_file || echo "Anywhere" > $home_cidr_previous_file
test -f $home__ip__previous_file || echo "Anywhere" > $home__ip__previous_file

home__ip__just_dug_up=$(dig +short $fqdn_to_dig_for_home_ip | tail -n1 | grep -E -o "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$")
if [[ $? -ne 0 ]];
then
  echo did not find a home ip from dig with $fqdn_to_dig_for_home_ip
  home__ip__just_dug_up="Anywhere"
  home__ip__for_etc_hosts="0.0.0.0"
  ip_mask=""
else
  home__ip__for_etc_hosts=$home__ip__just_dug_up
fi

home_cidr_current__value=${home__ip__just_dug_up}${ip_mask}
home__ip__current__value=${home__ip__just_dug_up}
home_cidr_previous_value=$(cat $home_cidr_previous_file)
home__ip__previous_value=$(cat $home__ip__previous_file)
echo $home_cidr_current__value > $home_cidr_previous_file
echo $home__ip__current__value > $home__ip__previous_file

## did homeip change?
if [[ "$home_cidr_current__value" == "$home_cidr_previous_value" ]];
then
  echo home cidr did NOT change
  exit 0
fi

## update home ip & fqdn in /etc/hosts
sed -i "/${fqdn_to_dig_for_home_ip}/c${home__ip__for_etc_hosts} ${fqdn_to_dig_for_home_ip}" /etc/hosts

## update ufw rules
echo updating the ufw rules for the new homeip
## update inbound rules
## grepping for port as matching "Anywhere" is not always rule unique to home IP
$ufw_cmd status | grep "\s${home__ip__previous_value}\s*$" | grep -E '^22/tcp' | while read rn
do
  echo found previous inbound ufw rule: $rn
  if [[ "$home_cidr_previous_value" == "Anywhere" ]]
  then
    home_cidr_previous_value="0.0.0.0/0"
  fi
  if [[ "$home_cidr_current__value" == "Anywhere" ]]
  then
    home_cidr_current__value="0.0.0.0/0"
  fi
  ## 587/tcp ALLOW 108.48.83.17
  ufw_portproto=$(echo $rn | awk '{print $1}')
  ufw_port=$(echo $ufw_portproto | awk -F/ '{print $1}')
  ufw_proto=$(echo $ufw_portproto | awk -F/ '{print $2}')
  ufw_allowdeny=$(echo $rn | awk '{print tolower($2)}')
  ## ufw allow proto tcp from 108.48.83.17/${ip_mask} to any port 587
  $ufw_cmd delete $ufw_allowdeny proto $ufw_proto from ${home_cidr_previous_value} to any port $ufw_port
  $ufw_cmd        $ufw_allowdeny proto $ufw_proto from ${home_cidr_current__value} to any port $ufw_port
done

exit 0
