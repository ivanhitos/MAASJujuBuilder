#!/bin/bash

# FINALIPMAAS1="192.168.122.3"
GATEWAY="192.168.122.1"
NETMASK="255.255.255.0"
CIDR="24"
# DNS="192.168.122.1"
# PROXY=""
# LPUSERNAME="ivanhitos"
# PASSWORD="ubunturocks"
# MAAS_STARTDHCP="192.168.122.220"
# MAAS_ENDDHCP="192.168.122.250"
QEMUHYPERVISOR_IP="192.168.122.1"
# QEMUHYPERVISOR_USER=ivan
HOST=$(hostname)

POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --maas_ip)
        FINALIPMAAS1="$2"
        shift # past argument
        shift # past value
        ;;
        --release)
        RELEASE="$2"
        shift # past argument
        shift # past value
        ;;
        # --maas_gateway)
        # GATEWAY="$2"
        # shift # past argument
        # shift # past value
        # ;;
        # --maas_netmask)
        # NETMASK="$2"
        # shift # past argument
        # shift # past value
        # ;;
        # --cidr)
        # CIDR="$2"
        # shift # past argument
        # shift # past value
        # ;;
        --dns)
        DNS="$2"
        shift # past argument
        shift # past value
        ;;
        --proxy)
        PROXY="$2"
        shift # past argument
        shift # past value
        ;;
        --lpusername)
        LPUSERNAME="$2"
        shift # past argument
        shift # past value
        ;;
        --maas_password)
        PASSWORD="$2"
        shift # past argument
        shift # past value
        ;;
        --maas_startdhcp)
        MAAS_STARTDHCP="$2"
        shift # past argument
        shift # past value
        ;;
        --maas_enddhcp)
        MAAS_ENDDHCP="$2"
        shift # past argument
        shift # past value
        ;;
        --qemu_user)
        QEMUHYPERVISOR_USER="$2"
        shift # past argument
        shift # past value
        ;;
        # --qemu_ip)
        # QEMUHYPERVISOR_IP="$2"
        # shift # past argument
        # shift # past value
        # ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac


done
set -- "${POSITIONAL[@]}" # restore positional parameters



RED='\033[0;31m'
GREEN='\033[0;32m'
LBLUE='\033[1;34m'
LYELLOW='\033[1;33m'

NC='\033[0m'


do_cmd()
{
    echo -e "${GREEN} - ${HOST} - $(date) - ${LBLUE} Executing: $@ ${NC}" | tee -a ${LOG} 2>&1
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

do_print_important()
{
    echo -e "${GREEN} - ${HOST} - $(date) - ${LYELLOW} $@ ${NC}" | tee -a ${LOG} 2>&1
}

do_print_error_exit()
{
    echo -e "${GREEN} - ${HOST} - $(date) - ${RED} Error: $@ ${NC}. Exiting." | tee -a ${LOG} 2>&1
    exit 1
}

if [ -z $FINALIPMAAS1 ] || [ -z $DNS ] || [ -z $LPUSERNAME ] || [ -z $PASSWORD ] || [ -z $MAAS_STARTDHCP ] || [ -z $MAAS_ENDDHCP ] || [ -z $QEMUHYPERVISOR_USER ]
then
    do_print_error_exit "Missing arguments."
fi

if (( "${#POSITIONAL[@]}" != "0"))
then     
    do_print_error_exit "Incorrect number of arguments."
fi
