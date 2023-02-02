#!/bin/bash

put_header()
{
echo -e "PCI Traffic Test with NAT by Txgen, Version 1.9.1.1"
echo -e "Written by Arsen Sogomonyan, arsens@silicom.co.il"
echo -e "Copyright (C) 2020, by Silicom Ltd. All rights reserved."
echo -e "____________________________________________________________"
echo -e ""
}

test -z "$(echo $PATH |grep "$PWD:")" && export PATH=$PWD:$PATH
name=library.sh
lib=$(which $name)
test ! -z "$lib" || { 
echo -e "\e[0;31mUndefined $name\e[m"
exit 1
}
test -s "$lib" || {
echo -e "\e[0;31mIllegal $name\e[m"
exit 1
}
source $lib
put_header

function ctrl_c()
{
	echo
	echo "Trapped Ctrl+C"
	echo
	kill_pid $busy
	for ((n=1; n<$pqty; ++n)) ; do
		check_txgen $pcount ${lnk[$n]} ${log[$n]}
		let sta+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_stat ${lnk[$n]} post
	done
	for ((n=1,k=2; k<$pqty; n+=2,k+=2)) ; do
		check_txrx $pcount ${lnk[$n]} ${lnk[$k]} $multiplier
		let sta+=$?
		check_txrx $pcount ${lnk[$k]} ${lnk[$n]} $multiplier
		let sta+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		ip neigh del ${dst[$n]} dev ${lnk[$n]}
		ip route del ${dst[$n]} dev ${lnk[$n]}
		ip address del ${src[$n]}/24 dev ${lnk[$n]}
		ip neigh flush dev ${lnk[$n]}
		ip route flush dev ${lnk[$n]}
		ip address flush dev ${lnk[$n]}
		ip link set up ${lnk[$n]}
	done
	status "Slot[$slot] TxRx" $sta
	let stats+=$?
	gen_pid=$(pidof txgen)
	test -z "$gen_pid" && kill_proc pcierror.sh
	# Use global $pcibus and $crcbus
	write_err 1
	let errno=$?
	status "Slot[$slot] PCIe" $errno
	let pcierr+=$errno
	echo "Loop counter is $count"
	echo
	status "Bus Error Test" $pcierr
	status "Txgen Test" $stats
	let stats+=pcierr
	status "PCI Test" $stats
	exit $?
}

trap ctrl_c SIGINT

which nohup > /dev/null || try nohup
which txgen > /dev/null || try txgen

