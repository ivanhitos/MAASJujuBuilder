#!/bin/bash

LOG=/tmp/maasVM-deploy.log
ARGS="$@"

source $(dirname "$0")/common.sh


do_cmd "sudo apt-get update -y"
do_cmd "sudo apt-get install qemu-utils virtinst libvirt-bin qemu-kvm uvtool sshuttle xmlstarlet -y"


sshagents=$(ssh-add -L|wc -l)
if [ "${sshagents}." == "0." ]
then
  do_print "SSH Agent doesn't contain a key, we will create one."
  do_cmd "ssh-keygen -f ~/.ssh/id_rsa -N ''" 
else
  do_print "SSH Agent contains a key, we will use that one."
fi
do_print "Synchronizing Bionic image, this will take time..."
do_cmd "uvt-simplestreams-libvirt sync release=bionic arch=amd64"
do_print "Synchronization of Bionic image, completed."
do_cmd "uvt-kvm create --cpu 1 --memory 2048 --disk 40 maas1"
do_print "Discovering MAAS1 IP..."

IPMAAS1_COMMAND="/usr/bin/uvt-kvm ip maas1"

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

do_print "Disabling DHCP."
do_cmd "(/usr/bin/virsh net-dumpxml default | tee default.xml)"
do_cmd "/usr/bin/xmlstarlet edit --delete \"/network/ip/dhcp\" default.xml | tee default-new.xml"
do_cmd "/usr/bin/virsh net-destroy default"
do_cmd "/usr/bin/virsh net-define default-new.xml"
do_cmd "/usr/bin/virsh net-start default"


do_print_important "Installing MAAS components... Check logs on MAAS server ${IPMAAS1}, that it will be changed to ${FINALIPMAAS1}"
do_cmd "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${IPMAAS1} git clone https://github.com/ivanhitos/MAASJujuBuilder.git"
do_cmd "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${IPMAAS1} nohup bash /home/ubuntu/MAASJujuBuilder/maas1.sh $ARGS" 
do_print "Continue on MAAS server: ${IPMAAS1}, that it will be changed to: ${FINALIPMAAS1}"

