#!/bin/bash

echo -e "____________________________________________________________"
echo -e ""
echo -e "Library for Network Functional Testing, Version 2.0.0.6"
echo -e "Written by Arsen Sogomonyan, arsens@silicom.co.il"
echo -e "Copyright (C) 2020, by Silicom Ltd. All rights reserved."
echo -e "____________________________________________________________"
echo -e ""

let count=0
let cerr1=0
let cerr2=0
let cerr3=0
let cerr4=0
let cerr5=0
let cerr6=0
let cerr7=0
let cerr8=0

test -z "$(echo $PATH |grep "$PWD:")" && export PATH=$PWD:$PATH
# plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
# test -z "$plxbuses" || echo plxbuses=$plxbuses
# accbuses=$(grep '0b40' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
# test -z "$accbuses" || echo accbuses=$accbuses
# nvmbuses=$(grep '0108' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
# test -z "$nvmbuses" || echo nvmbuses=$nvmbuses
# netbuses=$(grep '0280' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
# test -z "$netbuses" || echo netbuses=$netbuses
# ethbuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
# test -z "$ethbuses" || echo ethbuses=$ethbuses
# phybuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2 |uniq)
# test -z "$phybuses" || echo phybuses=$phybuses
# devices=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep net |awk -F/ '{print $NF}')
# test -z "$devices" || echo devices=$devices
# PCIeBus=$(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3)
# echo PCIeBus=$PCIeBus

# Version 1.0.0.21
try()
{
	local name=$1
	shift
	if [ -z "$1" ] ; then
		echo -e "\e[0;31mUndefined $name\e[m"
		if [[ -z "$noExit" ]]; then exit 1;	fi
	elif [ "$1" = "0" ] ; then
		echo -e "\e[0;31mIllegal $name\e[m"
		if [[ -z "$noExit" ]]; then exit 1;	fi
	else
		echo "$name="$@
	fi
	return 0
}

# Version 1.0.0.0
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

# Version 1.0.2.4
approve_motherboard()
{
	which dmidecode > /dev/null || try dmidecode
	local brd mbrd
	test -z "$1" && mbrd="X10DRi" || mbrd="$1"
	brd=$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)
	try Motherboard $brd
	test "$brd" = "$mbrd" || try Motherboard 0
}

# Version 1.0.0.0
pg_clear()
{
	local list
	local core
	list=$(ls /proc/net/pktgen | grep kpktgend)
	for core in $list ; do
		PGDEV=/proc/net/pktgen/$core
		pgset "rem_device_all"
	done
}

# Version 1.0.0.0
pgset()
{
	local result
	echo $1 > $PGDEV
	result=$(cat $PGDEV | fgrep "Result: OK:")
	if [ "$result" = "" ] ; then
		cat $PGDEV | fgrep Result:
	fi
	return 0
}

# Version 1.0.0.21
pg_create()
{
	local pg_start="$1"
	test -z "$pg_start" && try File_Name
	echo '#!/bin/bash' > $pg_start
	echo '' >> $pg_start
	echo 'trap ctrl_c SIGINT' >> $pg_start
	echo '' >> $pg_start
	echo 'function ctrl_c()' >> $pg_start
	echo '{' >> $pg_start
	echo '    echo' >> $pg_start
	echo '    echo "Trapped Ctrl+C"' >> $pg_start
	echo '    echo' >> $pg_start
	echo '    echo "stop" > /proc/net/pktgen/pgctrl' >> $pg_start
	echo '    exit 1' >> $pg_start
	echo '}' >> $pg_start
	echo '' >> $pg_start
	echo 'echo' >> $pg_start
	echo 'echo "Running... Ctrl+C to break"' >> $pg_start
	echo 'echo' >> $pg_start
	echo 'echo "start" > /proc/net/pktgen/pgctrl' >> $pg_start
	#echo 'echo "stop" > /proc/net/pktgen/pgctrl' >> $pg_start
	echo 'exit 0' >> $pg_start
	chmod 755 $pg_start
}

# Version 1.0.0.45
pg_clean()
{
	local core result=0
	local pg_start=$1
	test -z "$pg_start" && pg_start="pg_start.sh"
	test -s "$pg_start" && kill_proc $pg_start
	uload_mod pktgen
	sleep 1
	load_mod pktgen
	sleep 1
	test -f "$pg_start" && rm -f "$pg_start"
	PGDEV=/proc/net/pktgen/pgctrl
	pgset "stop"
	echo Stop
	list=$(ls /proc/net/pktgen | grep kpktgend)
	for core in $list ; do
		kill_proc kpktgend_$core
		let result+=$?
		echo $core
	done
	pg_clear
	echo Clean
	uload_mod pktgen
	sleep 1
	return $result
}

# Version 1.0.0.45
kill_proc()
{
	local proc_id process=$1
	test -z "$process" && return 0
	proc_id=$(pidof -x $process)
	test -z "$proc_id" && return 0
	kill -INT "$proc_id" > /dev/null 2>&1
	sleep 1
	proc_id=$(pidof -x $process)
	test -z "$proc_id" && return 0
	kill -TERM "$proc_id" > /dev/null 2>&1
	sleep 1
	proc_id=$(pidof -x $process)
	test -z "$proc_id" && return 0
	kill -KILL "$proc_id" > /dev/null 2>&1
	sleep 1
	proc_id=$(pidof -x $process)
	test -z "$proc_id" || echo $proc_id
	return 1
}

# Version 1.0.0.36
kill_pid()
{
	local proc_id sta
	let sta=0
	test -z "$1" && return 0
	until [ -z "$1" ] ; do
		proc_id=$1
		shift
		test -z "$(ps -A |grep "$proc_id")" && continue
		kill -INT "$proc_id" > /dev/null 2>&1
		sleep 1
		test -z "$(ps -A |grep "$proc_id")" && continue
		kill -TERM "$proc_id" > /dev/null 2>&1
		sleep 1
		test -z "$(ps -A |grep "$proc_id")" && continue
		kill -KILL "$proc_id" > /dev/null 2>&1
		sleep 1
		test -z "$(ps -A |grep "$proc_id")" || let sta++
	done
	return $sta
}

# Version 1.0.0.6
counter()
{
	local count="$1"
	test -z "$count" && return 1
	if [ "$count" -lt "10" ] ; then BS="\b"
	elif [ "$count" -lt "100" ] ; then BS="\b\b"
	elif [ "$count" -lt "1000" ] ; then BS="\b\b\b"
	elif [ "$count" -lt "10000" ] ; then BS="\b\b\b\b"
	elif [ "$count" -lt "100000" ] ; then BS="\b\b\b\b\b"
	elif [ "$count" -lt "1000000" ] ; then BS="\b\b\b\b\b\b"
	elif [ "$count" -lt "10000000" ] ; then BS="\b\b\b\b\b\b\b"
	elif [ "$count" -lt "100000000" ] ; then BS="\b\b\b\b\b\b\b\b"
	elif [ "$count" -lt "1000000000" ] ; then BS="\b\b\b\b\b\b\b\b\b"
	else BS="\b\b\b\b\b\b\b\b\b\b"
	fi
	echo -e "\b0$count$BS\b"
	return 0
}

# Version 1.0.0.0
err_read()
{
	local errors=""
	IFS=$'\n' read -d '' -r -a errors < /tmp/$1.err
	count=${errors[0]}
	cerr1=${errors[1]}
	cerr2=${errors[2]}
	cerr3=${errors[3]}
	cerr4=${errors[4]}
	cerr5=${errors[5]}
	cerr6=${errors[6]}
	cerr7=${errors[7]}
	cerr8=${errors[8]}
	return 0
}

# Version 1.0.0.0
err_write()
{
	let ++count
	echo "${count}" >  /tmp/$1.err
	echo "${cerr1}" >> /tmp/$1.err
	echo "${cerr2}" >> /tmp/$1.err
	echo "${cerr3}" >> /tmp/$1.err
	echo "${cerr4}" >> /tmp/$1.err
	echo "${cerr5}" >> /tmp/$1.err
	echo "${cerr6}" >> /tmp/$1.err
	echo "${cerr7}" >> /tmp/$1.err
	echo "${cerr8}" >> /tmp/$1.err
	return 0
}

# Version 1.0.0.25
err_check()
{
	local hex bit1 bit2 bit3 bit4 bit5 bit6 bit7 bit8
	let hex=$1
	if [ "$hex" -ne 0 ] ; then
		let bit1='((0x01&hex))'?1:0
		let bit2='((0x02&hex))'?1:0
		let bit3='((0x04&hex))'?1:0
		let bit4='((0x08&hex))'?1:0
		let bit5='((0x10&hex))'?1:0
		let bit6='((0x20&hex))'?1:0
		let bit7='((0x40&hex))'?1:0
		let bit8='((0x80&hex))'?1:0
		#echo "b$bit8$bit7$bit6$bit5$bit4$bit3$bit2$bit1"
		test "$bit1" = "0" || let ++cerr1
		test "$bit2" = "0" || let ++cerr2
		test "$bit3" = "0" || let ++cerr3
		test "$bit4" = "0" || let ++cerr4
		test "$bit5" = "0" || let ++cerr5
		test "$bit6" = "0" || let ++cerr6
		test "$bit7" = "0" || let ++cerr7
		test "$bit8" = "0" || let ++cerr8
	fi
	return 0
}

# Version 2.0.0.1
init_pcibus()
{
	test -n "$1" || try Mask
	local mask=$1
	test "$mask" -ne "0" && echo mask=$mask
	shift
	local extend width ab nbus bus crc j
	let j=0
	echo init_pcibus $@
	for ab in $@ ; do
		extend=$(echo $ab |cut -d: -f2) # |cut -d. -f1)
		let width=$(lspci -s$ab -vv |grep -a LnkSta: |cut -d, -f2 |cut -dx -f2)
		test "$width" -gt "0" && {
			bus[$j]=$ab
			crc[$j]=1 #normal bus
			if [[ "$mask" -eq "1" && "$extend" = "00.0" && "$j" -eq "0" ]] ; then
				try Tested_Bus "$ab CRC masked"
				crc[$j]=0 #mask PCI bus extender
			elif [[ "$mask" -gt "1" && "$mask" -eq "$j" ]] ; then
				try Tested_Bus "$ab CRC masked"
				crc[$j]=0 #mask specified PCI bus
			fi
			nbus=$(echo ${bus[$j]}0 |tr -d [:punct:])
			echo -e "0\n0\n0\n0\n0\n0\n0\n0" > /tmp/$nbus.err
			setpci -s ${bus[$j]} CAP_EXP+0xa.b=0xff
			pcibus=$(echo $pcibus ${bus[$j]})
			crcbus=$(echo $crcbus ${crc[$j]})
			let ++j
		}
	done
	return $j
}

# Version 2.0.0.1
init_pci_vf()
{
	test -n "$1" || try Mask
	local mask=$1
	test "$mask" -ne "0" && echo mask=$mask
	shift
	local extend width ab nbus bus crc j
	let j=0
	echo init_pcibus $@
	for ab in $@ ; do
		extend=$(echo $ab |cut -d: -f2) # |cut -d. -f1)
		let width=$(lspci -s$ab -vv |grep -a LnkSta: |cut -d, -f2 |cut -dx -f2)
		bus[$j]=$ab
		crc[$j]=1 #normal bus
		if [[ "$mask" -eq "1" && "$extend" = "00.0" && "$j" -eq "0" ]] ; then
			try Tested_Bus "$ab CRC masked"
			crc[$j]=0 #mask PCI bus extender
		elif [[ "$mask" -gt "1" && "$mask" -eq "$j" ]] ; then
			try Tested_Bus "$ab CRC masked"
			crc[$j]=0 #mask specified PCI bus
		fi
		nbus=$(echo ${bus[$j]}0 |tr -d [:punct:])
		echo -e "0\n0\n0\n0\n0\n0\n0\n0" > /tmp/$nbus.err
		setpci -s ${bus[$j]} CAP_EXP+0xa.b=0xff
		pcibus=$(echo $pcibus ${bus[$j]})
		crcbus=$(echo $crcbus ${crc[$j]})
		let ++j
	done
	return $j
}

