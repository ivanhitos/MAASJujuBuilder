#!/bin/bash

LOG=/tmp/maas-deploy.log


source $(dirname "$0")/common.sh


do_print "Installing MAAS..."
do_cmd "sudo apt update"
do_cmd "sudo apt install maas -y"
do_print "Installing Juju..."
do_cmd "sudo snap install juju --classic"


do_print "Configuring MAAS and Juju..."

echo " 
clouds:
    myMAAS:
        type: maas
        auth-types: [oauth1]
        endpoint: http://${FINALIPMAAS1}:5240/MAAS
" > cloud.yaml

do_cmd "/snap/bin/juju add-cloud myMAAS cloud.yaml"

do_cmd "sudo /usr/bin/maas createadmin --username=ubuntu --password=${PASSWORD} --email=root@localhost --ssh-import=lp:${LPUSERNAME}"
maaskey=$(sudo /usr/sbin/maas-region apikey --username=ubuntu)

echo "
credentials:
 myMAAS:
  ubuntu:
   auth-type: oauth1
   maas-oauth: XXXXX
" > maas.yaml

perl -pi -e ""s/XXXXX/$maaskey/g"" maas.yaml

do_cmd "/snap/bin/juju add-credential myMAAS -f maas.yaml"
do_cmd "/usr/bin/maas login ubuntu http://${FINALIPMAAS1}:5240/MAAS/ $maaskey"

if [ "${PROXY}." != "."]
then
	do_cmd "/usr/bin/maas ubuntu maas set-config name=http_proxy value=${PROXY}"

fi
do_cmd "/usr/bin/maas ubuntu ipranges create type=dynamic start_ip=${MAAS_STARTDHCP} end_ip=${MAAS_ENDDHCP}"
do_cmd "/usr/bin/maas ubuntu vlan update fabric-0 untagged dhcp_on=True primary_rack=maas1"
do_cmd "/usr/bin/maas ubuntu boot-sources read"
/usr/bin/maas ubuntu boot-source-selections create 1 os=\'ubuntu\' release=\'bionic\' arches=\'amd64\' subarches=\'*\' labels=\'*\'
do_cmd "/usr/bin/maas ubuntu boot-resources import"


setfacl -m maas:x   $(dirname "$SSH_AUTH_SOCK")
setfacl -m maas:rwx "$SSH_AUTH_SOCK"
sudo -E -s -u maas -H sh -c "/usr/bin/ssh-keygen -f ~/.ssh/id_rsa -N '';/usr/bin/ssh-copy-id -i ~/.ssh/id_rsa -oStrictHostKeyChecking=no ${QEMUHYPERVISOR_USER}@${QEMUHYPERVISOR_IP}"
do_cmd "/usr/bin/maas ubuntu pods create name=pod1 type=virsh power_address=qemu+ssh://${QEMUHYPERVISOR_USER}@${QEMUHYPERVISOR_IP}/system"

while [ "$(/usr/bin/maas ubuntu boot-resources is-importing|tail -n 1)." != "false." ]
do
 sleep 10
done

do_print "Bootstraping the Juju Controller..."
/snap/bin/juju bootstrap myMAAS myMAAS-controller --bootstrap-constraints "mem=2G"
