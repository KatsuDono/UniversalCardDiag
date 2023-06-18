#!/bin/bash

declareVars() {
	ver="v0.01"
	toolName='OneDrive sync utility'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	let exitExec=0
	let debugBrackets=0
	let retryCount=10
	let retryTimeout=5
}

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			silent) 
				silentMode=1 
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			debug) 
				debugMode=1 
				inform "Launch key: Debug mode"
			;;
			retry-count) 	retryCount=${VALUE};;
			retry-timeout) 	retryTimeout=${VALUE};;
			lock-contents) 	lockContents=${VALUE};;
			upload-path)	uploadPath=${VALUE};;
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
	# sshIpArg=172.30.7.24
	echo -e " Done.\n"
}

startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	# checkIpmiTool
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

initialSetup(){
	setupInternet
}

syncLoop() {
	local slotIdx targLine lockFilePath paramIdx retryCnt
	lockFilePath=/tmp/onedrive.lock
	let retryCnt=0

	echo -ne "\r\n"
	while true; do
		printf '\e[A\e[K\e[A\e[K'
		if [ -e "$lockFilePath" ]; then
			warn "  Unable to write to onedrive path, it is locked (try count: $retryCnt)"
			countDownDelay $retryTimeout "  Waiting for lock removal.."
		else
			dmsg echo "  Locking DB"
			echo Contents: $lockContents >$lockFilePath

			rsync -arvu "/home/smbLogs/LogStorage/" "/root/OneDrive/LogStorage/"
			syncLogsOnedrive $uploadPath

			dmsg echo "  Unlocking DB"
			rm -f "$lockFilePath"

			break;
		fi
		let retryCnt++
		if [ $retryCnt -gt $retryCount ]; then
			warn "  Reached maximum retry count, aborting onedrive sync."
			break;
		fi
	done
}

main() {
	echo "  Starting sync proccess"
	syncLoop
	passMsg "\n\tDone!\n"
}

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
(return 0 2>/dev/null) && echo -e "\tonedriveSyncUtility has been loaded as lib" || {
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
