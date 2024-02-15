#!/bin/bash

put_header()
{
echo -e "NIC Traffic Test by Pktgen, Version 1.9.0.1"
echo -e "Written by Arsen Sogomonyan, arsens@silicom.co.il"
echo -e "Copyright (C) 2019, by Silicom Ltd. All rights reserved."
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

initialize_pktgen()
{
	local pcount clone pktsize nop eth1 eth2 
	local id1 id2 mac1 mac2 core1 core2
	test -z "$1" && try pcount || pcount=$1
	shift
	test -z "$1" && try clone || clone=$1
	shift
	test -z "$1" && try pktsize || pktsize=$1
	shift
	test -z "$1" && try nop || nop=$1
	shift
	test -z "$1" && try eth1 || eth1=$1
	test -z "$2" && try eth2 || eth2=$2
	id1=$(echo $eth1 |tr -d [:alpha:])
	let id1=$(($id1 % 251 + 1))
	id2=$(echo $eth2 |tr -d [:alpha:])
	let id2=$(($id2 % 251 + 1))
	test "$id2" = "$id1" && let ++id2
	mac1=$(cat /sys/class/net/$eth1/address)
	mac2=$(cat /sys/class/net/$eth2/address)
	#mac1=00:e0:ee:ff:10:$(printf '%02x' $id1)
	#mac2=00:e0:ee:ff:20:$(printf '%02x' $id2)
	try Source_MAC $mac1
	try Target_MAC $mac2
	echo "> Setting up link"
	ip link set up $eth1 mtu 1500 #promisc on
	ip link set up $eth2 mtu 1500 #promisc on
	let core1=id1%ncpus
	let core2=id2%ncpus
	PGDEV=/proc/net/pktgen/kpktgend_$core1
	echo "> Adding $eth1 to pktgen"
	pgset "add_device $eth1"
	PGDEV=/proc/net/pktgen/$eth1
	pgset "count $pcount"
	pgset "clone_skb $clone"
	pgset "pkt_size $pktsize"
	pgset "dst $eth2"
	pgset "dst_mac $mac2"
	pgset "delay $nop"
	pgset "flag QUEUE_MAP_CPU"
	#pgset "burst 1"
	PGDEV=/proc/net/pktgen/kpktgend_$core2
	echo "> Adding $eth2 to pktgen"
	pgset "add_device $eth2"
	PGDEV=/proc/net/pktgen/$eth2
	pgset "count $pcount"
	pgset "clone_skb $clone"
	pgset "pkt_size $pktsize"
	pgset "dst $eth1"
	pgset "dst_mac $mac1"
	pgset "delay $nop"
	pgset "flag QUEUE_MAP_CPU"
	#pgset "burst 1"
}

check_transceiver()
{
	local sta pcount minSpeed
	test -z "$1" && try pcount || pcount=$1
	test -z "$2" && try minSpeed || minSpeed=$2
	echo "> Checking trasmission results"
	check_transmitter $pcount $minSpeed $ethlist1 $ethlist2
	let sta=$?
	lnk1=($ethlist1)
	lnk2=($ethlist2)
	for ((n=0; n<${#lnk1[@]}; n++)) ; do
		echo "> Checking stats ${lnk1[$n]}"
		check_stat ${lnk1[$n]} post
		echo "> Checking stats ${lnk2[$n]}"
		check_stat ${lnk2[$n]} post
		echo "> Checking txrx ${lnk1[$n]} ${lnk2[$n]}"
		check_txrx $pcount ${lnk1[$n]} ${lnk2[$n]} $multiplier
		let sta+=$?
		echo "> Checking txrx ${lnk2[$n]} ${lnk1[$n]}"
		check_txrx $pcount ${lnk2[$n]} ${lnk1[$n]} $multiplier
		let sta+=$?
	done
	#echo "> Killing pktgen ($pg_start)"
	#pg_clean $pg_start
	return $sta
}

function ctrl_c()
{
	echo
	echo "Trapped Ctrl+C"
	echo
	kill_proc $pg_start
	pg_pid=$(pidof -x "$pg_start")
	test -z "$pg_pid" && rm -f "$pg_start"
	PGDEV=/proc/net/pktgen/pgctrl
	pgset "stop" 
	echo Stop
	# Use global $ethlist1 and $ethlist2
	check_transceiver $pcount $minSpeed
	status "Pktgen Test" $?
	exit $?
}

trap ctrl_c SIGINT

pg_start="pg_start.sh"

ethlist1=""
ethlist2=""

let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
try CPU_Qty $ncpus

try Packet_Count $1
let pcount=$1
shift
let ppm=1+$pcount/1000001
test "$pcount" = "0" && let ppm=10
let clone=100000
let pktsize=1514
let multiplier=1
let mayberror=$multiplier*$ppm*1
let maybedrop=$multiplier*$ppm*1
let maybelost=$multiplier*$ppm*9 #include autonegotiation
echo mayberror=$mayberror
echo maybedrop=$maybedrop
echo maybelost=$maybelost
try Delay $1
let nop=$1
shift
try "Min_Speed(Mb/sec)" $1
let minSpeed=$1
shift

test -z "$1" && try Source_NIC
test -z "$2" && try Target_NIC

echo "> Loading pktgen module"
lsmod | grep pktgen || {
	echo "> pktgen not loaded, loading"
	modprobe pktgen || {
		echo -e "\033[;31m FAIL!!! Cannot load pktgen.ko!\033[0m"
		exit 1
	}
}
test -x "$pg_start" || {
	echo "> Starting pktgen"
	pg_create $pg_start
	echo "> Clearing pktgen"
	pg_clear
}
sleep 0.9

until [ -z "$2" ] ; do
	eth1=$1
	eth2=$2
	shift
	shift
	is_double_net $eth1 $eth2
	try Source_Net $eth1
	try Target_Net $eth2
	echo "> Initializing pktgen ($pcount $clone $pktsize $nop $eth1 $eth2)"
	initialize_pktgen $pcount $clone $pktsize $nop $eth1 $eth2
	# Increment global lists
	ethlist1=$(echo $ethlist1 $eth1)
	ethlist2=$(echo $ethlist2 $eth2)
done
echo "> Detecting link $ethlist1 $ethlist2"
detect_link $ethlist1 $ethlist2
for eth in $ethlist1 $ethlist2 ; do
	echo "> Check stat $eth"
	check_stat $eth past
done
test -x "$pg_start" || {
	echo "> pktgen creating2"
	pg_create $pg_start
}
sleep 0.9
echo
echo "Tested Eth_Net="$ethlist1 $ethlist2
echo Start
test -x "$pg_start" || {
	echo "> pktgen creating3"
	pg_create $pg_start
}
echo "> pktgen start2"
pg_pid=$(pidof -x "$pg_start")
while [ -z "$pg_pid" ] ; do
	test -x "$pg_start" || {
		echo "> pktgen creating4"
		pg_create $pg_start
	}
	echo -n "."
	./$pg_start &
	pg_pid=$(pidof -x "$pg_start")
done
echo
echo PID $pg_pid "Ctrl+C to break"
echo
until [ -z "$pg_pid" ] ; do
	sleep 0.1
	pg_pid=$(pidof -x "$pg_start")
done
echo Stop
sleep 0.9
test -z "$pg_pid" && rm -f "$pg_start"
# Use global $ethlist1 and $ethlist2
echo "> Checking transmission results2"
check_transceiver $pcount $minSpeed
status "Pktgen Test" $?
exit $?
