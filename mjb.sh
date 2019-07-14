#!/bin/bash

LOG=/tmp/maasVM-deploy.log

RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
NC='\033[0m'

do_cmd()
{
    echo -e "${GREEN} - HOST - $(date) - ${LBLUE} Executing $@ ${NC}" | tee -a ${LOG} 2>&1
    $@  >> ${LOG} 2>&1
    ret=$?

    if [[ $ret -eq 0 ]]
    then
        echo -e "${GREEN} - HOST - $(date) - ${LBLUE} Successfully ran [ $1 ] ${NC}" | tee -a ${LOG} 2>&1
    else
        echo -e "${GREEN} - HOST - $(date) - ${RED} Error: Command [ $1 ] returned ${ret}. Check ${LOG}. ${NC}" | tee -a ${LOG} 2>&1
        exit $ret
    fi
}

do_print()
{
    echo -e "${GREEN} - HOST - $(date) - ${LBLUE} $@ ${NC}" | tee -a ${LOG} 2>&1
}

do_cmd "sudo apt-get update -y"
do_cmd "sudo apt-get install qemu-utils virtinst libvirt-bin qemu-kvm uvtool sshuttle -y"
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


cat > maas-installer.sh<<'EOF'
#!/bin/bash

LOG=/tmp/maas-deploy.log


RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
NC='\033[0m'

do_cmd()
{
    echo -e "${GREEN} - MAAS - $(date) - ${LBLUE} Executing $@ ${NC}" | tee -a ${LOG} 2>&1
    $@  >> ${LOG} 2>&1
    ret=$?
    
    if [[ $ret -eq 0 ]]
    then
        echo -e "${GREEN} - MAAS - $(date) - ${LBLUE} Successfully ran [ $1 ] ${NC}" | tee  -a ${LOG} 2>&1
    else
        echo -e "${GREEN} - MAAS - $(date) - ${RED} Error: Command [ $1 ] returned ${ret}. Check ${LOG}. ${NC}" | tee -a ${LOG} 2>&1
        exit $ret
    fi
}

do_print()
{
    echo -e "${GREEN} - MAAS - $(date) - ${LBLUE} $@ ${NC}" | tee -a ${LOG} 2>&1
}


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
            addresses: [192.168.122.3/24]
            gateway4:  192.168.122.1
            nameservers:
              addresses: [192.168.122.1]
            match:
                macaddress: ${MACADRESS}
            set-name: ens3

\" > /etc/netplan/50-cloud-init.yaml" 

do_print "MAAS1 changing IP to 192.168.122.3. Connect to that IP and follow logs there."
do_cmd "sudo netplan apply"


# virsh net-dumpxml default > default.xml
# python load the xml to remove dhcp ----  and the dump it to default.xml
# virsh net-destroy default
# virsh net-define default.xml
# virsh net-start default

do_cmd "sudo apt update"
do_cmd "sudo apt install maas -y"
do_cmd "sudo snap install juju --classic"
source .profile

sleep 10

echo " 
clouds:
    myMAAS:
        type: maas
        auth-types: [oauth1]
        endpoint: http://192.168.122.3:5240/MAAS
" > cloud.yaml

do_cmd "juju add-cloud myMAAS cloud.yaml"

do_cmd "sudo maas createadmin --username=ubuntu --password=ubunturocks --email=root@localhost --ssh-import=lp:ivanhitos"
maaskey=$(sudo maas-region apikey --username=ubuntu)

echo "
credentials:
 myMAAS:
  ubuntu:
   auth-type: oauth1
   maas-oauth: XXXXX
" > maas.yaml

perl -pi -e ""s/XXXXX/$maaskey/g"" maas.yaml

do_cmd "juju add-credential myMAAS -f maas.yaml"
do_cmd "maas login ubuntu http://192.168.122.3:5240/MAAS/ $maaskey"
#do_cmd "maas ubuntu maas set-config name=http_proxy value=http://squid.internal:3128"
do_cmd "/usr/bin/maas ubuntu ipranges create type=dynamic start_ip=192.168.122.200 end_ip=192.168.122.250 comment=\'This is a reserved dynamic range\'"
do_cmd "/usr/bin/maas ubuntu vlan update fabric-0 untagged dhcp_on=True primary_rack=maas1"
do_cmd "/usr/bin/maas ubuntu boot-source-selections create 1 os=\'ubuntu\' release=\'bionic\' arches=\'amd64\' subarches=\'*\' labels=\'*\'"
do_cmd "/usr/bin/maas ubuntu boot-resources import"


setfacl -m maas:x   $(dirname "$SSH_AUTH_SOCK")
setfacl -m maas:rwx "$SSH_AUTH_SOCK"
do_cmd "sudo -E -s -u maas -H sh -c \"/usr/bin/ssh-copy-id -i ~/.ssh/id_rsa -oStrictHostKeyChecking=no ivan@192.168.122.1\""
do_cmd "/usr/bin/maas ubuntu pods create name=pod1 type=virsh power_address=qemu+ssh://ivan@192.168.122.1/system"

while [ "$(maas ubuntu boot-resources is-importing|tail -n 1)." != "false." ]
do
 sleep 10
done

do_cmd "juju bootstrap myMAAS myMAAS-controller --bootstrap-constraints \"mem=2G\""


EOF

do_print "Installing MAAS components..."

do_cmd "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null maas-installer.sh ubuntu@${IPMAAS1}:"
do_cmd "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${IPMAAS1} nohup bash /home/ubuntu/maas-installer.sh" 
do_print "MAAS installing... Check logs on 192.168.122.3."