let pcount=$1
try Packet_Count $pcount
shift
let ppm=1+$pcount/1000001
let neg=1000
let multiplier=1
let mayberror=$multiplier*$ppm*1
let maybedrop=$multiplier*$ppm*1
let maybelost=$multiplier*$ppm*50 #include autonegotiation
echo mayberror=$mayberror
echo maybedrop=$maybedrop
echo maybelost=$maybelost
try Delay $1
let nop=$1
shift
let bsize=$1
try Buffer_Size $bsize
shift
let pqty=$1
try Port_Qty $pqty
shift
try OrderFile $1
orderfile=$1
test -s "$orderfile" || try OrderFile 0
order=$(cat $orderfile)
echo order=$order
order=($order)
let odd=${#order[@]}%2
# test "${#order[@]}" = "$pqty" && test "$odd" = "1" || try OrderFile 0
shift

let pcierr=0
let stats=0
test -z "$1" && try Tested_Slot
for slot in $@ ; do
	plxbus=""
	ethbus=""
	pcibus=""
	crcbus=""
	echo
	auto_slot2net $pqty $slot # save result to 'net$1' and '$plx$1'
	test -s plx$slot && plx=$(cat plx$slot) || plx=""
	test -z "$plx" || plxbus=$(echo $plxbus $plx)
	net=$(cat net$slot)
	ports=($net)
	for ((j=1; j<$pqty; ++j)) ; do
		let n=${order[$j]}-1
		eth1=${ports[$n]}
		id1=$(echo $eth1 |tr -d [:alpha:])
		let id1=$(($id1 % 251 + 1))
		ip1="192.168.168.$id1"
		ad1="192.168.192.$id1"
		bus1=$(cat /sys/class/net/$eth1/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
		mac1=$(cat /sys/class/net/$eth1/address)
		#mac1=00:e0:ee:ff:10:$(printf '%02x' $id1)
		lnk[$j]=$eth1
		src[$j]=$ip1
		dst[$j]=$ad1
		log[$j]=$(echo $ip1 |tr -d '.')
		let ++j
		let n=${order[$j]}-1
		eth2=${ports[$n]}
		id2=$(echo $eth2 |tr -d [:alpha:])
		let id2=$(($id2 % 251 + 1))
		test "$id2" = "$id1" && let ++id2
		ip2="192.168.192.$id2"
		ad2="192.168.168.$id2"
		bus2=$(cat /sys/class/net/$eth2/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
		mac2=$(cat /sys/class/net/$eth2/address)
		#mac2=00:e0:ee:ff:20:$(printf '%02x' $id2)
		lnk[$j]=$eth2
		src[$j]=$ip2
		dst[$j]=$ad2
		log[$j]=$(echo $ip2 |tr -d '.')
		try Source_Net $eth1
		try Source_Bus $bus1
		try Source_MAC $mac1
		try Source_IP1 $ip1
		try Source_IP2 $ad1
		try Target_Net $eth2
		try Target_Bus $bus2
		try Target_MAC $mac2
		try Target_IP1 $ip2
		try Target_IP2 $ad2
		ip address add $ip1/24 brd + dev $eth1
		ip address add $ip2/24 brd + dev $eth2
		ip link set up $eth1 mtu 1500 #promisc on
		ip link set up $eth2 mtu 1500 #promisc on
		iptables -t nat -A POSTROUTING -s $ip1 -d $ad1 -j SNAT --to-source $ad2
		iptables -t nat -A PREROUTING -d $ad2 -j DNAT --to-destination $ip1
		iptables -t nat -A POSTROUTING -s $ip2 -d $ad2 -j SNAT --to-source $ad1
		iptables -t nat -A PREROUTING -d $ad1 -j DNAT --to-destination $ip2
		ip route add $ad1 dev $eth1
		ip neigh add $ad1 lladdr $mac2 dev $eth1 #arp -i $eth1 -s $ad1 $mac2
		ip route add $ad2 dev $eth2
		ip neigh add $ad2 lladdr $mac1 dev $eth2 #arp -i $eth2 -s $ad2 $mac1
		ethbus=$(echo $ethbus $bus1 $bus2)
		echo
	done
	detect_link ${lnk[@]}
	# Build global $pcibus and $crcbus
	init_pci_vf 0 $plxbus $ethbus
	# Run PCI-error Monitor for Specified PCI-buses
	pcierror.sh $pcibus &
	echo
	let sta=0
	for ((n=1; n<$pqty; ++n)) ; do
		autonegotiation=$(txgen udp ${dst[$n]} -b $bsize -d $nop -n $neg)
	done
	for ((n=1; n<$pqty; ++n)) ; do 
		check_stat ${lnk[$n]} past
	done
	date
	for ((n=1; n<$pqty; ++n)) ; do
		cmd[$n]="txgen udp ${dst[$n]} -b $bsize -d $nop -n $pcount"
		date > ${log[$n]}
		echo ${cmd[$n]} |tee -a ${log[$n]}
		nohup ${cmd[$n]} &>>${log[$n]} 2>&1 &
		let sta+=$?
		test "$sta" = "0" || status Nohup $sta
		pid[$n]=$!
		echo proc_id=${pid[$n]}
		sleep 1
	done
	busy=$(echo ${pid[@]})
	test -z "$busy" || 	echo PID $busy "Ctrl+C to break"
	until [ -z "$busy" ] ; do
		for ((n=1; n<$pqty; ++n)) ; do
			job[$n]=$(ps -A |grep -w ${pid[$n]})
		done
		busy=$(echo ${job[@]})
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_txgen $pcount ${lnk[$n]} ${log[$n]}
		let sta+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_stat ${lnk[$n]} post
	done
	for ((n=1,k=2; k<$pqty; n+=2,k+=2)) ; do
		check_txrx $pcount ${lnk[$n]} ${lnk[$k]} $multiplier
		let sta+=$?
		check_txrx $pcount ${lnk[$k]} ${lnk[$n]} $multiplier
		let sta+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		ip neigh del ${dst[$n]} dev ${lnk[$n]}
		ip route del ${dst[$n]} dev ${lnk[$n]}
		ip address del ${src[$n]}/24 dev ${lnk[$n]}
		ip neigh flush dev ${lnk[$n]}
		ip route flush dev ${lnk[$n]}
		ip address flush dev ${lnk[$n]}
		ip link set up ${lnk[$n]}
	done
	status "Slot[$slot] TxRx" $sta
	let stats+=$?
	gen_pid=$(pidof txgen)
	test -z "$gen_pid" && kill_proc pcierror.sh
	# Use global $pcibus and $crcbus
	write_err 1
	let errno=$?
	status "Slot[$slot] PCIe" $errno
	let pcierr+=$errno
	echo "Loop counter is $count"
	date
done
echo
status "Bus Error Test" $pcierr
status "Txgen Test" $stats
let stats+=pcierr
status "PCI Test" $stats
exit $?
