#!/bin/bash

put_header()
{
echo -e "Advanced synchronous data transfer test, Version 2.0.0.0"
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
	# Duplicated from the end of script
	for ((n=0; n<$num; n+=$inc)) ; do
		check_txgen $pcount ${lnk[$n]} ${log[$n]}
		let stats+=$?
	done
	for ((n=0; n<$num; ++n)) ; do
		check_stat ${lnk[$n]} post
	done
	for ((n=0,k=1; k<$num; n+=2,k+=2)) ; do
		if [ "$cval" -eq "0" ] ; then check_txrx $pcount ${lnk[$n]} ${lnk[$k]} $multiplier
		else check_loop $pcount ${lnk[$n]} $multiplier ; fi
		let stats+=$?
		test "$dir" -le "2" || {
			if [ "$cval" -eq "0" ] ; then check_txrx $pcount ${lnk[$k]} ${lnk[$n]} $multiplier
			else check_loop $pcount ${lnk[$k]} $multiplier ; fi
		}
		let stats+=$?
	done
	for ((n=0; n<$num; ++n)) ; do
		ip neigh del ${dst[$n]} dev ${lnk[$n]}
		ip route del ${dst[$n]} dev ${lnk[$n]}
		ip address del ${src[$n]}/24 dev ${lnk[$n]}
		ip neigh flush dev ${lnk[$n]}
		ip route flush dev ${lnk[$n]}
		ip address flush dev ${lnk[$n]}
		ip link set dev ${lnk[$n]} up
	done
	date
	test -z "$pci" && {
		status "Slot[$SLOTS] Txgen Test" $stats
		exit $?
	}
	gen_pid=$(pidof txgen)
	test -z "$gen_pid" && kill_proc pcierror.sh 2>&1
	# Use global $pcibus and $crcbus
	test -n "$pci" -a "$pci" != "x" -a "$pci" != "X" && {
		write_noaux 1
		let pcierr=$?
	}
	test "$pci" = "x" -o "$pci" = "X" && {
		write_err 1
		let pcierr=$?
	}
	echo "Loop counter is $count"
	echo
	status "Slot[$SLOTS] Bus Error Test" $pcierr
	status "Slot[$SLOTS] Txgen Test" $stats
	let stats+=pcierr
	status "Slot[$SLOTS] PCI Test" $stats
	exit $?
}

trap ctrl_c SIGINT

which nohup > /dev/null || try nohup
which txgen > /dev/null || try txgen

let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
try CPU_Qty $ncpus

args=$@
for s in $args ; do
	test "${s:0:1}" = '-' -a "${s:1:1}" != '-' && {
		let numbus=$(echo $s |cut -d- -f2)
		shift
	}
	test "${s:0:1}" = '-' -a "${s:1:1}" = '-' && {
		let tval=$(echo $s |cut -d- -f3)
		test -n "$tval" && try Link_timeout_sec $tval
		shift
	}
	test "${s:0:1}" = '/' && {
		let lval=$(echo $s |cut -d/ -f2)
		test -n "$lval" && try Maybelost_in_ppm $lval
		shift
	}
	test "${s:0:1}" = ':' && {
		let cval=$(echo $s |cut -d: -f2)
		extra=${s:2:1}
		shift
	}
done
test -n "$tval" || tval=""
test -n "$lval" || let lval=9
test -n "$cval" || cval="0"

try "Mode[1|2|3|4]" $1
pci=${1:1:1}
let dir=$1
shift
try Mode_detected $dir
test "$dir" -eq "1" && echo "Source => Target unidirectional mode enabled" && let inc=2
test "$dir" -eq "2" && echo "Target <= Source unidirectional mode enabled" && let inc=2
test "$dir" -eq "3" && echo "Bi-directional common mode enabled" && let inc=1
test "$dir" -eq "4" && echo "Bi-directional port-to-port mode enabled" && let inc=1
test "$dir" -gt "4" && try Mode 0
test -n "$pci" && echo "PCI traffic error register check mode enabled"
test "$pci" = "x" -o "$pci" = "X" && echo "Auxiliary power error bit check mode enabled"
test "$pci" = "X" && extra="X"
test -n "$cval" -a "$cval" -ne "0" && echo "Loopback mode enabled"

