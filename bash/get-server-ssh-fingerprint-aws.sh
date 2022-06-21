#!/bin/bash

##
## AWS ssh server fingerprint
##

AWS_SNS_ARN=$1
host_ssh_fingerprint_file=/var/tmp/host-fingerprints.txt
rm -f $host_ssh_fingerprint_file

ed25519=/etc/ssh/ssh_host_ed25519_key.pub
ecdsa=/etc/ssh/ssh_host_ecdsa_key.pub
rsa=/etc/ssh/ssh_host_rsa_key.pub
dsa=/etc/ssh/ssh_host_dsa_key.pub
[ -f $ed25519 ] && ssh-keygen -l -f $ed25519 | awk '{printf $2":"$4" "}' >> $host_ssh_fingerprint_file
[ -f $ecdsa ]   && ssh-keygen -l -f $ecdsa   | awk '{printf $2":"$4" "}' >> $host_ssh_fingerprint_file
[ -f $rsa ]     && ssh-keygen -l -f $rsa     | awk '{printf $2":"$4" "}' >> $host_ssh_fingerprint_file
[ -f $dsa ]     && ssh-keygen -l -f $dsa     | awk '{printf $2":"$4" "}' >> $host_ssh_fingerprint_file

echo "[[ssh-keyscan -t ed25519 ${WG_SERVER_FQDN} > /tmp/remote-ssh.scan]]" >> $host_ssh_fingerprint_file
echo "[[ssh-keygen -l -f /tmp/remote-ssh.scan]]" >> $host_ssh_fingerprint_file
echo "[[## compare /tmp/remote-ssh.scan with emailed fingerprint, if good...]]" >> $host_ssh_fingerprint_file
echo "[[cat /tmp/remote-ssh.scan >> ~/.ssh/known_hosts]]" >> $host_ssh_fingerprint_file

aws sns publish --topic-arn "$AWS_SNS_ARN" \
--message file://$host_ssh_fingerprint_file \
--subject "$WG_SERVER_PUBLIC_IP ($HOSTNAME) host ssh fingerprints"

rm -f $host_ssh_fingerprint_file
