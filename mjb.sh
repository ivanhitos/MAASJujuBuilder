#!/bin/bash

LOG=/tmp/maasVM-deploy.log
ARGS="$@"

source $(dirname "$0")/common.sh


do_cmd "sudo apt-get update -y"
do_cmd "sudo apt-get install qemu-utils virtinst libvirt-bin qemu-kvm uvtool sshuttle xmlstarlet -y"
source ${HOME}/.profile

sshagents=$(ssh-add -L|wc -l)
if [ "${sshagents}." == "0." ]
then
  do_print_error_exit "SSH Agent doesn't contain a key, please add the key."
fi
do_print "Synchronizing Bionic image, this will take time..."
do_cmd_as_libvirt "uvt-simplestreams-libvirt sync release=${RELEASE} arch=amd64"
do_print "Synchronization of Bionic image, completed."
do_cmd_as_libvirt "uvt-kvm create --cpu 1 --memory 4096 --disk 40 maas1 release=${RELEASE}"
do_print "Discovering MAAS1 IP..."

IPMAAS1_COMMAND="do_cmd_as_libvirt \"/usr/bin/uvt-kvm ip maas1\""

sentinel=0
while [ ${sentinel} -eq 0 ] 
do
        sleep 2
        ${IPMAAS1_COMMAND} > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
            sentinel=1
        fi
done


IPMAAS1=$(${IPMAAS1_COMMAND})
do_print "MAAS1 IP discovered: ${IPMAAS1}. Pinging it..."

sentinel=0
while [ ${sentinel} -eq 0 ] 
do
        sleep 2
        ping ${IPMAAS1} -c 1 -W 3 > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
        	sentinel=1
        fi
done

do_print "MAAS1 is now reachable."
sleep 10

do_cmd "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${IPMAAS1} git clone https://github.com/ivanhitos/MAASJujuBuilder.git"

do_print "Changing IP."
do_cmd "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${IPMAAS1} nohup bash /home/ubuntu/MAASJujuBuilder/changeIPmaas1.sh $ARGS" 


do_print "Disabling DHCP."
/usr/bin/virsh net-dumpxml default > default.xml
/usr/bin/xmlstarlet edit --delete "/network/ip/dhcp" default.xml > default-new.xml
sleep 5
do_cmd "/usr/bin/virsh net-destroy default"
sleep 5
do_cmd "/usr/bin/virsh net-define default-new.xml"
sleep 5
do_cmd "/usr/bin/virsh net-start default"
sleep 5
do_cmd "/usr/bin/virsh destroy maas1"
sleep 5
do_cmd "/usr/bin/virsh start maas1"

do_print "Waiting for MAAS1. Pinging it..."
do_print "... in the meantime configuring additional networks"
do_cmd "/usr/bin/virsh net-define overlay.xml"
do_cmd "/usr/bin/virsh net-start overlay"

sentinel=0
while [ ${sentinel} -eq 0 ] 
do
        sleep 2
        ping ${FINALIPMAAS1} -c 1 -W 3 > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
            sentinel=1
        fi
done
sleep 10

do_print_important "Installing MAAS components... Check logs on MAAS server: ${FINALIPMAAS1}:/tmp/maas-deploy.log"
do_cmd "ssh -A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${FINALIPMAAS1} nohup bash /home/ubuntu/MAASJujuBuilder/maas1.sh $ARGS" 
do_print "Completed."