let tcount=1
let pcount=$1
try Packet_Count $pcount
shift
try Delay $1
let nop=$1
shift
let ppm=$((1 + $pcount / 1000001))
let multiplier=1
let mayberror=$(($tcount * $multiplier * $ppm * 1))
let maybedrop=$(($tcount * $multiplier * $ppm * 1))
let maybelost=$(($tcount * $multiplier * $ppm * $lval))
echo mayberror=$mayberror
echo maybedrop=$maybedrop
echo maybelost=$maybelost
let dsize=1450
let bsize=450000

test "$dir" -lt "4" && {
	let pqty=$1
	try Port_Qty $pqty
	shift
	try OrderFile $1
	orderfile=$1
	shift
	test -s "$orderfile" || try OrderFile 0
	order=$(cat $orderfile)
	echo order=$order
	order=($order)
	let odd=${#order[@]}%2
	opt=""
	test "$odd" = "0" -a "${#order[@]}" = "$pqty" && opt=n
	test "$odd" = "1" -a "${#order[@]}" = "$pqty" && opt=v
	test "$odd" = "0" -a "${#order[@]}" = "$((pqty-1))" && opt=m
	test -z "$opt"  && try "order in file" 0
	test "$opt" = "n" && {
		echo General mode enabled
		let lo=0
		let hi=$pqty
	}
	test "$opt" = "v" && {
		echo Virtual port enabled
		let lo=1
		let hi=$pqty
	}
	test "$opt" = "m" && {
		echo Management port excluded
		let lo=0
		let hi=$pqty-1
	}
}
test "$dir" -eq "4" && {
	let lo=0
	let hi=2
	let pqty=0
	let snum=$1
	try Source_Port $snum
	shift
	let tnum=$1
	try Target_Port $tnum
	shift
}
let num=0
let stats=1
# test -z "$1" && try Tested_Slot
#removed, instead nets have to be provided to the script
netsArg=$*
test -n "$2" -a -z "$extra" && extra=X
test "$extra" = "x" -o "$extra" = "X" && echo "Advanced mode enabled"
SLOTS=$(echo $@ |tr ' ' ',')
echo
plxbus=""
ethbus=""
pcibus=""
crcbus=""
let pcierr=0
# for slot in $@ ; do
#for slot in $netsArg ; do
	# auto_slot2net $pqty $slot # save result to 'net$slot'; 'plx$slot' and 'pep$slot'
	# test -s plx$slot && plx=$(cat plx$slot) || plx=""
	# test -z "$plx" || plxbus=$(echo $plxbus $plx)
	# net=$(cat net$slot)
	# ports=($net)
	ports=($netsArg)
	echo "nets: $netsArg  lo=$lo  hi=$hi  dir=$dir"
	for ((j=$lo; j<$hi; ++j)) ; do
		echo "processing j:$j "
		test "$dir" -lt "4" && {
			let n=${order[$j]}-1
			test "$dir" -ne "2" && eth1=${ports[$n]} || eth2=${ports[$n]}
			let ++j
			let n=${order[$j]}-1
			test "$dir" -ne "2" && eth2=${ports[$n]} || eth1=${ports[$n]}
		}
		test "$dir" -eq "4" && {
			eth1=$(echo $net |cut -d' ' -f $snum)
			let ++j
			eth2=$(echo $net |cut -d' ' -f $tnum)
		}
		echo "  eth1=$eth1  eth2=$eth2"
		is_double_net $eth1 $eth2
		id1=$(echo $eth1 |cut -d. -f2 |tr -d [:alpha:])
		let id1=$(($id1 % 127 + 1))
		id2=$(echo $eth2 |cut -d. -f2 |tr -d [:alpha:])
		let id2=$(($id2 % 127 + 128))
		echo "  id1=$id1  id2=$id2"
		ip1="192.1$(cut -c1<<<"$j")0.$id1.$id1"
		ad1="192.1$(cut -c1<<<"$j")0.$id2.$id1"
		ip2="192.1$(cut -c1<<<"$j")0.$id2.$id2"
		ad2="192.1$(cut -c1<<<"$j")0.$id1.$id2"
		mac1=$(cat /sys/class/net/$eth1/address)
		mac2=$(cat /sys/class/net/$eth2/address)
		# mac1=00:e0:ee:ff:10:$(printf '%02x' $id1)
		# ip link set $eth1 address $mac1
		# mac2=00:e0:ee:ff:20:$(printf '%02x' $id2)
		# ip link set $eth2 address $mac2
		lnk[$num]=$eth1
		src[$num]=$ip1
		dst[$num]=$ad1
		log[$num]=$ad1
		let ++num
		lnk[$num]=$eth2
		src[$num]=$ip2
		dst[$num]=$ad2
		log[$num]=$ad2
		let ++num
		# test -n "$pci" && {
		# 	bus1=$(cat /sys/class/net/$eth1/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
		# 	bus2=$(cat /sys/class/net/$eth2/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
		# 	ethbus=$(echo $ethbus $bus1 $bus2)
		# 	try Target_Bus $bus2
		# 	try Source_Bus $bus1
		# }
		try Source_Net $eth1
		try Source_MAC $mac1
		try Source_IP1 $ip1
		try Source_IP2 $ad1
		try Target_Net $eth2
		try Target_MAC $mac2
		try Target_IP1 $ip2
		try Target_IP2 $ad2
		ip address add $ip1/24 brd + dev $eth1 ;echo " Adding $ip1/24 on $eth1"
		ip address add $ip2/24 brd + dev $eth2 ;echo " Adding $ip2/24 on $eth2"
		ip link set dev $eth1 up mtu 1500 promisc off
		ip link set dev $eth2 up mtu 1500 promisc off
		iptables -t nat -A POSTROUTING -s $ip1 -d $ad1 -j SNAT --to-source $ad2 ;echo " Setting NAT postroute SNAT Source:$ip1 to destination: $ad2"
		iptables -t nat -A PREROUTING -d $ad2 -j DNAT --to-destination $ip1 ;echo " Setting NAT preroute DNAT destination:$ad2 forward to destination: $ip1"
		iptables -t nat -A POSTROUTING -s $ip2 -d $ad2 -j SNAT --to-source $ad1 ;echo " Setting NAT postroute SNAT Source:$ip2 to destination: $ad1"
		iptables -t nat -A PREROUTING -d $ad1 -j DNAT --to-destination $ip2 ;echo " Setting NAT preroute DNAT destination:$ad1 forward to destination: $ip2"
		ip route add $ad1 dev $eth1 ;echo " Adding route $ad1 on dev $eth1"
		ip neigh add $ad1 lladdr $mac2 dev $eth1 ;echo " Adding neighbour lladdr $mac2 for $ad1 on dev $eth1"
		ip route add $ad2 dev $eth2 ;echo " Adding route $ad2 on dev $eth2"
		ip neigh add $ad2 lladdr $mac1 dev $eth2 ;echo " Adding neighbour lladdr $mac1 for $ad2 on dev $eth2"
		echo
	done
#done
test -z "$tval" && detect_link ${lnk[@]} || link_detect $tval ${lnk[@]}
test -n "$extra" && {
	set_channels $tcount ${lnk[@]}
	get_channels $tcount ${lnk[@]}
	status "Channel parameters" $?
	set_maxring ${lnk[@]}
	is_maxring ${lnk[@]}
	status "Ring parameters" $?
}
test -n "$pci" && {
	which pcierror.sh > /dev/null || try pcierror.sh
	# Build global $pcibus and $crcbus
	test -z "$numbus" && let numbus=0
	init_pcibus $numbus $plxbus $ethbus
	# Run PCI-error Monitor for Specified PCI-buses
	pcierror.sh $pcibus &
	echo
}
for ((n=0; n<$num; ++n)) ; do 
	check_stat ${lnk[$n]} past
done
date
let stats=0
test "$extra" = "X" && {
	stop_irqbalance
	get_irqbalance
}
for ((n=0; n<$num; n+=$inc)) ; do
	test "$extra" = "X" && {
		let c=$(($n % $ncpus))
		set_affinity $c ${lnk[$n]}
		test "$c" -lt "10" && let p=${tcount}0${c}0${c} || let p=${tcount}${c}${c}
		cmd[$n]="taskset -c $c txgen -p $p ${dst[$n]} -e udp -l $dsize -b $bsize -d $nop -n $pcount"
	}
	test "$extra" != "X" && cmd[$n]="txgen ${dst[$n]} -e udp -l $dsize -b $bsize -d $nop -n $pcount"
	date > ${log[$n]}
	echo ${cmd[$n]} |tee -a ${log[$n]}
	nohup ${cmd[$n]} &>>${log[$n]} 2>&1 &
	let stats+=$?
	test "$stats" = "0" || status Nohup $stats
	pid[$n]=$!
	echo proc_id=${pid[$n]}
	sleep 1
done
busy=$(echo ${pid[@]})
test -z "$busy" || 	echo PID $busy "Ctrl+C to break"
until [ -z "$busy" ] ; do
	for ((n=0; n<$num; n+=$inc)) ; do
		job[$n]=$(ps -A |grep -w ${pid[$n]})
	done
	busy=$(echo ${job[@]})
done
#let num=$(($num/2))
let pcount2=$(($pcount*2))
# Remember to duplicate any subsequent changes to the ctrl_c() function
for ((n=0; n<$num; n+=$inc)) ; do
	check_txgen $pcount ${lnk[$n]} ${log[$n]}
	let stats+=$?
done
for ((n=0; n<$num; ++n)) ; do
	check_stat ${lnk[$n]} post
done
for ((n=0,k=1; k<$num; n+=2,k+=2)) ; do
	if [ "$cval" -eq "0" ] ; then 
		echo -e " Checking txrx (\033[0;33m${lnk[$n]}\033[m ==> \033[0;33m${lnk[$k]}\033[m)"
		check_txrx $pcount2 ${lnk[$n]} ${lnk[$k]} $multiplier
	else 
		echo " Checking loop ($pcount2 ${lnk[$n]} $multiplier)"
		check_loop $pcount2 ${lnk[$n]} $multiplier
	fi
	let stats+=$?
	test "$dir" -le "2" || {
		if [ "$cval" -eq "0" ] ; then 
			echo -e " Checking txrx2 (\033[0;33m${lnk[$k]}\033[m ==> \033[0;33m${lnk[$n]}\033[m)"
			check_txrx $pcount2 ${lnk[$k]} ${lnk[$n]} $multiplier
		else 
			echo " Checking loop2 ($pcount2 ${lnk[$k]} $multiplier)"
			check_loop $pcount2 ${lnk[$k]} $multiplier
		fi
	}
	let stats+=$?
done
for ((n=0; n<$num; ++n)) ; do
	devExist="$(ip a show dev ${lnk[$n]} |grep ${src[$n]} 2>/dev/null)"
	if [ ! -z "$devExist" ]; then
		ip neigh del ${dst[$n]} dev ${lnk[$n]}
		ip route del ${dst[$n]} dev ${lnk[$n]}
		ip address del ${src[$n]}/24 dev ${lnk[$n]}
		ip neigh flush dev ${lnk[$n]}
		ip route flush dev ${lnk[$n]}
		ip address flush dev ${lnk[$n]}
		ip link set dev ${lnk[$n]} up
	fi
done
date
test -z "$pci" && {
	status "Slot[$SLOTS] Txgen Test" $stats
	exit $?
}
gen_pid=$(pidof txgen)
test -z "$gen_pid" && kill_proc pcierror.sh 2>&1
# Use global $pcibus and $crcbus
test -n "$pci" -a "$pci" != "x" -a "$pci" != "X" && {
	write_noaux 1
	let pcierr=$?
}
test "$pci" = "x" -o "$pci" = "X" && {
	write_err 1
	let pcierr=$?
}
echo "Loop counter is $count"
echo
status "ETH List[$SLOTS] Bus Error Test" $pcierr
status "ETH List[$SLOTS] Txgen Test" $stats
let stats+=pcierr
status "ETH List[$SLOTS] PCI Test" $stats
exit $?
