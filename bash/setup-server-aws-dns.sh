#!/bin/bash
set -eux

##
## setup dns
##

WG_CLOUDVPN_SERVER_HOSTNAME=$1
WG_CLOUDVPN_SERVER_DOMAIN_NAME=$2
AWS_ROUTE53_ZONEID_PRIVATE=$3
AWS_ROUTE53_ZONEID_PUBLIC=$4

## in /tmp so file removed on reboot
AWS_DNS_PUBLIC_IP_FILE=/tmp/aws-public-ip.txt
if [[ ! -f "${AWS_DNS_PUBLIC_IP_FILE}" ]]
then

route53jsonprivate="/var/tmp/route53private.json"
cat << EOF > $route53jsonprivate
{
  "Comment": "setup private hostname",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${WG_CLOUDVPN_SERVER_FQDN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${WG_CLOUDVPN_PRIVATE_IP_ADDR}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $AWS_ROUTE53_ZONEID_PRIVATE --change-batch file://$route53jsonprivate

route53jsonpublic="/var/tmp/route53public.json"
cat << EOF > $route53jsonpublic
{
  "Comment": "setup public hostname",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${WG_CLOUDVPN_SERVER_FQDN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${WG_CLOUDVPN_INTERNET_IP_ADDR}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $AWS_ROUTE53_ZONEID_PUBLIC --change-batch file://$route53jsonpublic

## set file so will not rerun unless server rebooted
echo "${WG_CLOUDVPN_INTERNET_IP_ADDR}" > ${AWS_DNS_PUBLIC_IP_FILE}

fi
