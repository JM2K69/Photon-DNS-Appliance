#!/bin/bash

# Bootstrap script

set -euo pipefail

if [ -e /root/ran_customization ]; then
    exit
else
    NETWORK_CONFIG_FILE=$(ls /etc/systemd/network | grep .network)

    HOSTNAME_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.hostname")
    IP_ADDRESS_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ipaddress")
    NETMASK_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.netmask")
    GATEWAY_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.gateway")
    ROOT_PASSWORD_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.root_password")

    ##################################
    ### No User Input, assume DHCP ###
    ##################################
    if [ -z "${HOSTNAME_PROPERTY}" ]; then
        cat > /etc/systemd/network/${NETWORK_CONFIG_FILE} << __CUSTOMIZE_PHOTON__
[Match]
Name=e*

[Network]
DHCP=yes
IPv6AcceptRA=no
__CUSTOMIZE_PHOTON__
    #########################
    ### Static IP Address ###
    #########################
    else
        HOSTNAME=$(echo "${HOSTNAME_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        IP_ADDRESS=$(echo "${IP_ADDRESS_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        NETMASK=$(echo "${NETMASK_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        GATEWAY=$(echo "${GATEWAY_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')

        echo -e "\e[96mConfiguring Static IP Address ..." > /dev/console
        cat > /etc/systemd/network/${NETWORK_CONFIG_FILE} << __CUSTOMIZE_PHOTON__
[Match]
Name=e*

[Network]
Address=${IP_ADDRESS}/${NETMASK}
Gateway=${GATEWAY}
__CUSTOMIZE_PHOTON__

    echo -e "\e[96mConfiguring hostname ..." > /dev/console
    hostnamectl set-hostname ${HOSTNAME}
    echo "${IP_ADDRESS} ${HOSTNAME}" >> /etc/hosts
    echo -e "\e[96mRestarting Network ..." > /dev/console
    systemctl restart systemd-networkd
    fi

    echo -e "\e[96mConfiguring root password ..." > /dev/console
    ROOT_PASSWORD=$(echo "${ROOT_PASSWORD_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    echo "root:${ROOT_PASSWORD}" | /usr/sbin/chpasswd

    echo -e "\e[96mDisabling iptables ..." > /dev/console
    systemctl disable iptables
    systemctl stop iptables

    # Ensure we don't run customization again
    touch /root/ran_customization
fi
if [ -e /root/ran_customization_dns ]; then
    exit
else
    echo -e "\e[96mConfiguring Unbound DNS ..." > /dev/console
    #### Find Values ########
    KEYBOARDLY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.keyboardlayout")
    ESXINUMBER=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.esxinumber")
    NETWORK=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.network")
    DNS_DOMAIN_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.domain")
    ESXINAME=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.esxiname")
    #### Map Values #####
    WSDOMAIN=$(echo "${DNS_DOMAIN_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    WSKEYBOARDLY=$(echo "${KEYBOARDLY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    WSESXINUMBER=$(echo "${ESXINUMBER}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    WSNETWORK=$(echo "${NETWORK}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    WSESXINAME=$(echo "${ESXINAME}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')

    cat > /etc/unbound/unbound.conf << __UBOUND_CONF__
server:
   interface: 0.0.0.0
   port: 53
   do-ip4: yes
   do-udp: yes
   access-control: 0.0.0.0/0 allow
   verbosity: 1

local-zone: "$WSDOMAIN." static
local-data: "vcsa.$WSDOMAIN A $WSNETWORK.80"
local-data-ptr: "$WSNETWORK.80 vcsa.$WSDOMAIN"
__UBOUND_CONF__

    if [[ $WSKEYBOARDLY = "fr" ]]
    then
	localectl set-keymap ${WSKEYBOARDLY}
    echo -e "\e[96mSet Locale to AZERTY ..." > /dev/console

    else
        localectl set-keymaps en-latin9
        echo -e "\e[96mSet Locale to QUERTY ..." > /dev/console
    fi

    cpt="1"
    while [ $WSESXINUMBER -ge $cpt ]
    do
        cat >> /etc/unbound/unbound.conf << __UBOUND_CONF__
local-data: "$WSESXINAME$cpt.$WSDOMAIN A $WSNETWORK.8$cpt"
local-data-ptr: "$WSNETWORK.8$cpt $WSESXINAME$cpt.$WSDOMAIN"
__UBOUND_CONF__

       cpt=$(( $cpt + 1))
    done
    cat >> /etc/unbound/unbound.conf << __UBOUND_CONF__

forward-zone:
   name: "."
   forward-addr: 1.1.1.1
   forward-addr: 8.8.8.8
__UBOUND_CONF__
    echo -e "\e[96mRestart Unbound service ..." > /dev/console
    systemctl stop unbound
    systemctl start unbound
    touch /root/ran_customization_dns
fi