# Version 1.0.0.31
write_err()
{
	test -z "$1" && let show=1 || let show=$1
	shift
	local qerr aqty nbus bus crc msg m
	let qerr=0
	bus=($pcibus)
	crc=($crcbus)
	let aqty=${#bus[@]}
	for (( m=0; m<$aqty; m++ )) ; do
		nbus=$(echo ${bus[$m]}0 |tr -d [:punct:])
		err_read $nbus
		err_write $nbus
		msg="${bus[$m]} Correctable Errors: ${cerr1}"
		[[ $show -ne 0 && $cerr1 -gt 0 ]] && echo ${msg}
		test ${crc[$m]} -eq 0 || let qerr+=cerr1
		msg="${bus[$m]} Correctable Errors Masked"
		[[ ${crc[$m]} -eq 0 && $cerr1 -gt 0 ]] && echo ${msg}
		msg="${bus[$m]} Non-Fatal Errors: ${cerr2}"
		[[ $show -ne 0 && $cerr2 -gt 0 ]] && echo ${msg}
		let qerr+=cerr2
		msg="${bus[$m]} Fatal Errors: ${cerr3}"
		[[ $show -ne 0 && $cerr3 -gt 0 ]] && echo ${msg}
		let qerr+=cerr3
		msg="${bus[$m]} Unsupported Requests: ${cerr4}"
		[[ $show -ne 0 && $cerr4 -gt 0 ]] && echo ${msg}
		let qerr+=cerr4
		msg="${bus[$m]} Aux Powers: ${cerr5}"
		[[ $show -ne 0 && $cerr5 -gt 0 ]] && echo ${msg}
		let qerr+=cerr5
		msg="${bus[$m]} Transactions Pending: ${cerr6}"
		[[ $show -ne 0 && $cerr6 -gt 0 ]] && echo ${msg}
		let qerr+='((cerr6<=count))?0:cerr6'
		msg="${bus[$m]} Unknown Errors: $((cerr7+cerr8))"
		[[ $show -ne 0 && $cerr7 -gt 0 || $show -ne 0 && $cerr8 -gt 0 ]] && echo ${msg}
		let qerr+=cerr7+cerr8
	done
	return $qerr
}

# Version 1.0.0.31
write_noaux()
{
	test -z "$1" && let show=1 || let show=$1
	shift
	local qerr aqty nbus bus crc msg m
	let qerr=0
	bus=($pcibus)
	crc=($crcbus)
	let aqty=${#bus[@]}
	for (( m=0; m<$aqty; m++ )) ; do
		nbus=$(echo ${bus[$m]}0 |tr -d [:punct:])
		err_read $nbus
		err_write $nbus
		msg="${bus[$m]} Correctable Errors: ${cerr1}"
		[[ $show -ne 0 && $cerr1 -gt 0 ]] && echo ${msg}
		test ${crc[$m]} -eq 0 || let qerr+=cerr1
		msg="${bus[$m]} Correctable Errors Masked"
		[[ ${crc[$m]} -eq 0 && $cerr1 -gt 0 ]] && echo ${msg}
		msg="${bus[$m]} Non-Fatal Errors: ${cerr2}"
		[[ $show -ne 0 && $cerr2 -gt 0 ]] && echo ${msg}
		let qerr+=cerr2
		msg="${bus[$m]} Fatal Errors: ${cerr3}"
		[[ $show -ne 0 && $cerr3 -gt 0 ]] && echo ${msg}
		let qerr+=cerr3
		msg="${bus[$m]} Unsupported Requests: ${cerr4}"
		[[ $show -ne 0 && $cerr4 -gt 0 ]] && echo ${msg}
		let qerr+=cerr4
		msg="${bus[$m]} Aux Powers: ${cerr5}"
		[[ $show -ne 0 && $cerr5 -gt 0 ]] && echo ${msg}
		#let qerr+=cerr5
		msg="${bus[$m]} Aux Powers Errors Masked"
		test $cerr5 -gt 0 && echo ${msg}
		msg="${bus[$m]} Transactions Pending: ${cerr6}"
		[[ $show -ne 0 && $cerr6 -gt 0 ]] && echo ${msg}
		let qerr+='((cerr6<=count))?0:cerr6'
		msg="${bus[$m]} Unknown Errors: $((cerr7+cerr8))"
		[[ $show -ne 0 && $cerr7 -gt 0 || $show -ne 0 && $cerr8 -gt 0 ]] && echo ${msg}
		let qerr+=cerr7+cerr8
	done
	return $qerr
}

# Version 1.0.0.31
write_allpci()
{
	test -z "$1" && let show=1 || let show=$1
	shift
	local qerr aqty nbus bus crc msg m
	let qerr=0
	bus=($pcibus)
	crc=($crcbus)
	let aqty=${#bus[@]}
	for (( m=0; m<$aqty; m++ )) ; do
		nbus=$(echo ${bus[$m]}0 |tr -d [:punct:])
		err_read $nbus
		err_write $nbus
		msg="${bus[$m]} Correctable Errors: ${cerr1}"
		test "$show" = "0" || echo ${msg}
		test "${crc[$m]}" = "0" || let qerr+=cerr1
		msg="${bus[$m]} Correctable Errors Masked"
		test "${crc[$m]}" = "0" && echo ${msg}
		msg="${bus[$m]} Non-Fatal Errors: ${cerr2}"
		test "$show" = "0" || echo ${msg}
		let qerr+=cerr2
		msg="${bus[$m]} Fatal Errors: ${cerr3}"
		test "$show" = "0" || echo ${msg}
		let qerr+=cerr3
		msg="${bus[$m]} Unsupported Requests: ${cerr4}"
		test "$show" = "0" || echo ${msg}
		let qerr+=cerr4
		msg="${bus[$m]} Aux Powers: ${cerr5}"
		test "$show" = "0" || echo ${msg}
		let qerr+=cerr5
		msg="${bus[$m]} Transactions Pending: ${cerr6}"
		test "$show" = "0" || echo ${msg}
		let qerr+='((cerr6<=count))?0:cerr6'
		msg="${bus[$m]} Unknown Errors: $((cerr7+cerr8))"
		test "$show" = "0" || echo ${msg}
		let qerr+=cerr7+cerr8
	done
	return $qerr
}

# Version 2.0.0.2
check_stat()
{
	test -n "$1" || try Interface
	test -n "$2" || try Label
	local tx_errors tx_err txerr tx_dropped tx_drop txdrop
	local rx_errors rx_err rxerr rx_dropped rx_drop rxdrop
	local sub vid did x
	test -s /sys/class/net/$1/device/uevent || {
		check_box $@
		return
	}
	sub=$(cat /sys/class/net/$1/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	vid=$(lspci -nms:$sub |cut -d'"' -f4)
	did=$(lspci -nms:$sub |cut -d'"' -f6)
	if [ "$vid" = "14e4" ] ; then
		ethtool -S $1 |grep tx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txdrop-$2
		test -s /tmp/$1-txdrop-$2 || echo 0 > /tmp/$1-txdrop-$2
		ethtool -S $1 |grep rx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxdrop-$2
		test -s /tmp/$1-rxdrop-$2 || echo 0 > /tmp/$1-rxdrop-$2
		ethtool -S $1 |grep tx_error_bytes |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txerr-$2
		ethtool -S $1 |grep rx_error_bytes |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxerr-$2
		ethtool -S $1 |grep -A 1 tx_error_bytes |tr '\n' ' ' |cut -d: -f3 |cut -d' ' -f2 > /tmp/$1-tx-$2
		ethtool -S $1 |grep -A 1 rx_error_bytes |tr '\n' ' ' |cut -d: -f3 |cut -d' ' -f2 > /tmp/$1-rx-$2
	elif [ "$vid" = "15b3" ] ; then
		ethtool -S $1 |grep tx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txdrop-$2
		test -s /tmp/$1-txdrop-$2 || echo 0 > /tmp/$1-txdrop-$2
		ethtool -S $1 |grep rx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxdrop-$2
		test -s /tmp/$1-rxdrop-$2 || echo 0 > /tmp/$1-rxdrop-$2
		ethtool -S $1 |grep tx_error_packets |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txerr-$2
		ethtool -S $1 |grep rx_error_packets |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxerr-$2
		ethtool -S $1 |grep tx_packets |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-tx-$2
		ethtool -S $1 |grep rx_packets |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rx-$2
	elif [ "$vid" = "8086" -a "$did" = "1592" -o "$vid" = "8086" -a "$did" = "1593" ] ; then
		# tx_dropped=$(ethtool -S $1 |grep tx |grep dropped |cut -d: -f2 |cut -d' ' -f2)
		# tx_drop=($tx_dropped)
		# for x in ${tx_drop[@]} ; do let txdrop+=$x ; done
		# echo $txdrop > /tmp/$1-txdrop-$2
		ethtool -S $1 |grep tx_dropped |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txdrop-$2
		test -s /tmp/$1-txdrop-$2 || echo 0 > /tmp/$1-txdrop-$2
		# rx_dropped=$(ethtool -S $1 |grep rx |grep dropped |cut -d: -f2 |cut -d' ' -f2)
		# rx_drop=($rx_dropped)
		# for x in ${rx_drop[@]} ; do let rxdrop+=$x ; done
		# echo $rxdrop > /tmp/$1-rxdrop-$2
		ethtool -S $1 |grep rx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxdrop-$2
		test -s /tmp/$1-rxdrop-$2 || echo 0 > /tmp/$1-rxdrop-$2
		# tx_errors=$(ethtool -S $1 |grep tx |grep "errors\|fail" |cut -d: -f2 |cut -d' ' -f2)
		# tx_err=($tx_errors)
		# for x in ${tx_err[@]} ; do let txerr+=$x ; done
		# echo $txerr > /tmp/$1-txerr-$2
		ethtool -S $1 |grep tx_errors: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txerr-$2
		test -s /tmp/$1-txerr-$2 || echo 0 > /tmp/$1-txerr-$2
		rx_errors=$(ethtool -S $1 |grep rx |grep errors |cut -d: -f2 |cut -d' ' -f2)
		rx_err=($rx_errors)
		for x in ${rx_err[@]} ; do let rxerr+=$x ; done
		echo $rxerr > /tmp/$1-rxerr-$2
		# ethtool -S $1 |grep rx_errors: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxerr-$2
		test -s /tmp/$1-rxerr-$2 || echo 0 > /tmp/$1-rxerr-$2
		ethtool -S $1 |grep tx_unicast: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-tx-$2
		ethtool -S $1 |grep rx_unicast: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rx-$2
	else
		ethtool -S $1 |grep tx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txdrop-$2
		test -s /tmp/$1-txdrop-$2 || echo 0 > /tmp/$1-txdrop-$2
		ethtool -S $1 |grep rx_dropped: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxdrop-$2
		test -s /tmp/$1-rxdrop-$2 || echo 0 > /tmp/$1-rxdrop-$2
		ethtool -S $1 |grep tx_errors: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txerr-$2
		ethtool -S $1 |grep rx_errors: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxerr-$2
		ethtool -S $1 |grep tx_packets: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-tx-$2
		ethtool -S $1 |grep rx_packets: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rx-$2
	fi
}

# Version 1.0.2.0
check_box()
{
	test -n "$1" || try Interface
	local ifphy=$1
	test -n "$2" || try Label
	local x rxover rx_dis rxdrop interr tx_err txerr
	let rxdrop=0
	rxover=$(ethtool -S $ifphy |grep -B5 rx_overrun: |cut -d: -f2 |cut -d' ' -f2)
	rx_dis=($rxover)
	for x in ${rx_dis[@]} ; do let rxdrop+=$x ; done
	echo $rxdrop > /tmp/$1-rxdrop-$2
	test -s /tmp/$1-rxdrop-$2 || echo 0 > /tmp/$1-rxdrop-$2
	ethtool -S $ifphy |grep bad_frames_received: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rxerr-$2
	test -s /tmp/$1-rxerr-$2 || echo 0 > /tmp/$1-rxerr-$2
	ethtool -S $ifphy |grep good_frames_received: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-rx-$2
	test -s /tmp/$1-rx-$2 || echo 0 > /tmp/$1-rx-$2
	ethtool -S $ifphy |grep good_frames_sent: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-tx-$2
	test -s /tmp/$1-tx-$2 || echo 0 > /tmp/$1-tx-$2
	ethtool -S $ifphy |grep excessive_collision: |tr '\n' ' ' |cut -d: -f2 |cut -d' ' -f2 > /tmp/$1-txdrop-$2
	test -s /tmp/$1-txdrop-$2 || echo 0 > /tmp/$1-txdrop-$2
	interr=$(ethtool -S $ifphy |grep -A3 internal_mac_transmit_err: |cut -d: -f2 |cut -d' ' -f2)
	tx_err=($interr)
	for x in ${tx_err[@]} ; do let txerr+=$x ; done
	echo $txerr > /tmp/$1-txerr-$2
	test -s /tmp/$1-txerr-$2 || echo 0 > /tmp/$1-txerr-$2
}

# Version 1.0.2.0
check_txgen()
{
	local hang pkt msg eth bus
	test -z "$1" && try Packet_Count
	let hang=$1
	shift
	test -z "$1" && try Interface
	eth=$1
	test -s /sys/class/net/$eth/device/uevent \
	&& bus=$(cat /sys/class/net/$eth/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	shift
	test -z "$1" && try Log_File
	test -s "$1" || try Log_File 0
	msg=$(tail -n1 $1)
	test -z "$msg" || echo "$bus $eth $msg"
	pkt=$(cat $1 |grep pkt |awk '{print $3}')
	test -z "$pkt" || let hang-=$pkt
	test "$hang" = "0"
	status "$bus $eth Transmission" $?
	return $?
}

# Version 1.0.0.29
check_transmitter()
{
	test -n "$1" || try Packet_Count
	local pcount
	let pcount=$1
	shift
	test -n "$1" || try "Min_Speed(Mb/sec)"
	local minSpeed
	let minSpeed=$1
	shift
	test -n "$1" || try Interface
	local eth cbus msg speed sval spd cnt counts dif err error ret nspd ncnt nerr nres
	let spd=0 cnt=0 dif=0 err=0 ret=0 nspd=0 ncnt=0 nerr=0 nres=0
	for eth in $@ ; do
		cbus=$(ls -l /sys/class/net/$eth |awk -F/ '{print $(NF-2)}' |cut -d: -f2-)
		msg=$(cat /proc/net/pktgen/$eth |grep pps |tr -s " " |cut -d' ' -f3)
		speed=$(echo "$cbus $eth Speed: ${msg}")
		sval=$(echo $speed |cut -d' ' -f4 |cut -d 'M' -f1)
		test -z "$sval" && let spd=1 || let spd=$(test "$sval" -ge "$minSpeed" ; echo $?)
		status "$speed" $(echo $spd)
		cnt=$(cat /proc/net/pktgen/$eth |grep Result |cut -d' ' -f5)
		counts=$(echo $cbus $eth Count: $cnt)
		test -z "$cnt" && let dif=1 || let dif=$(test "$pcount" -eq "$cnt" ; echo $?)
		test -z "$cnt" || test "$pcount" -eq "0" && let dif=0
		status "$counts" $(echo $dif)
		err=$(cat /proc/net/pktgen/$eth |grep pps |tr -s " " |cut -d' ' -f 6)
		error=$(echo $cbus $eth Error: $err)
		test -z "$err" && let err=1
		status "$error" $(echo $err)
		let ret=spd+dif+err
		status "$cbus $eth Transmission" $(echo $ret)
		let nspd+=spd
		let ncnt+=dif
		let nerr+=err
		let nres+=nspd+ncnt+nerr
	done
	return $nres
}

# Version 1.0.2.7
check_txrx()
{
	test -n "$1" || try Packet_Count
	local pcount
	let pcount=$1
	shift
	test -n "$1" || try Source_Interface
	local ethTx=$1
	shift
	test -n "$1" || try Target_Interface
	local ethRx=$1
	shift
	test -n "$1" && multi=$1 || multi=1
	local busTx busRx rx_past rx_post tx_past tx_post
	local rxdrop_past rxdrop_post txdrop_past txdrop_post
	local rxerr_past rxerr_post txerr_past txerr_post
	local tx_error rx_error tx_drop rx_drop tx_count rx_count
	local tx_lost rx_lost tx_over rx_over sta0
	let sta0=0
	test -s /sys/class/net/$ethTx/device/uevent \
	&& busTx=$(cat /sys/class/net/$ethTx/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	test -s /sys/class/net/$ethRx/device/uevent \
	&& busRx=$(cat /sys/class/net/$ethRx/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	rx_past=$(cat /tmp/$ethRx-rx-past)
	rx_post=$(cat /tmp/$ethRx-rx-post)
	tx_past=$(cat /tmp/$ethTx-tx-past)
	tx_post=$(cat /tmp/$ethTx-tx-post)
	rxdrop_past=$(cat /tmp/$ethRx-rxdrop-past)
	rxdrop_post=$(cat /tmp/$ethRx-rxdrop-post)
	txdrop_past=$(cat /tmp/$ethTx-txdrop-past)
	txdrop_post=$(cat /tmp/$ethTx-txdrop-post)
	rxerr_past=$(cat /tmp/$ethRx-rxerr-past)
	rxerr_post=$(cat /tmp/$ethRx-rxerr-post)
	txerr_past=$(cat /tmp/$ethTx-txerr-past)
	txerr_post=$(cat /tmp/$ethTx-txerr-post)
	let tx_error=$((txerr_post-txerr_past))
	let rx_error=$((rxerr_post-rxerr_past))
	let tx_drop=$((txdrop_post-txdrop_past))
	let rx_drop=$((rxdrop_post-rxdrop_past))
	let tx_count=$((tx_post-tx_past))
	let rx_count=$((rx_post-rx_past))
	test -z "$tx_count" -o -z "$tx_error" -o -z "$tx_drop" && let ++sta0
	test -z "$rx_count" -o -z "$rx_error" -o -z "$rx_drop" && let ++sta0
	test "$pcount" -eq "0" && let pcount=$tx_count
	test "$multi" -gt "1" && {
		echo "$busTx $ethTx-tx: multiplier is $multi"
		let pcount*=$multi
		echo "$busTx $ethTx-tx: $pcount expected"
		let tx_count*=$multi
	}
	let tx_over=$((tx_count-pcount))
	let tx_lost=$((pcount-tx_count))
	test "$tx_lost" -lt "0" && let tx_lost=0
	test "$tx_over" -lt "0" && let tx_over=0
	test -z "$tx_over" -o -z "$tx_lost" && let ++sta0
	echo "$busTx $ethTx-tx: $tx_count packets"
	echo "$busTx $ethTx-tx: $tx_error errors"
	echo "$busTx $ethTx-tx: $tx_drop dropped"
	echo "$busTx $ethTx-tx: $tx_lost lost"
	test "$tx_over" -gt "0" && echo "$busTx $ethTx-tx: $tx_over excess"
	test "$((tx_error-mayberror-tx_over))" -gt "0" && let ++sta0
	test "$((tx_drop-maybedrop-tx_over))" -gt "0" && let ++sta0
	test "$((tx_lost-maybelost-tx_over))" -gt "0" && let ++sta0
	status "$busTx $ethTx Transmitter" $sta0
	let rx_over=$((rx_count-pcount))
	let rx_lost=$((tx_count-rx_count))
	test "$rx_lost" -lt "0" && let rx_lost=0
	test "$rx_over" -lt "0" && let rx_over=0
	test -z "$rx_over" -o -z "$rx_lost" && let ++sta0
	echo "$busRx $ethRx-rx: $rx_count packets"
	echo "$busRx $ethRx-rx: $rx_error errors"
	echo "$busRx $ethRx-rx: $rx_drop dropped"
	echo "$busRx $ethRx-rx: $rx_lost lost"
	test "$rx_over" -gt "0" && echo "$busRx $ethRx-rx: $rx_over excess"
	test "$((rx_error-mayberror-rx_over))" -gt "0" && let ++sta0
	test "$((rx_drop-maybedrop-rx_over))" -gt "0" && let ++sta0
	test "$((rx_lost-maybelost-rx_over))" -gt "0" && let ++sta0
	status "$busRx $ethRx Receiver" $sta0
	return $?
}

# Version 1.0.2.14
check_loop()
{
	test -n "$1" || try Packet_Count
	local pcount
	let pcount=$1
	shift
	test -n "$1" || try Interface
	local ethTx=$1
	shift
	test -n "$1" && multi=$1 || multi=1
	local busTx busRx rx_past rx_post tx_past tx_post
	local rxdrop_past rxdrop_post txdrop_past txdrop_post
	local rxerr_past rxerr_post txerr_past txerr_post
	local tx_error rx_error tx_drop rx_drop tx_count rx_count
	local tx_lost rx_lost tx_over rx_over sta0
	let sta0=0
	test -s /sys/class/net/$ethTx/device/uevent \
	&& busTx=$(cat /sys/class/net/$ethTx/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	rx_past=$(cat /tmp/$ethTx-rx-past)
	rx_post=$(cat /tmp/$ethTx-rx-post)
	tx_past=$(cat /tmp/$ethTx-tx-past)
	tx_post=$(cat /tmp/$ethTx-tx-post)
	rxdrop_past=$(cat /tmp/$ethTx-rxdrop-past)
	rxdrop_post=$(cat /tmp/$ethTx-rxdrop-post)
	txdrop_past=$(cat /tmp/$ethTx-txdrop-past)
	txdrop_post=$(cat /tmp/$ethTx-txdrop-post)
	rxerr_past=$(cat /tmp/$ethTx-rxerr-past)
	rxerr_post=$(cat /tmp/$ethTx-rxerr-post)
	txerr_past=$(cat /tmp/$ethTx-txerr-past)
	txerr_post=$(cat /tmp/$ethTx-txerr-post)
	let tx_error=$((txerr_post-txerr_past))
	let rx_error=$((rxerr_post-rxerr_past))
	let tx_drop=$((txdrop_post-txdrop_past))
	let rx_drop=$((rxdrop_post-rxdrop_past))
	let tx_count=$((tx_post-tx_past))
	let rx_count=$((rx_post-rx_past))
	test -z "$tx_count" -o -z "$tx_error" -o -z "$tx_drop" && let ++sta0
	test -z "$rx_count" -o -z "$rx_error" -o -z "$rx_drop" && let ++sta0
	test "$pcount" -eq "0" && let pcount=$tx_count
	test "$multi" -gt "1" && {
		echo "$busTx $ethTx-tx: multiplier is $multi"
		let pcount*=$multi
		echo "$busTx $ethTx-tx: $pcount expected"
		let tx_count*=$multi
	}
	let tx_over=$((tx_count-pcount))
	let tx_lost=$((pcount-tx_count))
	test "$tx_lost" -lt "0" && let tx_lost=0
	test "$tx_over" -lt "0" && let tx_over=0
	test -z "$tx_over" -o -z "$tx_lost" && let ++sta0
	echo "$busTx $ethTx-tx: $tx_count packets"
	echo "$busTx $ethTx-tx: $tx_error errors"
	echo "$busTx $ethTx-tx: $tx_drop dropped"
	echo "$busTx $ethTx-tx: $tx_lost lost"
	test "$tx_over" -gt "0" && echo "$busTx $ethTx-tx: $tx_over excess"
	test "$((tx_error-mayberror-tx_over))" -gt "0" && let ++sta0
	test "$((tx_drop-maybedrop-tx_over))" -gt "0" && let ++sta0
	test "$((tx_lost-maybelost-tx_over))" -gt "0" && let ++sta0
	status "$busTx $ethTx Transmitter" $sta0
	let rx_over=$((rx_count-pcount))
	let rx_lost=$((tx_count-rx_count))
	test "$rx_lost" -lt "0" && let rx_lost=0
	test "$rx_over" -lt "0" && let rx_over=0
	test -z "$rx_over" -o -z "$rx_lost" && let ++sta0
	echo "$busTx $ethTx-rx: $rx_count packets"
	echo "$busTx $ethTx-rx: $rx_error errors"
	echo "$busTx $ethTx-rx: $rx_drop dropped"
	echo "$busTx $ethTx-rx: $rx_lost lost"
	test "$rx_over" -gt "0" && echo "$busTx $ethTx-rx: $rx_over excess"
	test "$((rx_error-mayberror-rx_over))" -gt "0" && let ++sta0
	test "$((rx_drop-maybedrop-rx_over))" -gt "0" && let ++sta0
	test "$((rx_lost-maybelost-rx_over))" -gt "0" && let ++sta0
	status "$busTx $ethTx Receiver" $sta0
	return $?
}

# Version 1.0.2.14
check_vlan()
{
	test -n "$1" || try Packet_Count
	local pcount
	let pcount=2*$1 # dual loop expected
	shift
	test -n "$1" || try Interface
	local ethTx=$1
	shift
	test -n "$1" && multi=$1 || multi=1
	local busTx busRx rx_past rx_post tx_past tx_post
	local rxdrop_past rxdrop_post txdrop_past txdrop_post
	local rxerr_past rxerr_post txerr_past txerr_post
	local tx_error rx_error tx_drop rx_drop tx_count rx_count
	local tx_lost rx_lost tx_over rx_over sta0
	let sta0=0
	test -s /sys/class/net/$ethTx/device/uevent \
	&& busTx=$(cat /sys/class/net/$ethTx/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	rx_past=$(cat /tmp/$ethTx-rx-past)
	rx_post=$(cat /tmp/$ethTx-rx-post)
	tx_past=$(cat /tmp/$ethTx-tx-past)
	tx_post=$(cat /tmp/$ethTx-tx-post)
	rxdrop_past=$(cat /tmp/$ethTx-rxdrop-past)
	rxdrop_post=$(cat /tmp/$ethTx-rxdrop-post)
	txdrop_past=$(cat /tmp/$ethTx-txdrop-past)
	txdrop_post=$(cat /tmp/$ethTx-txdrop-post)
	rxerr_past=$(cat /tmp/$ethTx-rxerr-past)
	rxerr_post=$(cat /tmp/$ethTx-rxerr-post)
	txerr_past=$(cat /tmp/$ethTx-txerr-past)
	txerr_post=$(cat /tmp/$ethTx-txerr-post)
	let tx_error=$((txerr_post-txerr_past))
	let rx_error=$((rxerr_post-rxerr_past))
	let tx_drop=$((txdrop_post-txdrop_past))
	let rx_drop=$((rxdrop_post-rxdrop_past))
	let tx_count=$((tx_post-tx_past))
	let rx_count=$((rx_post-rx_past))
	test -z "$tx_count" -o -z "$tx_error" -o -z "$tx_drop" && let ++sta0
	test -z "$rx_count" -o -z "$rx_error" -o -z "$rx_drop" && let ++sta0
	test "$pcount" -eq "0" && let pcount=$tx_count
	test "$multi" -gt "1" && {
		echo "$busTx $ethTx-tx: multiplier is $multi"
		let pcount*=$multi
		echo "$busTx $ethTx-tx: $pcount expected"
		let tx_count*=$multi
	}
	let tx_over=$((tx_count-pcount))
	let tx_lost=$((pcount-tx_count))
	test "$tx_lost" -lt "0" && let tx_lost=0
	test "$tx_over" -lt "0" && let tx_over=0
	test -z "$tx_over" -o -z "$tx_lost" && let ++sta0
	echo "$busTx $ethTx-tx: $tx_count packets"
	echo "$busTx $ethTx-tx: $tx_error errors"
	echo "$busTx $ethTx-tx: $tx_drop dropped"
	echo "$busTx $ethTx-tx: $tx_lost lost"
	test "$tx_over" -gt "0" && echo "$busTx $ethTx-tx: $tx_over excess"
	test "$((tx_error-mayberror-tx_over))" -gt "0" && let ++sta0
	test "$((tx_drop-maybedrop-tx_over))" -gt "0" && let ++sta0
	test "$((tx_lost-maybelost-tx_over))" -gt "0" && let ++sta0
	status "$busTx $ethTx Transmitter" $sta0
	let rx_over=$((rx_count-pcount))
	let rx_lost=$((tx_count-rx_count))
	test "$rx_lost" -lt "0" && let rx_lost=0
	test "$rx_over" -lt "0" && let rx_over=0
	test -z "$rx_over" -o -z "$rx_lost" && let ++sta0
	echo "$busTx $ethTx-rx: $rx_count packets"
	echo "$busTx $ethTx-rx: $rx_error errors"
	echo "$busTx $ethTx-rx: $rx_drop dropped"
	echo "$busTx $ethTx-rx: $rx_lost lost"
	test "$rx_over" -gt "0" && echo "$busTx $ethTx-rx: $rx_over excess"
	test "$((rx_error-mayberror-rx_over))" -gt "0" && let ++sta0
	test "$((rx_drop-maybedrop-rx_over))" -gt "0" && let ++sta0
	test "$((rx_lost-maybelost-rx_over))" -gt "0" && let ++sta0
	status "$busTx $ethTx Receiver" $sta0
	return $?
}

# Version 1.0.2.9
check_receiver()
{
	test -n "$1" || try Query_Count
	local qcount
	let qcount=$1
	shift
	test -n "$1" || try Packet_Count
	local pcount
	let pcount=$1*$qcount
	shift
	test -n "$1" || try Source_Interface
	local ethTx=$1
	shift
	test -n "$1" || try Target_Interface
	local ethRx=$1
	shift
	test -n "$1" && multi=$1 || multi=1
	local busTx busRx rx_past rx_post tx_past tx_post
	local rxdrop_past rxdrop_post txdrop_past txdrop_post
	local rxerr_past rxerr_post txerr_past txerr_post
	local tx_error rx_error tx_drop rx_drop tx_count rx_count
	local tx_lost rx_lost tx_over rx_over sta0
	let sta0=0
	test -s /sys/class/net/$ethTx/device/uevent \
	&& busTx=$(cat /sys/class/net/$ethTx/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	test -s /sys/class/net/$ethRx/device/uevent \
	&& busRx=$(cat /sys/class/net/$ethRx/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
	rx_past=$(cat /tmp/$ethRx-rx-past)
	rx_post=$(cat /tmp/$ethRx-rx-post)
	tx_past=$(cat /tmp/$ethTx-tx-past)
	tx_post=$(cat /tmp/$ethTx-tx-post)
	rxdrop_past=$(cat /tmp/$ethRx-rxdrop-past)
	rxdrop_post=$(cat /tmp/$ethRx-rxdrop-post)
	txdrop_past=$(cat /tmp/$ethTx-txdrop-past)
	txdrop_post=$(cat /tmp/$ethTx-txdrop-post)
	rxerr_past=$(cat /tmp/$ethRx-rxerr-past)
	rxerr_post=$(cat /tmp/$ethRx-rxerr-post)
	txerr_past=$(cat /tmp/$ethTx-txerr-past)
	txerr_post=$(cat /tmp/$ethTx-txerr-post)
	let tx_error=$((txerr_post-txerr_past))
	let rx_error=$((rxerr_post-rxerr_past))
	let tx_drop=$((txdrop_post-txdrop_past))
	let rx_drop=$((rxdrop_post-rxdrop_past))
	let tx_count=$((tx_post-tx_past))
	let rx_count=$((rx_post-rx_past))
	test -z "$tx_count" -o -z "$tx_error" -o -z "$tx_drop" && let ++sta0
	test -z "$rx_count" -o -z "$rx_error" -o -z "$rx_drop" && let ++sta0
	test "$pcount" -eq "0" && let pcount=$tx_count
	test "$multi" -gt "1" && {
		echo "$busTx $ethTx-tx: multiplier is $multi"
		let pcount*=$multi
		echo "$busTx $ethTx-tx: $pcount expected"
		let tx_count*=$multi
	}
	let tx_over=$((tx_count-pcount))
	let tx_lost=$((pcount-tx_count))
	test "$tx_lost" -lt "0" && let tx_lost=0
	test "$tx_over" -lt "0" && let tx_over=0
	test -z "$tx_over" -o -z "$tx_lost" && let ++sta0
	echo "$busTx $ethTx-tx: $tx_count packets"
	echo "$busTx $ethTx-tx: $tx_error errors"
	echo "$busTx $ethTx-tx: $tx_drop dropped"
	echo "$busTx $ethTx-tx: $tx_lost lost"
	test "$tx_over" -gt "0" && echo "$busTx $ethTx-tx: $tx_over excess"
	test "$((tx_error-mayberror-tx_over))" -gt "0" && let ++sta0
	test "$((tx_drop-maybedrop-tx_over))" -gt "0" && let ++sta0
	test "$((tx_lost-maybelost-tx_over))" -gt "0" && let ++sta0
	status "$busTx $ethTx Transmitter" $sta0
	let rx_over=$((rx_count-pcount))
	let rx_lost=$((tx_count-rx_count))
	test "$rx_lost" -lt "0" && let rx_lost=0
	test "$rx_over" -lt "0" && let rx_over=0
	test -z "$rx_over" -o -z "$rx_lost" && let ++sta0
	echo "$busRx $ethRx-rx: $rx_count packets"
	echo "$busRx $ethRx-rx: $rx_error errors"
	echo "$busRx $ethRx-rx: $rx_drop dropped"
	echo "$busRx $ethRx-rx: $rx_lost lost"
	test "$rx_over" -gt "0" && echo "$busRx $ethRx-rx: $rx_over excess"
	test "$((rx_error-mayberror-rx_over))" -gt "0" && let ++sta0
	test "$((rx_drop-maybedrop-rx_over))" -gt "0" && let ++sta0
	test "$((rx_lost-maybelost-rx_over))" -gt "0" && let ++sta0
	status "$busRx $ethRx Receiver" $sta0
	return $?
}

# Version 1.0.2.5
link_setup()
{
	local devices=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep net |awk -F/ '{print $NF}')
	test -z "$devices" || echo device=$devices
	test -z "$1" && try Interface || echo tested=$@
	local dev eth bus mac net j
	local lst=""
	let j=0
	for net in $@ ; do
		let ++j
		eth=""
		for dev in $devices ; do
			test "$net" = "$dev" && eth=$dev && break
		done
		test -z "$eth" && try "Interface:$net"
		try "net[$j]" $eth
		test -s /sys/class/net/$eth/device/uevent && {
			bus=$(cat /sys/class/net/$eth/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
			try "bus[$j]" $bus
		}
		mac=$(cat /sys/class/net/$eth/address)
		try "mac[$j]" $mac
		ip link set up $eth
		lst=$(echo $lst $eth)
	done
	echo interfaces=$lst
	sleep 2
	for net in $lst ; do
		state=$(ip link |grep $net |grep UP)
		if [ -z "$state" ] ; then
			status "$net Link" 1
			exit $?
		fi
	done
	return 0
}

# Version 1.0.0.0
link_detect()
{
	which ethtool > /dev/null || try ethtool
	local eth detect lnksta again left tval
	let tval=$1
	test -n "$tval" || try Timeout
	test "$tval" -ne "0" || try Timeout 0
	shift
	test -n "$1" || try Interface
	for eth in $@ ; do
		detect=$(ethtool $eth |grep 'Link detected:')
		lnksta=$(echo $(echo $detect |cut -d: -f2))
		let left=$tval
		until [[ "$lnksta" = "yes" || "$left" -eq "0" ]] ; do
			echo $eth $detect : left $left retry
			let --left
			sleep 1
			detect=$(ethtool $eth |grep 'Link detected:')
			lnksta=$(echo $(echo $detect |cut -d: -f2))
		done
		echo $eth $detect
		if [ "$lnksta" != "yes" ] ; then
			status "$eth Link" 1
			exit $?
		fi
	done
	return 0
}

# Version 1.0.0.32
detect_link()
{
	which ethtool > /dev/null || try ethtool
	local eth detect lnksta again left
	test -n "$1" || try Interface
	for eth in $@ ; do
		detect=$(ethtool $eth |grep 'Link detected:')
		lnksta=$(echo $(echo $detect |cut -d: -f2))
		let again=5
		let left=60
		until [[ "$lnksta" = "yes" || "$again" -eq "0" ]] ; do
			let --again
			until [[ "$lnksta" = "yes" || "$left" -eq "0" ]] ; do
				echo $eth $detect : left $left retry
				let --left
				sleep 1
				detect=$(ethtool $eth |grep 'Link detected:')
				lnksta=$(echo $(echo $detect |cut -d: -f2))
			done
			if [[ "$lnksta" != "yes" && "$again" -gt "0" ]] ; then
				ip link set up $eth
				let left=60
				echo $eth $detect : left $left again $again 
			fi
		done
		echo $eth $detect
		if [ "$lnksta" != "yes" ] ; then
			status "$eth Link" 1
			exit $?
		fi
	done
	return 0
}

# Version 1.0.0.33
detect_rate()
{
	which ethtool > /dev/null || try ethtool
	test -n "$1" || try Rate
	local rate=$1
	shift
	local eth detect lnksta again left speed spd value
	test -n "$1" || try Interface
	for eth in $@ ; do
		let again=5
		let left=60
		detect=$(ethtool $eth |grep 'Link detected:')
		lnksta=$(echo $(echo $detect |cut -d: -f2))
		until [[ "$lnksta" = "yes" || "$again" -eq "0" ]] ; do
			let --again
			until [[ "$lnksta" = "yes" || "$left" -eq "0" ]] ; do
				echo $eth $detect : left $left retry
				let --left
				sleep 1
				detect=$(ethtool $eth |grep 'Link detected:')
				lnksta=$(echo $(echo $detect |cut -d: -f2))
			done
			if [[ "$lnksta" != "yes" && "$again" -gt "0" ]] ; then
				ip link set up $eth
				let left=60
				echo $eth $detect : left $left again $again 
			fi
		done
		echo $eth $detect
		if [ "$lnksta" != "yes" ] ; then
			status "$eth Link" 1
			exit $?
		fi
		let value=0
		speed=$(ethtool $eth |grep Speed:)
		spd=$(echo $speed |cut -d' ' -f2)
		test "$spd" != "Unknown!" && value=$(echo $spd |cut -dM -f1)
		until [[ "$spd" != "Unknown!" && "$value" = "$rate" || "$again" -eq "0" ]] ; do
			let --again
			until [[ "$spd" != "Unknown!" && "$value" = "$rate" || "$left" -eq "0" ]] ; do
				echo $eth $speed : left $left retry
				let --left
				sleep 1
				speed=$(ethtool $eth |grep Speed:)
				spd=$(echo $speed |cut -d' ' -f2)
				test "$spd" != "Unknown!" && value=$(echo $spd |cut -dM -f1)
			done
			if [[ "$spd" = "Unknown!" || "$value" != "$rate" ]] ; then
				if [ "$again" -gt "0" ] ; then
					let left=60
					echo $eth $speed : left $left again $again
				fi
			fi
		done
		if [[ "$spd" = "Unknown!" || "$value" != "$rate" ]] ; then
			echo $eth $speed
			status "$eth Rate" 1
			exit $?
		fi
	done
	return $stats
}

# Version 1.0.0.0
rate_setup()
{
	which ethtool > /dev/null || try ethtool
	test -n "$1" || try Mode
	local mode=$1
	shift
	local eth
	local sta
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do
		ethtool -s $eth advertise $mode
		let sta+=$?
	done
	sleep 2
	return $sta
}

# Version 1.0.0.33
check_rate()
{
	which ethtool > /dev/null || try ethtool
	test -n "$1" || try Rate
	local rate=$1
	shift
	local eth speed spd value sta
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do
		speed=$(ethtool $eth |grep Speed:)
		echo "$eth $speed"
		spd=$(echo $speed |cut -d' ' -f2)
		if [ "$spd" = "Unknown!" ] ; then
			let ++sta
		else
			value=$(echo $spd |cut -dM -f1)
			test "$rate" = "$value" || let ++sta
		fi
	done
	return $sta
}

# Version 1.0.0.0
selftest()
{
	local eth self ret sta
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do
		self=$(ethtool -t $eth)
		let sta+=$?
		ret=$(echo $self | grep result | cut -d' ' -f5)
		echo "$eth $ret"
	done
	return $sta
}

# Version 1.0.0.19
blinktest()
{
	local eth ret sta
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do
		ethtool -p $eth 3
		let ret=$?
		let sta+=$ret
		status $eth $ret
	done
	return $sta
}

# Version 1.0.2.8
build_rc2d()
{
echo '#!/bin/bash'
echo '# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES'
echo '#'
echo '# It is highly advisable to create own systemd services or udev rules'
echo '# to run scripts during boot instead of using this file.'
echo '#'
echo '# In contrast to previous versions due to parallel execution during boot'
echo '# this script will NOT be run after all other services.'
echo '#'
echo '# Please note that you must run "chmod +x /etc/rc.d/rc.local" to ensure'
echo '# that this script will be executed during boot.'
echo ''
echo 'dmesg -n 1'
echo 'if [ -s "/root/bin/ipconfig.sh" ] ; then'
echo '	if [ -s "/root/.ip4addr2" ] ; then'
echo '		cp -f /root/.ip4addr2 /root/.ipconfig'
echo '		mv -f /root/.ipconfig /root/.ipconfig2'
echo '	fi'
echo '	if [ -s "/root/.ipconfig2" ] ; then'
echo '		/root/bin/ipconfig.sh 2 $(cat /root/.ipconfig2)'
echo '	fi'
echo '	if [ -s "/root/.ip4addr1" ] ; then'
echo '		cp -f /root/.ip4addr1 /root/.ipconfig'
echo '		mv -f /root/.ipconfig /root/.ipconfig1'
echo '	fi'
echo '	if [ -s "/root/.ipconfig1" ] ; then'
echo '		/root/bin/ipconfig.sh 1 $(cat /root/.ipconfig1)'
echo '	fi'
echo 'fi'
echo "cd /root"
echo "if [ -s $1 ] ; then"
echo "	chmod 755 $1"
echo "	$@"
echo "fi"
echo 'exit 0'
}

# Version 1.0.2.8
build_rc0d()
{
echo '#!/bin/bash'
echo '# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES'
echo '#'
echo '# It is highly advisable to create own systemd services or udev rules'
echo '# to run scripts during boot instead of using this file.'
echo '#'
echo '# In contrast to previous versions due to parallel execution during boot'
echo '# this script will NOT be run after all other services.'
echo '#'
echo '# Please note that you must run "chmod +x /etc/rc.d/rc.local" to ensure'
echo '# that this script will be executed during boot.'
echo ''
echo 'dmesg -n 1'
echo 'if [ -s "/root/bin/ipconfig.sh" ] ; then'
echo '	if [ -s "/root/.ip4addr2" ] ; then'
echo '		cp -f /root/.ip4addr2 /root/.ipconfig'
echo '		mv -f /root/.ipconfig /root/.ipconfig2'
echo '	fi'
echo '	if [ -s "/root/.ipconfig2" ] ; then'
echo '		/root/bin/ipconfig.sh 2 $(cat /root/.ipconfig2)'
echo '	fi'
echo '	if [ -s "/root/.ip4addr1" ] ; then'
echo '		cp -f /root/.ip4addr1 /root/.ipconfig'
echo '		mv -f /root/.ipconfig /root/.ipconfig1'
echo '	fi'
echo '	if [ -s "/root/.ipconfig1" ] ; then'
echo '		/root/bin/ipconfig.sh 1 $(cat /root/.ipconfig1)'
echo '	fi'
echo 'fi'
echo 'exit 0'
}

# Version 1.0.2.23
set_maxring()
{
	local eth rx_max tx_max fc_on 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
	done
	sleep 1
}

# Version 1.0.2.23
is_maxring()
{
	local eth rx_max tx_max fc_on 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		rx_cur=$(ethtool -g $eth |grep -A 4 Current |awk '/RX:/ {print $2}')
		tx_cur=$(ethtool -g $eth |grep -A 4 Current |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		test "$rx_cur" = "rx_max" -a "$tx_cur" = "tx_max"
		let sta+=$?
		echo $eth: $(ethtool -g $eth |grep -A 4 Current |grep 'RX:\|TX:')
	done
	sleep 1
}

# Version 1.0.2.19
adapt_on()
{
	local sta rx tx
	let sta=0
	test -n "$1" || try Interface
	for eth in $@ ; do
		ethtool -C $eth adaptive-tx on &> /dev/null
		ethtool -C $eth adaptive-rx on &> /dev/null
	done
	sleep 1
	for eth in $@ ; do
		rx=$(ethtool -c $eth |grep Adaptive |awk '{print $3}')
		tx=$(ethtool -c $eth |grep Adaptive |awk '{print $5}')
		test "$rx" = "on" -a "$tx" = "on"
		let sta+=$?
		echo $eth: $(ethtool -c $eth |grep Adaptive)
	done
	return $sta
}

# Version 1.0.2.19
adapt_off()
{
	local sta rx tx
	let sta=0
	test -n "$1" || try Interface
	for eth in $@ ; do
		ethtool -C $eth adaptive-tx off &> /dev/null
		ethtool -C $eth adaptive-rx off &> /dev/null
	done
	sleep 1
	for eth in $@ ; do
		rx=$(ethtool -c $eth |grep Adaptive |awk '{print $3}')
		tx=$(ethtool -c $eth |grep Adaptive |awk '{print $5}')
		test "$rx" = "off" -a "$tx" = "off"
		let sta+=$?
		echo $eth: $(ethtool -c $eth |grep Adaptive)
	done
	return $sta
}

# Version 1.0.3.4
set_usecs()
{
	local eth txusecs rxusecs txu rxu txus rxus
	let rxusecs=$1
	test -z "$rxusecs" && try rx-usecs $rxusecs
	shift
	let txusecs=$1
	test -z "$txusecs" && try tx-usecs $txusecs
	shift
	test -n "$1" || try Interface
	for eth in $@ ; do
		let txus=$txusecs
		let rxus=$rxusecs
		let txu=$(ethtool -c $eth |grep tx-usecs: |awk '{print $2}')
		let rxu=$(ethtool -c $eth |grep rx-usecs: |awk '{print $2}')
		test "$txu" -eq "0" && let txus=$txu
		test "$txus" -eq "0" && let rxus=$rxu
		ethtool -C $eth tx-usecs $txus &> /dev/null
		ethtool -C $eth rx-usecs $rxus &> /dev/null
	done
	sleep 1
}

# Version 1.0.3.4
get_usecs()
{
	local sta left eth txusecs rxusecs txu rxu txus rxus
	let rxusecs=$1
	test -z "$rxusecs" && try rx-usecs $rxusecs
	shift
	let txusecs=$1
	test -z "$txusecs" && try tx-usecs $txusecs
	shift
	let sta=0
	test -n "$1" || try Interface
	for eth in $@ ; do
		let left=10
		let txus=$txusecs
		let rxus=$rxusecs
		let txu=$(ethtool -c $eth |grep tx-usecs: |awk '{print $2}')
		let rxu=$(ethtool -c $eth |grep rx-usecs: |awk '{print $2}')
		test "$txu" -eq "0" && let txus=$txu
		test "$txus" -eq "0" && let rxus=$rxu
		until [[ "$rxus" -eq "$rxu" || "$left" -eq "0" ]] ; do
			ethtool -C $eth tx-usecs $txus &> /dev/null
			ethtool -C $eth rx-usecs $rxus &> /dev/null
			sleep 1
			let txu=$(ethtool -c $eth |grep tx-usecs: |awk '{print $2}')
			let rxu=$(ethtool -c $eth |grep rx-usecs: |awk '{print $2}')
			let --left
		done
		echo $eth: $(ethtool -c $eth |grep "tx-usecs:\|rx-usecs:")
		let txu=$(ethtool -c $eth |grep tx-usecs: |awk '{print $2}')
		let rxu=$(ethtool -c $eth |grep rx-usecs: |awk '{print $2}')
		test "$txus" -eq "$txu" -o "$txus" -eq "0"
		test "$?" || {
			status "$eth tx-usecs" 1
			let sta+=$?
			# break
		}
		test "$rxus" -eq "$rxu" || {
			status "$eth rx-usecs" 1
			let sta+=$?
			# break
		}
	done
	return $sta
}

# Version 2.0.0.6
set_channels()
{
	local eth ch_set ch_max ch_num ch_qty rx_max rx_num rx_qty tx_max tx_num tx_qty
	let ch_set=$1
	try Set_Channel $ch_set
	shift
	test -n "$1" || try Interface
	for eth in $@ ; do
		let ch_qty=rx_qty=tx_qty=$ch_set
		ch_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/Combined:/ {print $2}')
		test "$ch_qty" -gt "$ch_max" -a "$ch_max" -gt "0" && let ch_qty=$ch_max
		ch_num=$(ethtool -l $eth |grep -A 4 Current |awk '/Combined:/ {print $2}')
		test "$ch_max" -gt "0" -a "$ch_num" -ne "$ch_qty" && ethtool -L $eth combined $ch_qty
	done
	sleep 1
	for eth in $@ ; do
		let ch_qty=rx_qty=tx_qty=$ch_set
		ch_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/Combined:/ {print $2}')
		test "$ch_qty" -gt "$ch_max" -a "$ch_max" -gt "0" && let ch_qty=$ch_max
		ch_num=$(ethtool -l $eth |grep -A 4 Current |awk '/Combined:/ {print $2}')
		test "$ch_qty" -eq "$ch_num" || {
			rx_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
			test "$rx_qty" -gt "$rx_max" && let rx_qty=$rx_max
			rx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/RX:/ {print $2}')
			test "$rx_max" -gt "0" -a "$rx_num" -ne "$rx_qty" && ethtool -L $eth rx $rx_qty
			tx_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
			test "$tx_qty" -gt "$tx_max" && let tx_qty=$tx_max
			tx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/TX:/ {print $2}')
			test "$tx_max" -gt "0" -a "$tx_num" -ne "$tx_qty" && ethtool -L $eth tx $tx_qty
		}
	done
	sleep 1
}

# Version 2.0.0.3
get_channels()
{
	local sta left eth ch_set ch_max ch_num ch_qty rx_max rx_num rx_qty tx_max tx_num tx_qty
	let ch_set=ch_qty=rx_qty=tx_qty=$1
	try Get_Channel $ch_set
	shift
	let sta=0
	test -n "$1" || try Interface
	for eth in $@ ; do
		let ch_qty=rx_qty=tx_qty=$ch_set
		rx_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		test "$rx_qty" -gt "$rx_max" -a "$rx_max" -gt "0" && let rx_qty=$rx_max
		rx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		test "$tx_qty" -gt "$tx_max" -a "$tx_max" -gt "0" && let tx_qty=$tx_max
		tx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/TX:/ {print $2}')
		ch_max=$(ethtool -l $eth |grep -A 4 maximum |awk '/Combined:/ {print $2}')
		test "$ch_qty" -gt "$ch_max" -a "$ch_max" -gt "0" && let ch_qty=$ch_max
		ch_num=$(ethtool -l $eth |grep -A 4 Current |awk '/Combined:/ {print $2}')
		let left=10
		while [[ "$ch_max" -gt "0" && "$ch_num" -ne "$ch_qty" && "$left" -gt "0" ]] ; do
			ethtool -L $eth combined $ch_qty
			sleep 1
			ch_num=$(ethtool -l $eth |grep -A 4 Current |awk '/Combined:/ {print $2}')
			let --left
		done
		ch_num=$(ethtool -l $eth |grep -A 4 Current |awk '/Combined:/ {print $2}')
		test "$ch_qty" -eq "$ch_num" || {
			let left=10
			while [[ "$rx_max" -gt "0" && "$rx_num" -ne "$rx_qty" && "$left" -gt "0" ]] ; do
				ethtool -L $eth rx $rx_qty
				sleep 1
				rx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/RX:/ {print $2}')
				let --left
			done
			let left=10
			while [[ "$tx_max" -gt "0" && "$tx_num" -ne "$tx_qty" && "$left" -gt "0" ]] ; do
				ethtool -L $eth rx $tx_qty
				sleep 1
				tx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/TX:/ {print $2}')
				let --left
			done
		}
		ethtool -l $eth |grep -A 4 Current |grep -v Other
		rx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/RX:/ {print $2}')
		tx_num=$(ethtool -l $eth |grep -A 4 Current |awk '/TX:/ {print $2}')
		ch_num=$(ethtool -l $eth |grep -A 4 Current |awk '/Combined:/ {print $2}')
		test "$ch_qty" -eq "$ch_num" && continue
		test "$ch_max" -gt "0" -a "$ch_num" -ne "$ch_qty" && {
			status "$eth Channel parameters" 1
			let sta+=$?
			break
		}
		test "$rx_max" -gt "0" -a "$rx_num" -ne "$rx_qty" && {
			status "$eth Channel parameters" 1
			let sta+=$?
			break
		}
		test "$tx_max" -gt "0" -a "$tx_num" -ne "$tx_qty" && {
			status "$eth Channel parameters" 1
			let sta+=$?
			break
		}
	done
	return $sta
}

# Version 1.0.2.11
reset_flowctl()
{
	local eth rx_max tx_max fc_off 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		# ethtool -C $eth rx-usecs 30 &> /dev/null
		fc_off=$(ethtool -a $eth |grep -cw off)
		if [ "$fc_off" != "3" ]; then
			ethtool -s $eth autoneg off &> /dev/null
			ethtool -A $eth autoneg off &> /dev/null
			ethtool -A $eth rx off tx off &> /dev/null
			sleep 1
		fi
	done
	sleep 3
}

# Version 1.0.2.8
no_flowctl()
{
	local eth sta left fc_off 
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do ip link set up $eth ; done
	for eth in $@ ; do
		let left=30
		fc_off=$(ethtool -a $eth |grep -cw off)
		until [[ "$fc_off" = "3"  || "$left" -eq "0" ]] ; do
			ethtool -s $eth autoneg off &> /dev/null
			ethtool -A $eth autoneg off &> /dev/null
			ethtool -A $eth rx off tx off &> /dev/null
			sleep 3
			fc_off=$(ethtool -a $eth |grep -cw off)
			if [ "$fc_off" != "3" ] ; then
				echo "$eth flow control has error : left $left retry"
				ip link set up $eth
				sleep 3
			fi
			let --left
		done
		ethtool -a $eth
		fc_off=$(ethtool -a $eth |grep -cw off)
		if [ "$fc_off" != "3" ] ; then
			status "$eth Flow Control" 1
			let sta+=$?
			break
		fi
	done
	return $sta
}

# Version 1.0.2.11
set_flowctl()
{
	local eth rx_max tx_max fc_on 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		# ethtool -C $eth rx-usecs 30 &> /dev/null
		fc_on=$(ethtool -a $eth |grep -cw on)
		if [ "$fc_on" != "2" ]; then
			ethtool -s $eth autoneg off &> /dev/null
			ethtool -A $eth autoneg off &> /dev/null
			ethtool -A $eth rx on tx on &> /dev/null
			sleep 1
		fi
	done
	sleep 3
}

# Version 1.0.2.8
is_flowctl()
{
	local eth sta left fc_on
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do ip link set up $eth ; done
	for eth in $@ ; do
		let left=30
		fc_on=$(ethtool -a $eth |grep -cw on)
		until [[ "$fc_on" = "2"  || "$left" -eq "0" ]] ; do
			ethtool -s $eth autoneg off &> /dev/null
			ethtool -A $eth autoneg off &> /dev/null
			ethtool -A $eth rx on tx on &> /dev/null
			sleep 3
			fc_on=$(ethtool -a $eth |grep -cw on)
			if [ "$fc_on" != "2" ] ; then
				echo "$eth flow control has error : left $left retry"
				ip link set up $eth
				sleep 3
			fi
			let --left
		done
		ethtool -a $eth
		fc_on=$(ethtool -a $eth |grep -cw on)
		if [ "$fc_on" != "2" ] ; then
			status "$eth Flow Control" 1
			let sta+=$?
		fi
	done
	return $sta
}

# Version 1.0.2.11
set_autoneg()
{
	local eth rx_max tx_max fc_on 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		# ethtool -C $eth rx-usecs 30 &> /dev/null
		fc_on=$(ethtool -a $eth |grep -cw on)
		if [ "$fc_on" != "3" ]; then
			ethtool -s $eth autoneg on &> /dev/null
			ethtool -A $eth autoneg on &> /dev/null
			ethtool -A $eth rx on tx on &> /dev/null
			sleep 1
		fi
	done
	sleep 3
}

# Version 1.0.2.8
is_autoneg()
{
	local eth sta left fc_on
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do ip link set up $eth ; done
	for eth in $@ ; do
		let left=30
		fc_on=$(ethtool -a $eth |grep -cw on)
		until [[ "$fc_on" = "3"  || "$left" -eq "0" ]] ; do
			ethtool -s $eth autoneg on &> /dev/null
			ethtool -A $eth autoneg on &> /dev/null
			ethtool -A $eth rx on tx on &> /dev/null
			sleep 3
			fc_on=$(ethtool -a $eth |grep -cw on)
			if [ "$fc_on" != "3" ] ; then
				echo "$eth autoneg has error : left $left retry"
				ip link set up $eth
				sleep 3
			fi
			let --left
		done
		ethtool -a $eth
		fc_on=$(ethtool -a $eth |grep -cw on)
		if [ "$fc_on" != "3" ] ; then
			status "$eth Autoneg" 1
			let sta+=$?
		fi
	done
	return $sta
}

# Version 1.0.2.11
set_txrx()
{
	local eth rx_max tx_max fc_on 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		# ethtool -C $eth rx-usecs 30 &> /dev/null
		fc_on=$(ethtool -a $eth |grep -cw on)
		if [[ "$fc_on" != "2" && "$fc_on" != "3" ]]; then
			ethtool -A $eth rx on tx on &> /dev/null
			sleep 1
		fi
	done
	sleep 3
}

# Version 1.0.2.11
reset_txrx()
{
	local eth rx_max tx_max fc_off 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		# ethtool -C $eth rx-usecs 30 &> /dev/null
		fc_off=$(ethtool -a $eth |grep -cw off)
		if [[ "$fc_off" != "2" && "$fc_off" != "3" ]]; then
			ethtool -A $eth rx off tx off &> /dev/null
			sleep 1
		fi
	done
	sleep 3
}

# Version 1.0.2.25
is_txrxon()
{
	local eth sta left fc_on
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do ip link set up $eth ; done
	for eth in $@ ; do
		let left=30
		fc_on=$(ethtool -a $eth |grep -cw on)
		until [[ "$fc_on" -eq "2" || "$fc_on" -eq "3" || "$left" -eq "0" ]] ; do
			ethtool -A $eth rx on tx on &> /dev/null
			sleep 3
			fc_on=$(ethtool -a $eth |grep -cw on)
			if [[ "$fc_on" != "2" && "$fc_on" != "3" ]] ; then
				echo "$eth flow control has error : left $left retry"
				ip link set up $eth
				sleep 3
			fi
			let --left
		done
		ethtool -a $eth
		fc_on=$(ethtool -a $eth |grep -cw on)
		if [[ "$fc_on" != "2" && "$fc_on" != "3" ]] ; then
			status "$eth Flow Control" 1
			let sta+=$?
		fi
	done
	return $sta
}

# Version 1.0.2.25
is_txrxoff()
{
	local eth sta left fc_off
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do ip link set up $eth ; done
	for eth in $@ ; do
		let left=30
		fc_off=$(ethtool -a $eth |grep -cw off)
		until [[ "$fc_off" -eq "2" || "$fc_off" -eq "3" || "$left" -eq "0" ]] ; do
			ethtool -A $eth rx off tx off &> /dev/null
			sleep 3
			fc_on=$(ethtool -a $eth |grep -cw off)
			if [[ "$fc_off" != "2" && "$fc_off" != "3" ]] ; then
				echo "$eth flow control has error : left $left retry"
				ip link set up $eth
				sleep 3
			fi
			let --left
		done
		ethtool -a $eth
		fc_off=$(ethtool -a $eth |grep -cw off)
		if [[ "$fc_off" != "2" && "$fc_off" != "3" ]] ; then
			status "$eth Flow Control" 1
			let sta+=$?
		fi
	done
	return $sta
}

# Version 1.0.0.0
set_features()
{
	local eth offl sta
	test -n "$1" || try Interface
	let sta=0
	for eth in $@ ; do
		ethtool -K $eth rx off tx off
		offl=$(ethtool -k $eth | grep checksumming | grep -ciw off)
		if [ "$offl" != "2" ] ; then
			status "$eth Checksum Control" 1
			let sta+=$?
		fi
		ethtool -K $eth tso off
		offl=$(ethtool -k $eth | grep tcp-segmentation-offload | grep -ciw off)
		if [ "$offl" = "0" ] ; then
			status "$eth TCP-Segmentation Control" 1
			let sta+=$?
		fi
		ethtool -K $eth sg off
		offl=$(ethtool -k $eth | grep scatter-gather: | grep -ciw off)
		if [ "$offl" != "2" ] ; then
			status "$eth Scatter-Gather Control" 1
			let sta+=$?
		fi
	done
	return $sta
}

# Version 1.0.0.0
check_cpuqty()
{
	local ncpu
	let ncpu=$(nproc) # $(cat /proc/cpuinfo |grep -c proc)
	try CPU_qty $ncpu
	if [ "$ncpu" -lt "2" ] ; then
		echo "Nothing to do"
		if [[ -z "$noExit" ]]; then exit 1;	fi
	fi
	return $ncpu
}

# Version 1.0.0.36
stop_irqbalance()
{
	local ret
	ps -A |grep -q irqbalance
	ret=$?
	if [ "$ret" = "0" ] ; then
		kill_proc irqbalance
		ps -A |grep -q irqbalance
		ret=$?
	fi 
	return $ret
}

# Version 1.0.0.0
get_irqbalance ()
{
	local ret
	ps -A |grep -q irqbalance
	ret=$?
	if [ "$ret" = "0" ]; then
		echo "irqbalance service is running"
	else
		echo "irqbalance service is stoped"
	fi
	return $ret
}

# Allow usage of ',' or '-'
# Version 1.0.2.13
parse_range () {
	local list range r
	range=${@//,/ }
	range=${range//-/..}
	list=""
	for r in $range; do
		# eval lets us use vars in {#..#} range
		[[ $r =~ '..' ]] && r="$(eval echo {$r})"
		list+=" $r"
	done
	echo $list
}

# Version 1.0.2.22
set_affinity()
{
	local cores iface queues irqs IRQ core j n
	cores=$1
	shift
	iface=$1
	test -z "$iface" && try Interface
	cores=$(parse_range $cores)
	ncores=$(echo $cores | wc -w)
	n=1
	queues="${iface}-.*TxRx"
	irqs=$(grep "$queues" /proc/interrupts | cut -f1 -d:)
	[ -z "$irqs" ] && irqs=$(grep -w $iface /proc/interrupts | cut -f1 -d:)
	[ -z "$irqs" ] && irqs=$(for i in `ls -Ux /sys/class/net/$iface/device/msi_irqs` ;\
					do grep "$i:.*TxRx" /proc/interrupts | grep -v fdir | cut -f 1 -d : ;\
					done)
	[ -z "$irqs" ] && echo "Error: Could not find interrupts for $iface"
	echo "IFACE CORE MASK -> FILE"
	echo "======================="
	for IRQ in $irqs; do
		[ "$n" -gt "$ncores" ] && n=1
		j=1
		# much faster than calling cut for each
		for core in $cores; do
			[ $((j++)) -ge $n ] && break
		done
		set_smp_affinity $core $iface $IRQ
		((n++))
	done
	echo "======================="
}

# Version 1.0.2.13
set_smp_affinity()
{
	local vec idx mask mask_fill mask_zero mask_tmp core=$1 iface=$2 IRQ=$3
	test -z "$core" && try Cpu_Num
	test -z "$iface" && try Interface
	test -z "$IRQ" && try Interrupt
	vec=$core
	if [ $vec -ge 32 ] ; then
		mask_fill=""
		mask_zero="00000000"
		let "idx = $vec / 32"
		for ((i=1; i<=$idx;i++)) ; do
			mask_fill="${mask_fill},${mask_zero}"
		done
		let "vec -= 32 * $idx"
		mask_tmp=$((1<<$vec))
		mask=$(printf "%X%s" $mask_tmp $mask_fill)
	else
		mask_tmp=$((1<<$vec))
		mask=$(printf "%X" $mask_tmp)
	fi
	printf "%s" $mask > /proc/irq/$IRQ/smp_affinity
	printf "%s %d %s -> /proc/irq/$IRQ/smp_affinity\n" $iface $core $mask
	# XPS_ENABLE / XPS_DISABLE (mask=0 for disable)
	# mask=0 # '0' for disable
	# printf "%s %d %s -> /sys/class/net/%s/queues/tx-%d/xps_cpus\n" $iface $core $mask $iface $((n-1))
	# printf "%s" $mask > /sys/class/net/$iface/queues/tx-$((n-1))/xps_cpus
	let left=10
	let val=0x$(cat /proc/irq/$IRQ/smp_affinity |awk -F, '{print $NF}')
	value=$(printf '%x' $val)
	while [[ "$mask" != "$value" && "$left" -gt "0" ]] ; do
		printf "%s" $mask > /proc/irq/$IRQ/smp_affinity
		printf "%s %d %s -> /proc/irq/$IRQ/smp_affinity\n" $iface $core $mask
		sleep 1
		let --left
		let val=0x$(cat /proc/irq/$IRQ/smp_affinity |awk -F, '{print $NF}')
		value=$(printf '%x' $val)
	done
	test "$left" -eq "0" && printf "%s %d %s <- /proc/irq/$IRQ/smp_affinity\n" $iface $core $value
}

# Version 1.0.2.22
set_irq_aff()
{
	local sta ncpu ncpus eth queues irqs irq j cpu mask left value val
	let ncpus=$(nproc)
	test -z "$ncpus" -o "$ncpus" -eq "0" && try Cpu_Qty $ncpus
	let ncpu=$1
	test -z "$ncpu" && try Cpu_Num
	shift
	let sta=0
	test -z "$1" && try Interface
	for eth in $@ ; do
		queues="${eth}-.*TxRx"
		irqs=$(grep "$queues" /proc/interrupts | cut -f1 -d:)
		[ -z "$irqs" ] && irqs=$(grep -w $eth /proc/interrupts | cut -f1 -d:)
		[ -z "$irqs" ] && irqs=$(for j in $(ls -Ux /sys/class/net/$eth/device/msi_irqs) ;\
					do grep "$j:.*TxRx" /proc/interrupts |grep -v fdir |cut -f1 -d: ;\
					done)
		[ -z "$irqs" ] && echo "Error: Could not find interrupts for $eth"
		[ -z "$irqs" ] && let sta++
		for irq in $irqs ; do
			test -r "/proc/irq/$irq/smp_affinity" || continue
			let cpu=ncpu%ncpus
			if [ $cpu -lt 0 ] ; then continue ; fi
			mask=`printf %x $[2 ** $cpu]`
			echo "Assign SMP affinity: irq $irq, eth $eth, cpu $cpu, mask 0x$mask"
			echo "$mask" > /proc/irq/$irq/smp_affinity
		done
		sleep 1
		for irq in $irqs ; do
			test -r "/proc/irq/$irq/smp_affinity" || continue
			let cpu=ncpu%ncpus
			if [ $cpu -lt 0 ] ; then continue ; fi
			mask=`printf %x $[2 ** $cpu]`
			let left=10
			let val=0x$(cat /proc/irq/$irq/smp_affinity |awk -F, '{print $NF}')
			value=$(printf '%x' $val)
			while [[ "$mask" != "$value" && "$left" -gt "0" ]] ; do
				echo "$mask" > /proc/irq/$irq/smp_affinity
				sleep 1
				let --left
				let val=0x$(cat /proc/irq/$irq/smp_affinity |awk -F, '{print $NF}')
				value=$(printf '%x' $val)
				echo "SMP affinity value: irq $irq, eth $eth, cpu $cpu, value 0x$value"
			done
			test "$left" -eq "0" && let sta++
		done
	done
	return $sta
}

# Version 1.0.2.22
set_irq()
{
	test -n "$1" || try CPU_qty
	local ncpu=$1
	shift
	test -n "$1" || try Interface
	local eth queues irqs irq j cpu mask left value val nn n
	let n=0
	for eth in $@ ; do
		queues="${eth}-.*TxRx"
		irqs=$(grep "$queues" /proc/interrupts | cut -f1 -d:)
		[ -z "$irqs" ] && irqs=$(grep -w $eth /proc/interrupts | cut -f1 -d:)
		[ -z "$irqs" ] && irqs=$(for j in $(ls -Ux /sys/class/net/$eth/device/msi_irqs) ;\
					do grep "$j:.*TxRx" /proc/interrupts |grep -v fdir |cut -f1 -d: ;\
					done)
		[ -z "$irqs" ] && echo "Error: Could not find interrupts for $eth"
		let nn=$n
		for irq in $irqs ; do
			test -r "/proc/irq/$irq/smp_affinity" || continue
			let cpu=n%ncpu
			if [ $cpu -lt 0 ] ; then continue ; fi
			mask=`printf %x $[2 ** $cpu]`
			echo "Assign SMP affinity: irq $irq, eth $eth, cpu $cpu, mask 0x$mask"
			echo "$mask" > /proc/irq/$irq/smp_affinity
			let ++n
		done
		sleep 2
		let n=$nn
		for irq in $irqs ; do
			test -r "/proc/irq/$irq/smp_affinity" || continue
			let cpu=n%ncpu
			if [ $cpu -lt 0 ] ; then continue ; fi
			mask=`printf %x $[2 ** $cpu]`
			let left=10
			let val=0x$(cat /proc/irq/$irq/smp_affinity |awk -F, '{print $NF}')
			value=$(printf '%x' $val)
			while [[ "$mask" != "$value" && "$left" -gt "0" ]] ; do
				echo "$mask" > /proc/irq/$irq/smp_affinity
				sleep 2
				let --left
				let val=0x$(cat /proc/irq/$irq/smp_affinity |awk -F, '{print $NF}')
				value=$(printf '%x' $val)
				echo "SMP affinity value: irq $irq, eth $eth, cpu $cpu, value 0x$value"
			done
			let ++n
		done
	done
	return 0
}

# Version 1.0.0.47
check_rdif_status()
{
	which rdifctl > /dev/null || try rdifctl
	which rdifd   > /dev/null || try rdifd
	which rdif    > /dev/null || try rdif
	local sta pid
	pid=$(pidof rdifd)
	echo rdifd $pid
	if [ -z "$pid" ] ; then
		expect -c "
		set timeout 30
		log_user 1
		exp_internal 0
		spawn rdifd -v &
		expect {
		*inserted!* { }
		timeout { send_user \nTimeout\n ; exit 1 }
		eof { send_user \nEOF\n ; exit 1 }
		}
		expect {
		*enabled* { send_user Done\n ; send exit\r }
		timeout { send_user \nTimeout\n ; exit 1 }
		eof { send_user \nEOF\n ; exit 1 }
		}
		"
		let sta=$?
		test "$sta" -eq "0" || try RDIFD_status 0
	fi
}

# Version 1.0.0.0
check_rdif_devnum()
{
	test -n "$1" || try DEV_NUM
	local dev_qty dev_num loop i
	let loop=9
	let dev_qty=$1
	let dev_num=0
	for ((i=loop; i>0; --i)) ; do
		dev_num=$(rdifctl get_dev_num |grep -v Fail |cut -d' ' -f6)
		test -n "$dev_num" && break
		sleep 1
		echo retry $i
	done
	test -n "$dev_num" || try Rdif_Device
	test "$dev_num" -eq "$DEV_NUM" || try Rdif_Dev_Qty 0
	try dev_num $dev_num
}

# Version 1.0.1.2
is_double_net()
{
	local devices=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep net |awk -F/ '{print $NF}')
	test -n "$devices" || try Interface 0
	test -n "$1" || try Source_Interface
	test -n "$2" || try Target_Interface
	local dev eth net
	for net in $@ ; do
		eth=""
		for dev in $devices ; do
			test "$net" = "$dev" && eth=$dev && break
		done
		test -n "$eth" || try "Interface:$net"
	done
	return 0
}

# Version 1.0.0.0
nic2net()
{
	which eeupdate64e > /dev/null || try eeupdate64e
	test -n "$1" || try NIC
	local eth sta mac j
	local net=""
	let sta=0
	for j in $@ ; do
		eeupdate64e /nic=$j /mac_dump_file > /dev/null
		let sta+=$?
		mac=$(cat mac.txt)
		try "MAC[$j]" $mac
		mac=$(echo ${mac:0:2}:${mac:2:2}:${mac:4:2}:${mac:6:2}:${mac:8:2}:${mac:10:2})
		eth=$(grep -i $mac /sys/class/net/*/address | cut -d/ -f5)
		test -n "$eth" || try Interface
		net=$(echo $net $eth)
	done
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return $sta
}

# Version 1.0.0.15
pep2net()
{
	local rrcbuses=$(grep '0x15a4' /sys/bus/pci/devices/*/device |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	echo RRC.bus=$rrcbuses
	which lspci > /dev/null || try lspci
	test -n "$1" || try PEP_MAX
	local pep_max
	let pep_max=$1
	shift
	local lpep pep bus j
	local net=""
	test -n "$1" || try PEP 0
	for j in $@ ; do
		echo
		let lpep=$j
		try PEP 0$lpep
		test "$lpep" -le $PEP_MAX || try PEP 0
		for bus in $rrcbuses ; do
			pep=$(echo $(lspci -nns:$bus -vv |grep -a '\[VP\]' |cut -d: -f2))
			if [ "$lpep" = "$pep" ] ; then
				eth=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $bus |awk -F/ '{print $NF}')
				test -n "$eth" || try PEP 0
				echo net=$eth
				net=$(echo $net $eth)
			fi
		done
	done
	echo
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return 0
}

# Version 1.0.2.4
dev0pep2net()
{
	approve_motherboard "X10DRi"
	local rrcbuses=$(grep '0x15a4' /sys/bus/pci/devices/*/device |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	echo RRC.bus=$rrcbuses
	which lspci > /dev/null || try lspci
	test -n "$1" || try PEP_MAX
	local pep_max
	let pep_max=$1
	shift
	local lpep pep bus j
	local net=""
	test -n "$1" || try PEP 0
	for j in $@ ; do
		echo
		let lpep=$j
		try PEP 0$lpep
		test "$lpep" -le $PEP_MAX || try PEP 0
		for bus in $rrcbuses ; do
			pep=$(echo $(lspci -nns:$bus -vv |grep -a '\[VP\]' |cut -d: -f2))
			if [ "$lpep" = "$pep" ] ; then
				test "${bus:0:2}" -ge "80" && continue
				eth=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $bus |awk -F/ '{print $NF}')
				test -n "$eth" || try PEP 0
				echo net=$eth
				net=$(echo $net $eth)
			fi
		done
	done
	echo
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return 0
}

# Version 1.0.2.4
dev1pep2net()
{
	approve_motherboard "X10DRi"
	local rrcbuses=$(grep '0x15a4' /sys/bus/pci/devices/*/device |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	echo RRC.bus=$rrcbuses
	which lspci > /dev/null || try lspci
	test -n "$1" || try PEP_MAX
	local pep_max
	let pep_max=$1
	shift
	local lpep pep bus j
	local net=""
	test -n "$1" || try PEP 0
	for j in $@ ; do
		echo
		let lpep=$j
		try PEP 0$lpep
		test "$lpep" -le $PEP_MAX || try PEP 0
		for bus in $rrcbuses ; do
			pep=$(echo $(lspci -nns:$bus -vv |grep -a '\[VP\]' |cut -d: -f2))
			if [ "$lpep" = "$pep" ] ; then
				test "${bus:0:2}" -lt "80" && continue
				eth=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $bus |awk -F/ '{print $NF}')
				test -n "$eth" || try PEP 0
				echo net=$eth
				net=$(echo $net $eth)
			fi
		done
	done
	echo
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return 0
}

# Version 1.0.3.2
auto_slot2bus()
{
	which dmidecode > /dev/null || try dmidecode
	local pciebus=$(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3)
	echo PCIeBus=$pciebus
	# begin: for the back compatibility only
	test -z "$1" && try Device_ID
	local did=$1
	shift
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	# end: for the back compatibility only
	test -z "$1" && try Tested_Slot
	local slot pci plxbus i ethbus bus exist
	local net=""
	local plx=""
	local plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	local ethbuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	test -z "$ethbuses" && try Eth_Device
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		let i=0
		for pci in $pciebus ; do
			let ++i
			test "$i" = "$slot" || continue
			test "$pci" = "ff" && try Tested_Slot 0
			try tested_slot $slot
			echo slot[$i].pcibus=$pci
			plxbus=""
			for bus in $plxbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep :$pci: |awk -F/ '{print $NF}' |grep -w $bus)
				test -z "$exist" || plxbus=$(echo $plxbus $bus)
			done
			test -z "$plxbus" || echo slot[$i].plx=$plxbus
			plx=$(echo $plx $plxbus)
			ethbus=""
			for bus in $ethbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep :$pci: |awk -F/ '{print $NF}' |grep -w $bus)
				test -z "$exist" || ethbus=$(echo $ethbus $bus)
			done
			test -z "$ethbus" && try Eth_Bus
			echo slot[$i].ethbus=$ethbus
			net=$(echo $net $ethbus)
		done
	done
	#save result to 'plx$1' for the future using
	echo $plx > plx$1
	test -z "$plx" || test -s "plx$1" || try Error
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	# echo "-------------------------"
	return 0
}

# Version 1.0.3.2
autoslot2net()
{
	which dmidecode > /dev/null || try dmidecode
	local pciebus=$(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3)
	echo PCIeBus=$pciebus
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot eth pci plxbus i bus exist neta
	local net=""
	local plx=""
	local plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		let i=0
		for pci in $pciebus ; do
			let ++i
			test "$i" = "$slot" || continue
			test "$pci" = "ff" && try Tested_Slot 0
			try tested_slot $slot
			echo slot[$i].bus=$pci
			plxbus=""
			for bus in $plxbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep :$pci: |awk -F/ '{print $NF}' |grep -w $bus)
				test -z "$exist" || plxbus=$(echo $plxbus $bus)
			done
			test -z "$plxbus" || echo slot[$i].plx=$plxbus
			plx=$(echo $plx $plxbus)
			eth=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep :$pci: |awk -F/ '{print $NF}')
			test -z "$eth" && try Interface
			echo slot[$i].net=$eth
			neta=($eth)
			test "$pqty" = "0" || test "$pqty" = "${#neta[@]}" || try Port_Qty 0
			net=$(echo $net $eth)
		done
	done
	#save result to 'plx$1' for the future using
	echo $plx > plx$1
	test -z "$plx" || test -s "plx$1" || try Error
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return 0
}

# Version 1.0.0.22
x8x8_slot2net()
{
	which dmidecode > /dev/null || try dmidecode
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot list1 sid1 num1 bus1 bus2 hex1 hex2 net1 net2 qty nets buses
	local net=""
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		list1=$(echo $(dmidecode -t slot |grep -A8 x16 |grep -A7 "In Use" |grep ID: |cut -d' ' -f2))
		test -z "$list1" && try Tested_Slot
		sid1=$(dmidecode -t slot |grep -A8 x16 |grep -A7 "In Use" |grep "ID: $slot")
		test -z "$sid1" && try Tested_Slot
		num1=$(echo $sid1 |cut -d' ' -f2)
		try tested_slot $num1
		test "$num1" = "$slot" || try Tested_Slot 0
		bus1=$(dmidecode -t slot |grep -A8 x16 |grep -A7 "In Use" |grep -A5 "ID: $slot" |grep "Bus Address:" |cut -d: -f3)
		try tested_bus1 $bus1
		let hex1=0x$bus1
		let hex2=hex1+1
		bus2=$(printf "%02x" $hex2)
		try tested_bus2 $bus2
		qty=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -ci ":$bus1:\|:$bus2:")
		net1=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep :$bus1: |awk -F/ '{print $NF}')
		net2=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep :$bus2: |awk -F/ '{print $NF}')
		test "$net1" = "$net2" && net2=""
		case $slot in
		2)   nets=$(echo $net2 $net1) ; buses=$(echo 0x$bus2 0x$bus1) ;;
		4|6) nets=$(echo $net1 $net2) ; buses=$(echo 0x$bus1 0x$bus2) ;;
		*)   try Tested_Slot 0 ;;
		esac
		echo buses=$buses
		echo ports=$nets
		try port_qty $qty
		test "$pqty" = "0" || test "$pqty" = "$qty" || try Port_Qty 0
		net=$(echo $net $nets)
	done
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return 0
}

# Version 1.0.0.22
x4x4_slot2net()
{
	which dmidecode > /dev/null || try dmidecode
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot list1 sid1 num1 bus1 bus2 hex1 hex2 net1 net2 qty nets buses
	local net=""
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		list1=$(echo $(dmidecode -t slot |grep -A7 "In Use" |grep ID: |cut -d' ' -f2))
		test -z "$list1" && try Tested_Slot
		sid1=$(dmidecode -t slot |grep -A7 "In Use" |grep "ID: $slot")
		test -z "$sid1" && try Tested_Slot
		num1=$(echo $sid1 |cut -d' ' -f2)
		try tested_slot $num1
		test "$num1" = "$slot" || try Tested_Slot 0
		bus1=$(dmidecode -t slot |grep -A7 "In Use" |grep -A5 "ID: $slot" |grep "Bus Address:" |cut -d: -f3)
		try tested_bus1 $bus1
		let hex1=0x$bus1
		let hex2=hex1+1
		bus2=$(printf "%02x" $hex2)
		try tested_bus2 $bus2
		qty=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -ci ":$bus1:\|:$bus2:")
		net1=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep :$bus1: |awk -F/ '{print $NF}')
		net2=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep :$bus2: |awk -F/ '{print $NF}')
		test "$net1" = "$net2" && net2=""
		case $slot in
		1|3) nets=$(echo $net2 $net1) ; buses=$(echo 0x$bus2 0x$bus1) ;;
		5|6) nets=$(echo $net1 $net2) ; buses=$(echo 0x$bus1 0x$bus2) ;;
		*)   try Tested_Slot 0 ;;
		esac
		echo buses=$buses
		echo ports=$nets
		try port_qty $qty
		test "$pqty" = "0" || test "$pqty" = "$qty" || try Port_Qty 0
		net=$(echo $net $nets)
	done
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -s "net$1" || try Error
	return 0
}

