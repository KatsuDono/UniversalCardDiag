#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

function IPPowerCheckSerial () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local i ttyN outlet swRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"

	dmsg "startup port setup"
	
	echo -n " Checking serial connections to IPPower on $ttyN, "
	swRes="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.5 "read p6")"
	dmsg "swRes=$swRes"
	if [ ! -z "$(echo "$swRes" |grep "1=")" ]; then
		echo -e "\e[0;32mok.\e[m"
	else
		echo -e "\e[0;31mfail.\e[m"
		echo -ne " Retrying..\n Warmup."
		for (( i=1; i<6; i++ )); do
			if [ $i -eq 3 ]; then countDownDelay 15 "  Waiting for setup delay"; fi
			echo -n "."
			warmupCmd="$(sendIPPowerSerialCmd $ttyN 19200 2 read p6)"; dmsg "$warmupCmd"
			echo -n "."
			warmupCmd="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.5 read p6)"; dmsg "$warmupCmd"
			echo -n "."
			if [ ! -z "$(echo "$warmupCmd" |grep "1=")" ]; then break; else echo -n "_"; fi
			sleep 0.5
		done
		
		# echo -ne " Warmup."
		# for (( i=1; i<6; i++ )); do
		# 	echo -n "."
		# 	warmupCmd="$(sendIPPowerSerialCmd $ttyN 19200 2 read p6)"; dmsg "$warmupCmd"
		# 	echo -n "."
		# 	warmupCmd="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.5 read p6)"; dmsg "$warmupCmd"
		# 	echo -n "."
		# 	if [ ! -z "$(echo "$warmupCmd" |grep "1=")" ]; then break; else echo -n "_"; fi
		# 	sleep 0.5
		# done
		dmsg "pids of ttyUSB: $(lsof |grep ttyUSB)"
		# lsofPids=$(lsof |grep $ttyN |awk '{print $2}')
		# for pid in $lsofPids; do kill -9 $pid; echo "  Killing PID $pid"; done
		if [ -z "$(echo "$warmupCmd" |grep "1=")" ]; then except "IPPower serial connection failure"; else echo -e " Serial \e[0;32mconnected.\e[m"; fi
		
	fi

}

function IPPowerSwPowerAll () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local i
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateNumAssign "targState" "$2"

	for (( i=1; i<5; i++ )); do
		IPPowerSwPower $ttyN $i $targState
	done
}

function IPPowerSwPowerAllNoDelay () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local i
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateNumAssign "targState" "$2"

	for (( i=1; i<5; i++ )); do
		IPPowerSwPowerNoDelay $ttyN $i $targState
	done
}

function IPPowerSwPower () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN outlet swRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateNumAssign "outlet" "$2"
	privateNumAssign "targState" "$3"
	if [ "$outlet" -ge 0 ] && [ "$outlet" -le 5 ]; then
		echo -n " Switching $outlet outlet to $targState, "
		swRes="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.04 set p6$outlet $targState)"
		dmsg echo "$swRes"
		if [ "$targState" = "$(echo "$swRes" |grep "$outlet=" |cut -d= -f2)" ]; then
			echo -e "\e[0;32mok.\e[m"
		else
			echo -e "\e[0;31mfail.\e[m"
			for (( c=0; c<6; c++ )); do 
				echo -n " Retrying to switch $outlet outlet to $targState, "
				swRes="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.04 set p6$outlet $targState)"
				dmsg echo "$swRes"
				if [ "$targState" = "$(echo "$swRes" |grep "$outlet=" |cut -d= -f2)" ]; then
					echo -e "\e[0;32mok.\e[m"
					break;
				else
					echo -e "\e[0;31mfail.\e[m"
					if [ $c -gt 4 ]; then except "Outlet could not be switched"; fi
				fi
			done
		fi
	else
		except "Outlet nuber is not in range: $outlet"
	fi
}

