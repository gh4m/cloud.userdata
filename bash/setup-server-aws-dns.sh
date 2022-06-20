#!/bin/bash

##
## setup dns
##

echo USERDATA_RUNNING $0 ${*}

SERVER___HOSTNAME=$1
SERVER_DOMAINNAME=$2
ROUTE53_ZONEID_PRIVATE=$3
ROUTE53_ZONEID_PUBLIC=$4
SERVER_PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
SERVER__LOCAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

route53jsonprivate="/var/tmp/route53private.json"
cat << EOF >> $route53jsonprivate
{
  "Comment": "setup private hostname",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${SERVER___HOSTNAME}.${SERVER_DOMAINNAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${SERVER__LOCAL_IP}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $ROUTE53_ZONEID_PRIVATE --change-batch file://$route53jsonprivate

route53jsonpublic="/var/tmp/route53public.json"
cat << EOF >> $route53jsonpublic
{
  "Comment": "setup public hostname",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${SERVER___HOSTNAME}.${SERVER_DOMAINNAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${SERVER_PUBLIC_IP}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $ROUTE53_ZONEID_PUBLIC --change-batch file://$route53jsonpublic