# Version 1.0.0.1
write_sfp_byte()
{
	local eth result nres passed
	test -n "$1" || try Offset
	local offset=$1
	shift
	test -n "$1" || try Address
	local address=$1
	shift
	test -n "$1" || try Databyte
	local databyte=$1
	shift
	test -n "$1" || try Interface
	for eth in $@ ; do
		result=$(slcm_util $eth read_sfp $offset $address)
		sleep 0.2
		let nres=$(echo "$result" |grep -ciw $databyte)
		test "$nres" -eq "1" && continue
		result=$(slcm_util $eth write_sfp $offset $address $databyte)
		echo "$result"
		passed=$(echo "$result" |grep Ok)
		sleep 0.2
		test -n "$passed" || {
			echo "failed: repeat one more time!"
			result=$(slcm_util $eth write_sfp $offset $address $databyte)
			echo "$result"
			sleep 0.2
		}
	done
	sleep 2
	result=$(for eth in $@ ; do slcm_util $eth read_sfp $offset $address ; sleep 0.2 ; done)
	echo "$result"
	let nres=$(echo "$result" |grep -ciw $databyte)
	return $nres
}

# Version 1.0.0.1
read_sfp_byte()
{
	local eth result nres
	test -n "$1" || try Offset
	local offset=$1
	shift
	test -n "$1" || try Address
	local address=$1
	shift
	test -n "$1" || try Databyte
	local databyte=$1
	shift
	test -n "$1" || try Interface
	result=$(for eth in $@ ; do slcm_util $eth read_sfp $offset $address ; sleep 0.2 ; done)
	echo "$result"
	let nres=$(echo "$result" |grep -ciw $databyte)
	return $nres
}

