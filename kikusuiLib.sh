#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

kikusuiInit() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local kikusuiIP cmdRes
	privateVarAssign "${FUNCNAME[0]}" "kikusuiIP" "$1"
	verifyIp "${FUNCNAME[0]}" $kikusuiIP
	echo " Initializing Kikusui by IP $kikusuiIP.."
	cmdRes=$(lxi scpi -a $kikusuiIP "*IDN?")
	if [[ ! -z "$(echo $cmdRes |grep PWR401)" ]]; then
		echo "  Kikusui connected!"
		echo "  Info: $cmdRes"
		sleep 0.1
		printf "  Voltage: %1.2f\n" $(lxi scpi -a $kikusuiIP "MEAS:VOLT?")
		sleep 0.1
		printf "  Current: %1.2f\n" $(lxi scpi -a $kikusuiIP "MEAS:CURR?")
	else
		except "Kikusui connection on $kikusuiIP failed, or incorrect model"
	fi
	echo " Done."
}

kikusuiSetupDefault() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes measVolt measCurr maxVolt maxCurr
	acquireVal "Kikusui IP" kikusuiIP kikusuiIP
	verifyIp "${FUNCNAME[0]}" $kikusuiIP
	echo " Setting up Kikusui.."
	echo "  Turning PSU output off"
	sendKikusuiCmd "current 0"
	sendKikusuiCmd "voltage 0"
	sendKikusuiCmd "output off"
	sleep 0.5
	echo -n "  Checking PSU output is off: "
	cmdRes=$(lxi scpi -a $kikusuiIP "output?" 2>&1); sleep 0.1
	if [[ "$cmdRes" = "0" ]]; then 
		echo -e "\e[0;32moff\e[m"
		echo "  Setting PSU output voltage to 12.2V"
		sendKikusuiCmd "voltage 12.2"
		echo "  Setting PSU output current to 7A"
		sendKikusuiCmd "current 7"
		maxVolt=$(printf "%1.1f" $(getKikusuiCmd "voltage?")); sleep 0.2
		maxCurr=$(printf "%1.0f" $(getKikusuiCmd "current?")); sleep 0.2
		if [ "$maxVolt" = "12.2" -a "$maxCurr" = "7" ]; then
			echo -e "  Checked PSU voltage: $maxVolt, current: $maxCurr: \e[0;32mok\e[m"
		else
			except "Kikusui voltage ($measVolt) or current ($measCurr) not in range"
		fi
	else 
		echo -e "\e[0;31mon\e[m"
		except "Kikusui on $kikusuiIP wasnt turned off"
	fi
	
	echo " Done."
}

sendKikusuiCmd() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes sendCmd
	privateVarAssign "${FUNCNAME[0]}" "sendCmd" "$1"
	verifyIp "${FUNCNAME[0]}" $kikusuiIP
	sleep 0.2
	cmdRes=$(lxi scpi -a $kikusuiIP "$sendCmd" 2>&1)
}

getKikusuiCmd() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes sendCmd
	privateVarAssign "${FUNCNAME[0]}" "sendCmd" "$1"
	verifyIp "${FUNCNAME[0]}" $kikusuiIP
	cmdRes=$(lxi scpi -a $kikusuiIP "$sendCmd" 2>&1) 2>&1
	if [[ ! -z "$(echo $cmdRes |grep Error)" ]]; then 
		sleep 0.2
		cmdRes=$(lxi scpi -a $kikusuiIP "$sendCmd" 2>&1)
		if [[ ! -z "$(echo $cmdRes |grep Error)" ]]; then 
			sleep 0.2
			cmdRes=$(lxi scpi -a $kikusuiIP "$sendCmd" 2>&1)
		else
			echo -n "$cmdRes"
		fi
	else
		echo -n "$cmdRes"
	fi
	sleep 0.1
}

checkJQPkg() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local whichCmd
	echo " Checking JQ present.."
	which jq 2>&1 > /dev/null
	if [ $? -eq 0 ]; then 
		echo "  jq present, ok"	
	else 
		warn "  JQ is not installed!"
		installJQTools
	fi
	echo " Done."
}

installJQTools() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	testFileExist "/root/multiCard/rpmPackages/jq-1.6-2.el7.x86_64.rpm"
	testFileExist "/root/multiCard/rpmPackages/oniguruma-6.8.2-2.el7.x86_64.rpm"
	
	warn "  Initializing install.."
	
	inform "   Installing regular expressions library.."
	rpm -i /root/multiCard/rpmPackages/oniguruma-6.8.2-2.el7.x86_64.rpm
	if [ $? -eq 0 ]; then echo "    regular expressions library installed"; else except "regular expressions library was not installed"; fi
		
	inform "   Installing jq.."
	rpm -i /root/multiCard/rpmPackages/jq-1.6-2.el7.x86_64.rpm
	if [ $? -eq 0 ]; then echo "    jq installed"; else except "jq was not installed"; fi

	inform "  Installing done."
}

checkLxiPkg() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo " Checking LXI tools present.."
	which lxi 2>&1 > /dev/null
	if [ $? -eq 0 ]; then 
		echo "  lxi tools present, ok"	
	else 
		warn "  LXI tools are not installed!"
		installLxiTools
	fi
	echo " Done."
}

installLxiTools() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	testFileExist "/root/multiCard/rpmPackages/liblxi-1.16-1.el7.x86_64.rpm"
	testFileExist "/root/multiCard/rpmPackages/lxi-tools-2.1-1.el7.x86_64.rpm"
	warn "  Initializing install.."
	inform "   Installing liblxi.."
	rpm -i /root/multiCard/rpmPackages/liblxi-1.16-1.el7.x86_64.rpm
	if [ $? -eq 0 ]; then echo "    liblxi installed"; else except "liblxi was not installed"; fi
	inform "   Installing lxi-tools.."
	rpm -i /root/multiCard/rpmPackages/lxi-tools-2.1-1.el7.x86_64.rpm
	if [ $? -eq 0 ]; then echo "    lxi-tools installed"; else except "lxi-tools was not installed"; fi
	inform "  Installing done."
}


if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tKikusui lib for testing (support: arturd@silicom.co.il)'
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
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi