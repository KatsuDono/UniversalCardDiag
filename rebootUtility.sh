#!/bin/bash

declareVars() {
	ver="v0.01"
	toolName='Reboot utility'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	let exitExec=0
	let debugBrackets=0
}

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			ssh-ip) sshIpArg=${VALUE} ;;
			ssh-user) sshUserArg=${VALUE} ;;
			ipmi-ip) ipmiIpArg=${VALUE} ;;
			ipmi-user) ipmiUserArg=${VALUE} ;;
			ipmi-pass) ipmiPassArg=${VALUE} ;;
			silent) 
				silentMode=1 
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			debug) 
				debugMode=1 
				inform "Launch key: Debug mode"
			;;
			help) showHelp ;;
			*) echo "Unknown arg: $ARG"; showHelp
		esac
	done
}

showHelp() {
	warn "\n=================================" "" "sil"
	echo -e "$toolName"
	echo -e " Arguments:"
	echo -e " --help"
	echo -e "\tShow help message\n"	
	echo -e " --silent"
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	echo -e " Setting defaults.."
	sshIpArg=172.30.7.24
	sshUserArg=root
	ipmiIpArg=172.30.7.25
	ipmiUserArg=ADMIN
	ipmiPassArg=QLGADZQAWW
	echo -e " Done.\n"
}

checkIpmiTool() {
	which ipmitool &> /dev/null && {
		echo -e '  ipmitool '$gr"ok."$ec
	} || {
		except "ipmitool is not installed."
	}
}

startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	checkIpmiTool
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

initialSetup(){
	publicVarAssign fatal sshIp $sshIpArg
	publicVarAssign fatal sshUser $sshUserArg
	publicVarAssign fatal ipmiIp $ipmiIpArg
	publicVarAssign fatal ipmiUser $ipmiUserArg
	publicVarAssign fatal ipmiPass $ipmiPassArg

}

powerDownSsh() {
	echo "  Powering down host: $sshUser@$sshIp"
	sshSendCmdSilent $sshIp $sshUser "poweroff"
}

powerUpIpmi() {
	echo "  Powering up IPMI: $ipmiUser@$ipmiIp"
	ipmiPowerUP $ipmiIp $ipmiUser $ipmiPass
}

main() {
	echo "  Checking IPMI is UP"
	sshWaitForPing 3 $ipmiIpArg
	if [ $? -eq 1 ]; then except "IPMI is down (IP: $ipmiIpArg)"; fi
	echo "  Checking SSH is DOWN"
	sshWaitForPing 3 $sshIp
	if [ $? -eq 0 ]; then
		powerDownSsh
		countDownDelay 15 "  Waiting for power down.."
		sshWaitForPing 5 $sshIp
		if [ $? -eq 1 ]; then
			echo "  Host $sshIp is down."
			powerUpIpmi
		else
			except "Host $sshIp is up!"
		fi
	else
		powerUpIpmi
	fi
	countDownDelay 170 "  Waiting for boot.."
	sshWaitForPing 30 $sshIp
	if [ $? -eq 0 ]; then
		ipmiCheckChassis $ipmiIp $ipmiUser $ipmiPass
		echo "  Power up ok."
	else
		except "Host $sshIp is down!"
	fi
	passMsg "\n\tDone!\n"
}

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
(return 0 2>/dev/null) && echo -e "\trebootUtility has been loaded as lib" || {
	trap "exit 1" 10
	PROC="$$"
	declareVars
	source /root/multiCard/arturLib.sh; let status+=$?
	source /root/multiCard/graphicsLib.sh; let status+=$?
	if [[ ! "$status" = "0" ]]; then 
		echo -e "\t\e[0;31mLIBRARIES ARE NOT LOADED! UNABLE TO PROCEED\n\e[m"
		exit 1
	fi
	echoHeader "$toolName" "$ver"
	echoSection "Startup.."
	setEmptyDefaults
	parseArgs "$@"
	initialSetup
	startupInit
	main
	echo -e "See $(inform "--help" "--nnl" "--sil") for available parameters\n"
}