# Version 1.0.0.0
asc_dump()
{
	local eth val ret res ofs len
	test -n "$1" || try Offset
	ofs=$1
	shift
	test -n "$1" || try Length
	len=$1
	shift
	test -n "$1" || try Interface
	let ret=0
	for eth in $@ ; do
		echo "read from $eth offset $ofs length $len"
		val=$(ethtool -e $eth offset $ofs length $len |grep : |cut -d: -f2 | xxd -r -p)
		let ret+=$?
		res=$(echo -e "$res\n$val")
	done
	echo "Dump Result:$res"
	return $ret
}

# Version 1.0.0.0
hex_dump()
{
	local eth val ret res ofs len
	test -n "$1" || try Offset
	ofs=$1
	shift
	test -n "$1" || try Length
	len=$1
	shift
	test -n "$1" || try Interface
	let ret=0
	for eth in $@ ; do
		echo "read from $eth offset $ofs length $len"
		res=$(ethtool -e $eth offset $ofs length $len)
		let ret+=$?
		echo "$res"
	done
	return $ret
}

# Version 1.0.0.0
mac_dump()
{
	local eth val ret res ofs len
	test -n "$1" || try Offset
	ofs=$1
	shift
	test -n "$1" || try Length
	len=$1
	shift
	test -n "$1" || try Interface
	let ret=0
	for eth in $@ ; do
		echo "read from $eth offset $ofs length $len"
		val=$(ethtool -e $eth offset $ofs length $len |grep : |awk '{print $2 $3 $4 $5 $6 $7}' | tr [:lower:] [:upper:])
		let ret+=$?
		res=$(echo -e "$res\n$val")
	done
	echo "Dump Result:$res"
	return $ret
}

