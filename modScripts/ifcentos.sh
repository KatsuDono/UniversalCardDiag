#!/bin/bash

echo -e "____________________________________________________________"
echo -e ""
echo -e "Bind Static IP to the Existed Interface, Version 1.8.0.4"
echo -e "Written by Arsen Sogomonyan, arsens@silicom.co.il"
echo -e "Copyright (C) 2020, by Silicom Ltd. All rights reserved."
echo -e "____________________________________________________________"
echo -e ""

try()
{
	local name=$1
	shift
	if [ -z "$1" ] ; then
		echo -e "\e[0;31mUndefined $name\e[m"
		exit 1
	elif [ "$1" = "0" ] ; then
		echo -e "\e[0;31mIllegal $name\e[m"
		exit 1
	else
		echo "$name="$@
	fi
	return 0
}

status()
{
	if [ "$2" = "0" ] ; then
		echo -e "\e[0;32m$1 Passed\e[m"
		return 0
	else
		echo -e "\e[0;31m$1 Failed\e[m"
		return 1
	fi
}

is_ethernet()
{
	local devices
	devices=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep net |grep -v virtual |awk -F/ '{print $NF}')
	test ! -z "$devices" || try Interface 0
	test ! -z "$1" || try Interface
	local dev eth net
	for net in $@ ; do
		eth=""
		for dev in $devices ; do
			test "$net" = "$dev" && eth=$dev && break
		done
		test ! -z "$eth" || try "Interface:$net"
	done
	return 0
}

devices=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep net |grep -v virtual |awk -F/ '{print $NF}')
try devices $devices
try Interface $1
eth=$1
shift

ipa=$1
try IP4ADDR $ipa
ip0=$(echo $ipa | cut -d. -f1)
if [ "$ip0" = "192" ] ; then
	gtw=$(echo $1 | cut -d. -f1-3).9
	msk=255.255.255.0
	pre=24
elif [ "$ip0" = "172" ] ; then
	gtw=$(echo $1 | cut -d. -f1-2).0.9
	msk=255.255.0.0
	pre=16
elif [ "$ip0" = "10" ] ; then
	gtw=$(echo $1 | cut -d. -f1).0.0.9
	msk=255.0.0.0
	pre=8
else
	try IP4ADDR 0
fi
try NETMASK $msk
try GATEWAY $gtw

dns1='8.8.8.8'
dns2='8.8.4.4'

is_ethernet $eth
mac=$(cat /sys/class/net/$eth/address)

test -s "/etc/centos-release" -o -s "/etc/fedora-release" || try "CentOS/Fedora Version" 0
ipc=$(echo $ipa | cut -d. -f3)
ipd=$(echo $ipa | cut -d. -f4)
hostnamectl set-hostname centos-ip$ipc-$ipd

uid=$(uuidgen $eth)
echo "DEVICE=${eth}" > /etc/sysconfig/network-scripts/ifcfg-$eth
echo "HWADDR=${mac}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "TYPE=Ethernet" >> /etc/sysconfig/network-scripts/ifcfg-$eth
if [ $ipc -eq 0 -a $ipd -eq 0 ]; then
	echo "BOOTPROTO=dhcp" >> /etc/sysconfig/network-scripts/ifcfg-$eth
	echo "NM_CONTROLLED=yes" >> /etc/sysconfig/network-scripts/ifcfg-$eth
else
	echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-$eth
	echo "IPADDR=${ipa}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
	echo "NM_CONTROLLED=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
fi
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPADDR0=${ipa}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#PREFIX=${pre}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "NETMASK=${msk}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "GATEWAY=${gtw}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#GATEWAY0=${gtw}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "DNS1=${dns1}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "DNS2=${dns2}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#PEERROUTES=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#USERCTL=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#UUID=${uid}" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "IPV6INIT=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV6_AUTOCONF=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV6_DEFROUTE=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV6_PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV6_PEERROUTES=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV6_PRIVACY=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV6_FAILURE_FATAL=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
echo "#IPV4_FAILURE_FATAL=no" >> /etc/sysconfig/network-scripts/ifcfg-$eth
ifconfig $eth down
systemctl condrestart network.service
if [ $ipc -eq 0 -a $ipd -eq 0 ]; then
	ip link set up $eth
else
	ifconfig $eth $ipa up
fi
sleep 2
ifconfig $eth
status "IP Config" 0
exit 0
