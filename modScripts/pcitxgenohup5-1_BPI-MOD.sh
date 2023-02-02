#!/bin/bash

put_header()
{
echo -e "Dual PCI Traffic Test with NAT by Txgen, Version 1.9.1.1"
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
		check_txgen $pcount ${lnk1[$n]} ${log1[$n]}
		let sta1+=$?
		check_txgen $pcount ${lnk2[$n]} ${log2[$n]}
		let sta2+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_stat ${lnk1[$n]} post
		check_stat ${lnk2[$n]} post
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_txrx $pcount ${lnk1[$n]} ${lnk2[$n]} $multiplier
		let sta2+=$?
		check_txrx $pcount ${lnk2[$n]} ${lnk1[$n]} $multiplier
		let sta1+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		ip neigh del ${dst1[$n]} dev ${lnk1[$n]}
		ip neigh del ${dst2[$n]} dev ${lnk2[$n]}
		ip route del ${dst1[$n]} dev ${lnk1[$n]}
		ip route del ${dst2[$n]} dev ${lnk2[$n]}
		ip address del ${src1[$n]}/24 dev ${lnk1[$n]}
		ip address del ${src2[$n]}/24 dev ${lnk2[$n]}
		ip neigh flush dev ${lnk1[$n]}
		ip neigh flush dev ${lnk2[$n]}
		ip route flush dev ${lnk1[$n]}
		ip route flush dev ${lnk2[$n]}
		ip address flush dev ${lnk1[$n]}
		ip address flush dev ${lnk2[$n]}
		ip link set up ${lnk1[$n]}
		ip link set up ${lnk2[$n]}
	done
	status "Slot[$slot] TxRx" $sta1
	let stats+=$?
	status "Slot[$pair] TxRx" $sta2
	let stats+=$?
	gen_pid=$(pidof txgen)
	test -z "$gen_pid" && kill_proc pcierror.sh
	# Use global $pcibus and $crcbus
	write_err 1
	let errno=$?
	status "Slot[$slot] PCIe" $errno
	status "Slot[$pair] PCIe" $errno
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

let pcierr=0
let stats=0
test -z "$1" && try Tested_Slot
test -z "$2" && try Paired_Slot
until [ -z "$2" ] ; do
	plxbus=""
	ethbus=""
	pcibus=""
	crcbus=""
	echo
	let slot=$1
	auto_slot2net $pqty $slot # save result to 'net$1' and '$plx$1'
	test -s plx$slot && plx=$(cat plx$slot) || plx=""
	test -z "$plx" || plxbus=$(echo $plxbus $plx)
	net1p=$(cat net$slot)
	port1p=($net1p)
	shift
	let pair=$1
	let pqty=4
	auto_slot2net $pqty $pair # save result to 'net$1' and '$plx$1'
	test -s plx$pair && plx=$(cat plx$pair) || plx=""
	test -z "$plx" || plxbus=$(echo $plxbus $plx)
	net2p=$(cat net$pair)
	port2p=($net2p)
	let pqty=5
	shift
	for ((n=1; n<$pqty; ++n)) ; do
		eth1=${port1p[$n]}
		id1=$(echo $eth1 |tr -d [:alpha:])
		echo "DEBUG> eth1=$eth1 id1=$id1"
		let id1=$(($id1 % 251 + 1))
		ip1="192.168.168.$id1"
		ad1="192.168.192.$id1"
		bus1=$(cat /sys/class/net/$eth1/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
		mac1=$(cat /sys/class/net/$eth1/address)
		#mac1=00:e0:ee:ff:10:$(printf '%02x' $id1)
		lnk1[$n]=$eth1
		src1[$n]=$ip1
		dst1[$n]=$ad1
		log1[$n]=$(echo $ip1 |tr -d '.')
		eth2=${port2p[$n-1]}
		id2=$(echo $eth2 |tr -d [:alpha:])
		let id2=$(($id2 % 251 + 1))
		test "$id2" = "$id1" && let ++id2
		ip2="192.168.192.$id2"
		ad2="192.168.168.$id2"
		bus2=$(cat /sys/class/net/$eth2/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
		mac2=$(cat /sys/class/net/$eth2/address)
		#mac2=00:e0:ee:ff:20:$(printf '%02x' $id2)
		lnk2[$n]=$eth2
		src2[$n]=$ip2
		dst2[$n]=$ad2
		log2[$n]=$(echo $ip2 |tr -d '.')
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
	detect_link ${lnk1[@]} ${lnk2[@]}
	# Build global $pcibus and $crcbus
	init_pci_vf 0 $plxbus $ethbus
	# Run PCI-error Monitor for Specified PCI-buses
	pcierror.sh $pcibus &
	echo
	let sta1=0
	let sta2=0
	for ((n=1; n<$pqty; ++n)) ; do
		autonegotiation=$(txgen udp ${dst1[$n]} -b $bsize -d $nop -n $neg)
		autonegotiation=$(txgen udp ${dst2[$n]} -b $bsize -d $nop -n $neg)
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_stat ${lnk1[$n]} past
		check_stat ${lnk2[$n]} past
	done
	date
	for ((n=1; n<$pqty; ++n)) ; do
		cmd1[$n]="txgen udp ${dst1[$n]} -b $bsize -d $nop -n $pcount"
		date > ${log1[$n]}
		echo ${cmd1[$n]} |tee -a ${log1[$n]}
		nohup ${cmd1[$n]} &>>${log1[$n]} 2>&1 &
		let sta1+=$?
		test "$sta1" = "0" || status Nohup $sta1
		pid1[$n]=$!
		echo proc_id=${pid1[$n]}
		sleep 1
		cmd2[$n]="txgen udp ${dst2[$n]} -b $bsize -d $nop -n $pcount"
		date > ${log2[$n]}
		echo ${cmd2[$n]} |tee -a ${log2[$n]}
		nohup ${cmd2[$n]} &>>${log2[$n]} 2>&1 &
		let sta2+=$?
		test "$sta2" = "0" || status Nohup $sta2
		pid2[$n]=$!
		echo proc_id=${pid2[$n]}
		sleep 1
	done
	busy=$(echo ${pid1[@]} ${pid2[@]})
	test -z "$busy" || 	echo PID $busy "Ctrl+C to break"
	until [ -z "$busy" ] ; do
		for ((n=1; n<$pqty; ++n)) ; do
			job1[$n]=$(ps -A |grep -w ${pid1[$n]})
			job2[$n]=$(ps -A |grep -w ${pid2[$n]})
		done
		busy=$(echo ${job1[@]} ${job2[@]})
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_txgen $pcount ${lnk1[$n]} ${log1[$n]}
		let sta1+=$?
		check_txgen $pcount ${lnk2[$n]} ${log2[$n]}
		let sta2+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_stat ${lnk1[$n]} post
		check_stat ${lnk2[$n]} post
	done
	for ((n=1; n<$pqty; ++n)) ; do
		check_txrx $pcount ${lnk1[$n]} ${lnk2[$n]} $multiplier
		let sta2+=$?
		check_txrx $pcount ${lnk2[$n]} ${lnk1[$n]} $multiplier
		let sta1+=$?
	done
	for ((n=1; n<$pqty; ++n)) ; do
		ip neigh del ${dst1[$n]} dev ${lnk1[$n]}
		ip neigh del ${dst2[$n]} dev ${lnk2[$n]}
		ip route del ${dst1[$n]} dev ${lnk1[$n]}
		ip route del ${dst2[$n]} dev ${lnk2[$n]}
		ip address del ${src1[$n]}/24 dev ${lnk1[$n]}
		ip address del ${src2[$n]}/24 dev ${lnk2[$n]}
		ip neigh flush dev ${lnk1[$n]}
		ip neigh flush dev ${lnk2[$n]}
		ip route flush dev ${lnk1[$n]}
		ip route flush dev ${lnk2[$n]}
		ip address flush dev ${lnk1[$n]}
		ip address flush dev ${lnk2[$n]}
		ip link set up ${lnk1[$n]}
		ip link set up ${lnk2[$n]}
	done
	status "Slot[$slot] TxRx" $sta1
	let stats+=$?
	status "Slot[$pair] TxRx" $sta2
	let stats+=$?
	gen_pid=$(pidof txgen)
	test -z "$gen_pid" && kill_proc pcierror.sh
	# Use global $pcibus and $crcbus
	write_err 1
	let errno=$?
	status "Slot[$slot] PCIe" $errno
	status "Slot[$pair] PCIe" $errno
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
