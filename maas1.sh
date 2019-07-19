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

if [ "${PROXY}." != "." ]
then
	do_cmd "/usr/bin/maas ubuntu maas set-config name=http_proxy value=${PROXY}"

fi
/usr/bin/maas bogdan maas set-config name=upstream_dns value="${DNS}" >> ${LOG} 2>&1
echo "Adding DNS upstream to MAAS, exit code: $?" 
do_cmd "/usr/bin/maas ubuntu ipranges create type=dynamic start_ip=${MAAS_STARTDHCP} end_ip=${MAAS_ENDDHCP}"
do_cmd "/usr/bin/maas ubuntu vlan update fabric-0 untagged dhcp_on=True primary_rack=maas1"
do_cmd "/usr/bin/maas ubuntu boot-sources read"
sleep 30 
/usr/bin/maas ubuntu boot-source-selections create 1 os=\'ubuntu\' release=\'bionic\' arches=\'amd64\' subarches=\'*\' labels=\'*\' >> ${LOG} 2>&1
echo "Running maas boot-source-selection create, exit code: $?" 
do_cmd "/usr/bin/maas ubuntu boot-resources import"


do_print "Setting SSH Agent permissions for MAAS..."
setfacl -m maas:x   $(dirname "$SSH_AUTH_SOCK") >> ${LOG} 2>&1
echo "Setting permissions on directory, exit code: $?" 
setfacl -m maas:rwx "$SSH_AUTH_SOCK" >> ${LOG} 2>&1 
echo "Setting permissions on file, exit code: $?"
sudo -E -s -u maas -H sh -c "/usr/bin/ssh-keygen -f ~/.ssh/id_rsa -N '';/usr/bin/ssh-copy-id -i ~/.ssh/id_rsa -oStrictHostKeyChecking=no ${QEMUHYPERVISOR_USER}@${QEMUHYPERVISOR_IP}" >> ${LOG} 2>&1
echo "Running SSH Copy and stuff, exit code: $?"

do_print "Waiting for images to be imported to MAAS .."
while [ "$(/usr/bin/maas ubuntu boot-resources is-importing|tail -n 1)." != "false." ]
do
 sleep 10
done
sleep 100 # just some random wait... not sure why we have to wait here. it fails with "Ephemeral operating system ubuntu bionic is unavailable.""

do_cmd "/usr/bin/maas ubuntu pods create name=pod1 type=virsh power_address=qemu+ssh://${QEMUHYPERVISOR_USER}@${QEMUHYPERVISOR_IP}/system"
do_cmd "/usr/bin/maas ubuntu pod update name=pod1 cpu_over_commit_ratio=8 memory_over_commit_ratio=10.0"

# ERROR failed to bootstrap model: cannot start bootstrap instance: unexpected: 
# ServerError: 400 Bad Request ({"distro_series": ["'bionic' is not a valid distro_series.  It should be one of: ''."]})
sleep 100 
do_print "Bootstraping the Juju Controller..."
/snap/bin/juju bootstrap myMAAS myMAAS-controller --bootstrap-constraints "mem=2G" >> ${LOG} 2>&1
echo "Controller bootstrap exited with code: $?" 

#
