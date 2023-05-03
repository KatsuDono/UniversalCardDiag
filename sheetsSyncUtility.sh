#!/bin/bash

declareVars() {
	ver="v0.01"
	toolName='Google Sheets sync utility'
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
	# sshIpArg=172.30.7.24
	echo -e " Done.\n"
}

startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	# checkIpmiTool
	echo -e " Done.\n"
}

initialSetup(){
	setupInternet
}

syncLoop() {
	local lockFilePath retryCnt filePath
	lockFilePath=/tmp/gsheets.lock
	filePath="/tmp/gsheets.csv"
	let retryCnt=0

	echo -ne "\r\n"
	while true; do
		printf '\e[A\e[K\e[A\e[K'
		if [ -e "$lockFilePath" ]; then
			warn "  Unable to write to google path, it is locked (try count: $retryCnt)"
			countDownDelay 5 "  Waiting for lock removal.."
		else
			echo "  Locking GSheets"
			echo 1>$lockFilePath

			sqlExportViewCSV "SlotJobsView" |& tee $filePath
			python3 /root/multiCard/sheetSQLUpdateUtility.py $filePath
			echo "  Unlocking GSheets"
			rm -f "$lockFilePath"
			break;
		fi
		let retryCnt++
		if [ $retryCnt -gt 20 ]; then
			warn "  Reached maximum retry count, aborting sync."
			break;
		fi
	done
}

main() {
	echo "  Starting sync proccess"
	syncLoop
	passMsg "\n\tDone!\n"
}

export MC_SCRIPT_PATH=/root/multiCard
source ${MC_SCRIPT_PATH}/arturLib.sh; let loadStatus+=$?
source ${MC_SCRIPT_PATH}/graphicsLib.sh; let loadStatus+=$?
source ${MC_SCRIPT_PATH}/sqlLib.sh; let loadStatus+=$?

if [[ ! "$loadStatus" = "0" ]]; then 
	echo -e "\t\e[0;31mLIBRARIES ARE NOT LOADED! UNABLE TO PROCEED\n\e[m"
	exit 1
else
	unset loadStatus
	echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
	(return 0 2>/dev/null) && echo -e "\tsheetsSyncUtility has been loaded as lib" || {
		trap "exit 1" 10
		PROC="$$"
		declareVars
		echoHeader "$toolName" "$ver"
		echoSection "Startup.."
		setEmptyDefaults
		parseArgs "$@"
		initialSetup
		startupInit
		main
		echo -e "See $(inform "--help" "--nnl" "--sil") for available parameters\n"
	}
fi