# Version 1.0.0.0
s64_dump()
{
	local eth val ret res ofs len
	test -n "$1" || try Offset
	ofs=$1
	shift
	test -n "$1" || try Length
	len=$1
	shift
	test -n "$1" || try Interface
	let ret=0
	for eth in $@ ; do
		echo "read from $eth offset $ofs length $len"
		val=$(ethtool -e $eth offset $ofs length $len |grep : |awk '{print $2 $3 $4 $5 $6 $7 $8 $9 }' | tr [:lower:] [:upper:])
		let ret+=$?
		res=$(echo -e "$res\n$val")
	done
	echo "Dump Result:$res"
	return $ret
}

# Version 1.0.0.28
mac_dump_all()
{
	local net eth val ret res ofs len
	test -n "$1" || try Length
	len=$1
	shift
	test -n "$1" || try Interface
	net=$(cat $1)
	shift
	test -n "$1" || try Port_Num
	let ret=0
	until [ -z "$1" ] ; do
		eth=$(echo $net |cut -d' ' -f$1)
		shift
		test -n "$1" || try Offset
		test "${1:0:2}" = "0x" || try Offset 0
		until [[ -z "$1" || "${1:0:2}" != "0x" ]] ; do
			ofs=$1
			shift
			echo "read from $eth offset $ofs length $len"
			val=$(ethtool -e $eth offset $ofs length $len |grep : |awk '{print $2 $3 $4 $5 $6 $7}' | tr [:lower:] [:upper:])
			let ret+=$?
			res=$(echo -e "$res\n$val")
		done
	done
	echo "Dump Result:$res"
	return $ret
}

# Version 1.0.0.28
s64_dump_all()
{
	local net eth val ret res ofs len
	test -n "$1" || try Length
	len=$1
	shift
	test -n "$1" || try Interface
	net=$(cat $1)
	shift
	test -n "$1" || try Port_Num
	let ret=0
	until [ -z "$1" ] ; do
		eth=$(echo $net |cut -d' ' -f$1)
		shift
		test -n "$1" || try Offset
		test "${1:0:2}" = "0x" || try Offset 0
		until [[ -z "$1" || "${1:0:2}" != "0x" ]] ; do
			ofs=$1
			shift
			echo "read from $eth offset $ofs length $len"
			val=$(ethtool -e $eth offset $ofs length $len |grep : |awk '{print $2 $3 $4 $5 $6 $7 $8 $9 }' | tr [:lower:] [:upper:])
			let ret+=$?
			res=$(echo -e "$res\n$val")
		done
	done
	echo "Dump Result:$res"
	return $ret
}

# Version 1.0.0.4
asc_all_dump()
{
	local net eth val ret res ofs len
	net=$(cat $1)
	test -n "$net" || try Interface
	shift
	let ret=0
	test -n "$1" || try Offset
	test -n "$2" || try Length
	until [ -z "$2" ] ; do
		ofs=$1
		len=$2
		shift
		shift
		res=""
		echo
		for eth in $net ; do
			echo "read from $eth offset $ofs length $len"
			val=$(ethtool -e $eth offset $ofs length $len |grep : |cut -d: -f2 | xxd -r -p)
			let ret+=$?
			res=$(echo -e "$res\n$val")
		done
		echo "Dump Result:$res"
	done
	return $ret
}

# Version 1.0.0.4
hex_all_dump()
{
	local net eth val ret res ofs len
	net=$(cat $1)
	test -n "$net" || try Interface
	shift
	let ret=0
	test -n "$1" || try Offset
	test -n "$2" || try Length
	until [ -z "$2" ] ; do
		ofs=$1
		len=$2
		shift
		shift
		res=""
		echo "----------------------------------------"
		for eth in $net ; do
			echo "read from $eth offset $ofs length $len"
			res=$(ethtool -e $eth offset $ofs length $len)
			let ret+=$?
			echo "$res"
			echo
		done
	done
	return $ret
}

# Version 1.0.0.4
mac_all_dump()
{
	local net eth val ret res ofs len
	net=$(cat $1)
	test -n "$net" || try Interface
	shift
	let ret=0
	test -n "$1" || try Offset
	let len=6
	until [ -z "$1" ] ; do
		ofs=$1
		shift
		res=""
		echo
		for eth in $net ; do
			echo "read from $eth offset $ofs length $len"
			val=$(ethtool -e $eth offset $ofs length $len |grep : |awk '{print $2 $3 $4 $5 $6 $7}' | tr [:lower:] [:upper:])
			let ret+=$?
			res=$(echo -e "$res\n$val")
		done
		echo "Dump Result:$res"
	done
	return $ret
}

# Version 1.0.0.4
s64_all_dump()
{
	local net eth val ret res ofs len
	net=$(cat $1)
	test -n "$net" || try Interface
	shift
	let ret=0
	test -n "$1" || try Offset
	let len=8
	until [ -z "$1" ] ; do
		ofs=$1
		shift
		res=""
		echo
		for eth in $net ; do
			echo "read from $eth offset $ofs length $len"
			val=$(ethtool -e $eth offset $ofs length $len |grep : |awk '{print $2 $3 $4 $5 $6 $7 $8 $9 }' | tr [:lower:] [:upper:])
			let ret+=$?
			res=$(echo -e "$res\n$val")
		done
		echo "Dump Result:$res"
	done
	return $ret
}

# Version 1.0.0.7
uload_mod()
{
	try Module $1
	dmesg -c > /dev/null
	sleep 1
	rmmod $1
	dmesg -c > /dev/null
	sleep 1
	msg=$(lsmod | grep $1)
	if [ -z "$msg" ] ; then
		echo -e "\e[0;32mUnload Passed Successfully\e[m"
	else
		echo -e "\e[0;31mUnload Failed with $msg\e[m"
		if [[ -z "$noExit" ]]; then exit 1;	fi
	fi
	return 0
}

# Version 1.0.0.7
load_mod()
{
	try Module $1
	modprobe $1
	dmsg=$(dmesg | grep fail)
	lmsg=$(lsmod | grep $1)
	if [ -z "lmsg" ] ; then
		if [ -z "$dmsg" ] ; then
			echo -e "\e[0;31mLoad Failed\e[m"
		else
			echo -e "\e[0;31mLoad Failed with\e[m"
			echo -e "\e[0;31m$dmsg\e[m"
		fi
		if [[ -z "$noExit" ]]; then exit 1;	fi
	else
		if [ ! -z "$dmsg" ] ; then
			echo -e "\e[0;33mLoad Warning with\e[m"
			echo -e "\e[0;33m$dmsg\e[m"
		fi
		echo "$lmsg"
		echo -e "\e[0;32mLoad Passed Successfully\e[m"
	fi
	return 0
}

# Version 1.0.0.7
loadvf_mod()
{
	which lspci > /dev/null || try lspci
	try Module $1
	mod=$1
	shift
	if [ -z "$2" ] ; then
		modprobe $mod
	else
		try Dev_ID $1
		did=$1
		try max_vfs $2
		max_vfs=$2
		vfs=$2
		qty=$(lspci -nd:$did |grep -ciw 15a4)
		for ((i=1; i<$qty ; i++)) ; do
			max_vfs=$(echo $max_vfs,$vfs)
		done
		echo modprobe $mod max_vfs=$max_vfs
		modprobe $mod max_vfs=$max_vfs
	fi
	dmsg=$(dmesg | grep fail)
	lmsg=$(lsmod | grep $1)
	if [ -z "lmsg" ] ; then
		if [ -z "$dmsg" ] ; then
			echo -e "\e[0;31mLoad Failed\e[m"
		else
			echo -e "\e[0;31mLoad Failed with\e[m"
			echo -e "\e[0;31m$dmsg\e[m"
		fi
		if [[ -z "$noExit" ]]; then exit 1;	fi
	else
		if [ ! -z "$dmsg" ] ; then
			echo -e "\e[0;33mLoad Warning with\e[m"
			echo -e "\e[0;33m$dmsg\e[m"
		fi
		echo "$lmsg"
		echo -e "\e[0;32mLoad Passed Successfully\e[m"
	fi
	return 0
}