function IPPowerSwPowerNoDelay () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN outlet swRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateNumAssign "outlet" "$2"
	privateNumAssign "targState" "$3"
	if [ "$outlet" -ge 0 ] && [ "$outlet" -le 5 ]; then
		echo -n " Switching $outlet outlet to $targState, "
		swRes="$(sendIPPowerSerialCmd $ttyN 19200 0.04 set p6$outlet $targState)"
		dmsg echo "$swRes"
		if [ "$targState" = "$(echo "$swRes" |grep "$outlet=" |cut -d= -f2)" ]; then
			echo -e "\e[0;32mok.\e[m"
		else
			echo -e "\e[0;31mfail.\e[m"
			echo -n " Retrying to switch $outlet outlet to $targState, "
			swRes="$(sendIPPowerSerialCmd $ttyN 19200 0.04 set p6$outlet $targState)"
			dmsg echo "$swRes"
			if [ "$targState" = "$(echo "$swRes" |grep "$outlet=" |cut -d= -f2)" ]; then
				echo -e "\e[0;32mok.\e[m"
			else
				except "Outlet could not be switched"
			fi
		fi
	else
		except "Outlet nuber is not in range: $outlet"
	fi
}

function sendIPPowerSerialCmdDelayed () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd i 
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "delay" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmd" "$*"

	logFilePath="/tmp/IPPowerSerialCMD.log"

	dmsg "using dev /dev/$ttyN"
	if ! [[ -e "/dev/$ttyN" ]]; then
		except "Serial dev does not exist"
	fi

	echo " Owning $ttyN"
	chmod o+rw /dev/$ttyN
	echo " Setting baud $baud"
	dmsg "setting baud and reverse on dev /dev/$ttyN"
	stty $baud < /dev/$ttyN
	stty $baud -F /dev/$ttyN

	killLogWriters $logFilePath
	rm -f $logFilePath
	
	dmsg "starting log"
	echo " Started log file"
	cat -v < /dev/$ttyN |& tee $logFilePath >/dev/null &

	dmsg "sending cmd to /dev/$ttyN: $cmd"
	echo " Sending cmd: $cmd"
	echo -ne "\r" > /dev/$ttyN
	sleep $delay
	echo -ne "\r" > /dev/$ttyN
	sleep $delay
	for (( i=0; i<${#cmd}; i++ )); do echo -ne "${cmd:$i:1}" > /dev/$ttyN; sleep 0.05; done
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	# echo -e "\r" > /dev/$ttyN
	# echo -e "\r" > /dev/$ttyN
	# echo -e "\r" > /dev/$ttyN
	# echo -e "\r" > /dev/$ttyN
	# echo -e "\r" > /dev/$ttyN
	# echo -e "\r" > /dev/$ttyN
	sleep $delay
	sleep $delay
	sleep $delay

	killLogWriters $logFilePath
	killSerialWriters /dev/$ttyN
	dmsg "reading log"
	echo " Reading log file"
	outlStat="$(cat "$logFilePath" )"
	dmsg "full log: $outlStat"

	outlStat="$(echo "$outlStat" |grep p6 |grep status |cut -d: -f2)"
	dmsg "after cut log status:\n"$outlStat
	
	if [ ! -z "$outlStat" ]; then
		echo -e "\n\n Outlet status:"
		echo "  1=$(echo $outlStat |awk '{print $4}')"
		echo "  2=$(echo $outlStat |awk '{print $3}')"
		echo "  3=$(echo $outlStat |awk '{print $2}')"
		echo "  4=$(echo $outlStat |awk '{print $1}')"
	else
		echo -e " Outlet status returned empty!\n Full log:\n $(cat "$logFilePath" )"
	fi
}

function sendIPPowerSerialCmd () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmd" "$*"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"


	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	send \n\r
	expect {
		Connected { 
			send \r\n
			send \r\n
			send \n
			send \"\r\ndir\r\n\"
			send \"\r\ndir\r\n\"
		}
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	send \n\r
	expect {
		*CMD:* { 
			send \"$cmd\r\"
			send \r\n
		}
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*status :* { send \x14q\r }
	timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	Disconnected { send_user Done\n }
	timeout { send_user \"\nTimeout4\n\"; exit 1 }
	eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	return $?
}

ipPowerInit() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	acquireVal "IPPower IP address" ippIP ippIP
	verifyIp "${FUNCNAME[0]}" $ippIP
	sshWaitForPing 30 $ippIP 2
	acquireVal "IPPower user" ippUsr ippUsr
	acquireVal "IPPower password" ippPsw ippPsw
}

ipPowerSetPowerUP() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	ipPowerSetPowerHttp $ippIP $ippUsr $ippPsw 1 1
	ipPowerSetPowerHttp $ippIP $ippUsr $ippPsw 2 1
}

ipPowerSetPowerDOWN() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	ipPowerSetPowerHttp $ippIP $ippUsr $ippPsw 1 0
	ipPowerSetPowerHttp $ippIP $ippUsr $ippPsw 2 0
}

ipPowerSetPortPowerDOWN() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	privateNumAssign "ippPortNum" "$1"
	if [ $ippPortNum -lt 1 -o $ippPortNum -gt 4 ]; then except "illegal port number: $ippPortNum"; fi
	ipPowerSetPortPower $ippPortNum 0
}

ipPowerSetPortPowerUP() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	privateNumAssign "ippPortNum" "$1"
	if [ $ippPortNum -lt 1 -o $ippPortNum -gt 4 ]; then except "illegal port number: $ippPortNum"; fi
	ipPowerSetPortPower $ippPortNum 1
}

ipPowerSetPortPower() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	privateNumAssign "ippPortNum" "$1"
	privateNumAssign "ippPortTargState" "$2"
	if [ $ippPortNum -lt 1 -o $ippPortNum -gt 4 ]; then except "illegal port number: $ippPortNum"; fi
	if [ $ippPortNum -lt 0 -o $ippPortTargState -gt 1 ]; then except "illegal port target state: $ippPortTargState"; fi
	ipPowerSetPowerHttp $ippIP $ippUsr $ippPsw $ippPortNum $ippPortTargState
}

ipPowerSetPowerHttp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ipPowerIP ipPowerUser ipPowerPass targPort targState cmdRes
	privateVarAssign "${FUNCNAME[0]}" "ipPowerIP" "$1"
	verifyIp "${FUNCNAME[0]}" $ipPowerIP
	privateVarAssign "${FUNCNAME[0]}" "ipPowerUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "ipPowerPass" "$3"
	privateVarAssign "${FUNCNAME[0]}" "targPort" "$4"
	privateVarAssign "${FUNCNAME[0]}" "targState" "$5"
	cmdRes=$(wget --timeout=20 "http://$ipPowerIP/set.cmd?user=$ipPowerUser+pass=$ipPowerPass+cmd=setpower+p6$targPort=$targState" 2>&1)
	rm -f './set.cmd?user=$ipPowerUser+pass=$ipPowerPass+cmd='*
	# cmdRes=$(wget "http://172.30.4.207/set.cmd?user=admin+pass=12345678+cmd=setpower+p61=1" 2>&1)
}

ipPowerSetPowerTelnet() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ipPowerIP ipPowerUser ipPowerPass targPort targState cmdRes
	privateVarAssign "${FUNCNAME[0]}" "ipPowerIP" "$1"
	verifyIp "${FUNCNAME[0]}" $ipPowerIP
	privateVarAssign "${FUNCNAME[0]}" "ipPowerUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "ipPowerPass" "$3"
	privateVarAssign "${FUNCNAME[0]}" "targPort" "$4"
	privateVarAssign "${FUNCNAME[0]}" "targState" "$5"
	eval "{ echo admin=12345678; sleep 0.1; echo setpower=0000; sleep 0.1; echo setpower=1111; }" | telnet 172.30.4.207
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tIPPower lib for testing (support: arturd@silicom.co.il)'
	if ! [ "$(type -t sendToKmsg 2>&1)" == "function" ]; then 
		source /root/multiCard/arturLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mMAIN LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t privateVarAssign 2>&1)" == "function" ]; then 
		source /root/multiCard/utilLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mUTILITY LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t sendSerialCmd 2>&1)" == "function" ]; then 
		source /root/multiCard/serialLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mSERIAL LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi