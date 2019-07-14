#!/bin/bash

FINALIPMAAS1="192.168.122.3"
GATEWAY="192.168.122.1"
NETMASK="255.255.255.0"
CIDR="24"
DNS="192.168.122.1"
PROXY=""
LPUSERNAME="ivanhitos"
PASSWORD="ubunturocks"
MAAS_STARTDHCP="192.168.122.220"
MAAS_ENDDHCP="192.168.122.250"
QEMUHYPERVISOR_IP="192.168.122.1"
QEMUHYPERVISOR_USER=ivan
HOST=$(hostname)



RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
NC='\033[0m'


do_cmd()
{
    echo -e "${GREEN} - ${HOST} - $(date) - ${LBLUE} Executing $@ ${NC}" | tee -a ${LOG} 2>&1
    $@  >> ${LOG} 2>&1
    ret=$?

    if [[ $ret -eq 0 ]]
    then
        echo -e "${GREEN} - ${HOST} - $(date) - ${LBLUE} Successfully ran [ $1 ] ${NC}" | tee -a ${LOG} 2>&1
    else
        echo -e "${GREEN} - ${HOST} - $(date) - ${RED} Error: Command [ $1 ] returned ${ret}. Check ${LOG}. ${NC}" | tee -a ${LOG} 2>&1
        exit $ret
    fi
}

do_print()
{
    echo -e "${GREEN} - ${HOST} - $(date) - ${LBLUE} $@ ${NC}" | tee -a ${LOG} 2>&1
}