# Version 1.0.0.7
insert_mod()
{
	try Module $1
	insmod $1
	dmsg=$(dmesg | grep fail)
	lmsg=$(lsmod | grep $1)
	if [ -z "lmsg" ] ; then
		if [ -z "$dmsg" ] ; then
			echo -e "\e[0;31mLoad Failed\e[m"
		else
			echo -e "\e[0;31mLoad Failed with\e[m"
			echo -e "\e[0;31m$dmsg\e[m"
		fi
		if [[ -z "$noExit" ]]; then exit 1;	fi
	else
		if [ ! -z "$dmsg" ] ; then
			echo -e "\e[0;33mLoad Warning with\e[m"
			echo -e "\e[0;33m$dmsg\e[m"
		fi
		echo "$lmsg"
		echo -e "\e[0;32mLoad Passed Successfully\e[m"
	fi
	return 0
}

# Version 1.0.0.38
speed_width()
{
	which lspci > /dev/null || try lspci
	local bus speed width ret sta
	let sta=0
	bus=$1
	try bus $bus
	shift
	test -n "$1" || try Speed
	echo Speed=$1
	speed=$(lspci -vv -s$bus |grep -a LnkSta: |awk '{print $3}' |tr -d , |cut -dG -f1)
	test "$speed" != "unknown" || speed=0
	echo speed=$speed
	let ret=$(test "$1" = "$speed" ; echo $?)
	let sta+=ret
	status Speed $ret
	test -n "$2" || try Width
	echo Width=$2
	let width=$(lspci -vv -s$bus |grep -a LnkSta: |awk -F, '{print $2}' |cut -dx -f2)
	echo width=$width
	let ret=$(test "$2" = "$width" ; echo $?)
	let sta+=ret
	status Width $ret
	return $sta
}

# Version 1.0.1.1
qcu_info()
{
	which qcu64e > /dev/null || try qcu64e
	local cmd mode num phy ret hex bus dec qcu nic current ti last
	cmd=$1
	test -n "$cmd" || try Command
	shift
	mode=$1
	test -n "$mode" || try Mode
	shift
	let num=$1
	test -n "$num" || try Slot
	shift
	phy=$1
	test -n "$phy" || try Phy_Bus
	let ret=0
	hex=0x$phy
	let bus=$hex
	echo "Bus(dec)="$bus
	if [ "$bus" -lt "10" ] ; then
		dec=00$bus
	elif [ "$bus" -lt "100" ] ; then
		dec=0$bus
	else
		dec=$bus
	fi
	qcu=$(qcu64e |grep :$dec |cut -d: -f2 |cut -d' ' -f1)
	if [ "$qcu" = "$dec" ] ; then
		nic=$(echo $(qcu64e |grep :$dec |cut -d')' -f1))
		current=$(qcu64e /info /NIC=$nic | grep Current |cut -d' ' -f3)
	fi
	echo Mode=$current
	if [ -z "$current" ] ; then
		status "Slot[$num] Configuration" 1
		return $?
	fi
	if [ "$cmd" = "-INFO" ] ; then
		if [ "$mode" = "${current:0:4}" ] ; then
			status "Slot[$num] Configuration" 0
			let ret+=$?
		else
			status "Slot[$num] Configuration" 1
			let ret+=$?
		fi
	fi
	if [ "$cmd" = "-SET" ] ; then
		if [ "$mode" = "${current:0:4}" ] ; then
			echo "Slot[$num] Nothing To Do"
			status "Slot[$num] Set Mode" 0
		else
			qcu=$(echo $(qcu64e /info /NIC=$nic | grep -v Current | grep "$mode"))
			if [ -z "$qcu" ] ; then
				try "Slot[$num] Set Mode" 0
			elif [ "${qcu:0:4}" = "$mode" ] ; then
				let last=4
				for (( ti=0; ti < $last; ti++ )) ; do
					echo qcu64e /NIC=$nic /set "$qcu"
					qcu64e /NIC=$nic /set "$qcu"
					let ret+=$?
					current=$(qcu64e /info /NIC=$nic | grep Current |cut -d' ' -f3)
					test "${current:0:4}" = "$mode" && break
				done
				echo retried $ti times
				current=$(qcu64e /info /NIC=$nic | grep Current |cut -d' ' -f3)
				test "${current:0:4}" = "$mode" || let ++ret
				status "Slot[$num] Set Mode" $ret
			else
				try "Slot[$num] Set Mode" 0
			fi
		fi
	fi
	return $ret
}

# Version 1.0.2.2
epct_info()
{
	which epct64e > /dev/null || try epct64e
	local cmd mode num phy ret hex bus dec epct nic current ti last
	cmd=$1
	test -n "$cmd" || try Command
	shift
	mode=$1
	test -n "$mode" || try Mode
	shift
	let num=$1
	test -n "$num" || try Slot
	shift
	phy=$1
	test -n "$phy" || try Phy_Bus
	let ret=0
	hex=0x$phy
	let bus=$hex
	echo "Bus(dec)="$bus
	if [ "$bus" -lt "10" ] ; then
		dec=00$bus
	elif [ "$bus" -lt "100" ] ; then
		dec=0$bus
	else
		dec=$bus
	fi
	epct=$(epct64e /devices |grep :$dec |cut -d: -f2 |cut -d' ' -f1)
	if [ "$epct" = "$dec" ] ; then
		nic=$(echo $(epct64e /devices |grep :$dec |cut -d')' -f1))
		current=$(epct64e /NIC=$nic /get |grep "    X    "|awk '{print $2}')
	fi
	echo Mode=$current
	if [ -z "$current" ] ; then
		status "Slot[$num] Configuration" 1
		return $?
	fi
	if [ "$cmd" = "-GET" ] ; then
		if [ "$mode" = "$current" ] ; then
			status "Slot[$num] Configuration" 0
			let ret+=$?
		else
			status "Slot[$num] Configuration" 1
			let ret+=$?
		fi
	fi
	if [ "$cmd" = "-SET" ] ; then
		if [ "$mode" = "$current" ] ; then
			echo "Slot[$num] Nothing To Do"
			status "Slot[$num] Set Mode" 0
		else
			epct=$(echo $(epct64e /NIC=$nic /get |grep "$mode" |awk '{print $1}'))
			if [ -z "$epct" ] ; then
				try "Slot[$num] Set Mode" 0
			elif [ "$epct" = "$mode" ] ; then
				let last=4
				for (( ti=0; ti < $last; ti++ )) ; do
					echo epct64e /NIC=$nic /set "$epct"
					echo "_________________________________________"
					echo
					epct64e /NIC=$nic /set "$epct"
					let ret+=$?
					current=$(epct64e /NIC=$nic /get |grep "    X    "|awk '{print $2}')
					test "$current" = "$mode" && break
				done
				echo "_________________________________________"
				echo
				echo retried $ti times
				current=$(epct64e /NIC=$nic /get |grep "    X    "|awk '{print $2}')
				test "$current" = "$mode" || let ++ret
				status "Slot[$num] Set Mode" $ret
			else
				try "Slot[$num] Set Mode" 0
			fi
		fi
	fi
	return $ret
}

# Define both 'core1' and 'core2'
# Version 1.0.3.6
set_core2duo()
{
	let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
	test "$ncpus" -le "2" && {
		let core1=$(($ncpus-1))
		let core2=0x0
		return
	}
	test -z "$ncpu1" && let ncpu1=$(($ncpus/2))
	test -z "$ncpu2" && let ncpu2=0x0
	let core1=$ncpu1
	let core2=$ncpu2
	let ncpu1++
	test "$ncpu1" -lt "$ncpus" || let ncpu1=0x0
	let ncpu2++
	test "$ncpu2" -lt "$ncpus" || let ncpu2=0x0
}

# Define both 'core1' and 'core2'
# Version 1.0.3.6
set_dualcore()
{
	let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
	test "$ncpus" -le "2" && {
		let core1=$(($ncpus-1))
		let core2=0x0
		return
	}
	test -z "$ncpu1" && let ncpu1=$(($ncpus-1))
	test -z "$ncpu2" && let ncpu2=0x0
	let core1=$ncpu1
	let core2=$ncpu2
	let ncpu1--
	test "$ncpu1" -ge "0" || let ncpu1=$(($ncpus-1))
	let ncpu2++
	test "$ncpu2" -lt "$ncpus" || let ncpu2=0x0
}

# Define both 'core1' and 'core2'
# Version 1.0.3.6
set_core2cpu()
{
	let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
	test "$ncpus" -le "2" && {
		let core1=$(($ncpus-1))
		let core2=0x0
		return
	}
	test -z "$ncpu1" && let ncpu1=$(($ncpus/2))
	test -z "$ncpu2" && let ncpu2=$(($ncpus/2+1))
	let core1=$ncpu1
	let core2=$ncpu2
	let ncpu1++
	test "$ncpu1" -lt "$ncpus" || let ncpu1=0x0
	let ncpu2++
	test "$ncpu2" -lt "$ncpus" || let ncpu2=0x0
}

# Define both 'core1' and 'core2'
# Version 1.0.3.6
set_cpu_core()
{
	let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
	test "$ncpus" -le "2" && {
		let core1=$(($ncpus-1))
		let core2=0x0
		return
	}
	test -z "$ncpu1" && let ncpu1=0x0
	test -z "$ncpu2" && let ncpu2=0x1
	let core1=$ncpu1
	let core2=$ncpu2
	let ncpu1++
	test "$ncpu1" -lt "$ncpus" || let ncpu1=0x0
	let ncpu2++
	test "$ncpu2" -lt "$ncpus" || let ncpu2=0x0
}

# Define both 'core1' and 'core2'
# Version 2.0.0.0
set_core4cpu()
{
	let ncpus=$(nproc) # $(cat /proc/cpuinfo | grep -ciw processor)
	test "$ncpus" -le "2" && {
		let core1=$(($ncpus-1))
		let core2=0x0
		return
	}
	test -z "$ncpu1" && let ncpu1=$(($ncpus/4))
	test -z "$ncpu2" && let ncpu2=0x0
	let core1=$ncpu1
	let core2=$ncpu2
	let ncpu1++
	test "$ncpu1" -lt "$ncpus" || let ncpu1=0x0
	let ncpu2++
	test "$ncpu2" -lt "$ncpus" || let ncpu2=0x0
}

# Define both 'core1' and 'core2'
# Version 1.0.2.27
bind_slot2core()
{
	local slot ncpu
	let ncpu=$(nproc)
	test -z "$1" && try Tested_Slot
	let slot=$1
	if [ "$ncpu" -eq "12" ] ; then
		case $slot in
		1) core1=0x0; core2=1  ;;
		2) core1=2  ; core2=3  ;;
		3) core1=4  ; core2=5  ;;
		4) core1=6  ; core2=7  ;;
		5) core1=8  ; core2=9  ;;
		6) core1=10 ; core2=11 ;;
		*) try Tested_Slot 0 ;;
		esac
	elif [ "$ncpu" -eq "16" ] ; then
		case $slot in
		1) core1=0x0; core2=1  ;;
		2) core1=2  ; core2=3  ;;
		3) core1=4  ; core2=5  ;;
		4) core1=12 ; core2=13 ;;
		5) core1=8  ; core2=9  ;;
		6) core1=10 ; core2=11 ;;
		*) try Tested_Slot 0 ;;
		esac
	elif [ "$ncpu" -eq "20" ] ; then
		case $slot in
		1) core1=0x0; core2=1  ;;
		2) core1=4  ; core2=5  ;;
		3) core1=10 ; core2=11 ;;
		4) core1=14 ; core2=15 ;;
		5) core1=8  ; core2=9  ;;
		6) core1=18 ; core2=19 ;;
		*) try Tested_Slot 0 ;;
		esac
	elif [ "$ncpu" -eq "24" ] ; then
		case $slot in
		1) core1=0x0; core2=13 ;;
		2) core1=2  ; core2=15 ;;
		3) core1=4  ; core2=17 ;;
		4) core1=6  ; core2=19 ;;
		5) core1=8  ; core2=21 ;;
		6) core1=10 ; core2=23 ;;
		*) try Tested_Slot 0 ;;
		esac
	elif [ "$ncpu" -eq "32" ] ; then
		case $slot in
		1) core1=0x0; core2=13 ;;
		2) core1=2  ; core2=15 ;;
		3) core1=4  ; core2=17 ;;
		4) core1=12 ; core2=25 ;;
		5) core1=8  ; core2=21 ;;
		6) core1=10 ; core2=23 ;;
		*) try Tested_Slot 0 ;;
		esac
	elif [ "$ncpu" -eq "40" ] ; then
		case $slot in
		1) core1=0x0; core2=21 ;;
		2) core1=4  ; core2=25 ;;
		3) core1=10 ; core2=31 ;;
		4) core1=14 ; core2=35 ;;
		5) core1=8  ; core2=29 ;;
		6) core1=18 ; core2=39 ;;
		*) try Tested_Slot 0 ;;
		esac
	else
		try Cpu_Qty 0
	fi
}

# Define both 'core1' and 'core2'
# Version 1.0.2.27
bind_pair2core()
{
	local slot port pnum ncpu
	let ncpu=$(nproc)
	test -z "$1" && try Tested_Slot
	let slot=$1
	shift
	test -z "$1" && try Tested_Pair
	let pair=$1
	if [ "$ncpu" -eq "12" ] ; then
		case $slot in
		1) core1=0x0;;
		2) core1=2  ;;
		3) core1=4  ;;
		4) core1=6  ;;
		5) core1=8  ;;
		6) core1=10 ;;
		*) try Tested_Slot 0 ;;
		esac
		case $pair in
		1) core2=1  ;;
		2) core2=3  ;;
		3) core2=5  ;;
		4) core2=7  ;;
		5) core2=9  ;;
		6) core2=11 ;;
		*) try Tested_Pair 0 ;;
		esac
	elif [ "$ncpu" -eq "16" ] ; then
		case $slot in
		1) core1=0x0;;
		2) core1=2  ;;
		3) core1=4  ;;
		4) core1=12 ;;
		5) core1=8  ;;
		6) core1=10 ;;
		*) try Tested_Slot 0 ;;
		esac
		case $pair in
		1) core2=1  ;;
		2) core2=3  ;;
		3) core2=5  ;;
		4) core2=13 ;;
		5) core2=9  ;;
		6) core2=11 ;;
		*) try Tested_Pair 0 ;;
		esac
	elif [ "$ncpu" -eq "20" ] ; then
		case $slot in
		1) core1=0x0;;
		2) core1=4  ;;
		3) core1=10 ;;
		4) core1=14 ;;
		5) core1=8  ;;
		6) core1=18 ;;
		*) try Tested_Slot 0 ;;
		esac
		case $pair in
		1) core2=1  ;;
		2) core2=5  ;;
		3) core2=11 ;;
		4) core2=15 ;;
		5) core2=9  ;;
		6) core2=19 ;;
		*) try Tested_Pair 0 ;;
		esac
	elif [ "$ncpu" -eq "24" ] ; then
		case $slot in
		1) core1=0x0;;
		2) core1=2  ;;
		3) core1=4  ;;
		4) core1=6  ;;
		5) core1=8  ;;
		6) core1=10 ;;
		*) try Tested_Slot 0 ;;
		esac
		case $pair in
		1) core2=13 ;;
		2) core2=15 ;;
		3) core2=17 ;;
		4) core2=19 ;;
		5) core2=21 ;;
		6) core2=23 ;;
		*) try Tested_Pair 0 ;;
		esac
	elif [ "$ncpu" -eq "32" ] ; then
		case $slot in
		1) core1=0x0;;
		2) core1=2  ;;
		3) core1=4  ;;
		4) core1=12 ;;
		5) core1=8  ;;
		6) core1=10 ;;
		*) try Tested_Slot 0 ;;
		esac
		case $pair in
		1) core2=13 ;;
		2) core2=15 ;;
		3) core2=17 ;;
		4) core2=25 ;;
		5) core2=21 ;;
		6) core2=23 ;;
		*) try Tested_Pair 0 ;;
		esac
	elif [ "$ncpu" -eq "40" ] ; then
		case $slot in
		1) core1=0x0;;
		2) core1=4  ;;
		3) core1=10 ;;
		4) core1=14 ;;
		5) core1=8  ;;
		6) core1=18 ;;
		*) try Tested_Slot 0 ;;
		esac
		case $pair in
		1) core2=21 ;;
		2) core2=25 ;;
		3) core2=31 ;;
		4) core2=35 ;;
		5) core2=29 ;;
		6) core2=39 ;;
		*) try Tested_Pair 0 ;;
		esac
	else
		try Cpu_Qty 0
	fi
}

# Version 1.0.2.26
set_hugepages()
{
	local num qty pages
	let pages=$1
	test -z "$pages" && try HugePages
	num=$(grep HugePages_Total /proc/meminfo |awk '{print $2}')
	qty=$(grep HugePages_Free  /proc/meminfo |awk '{print $2}')
	test -n $"num" -a -n $"qty" || {
		echo $pages > /proc/sys/vm/nr_hugepages
		sleep 1
		num=$(grep HugePages_Total /proc/meminfo |awk '{print $2}')
		qty=$(grep HugePages_Free  /proc/meminfo |awk '{print $2}')
		test -n $"num" -a -n $"qty" || try HugePages 0
	}
	cat /proc/meminfo |grep Huge
	test "$qty" -ge "$pages" || {
		let num+=$(($pages-$qty))
		echo renew_hugepages=$num
		echo $num > /proc/sys/vm/nr_hugepages
		sleep 1
		num=$(grep HugePages_Total /proc/meminfo |awk '{print $2}')
		qty=$(grep HugePages_Free /proc/meminfo |awk '{print $2}')
		cat /proc/meminfo | grep Huge
		test "$qty" -ge "$pages" #|| try HugePages 0
	}
	return $?
}

# Version 1.0.2.28
init_global_var()
{
	which dmidecode > /dev/null || try dmidecode
	local mbrd=$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)
	test "$mbrd" = "X10DRi" && {
		# echo baseboard=$mbrd
		mbcode="8086:1521"
		mbslot=3
		mbpqty=2
		mb_phy=""
	}
}

