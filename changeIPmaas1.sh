#!/bin/bash

LOG=/tmp/maas-changeIP.log


source $(dirname "$0")/common.sh


do_cmd "sudo apt update"
do_cmd "sudo apt install python-pip -y"
do_cmd "sudo pip install yq"
do_cmd "sudo apt install jq -y"

sudo bash -c "echo  'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"

MACADRESS=$(cat /etc/netplan/50-cloud-init.yaml | yq .network.ethernets.ens3.match.macaddress)
sudo bash -c "echo \"

network:
    version: 2
    ethernets:
        ens3:
            dhcp4: no
            dhcp6: no
            addresses: [${FINALIPMAAS1}/${CIDR}]
            gateway4:  ${GATEWAY}
            nameservers:
              addresses: [${DNS}]
            match:
                macaddress: ${MACADRESS}
            set-name: ens3

\" > /etc/netplan/50-cloud-init.yaml" 

do_print "Changing IP to ${FINALIPMAAS1}. Connect to that IP and follow logs there."
do_cmd "sudo netplan apply"
