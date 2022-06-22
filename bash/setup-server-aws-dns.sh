#!/bin/bash
set -eux

##
## setup dns
##

echo USERDATA_RUNNING $0 ${*}

WG_SERVER_HOSTNAME=$1
WG_SERVER_DOMAIN=$2
WG_SERVER_FQDN=${WG_SERVER_HOSTNAME}.${WG_SERVER_DOMAIN}
AWS_ROUTE53_ZONEID_PRIVATE=$3
AWS_ROUTE53_ZONEID_PUBLIC=$4
WG_SERVER_PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
WG_SERVER_LOCAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

## in /tmp so removed on reboot
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
        "Name": "${WG_SERVER_FQDN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${WG_SERVER_LOCAL_IP}"
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
        "Name": "${WG_SERVER_FQDN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${WG_SERVER_PUBLIC_IP}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $AWS_ROUTE53_ZONEID_PUBLIC --change-batch file://$route53jsonpublic

echo "${WG_SERVER_PUBLIC_IP}" > ${AWS_DNS_PUBLIC_IP_FILE}

fi