# Version 1.0.3.3
auto_slot2net()
{
	init_global_var
	local pciebus=$(getDmiSlotBuses)
	echo PCIeBus=$pciebus
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot eth pci plxbus i bus exist neta pep1 bdf1 net1
	local slotbus ethbus idlast buses bqty dotest notest
	local net=""
	local pep=""
	local plx=""
	local plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	local ethbuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		let i=0
		for pci in $pciebus ; do
			let ++i
			test "$i" = "$slot" || continue
			test "$pci" = "ff" && try Tested_Slot 0
			try tested_slot $slot
			slotbus=$(getPciSlotRootBus $pci)
			test -z "$slotbus" && try Tested_Device
			echo slot[$i].bus=$slotbus
			publicVarAssign fatal devsOnUutSlotBus $(getDevsOnPciRootBus $slotbus |cut -d: -f2-)
			plxbus=""
			for bus in $plxbuses ; do
				exist=$(echo -n "$devsOnUutSlotBus" |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && plxbus=$(echo $plxbus $bus)
			done
			test -n "$plxbus" && echo slot[$i].plx=$plxbus
			plx=$(echo $plx $plxbus)
			ethbus=""
			for bus in $ethbuses ; do
				exist=$(echo -n "$devsOnUutSlotBus" |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && \
				idlast=$(cat /sys/bus/pci/devices/0000:$bus/uevent |grep PCI_ID |cut -d= -f2)
				test -n "$exist" && ethbus=$(echo $ethbus $bus)
			done
			test -n "$ethbus" -a "$idlast" = "$mbcode" -a "$i" = "$mbslot" && {
				buses=($ethbus)
				bqty=${#buses[@]}
				dotest=""
				notest=""
				for ((j=0; j<$bqty-$mbpqty; j++)) ; do dotest=$(echo $dotest ${buses[$j]}) ; done
				for ((j=$bqty-$mbpqty; j<$bqty; j++)) ; do notest=$(echo $notest ${buses[$j]}) ; done
				test -n "$notest" && mb_phy=$(echo $notest |cut -d: -f1)
				ethbus=$(echo $dotest)
			}
			test -d "/sys/class/net" && \
			eth=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $slotbus |grep -v :$mb_phy: |awk -F/ '{print $NF}')
			test -z "$eth" && try Interface
			echo slot[$i].net=$eth
			neta=($eth)
			test "$pqty" = "0" -o "$pqty" = "${#neta[@]}" || try Port_Qty 0
			for net1 in $eth ; do
				bdf1=$(ethtool -i $net1 |grep bus-info |cut -d: -f 3,4)
				pep1=$(echo $(lspci -nns:$bdf1 -vv |grep -a '\[VP\]' |cut -d: -f2))
				pep=$(echo $pep $pep1)
			done
			test -n "$pep" && echo slot[$i].pep=$pep
			net=$(echo $net $eth)
		done
	done
	#save result to 'plx$1' for the future using
	echo $plx > plx$1
	test -z "$plx" -o -s "plx$1" || try Error
	#save result to 'pep$1' for the future using
	echo $pep > pep$1
	test -z "$pep" -o -s "pep$1" || try Error
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -n "$net" -a -s "net$1" || try Error
	return 0
}

# Version 1.0.3.3
autoslot2bus()
{
	init_global_var
	which dmidecode > /dev/null || try dmidecode
	local pciebus=$(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3)
	echo PCIeBus=$pciebus
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot pci plxbus i bus exist neta pep1
	local slotbus ethbus idlast buses bqty dotest notest
	local net=""
	local pep=""
	local plx=""
	local plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	local ethbuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	test -z "$ethbuses" && try Eth_Device
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		let i=0
		for pci in $pciebus ; do
			let ++i
			test "$i" = "$slot" || continue
			try tested_slot $slot
			slotbus=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$pci: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
			test -z "$slotbus" && try Tested_Device
			echo slot[$i].pcibus=$slotbus
			plxbus=""
			for bus in $plxbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep $slotbus |awk -F/ '{print $NF}' |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && plxbus=$(echo $plxbus $bus)
			done
			test -n "$plxbus" && echo slot[$i].plxbus=$plxbus
			plx=$(echo $plx $plxbus)
			ethbus=""
			for bus in $ethbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep $slotbus |awk -F/ '{print $NF}' |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && \
				idlast=$(cat /sys/bus/pci/devices/0000:$bus/uevent |grep PCI_ID |cut -d= -f2)
				test -n "$exist" && ethbus=$(echo $ethbus $bus)
			done
			test -n "$ethbus" -a "$idlast" = "$mbcode" -a "$i" = "$mbslot" && {
				buses=($ethbus)
				bqty=${#buses[@]}
				dotest=""
				notest=""
				for ((j=0; j<$bqty-$mbpqty; j++)) ; do dotest=$(echo $dotest ${buses[$j]}) ; done
				for ((j=$bqty-$mbpqty; j<$bqty; j++)) ; do notest=$(echo $notest ${buses[$j]}) ; done
				test -n "$notest" && mb_phy=$(echo $notest |cut -d: -f1)
				ethbus=$(echo $dotest)
			}
			test -z "$ethbus" && try Eth_Bus
			echo slot[$i].ethbus=$ethbus
			neta=($ethbus)
			test "$pqty" = "0" -o "$pqty" = "${#neta[@]}" || try Port_Qty 0
			for bus in $ethbus ; do
				pep1=$(echo $(lspci -nns:$bus -vv |grep -a '\[VP\]' |cut -d: -f2))
				pep=$(echo $pep $pep1)
			done
			test -n "$pep" && echo slot[$i].pepnum=$pep
			net=$(echo $net $ethbus)
		done
	done
	#save result to 'plx$1' for the future using
	echo $plx > plx$1
	test -z "$plx" -o -s "plx$1" || try Error
	#save result to 'pep$1' for the future using
	echo $pep > pep$1
	test -z "$pep" -o -s "pep$1" || try Error
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -n "$net" -a -s "net$1" || try Error
	# echo "-------------------------"
	return 0
}

# Version 1.0.3.3
auto_slot2pep()
{
	init_global_var
	local pciebus=$(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3)
	echo PCIeBus=$pciebus
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot eth pci plxbus i bus exist neta pep1 bdf1 net1 nets peps
	local slotbus ethbus idlast buses bqty dotest notest
	local nets=""
	local peps=""
	local net=""
	local pep=""
	local plx=""
	local plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	local ethbuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		let i=0
		for pci in $pciebus ; do
			let ++i
			test "$i" = "$slot" || continue
			test "$pci" = "ff" && try Tested_Slot 0
			try tested_slot $slot
			slotbus=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$pci: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
			test -z "$slotbus" && try Tested_Device
			echo slot[$i].bus=$slotbus
			plxbus=""
			for bus in $plxbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep $slotbus |awk -F/ '{print $NF}' |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && plxbus=$(echo $plxbus $bus)
			done
			test -n "$plxbus" && echo slot[$i].plx=$plxbus
			plx=$(echo $plx $plxbus)
			ethbus=""
			for bus in $ethbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep $slotbus |awk -F/ '{print $NF}' |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && \
				idlast=$(cat /sys/bus/pci/devices/0000:$bus/uevent |grep PCI_ID |cut -d= -f2)
				test -n "$exist" && ethbus=$(echo $ethbus $bus)
			done
			test -n "$ethbus" -a "$idlast" = "$mbcode" -a "$i" = "$mbslot" && {
				buses=($ethbus)
				bqty=${#buses[@]}
				dotest=""
				notest=""
				for ((j=0; j<$bqty-$mbpqty; j++)) ; do dotest=$(echo $dotest ${buses[$j]}) ; done
				for ((j=$bqty-$mbpqty; j<$bqty; j++)) ; do notest=$(echo $notest ${buses[$j]}) ; done
				test -n "$notest" && mb_phy=$(echo $notest |cut -d: -f1)
				ethbus=$(echo $dotest)
			}
			test -d "/sys/class/net" && \
			eth=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $slotbus |grep -v :$mb_phy: |awk -F/ '{print $NF}')
			test -z "$eth" && try Interface
			echo slot[$i].net=$eth
			neta=($eth)
			test "$pqty" = "0" -o "$pqty" = "${#neta[@]}" || try Port_Qty 0
			for net1 in $eth ; do
				bdf1=$(ethtool -i $net1 |grep bus-info |cut -d: -f 3,4)
				pep1=$(echo $(lspci -nns:$bdf1 -vv |grep -a '\[VP\]' |cut -d: -f2))
				test "$pep1" = "0" && {
					peps=$(echo $pep1 $peps)
					nets=$(echo $net1 $nets)
				} || {
					peps=$(echo $peps $pep1)
					nets=$(echo $nets $net1)
				}
			done
			pep=$(echo $pep $peps)
			test -n "$pep" && echo slot[$i].pep=$pep
			net=$(echo $net $nets)
		done
	done
	#save result to 'plx$1' for the future using
	echo $plx > plx$1
	test -z "$plx" -o -s "plx$1" || try Error
	#save result to 'pep$1' for the future using
	echo $pep > pep$1
	test -z "$pep" -o -s "pep$1" || try Error
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -n "$net" -a -s "net$1" || try Error
	return 0
}

# Version 1.0.3.3
autoslot2pep()
{
	init_global_var
	which dmidecode > /dev/null || try dmidecode
	local pciebus=$(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3)
	echo PCIeBus=$pciebus
	test -z "$1" && try Port_Qty
	local pqty=$1
	shift
	test -z "$1" && try Tested_Slot
	local slot pci plxbus i bus exist neta pep1 nets peps
	local slotbus ethbus idlast buses bqty dotest notest
	local nets=""
	local peps=""
	local net=""
	local pep=""
	local plx=""
	local plxbuses=$(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	local ethbuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	test -z "$ethbuses" && try Eth_Device
	for slot in $@ ; do
		echo -e "\e[0;32mTested_Slot=$slot\e[m"
		echo Compare...
		let i=0
		for pci in $pciebus ; do
			let ++i
			test "$i" = "$slot" || continue
			try tested_slot $slot
			slotbus=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$pci: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
			test -z "$slotbus" && try Tested_Device
			echo slot[$i].pcibus=$slotbus
			plxbus=""
			for bus in $plxbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep $slotbus |awk -F/ '{print $NF}' |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && plxbus=$(echo $plxbus $bus)
			done
			test -n "$plxbus" && echo slot[$i].plxbus=$plxbus
			plx=$(echo $plx $plxbus)
			ethbus=""
			for bus in $ethbuses ; do
				exist=$(ls -l /sys/bus/pci/devices/ |grep $slotbus |awk -F/ '{print $NF}' |grep -v $slotbus |grep -w $bus)
				test -n "$exist" && \
				idlast=$(cat /sys/bus/pci/devices/0000:$bus/uevent |grep PCI_ID |cut -d= -f2)
				test -n "$exist" && ethbus=$(echo $ethbus $bus)
			done
			test -n "$ethbus" -a "$idlast" = "$mbcode" -a "$i" = "$mbslot" && {
				buses=($ethbus)
				bqty=${#buses[@]}
				dotest=""
				notest=""
				for ((j=0; j<$bqty-$mbpqty; j++)) ; do dotest=$(echo $dotest ${buses[$j]}) ; done
				for ((j=$bqty-$mbpqty; j<$bqty; j++)) ; do notest=$(echo $notest ${buses[$j]}) ; done
				test -n "$notest" && mb_phy=$(echo $notest |cut -d: -f1)
				ethbus=$(echo $dotest)
			}
			test -z "$ethbus" && try Eth_Bus
			echo slot[$i].ethbus=$ethbus
			neta=($ethbus)
			test "$pqty" = "0" -o "$pqty" = "${#neta[@]}" || try Port_Qty 0
			for bus in $ethbus ; do
				pep1=$(echo $(lspci -nns:$bus -vv |grep -a '\[VP\]' |cut -d: -f2))
				test "$pep1" = "0" && {
					peps=$(echo $pep1 $peps)
					nets=$(echo $bus  $nets)
				} || {
					peps=$(echo $peps $pep1)
					nets=$(echo $nets  $bus)
				}
			done
			pep=$(echo $pep $peps)
			test -n "$pep" && echo slot[$i].pepnum=$pep
			net=$(echo $net $nets)
		done
	done
	#save result to 'plx$1' for the future using
	echo $plx > plx$1
	test -z "$plx" -o -s "plx$1" || try Error
	#save result to 'pep$1' for the future using
	echo $pep > pep$1
	test -z "$pep" -o -s "pep$1" || try Error
	#save result to 'net$1' for the future using
	echo $net > net$1
	test -n "$net" -a -s "net$1" || try Error
	# echo "-------------------------"
	return 0
}

# Version 1.0.3.5
swap_data()
{
	test -z "$1" && return 1
	local iname
	for iname in $@ ; do
		test -s "$iname" || try "$iname" 0
		cat $iname |tr ' ' '\n' > /tmp/o.tmp
		echo $(tac /tmp/o.tmp |tr '\n' ' ') > $iname
	done
}

# Version 1.0.3.5
correct_bifurcation()
{
	test -z "$1" && return 1
	local iname=$1
	shift
	test -z "$1" && return 1
	which dmidecode > /dev/null || try dmidecode
	local mbrd=$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)
	local slot sta
	let sta=0
	for slot in $@ ; do
		test "$mbrd" = "X10DRi" -a "$slot" -lt "4" && {
			swap_data $iname$slot
			let sta+=$?
		}
	done
	return $sta
}

# Version 2.0.0.4
swap_dual_data()
{
	test -z "$1" && return 1
	local iname hi lo
	for iname in $@ ; do
		test -s "$iname" || try "$iname" 0
		cat $iname |tr ' ' '\n' > /tmp/o.tmp
		hi=$(head -n 2 /tmp/o.tmp)
		lo=$(tail -n 2 /tmp/o.tmp)
		echo $(echo $lo $hi |tr '\n' ' ') > $iname
	done
}

# Version 2.0.0.4
correct_dual_bifurcation()
{
	test -z "$1" && return 1
	local iname=$1
	shift
	test -z "$1" && return 1
	which dmidecode > /dev/null || try dmidecode
	local mbrd=$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)
	local slot sta
	let sta=0
	for slot in $@ ; do
		test "$mbrd" = "X10DRi" -a "$slot" -lt "4" && {
			swap_dual_data $iname$slot
			let sta+=$?
		}
	done
	return $sta
}

# Version 2.0.0.5
set_rxtx()
{
	local eth rx_max tx_max flow 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		flow=$(ethtool -a $eth |grep -cw on)
		test "$flow" -lt "2" && ethtool -A $eth rx on tx on &> /dev/null # && sleep 0.1
	done
	sleep 3
}

# Version 2.0.0.5
reset_rxtx()
{
	local eth rx_max tx_max flow 
	test -n "$1" || try Interface
	for eth in $@ ; do
		rx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/RX:/ {print $2}')
		tx_max=$(ethtool -g $eth |grep -A 4 maximum |awk '/TX:/ {print $2}')
		ethtool -G $eth tx $tx_max rx $rx_max &> /dev/null
		flow=$(ethtool -a $eth |grep -cw off)
		test "$flow" -lt "2" && ethtool -A $eth rx off tx off &> /dev/null # && sleep 0.1
	done
	sleep 3
}

# Version 2.0.0.5
is_rxtxon()
{
	local eth sta left flow list retry
	test -n "$1" || try Interface
	let sta=0
	for ((left=30; left>0; left--)) ; do
		for eth in $@ ; do ip link set dev $eth up ; done
		for eth in $@ ; do
			flow=$(ethtool -a $eth |grep -cw on)
			test "$flow" -lt "2" && ethtool -A $eth rx on tx on &> /dev/null # && sleep 0.1
		done
		for ((retry=10; retry>0; retry--)) ; do
			list=""
			for eth in $@ ; do
				flow=$(ethtool -a $eth |grep -cw on)
				test "$flow" -lt "2" && list=$(echo $list $eth)
			done
			test -z "$list" && break 2
			sleep 1
		done
		echo "$list flow control setting error : left $left retry"
		for eth in $@ ; do ethtool -s $eth autoneg on &> /dev/null ; done
	done
	list=""
	for eth in $@ ; do 
		ethtool -a $eth
		flow=$(ethtool -a $eth |grep -cw on)
		test "$flow" -lt "2" && {
			list=$(echo $list $eth)
			let sta++
		}
	done
	test -n "$list" && status "$list Flow Control" $sta
	return $sta
}

# Version 2.0.0.5
is_rxtxoff()
{
	local eth sta left flow list
	test -n "$1" || try Interface
	let sta=0
	for ((left=30; left>0; left--)) ; do
		for eth in $@ ; do ip link set dev $eth up ; done
		for eth in $@ ; do
			flow=$(ethtool -a $eth |grep -cw off)
			test "$flow" -lt "2" && ethtool -A $eth rx off tx off &> /dev/null # && sleep 0.1
		done
		for ((retry=10; retry>0; retry--)) ; do
			list=""
			for eth in $@ ; do
				flow=$(ethtool -a $eth |grep -cw off)
				test "$flow" -lt "2" && list=$(echo $list $eth)
			done
			test -z "$list" && break 2
			sleep 1
		done
		echo "$list flow control setting error : left $left retry"
		for eth in $@ ; do ethtool -s $eth autoneg on &> /dev/null ; done
	done
	list=""
	for eth in $@ ; do 
		ethtool -a $eth
		flow=$(ethtool -a $eth |grep -cw off)
		test "$flow" -lt "2" && {
			list=$(echo $list $eth)
			let sta++
		}
	done
	test -n "$list" && status "$list Flow Control" $sta
	return $sta
}

