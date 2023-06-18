#!/bin/bash

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			debug) debugMode=1 ;;
			autostart) autostartMode=1 ;;
			no-reboot) noReboot=1 ;;
			no-debug) noDebug=1 ;;
			no-verify) noVerify=1 ;;
			debug-stack) dmsgStack=1 ;;
			silent) 
				silentMode=1 
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			help) showHelp ;;
			*) dmsg echo "Unknown startup arg: $ARG"
		esac
	done
}

showHelp() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	warn "\n=================================" "" "sil"
	echo -e "$toolName"
	echo -e " Arguments:"
	echo -e " --help"
	echo -e "\tShow help message\n"	
	echo -e " --autostart"
	echo -e "\tAutomatic startup mode\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"		
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e " Setting defaults.."
	publicVarAssign warn internetAcq "0"
	publicNumAssign maxSlots "$(($(getMaxSlots)-1))"
	echo -e " Done.\n"
}

startupInit() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e " StartupInit.."
	setupInternet
	echo -e -n "  Creating LogStorage folder /root/multiCard/LogStorage: "; echoRes "mkdir -p /root/multiCard/LogStorage"
	echo -e -n "  Creating FailLogs folder /root/multiCard/LogStorage/FailLogs: "; echoRes "mkdir -p /root/multiCard/LogStorage/FailLogs"
	echo -e -n "  Creating GlobalLogs folder /root/multiCard/LogStorage/GlobalLogs: "; echoRes "mkdir -p /root/multiCard/LogStorage/GlobalLogs"
	echo -e -n "  Creating JobStorage folder /root/multiCard/LogStorage/JobStorage: "; echoRes "mkdir -p /root/multiCard/LogStorage/JobStorage"
	echo -e -n "  Creating OneDrive LogStorage folder /root/OneDrive/LogStorage: "; echoRes "mkdir -p /root/OneDrive/LogStorage"
	echo -e -n "  Creating OneDrive FailLogs folder /root/OneDrive/LogStorage/FailLogs: "; echoRes "mkdir -p /root/OneDrive/LogStorage/FailLogs"
	echo -e -n "  Creating OneDrive GlobalLogs folder /root/OneDrive/LogStorage/GlobalLogs: "; echoRes "mkdir -p /root/OneDrive/LogStorage/GlobalLogs"
	echo -e -n "  Creating OneDrive JobStorage folder /root/OneDrive/LogStorage/JobStorage: "; echoRes "mkdir -p /root/OneDrive/LogStorage/JobStorage"
	echo -e " Done.\n"
}

createGlobalLog() {
	local logPath ln1 ln2
	privateVarAssign fatal logPath "$1"
	if [[ -e "$logPath" ]]; then
		ln1=$(cat $logPath |head -n1 |grep 'sep=;')
		ln2=$(cat $logPath |head -n2 |tail -n1 |grep 'JobID;PN;TN;Slot;CurrentRun')
		if [ -z "$ln1" -o -z "$ln2" ]; then
			if [ -z "$(cat $logPath)" ]; then
				echo "empty, corrected."
				echo -e "sep=;\nJobID;PN;TN;Slot;CurrentRun;TestResult;PassedRuns;FailedRuns;RunsLeft;Temp1;Temp2;Temp3;Temp4;DBID;MAC" 2>&1 |& tee -a "$logPath" >/dev/null
			else
				critWarn "log: $logPath exists and is corrupted or formatted wrong"
			fi
		else
			echo "validated, not empty"
		fi
	else
		echo "non existent, created."
		echo -e "sep=;\nJobID;PN;TN;Slot;CurrentRun;TestResult;PassedRuns;FailedRuns;RunsLeft;Temp1;Temp2;Temp3;Temp4;DBID;MAC" 2>&1 |& tee -a "$logPath" >/dev/null
	fi
}

loadCfg() {
	local cfgPath srcRes cfgPathArg randHexLong idx globalLogName globalLogPath
	cfgPathArg=$1

	echo -e "  Loading config file.."
	if [ -z "$cfgPathArg" ]; then
		cfgPath="$(readlink -f ${0} |cut -d. -f1).cfg"
	else
		cfgPath=$cfgPathArg
	fi
	if [[ -e "$cfgPath" ]]; then 
		echo -e "   Config file $cfgPath found."
		cfgSize=$(stat -c%s "$cfgPath")
		echo -n "   Checking size.. "
		if [ $cfgSize -gt 0 ]; then
			echo "Validated."
			echo -n "   Sourcing CFG: "
			source "$cfgPath"
			# srcRes="$(source "$cfgPath" 3>&1 1>&2 2>&3 3>&- 1> /dev/null)"
			if [ -z "$srcRes" ]; then 
				echo "config loaded"
				echo -n "   Checking DB unique ID: "
				dbID=$(readDB 99 --db-id)
				if [ "$dbID" = "NULL" ]; then
					echo -e "NULL\n   DB ID does not exist, creating..."
					randHexLong=$(xxd -u -l 16 -p /dev/urandom)
					writeDB 99 --db-id=$randHexLong
					echo "   New DB ID: $(readDB 99 --db-id)"
				else
					if [ -z "$dbID" ]; then 
						critWarn "config file is corrupted"
					else
						echo "$dbID"
						echo "   Checking DB global logs: "
						for ((idx=0;idx<=$maxSlots;idx++)); do 
							echo -n "    Slot $(($idx+1)): "
							globalLogName=$(readDB $idx --global-log)
							if [ -z "$globalLogName" ]; then
								critWarn "NULL"
							else
								mkdir -p /root/multiCard/LogStorage &> /dev/null
								mkdir -p /root/multiCard/LogStorage/GlobalLogs &> /dev/null
								if [ "$globalLogName" = "GLOBAL-LOG.csv" ]; then
									echo -n "not set, setting: "
									globalLogName=$(echo -n "$globalLogName" |cut -d. -f1)_$dbID.csvDB
									writeDB $idx --global-log=$globalLogName
									echo -n "$(readDB $idx --global-log). Contents: "
									privateVarAssign "${FUNCNAME[0]}" "globalLogPath" "/root/multiCard/LogStorage/GlobalLogs/$globalLogName"
									createGlobalLog $globalLogPath
								else
									echo -n "set, validating: "
									if [ ! -z "$(echo -n $globalLogName |grep $dbID)" ]; then
										echo -n "validated. Contents: "
										privateVarAssign "${FUNCNAME[0]}" "globalLogPath" "/root/multiCard/LogStorage/GlobalLogs/$globalLogName"
										createGlobalLog $globalLogPath
									else
										critWarn "not validated."
									fi
								fi
							fi
						done
						echo "   Done."
					fi
				fi
			else 
				critWarn "config file is corrupted"
			fi
		else
			critWarn "Invalid, empty file, skipping"
		fi
	else
		warn "  Config file not found by path: $cfgPath"
	fi
	echo -e "  Done."
}

declareVars() {
	ver="v0.01"
	toolName="Boot Launcher"
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	jobDBPath="/root/multiCard/job.DB"
	rebootServerIp=172.30.7.28
	rebootServerUser=root
	syncSrvIp=172.30.7.17
	syncSrvUser=root
	loadCfg $jobDBPath
	hwKeySerialArr=(
		"0401a7e4041ab89ba243a4ca4ef84fcbcc2a6117db8dbc6e601ae70c410fff1233af0000000000000000000040c5104100178218975581078cab4735"
		"04014ebef0963de8c83108b6c618529a5db4bbae3103170ccc1f832ad1f7027bb28000000000000000000000d008ab9fff168218975581078cab4740"
	)
	pnArr=(
		"PE210G2BPI9-SR"
		"PE210G2BPI9-SRSD-BC8"
		"PE210G2BPI9-SR-SD"
		"PE210G2BPI9-SRD-SD"
		"PE210G2SPI9A-XR"
		"PE310G4BPI71-SR"
		"PE310G4BPI71-LR"
		"PE310G4I71L-XR-CX1"
		"PE310G2BPI71-SR"
		"PE340G2BPI71-QS43"
		"PE310G4DBIR"
		"PE310G4BPI9-SR"
		"PE310G4BPI9-LR"
		"PE325G2I71-XR-CX"
		"PE325G2I71-XR-SP"
		"PE31625G4I71L-XR-CX"
		"M4E310G4I71-XR-CP2"
		"PE340G2DBIR-QS41"
		"PE3100G2DBIR"
		"PE425G4I71L"
		"PE425G4I71L-XR-CX"
		"P410G8TS81-XR"
		"PE210G2BPI40-T"
		"PE310G4BPI40-T"
		"PE310G4DBIR-T"
		"PE310G4I40-T"
		"PE2G2I35"
		"PE2G4I35"
	)
}

main() {
	local jobCreate defStartup slotSel
	addSQLLogRecord $syncSrvIp $dbID --server-up
	if [ ! -z "$autostartMode" ]; then
		checkHWkey
		if [ $? -eq 0 ]; then 
			checkJobStates
		else
			testHaltLoop
		fi
	else
		echo -e "\n  Select action:"
		options=("Create or manage job" "Normal startup")
		case `select_opt "${options[@]}"` in
			0)
				echoSection "Job creation"
				createJobsLoop
			;;
			1) 
				checkJobStates
			;;
			*) except "Unknown action";;
		esac
	fi
}

readDB() {
	local slotIdx resPrint
	privateNumAssign "slotIdx" "$1"; shift
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		case "$KEY" in
			db-id)			resPrint=${slotMatrix[$slotIdx,99]} ;;
			ssh-ip)			resPrint=${slotMatrix[99,98]} ;;
			ssh-user)		resPrint=${slotMatrix[99,97]} ;;
			ipmi-ip)		resPrint=${slotMatrix[99,96]} ;;
			ipmi-user)		resPrint=${slotMatrix[99,95]} ;;
			ipmi-pass)		resPrint=${slotMatrix[99,94]} ;;
			slot-num) 		resPrint=${slotMatrix[$slotIdx,0]} ;;
			pn) 			resPrint=${slotMatrix[$slotIdx,1]} ;;
			tn) 			resPrint=${slotMatrix[$slotIdx,2]} ;;
			mac) 			resPrint=${slotMatrix[$slotIdx,3]} ;;
			pci-test) 		resPrint=${slotMatrix[$slotIdx,10]} ;;
			link-test) 		resPrint=${slotMatrix[$slotIdx,11]} ;;
			job-id) 		resPrint=${slotMatrix[$slotIdx,19]} ;;
			test-start) 	resPrint=${slotMatrix[$slotIdx,20]} ;;
			test-end) 		resPrint=${slotMatrix[$slotIdx,21]} ;;
			test-result) 	resPrint=${slotMatrix[$slotIdx,22]} ;;
			pass-runs) 		resPrint=${slotMatrix[$slotIdx,23]} ;;
			fail-runs) 		resPrint=${slotMatrix[$slotIdx,24]} ;;
			total-runs) 	resPrint=${slotMatrix[$slotIdx,25]} ;;
			current-run) 	resPrint=${slotMatrix[$slotIdx,26]} ;;
			runs-left) 		resPrint=${slotMatrix[$slotIdx,27]} ;;
			last-run-log)	resPrint=${slotMatrix[$slotIdx,28]} ;;
			total-log)		resPrint=${slotMatrix[$slotIdx,29]} ;;
			global-log)		resPrint=${slotMatrix[$slotIdx,30]} ;;
			*) except "Unknown DB key: $ARG"
		esac
	done
	if [ ! -z "$resPrint" ]; then echo -n "$resPrint"; fi
}

writeSQLDB() {
	local KEY VALUE sqlFunc sqlExecRes sshCmd cmdRes
	local totalRunsSQLDB currentRunSQLDB runsLeftSQLDB passedRunsSQLDB failedRunsSQLDB statusSQLDB
	local TNSQLDB PNSQLDB MACSQLDB slotNumSQLDB srvHexIDSQLDB JobHexID
	privateVarAssign "${FUNCNAME[0]}" "JobHexID" "$1"; shift
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			update-job-counters) 
				if [ ! -z "$sqlFunc" ]; then
					except "double sql function keys present, existing value: $sqlFunc duplicate value: ${VALUE}"
				else 
					sqlFunc="updJobCnt"
				fi 
			;;
			update-job-status) 
				if [ ! -z "$sqlFunc" ]; then
					except "double sql function keys present, existing value: $sqlFunc duplicate value: ${VALUE}"
				else 
					sqlFunc="updJobSta"
				fi 
			;;
			add-job) 
				if [ ! -z "$sqlFunc" ]; then
					except "double sql function keys present, existing value: $sqlFunc duplicate value: ${VALUE}"
				else 
					sqlFunc="addJob"
				fi 
			;;

			"slotNum"|"totalRuns"|"currentRun"|"runsLeft"|"passedRuns"|"failedRuns") 	privateNumAssign "${KEY}SQLDB" "${VALUE}" ;;
			"TN"|"PN"|"MAC"|"status") 	privateVarAssign "${FUNCNAME[0]}" "${KEY}SQLDB" "${VALUE}" ;;
			"srvHexID") 	privateVarAssign "${FUNCNAME[0]}" "srvHexIDSQLDB" "${VALUE}" ;;
			*) except "Unknown SQLDB key: $ARG"
		esac
	done
	case "$sqlFunc" in
		updJobCnt)	
			echo "Updating SQL slot sounters: $totalRunsSQLDB,$currentRunSQLDB,$runsLeftSQLDB,$passedRunsSQLDB,$failedRunsSQLDB"
			if [ -z "$totalRunsSQLDB" -o -z "$currentRunSQLDB" -o -z "$runsLeftSQLDB" -o -z "$passedRunsSQLDB" -o -z "$failedRunsSQLDB" ]; then
				except "input parameters undefined for sqlFunc: $sqlFunc"
			else
				sshCmd='source /root/multiCard/sqlLib.sh &>/dev/null; '"sqlUpdateJobCounters \"$JobHexID\" \"$totalRunsSQLDB\" \"$currentRunSQLDB\" \"$runsLeftSQLDB\" \"$passedRunsSQLDB\" \"$failedRunsSQLDB\""
				cmdRes="$(sshSendCmd $syncSrvIp root "${sshCmd}")"
				sqlExecRes="$cmdRes"
				# sqlExecRes="$(sqlUpdateJobCounters "$JobHexID" "$totalRunsSQLDB" "$currentRunSQLDB" "$runsLeftSQLDB" "$passedRunsSQLDB" "$failedRunsSQLDB")"
				dmsg inform "$sqlExecRes"
				privateNumAssign "sqlExitStatus" "$sqlExecRes"
			fi
			if [ $sqlExecRes -le 0 ]; then
				except "sqlFunc:$sqlFunc exited with status: $sqlExecRes"
			else
				dmsg echo "  sql exit status: $sqlExecRes"
			fi
		;;
		updJobSta)	
			echo "Updating SQL slot status: $statusSQLDB"
			if [ -z "$statusSQLDB" ]; then
				except "input parameters undefined for sqlFunc: $sqlFunc"
			else
				sshCmd='source /root/multiCard/sqlLib.sh &>/dev/null;'"sqlUpdateJobStatus \"$JobHexID\" \"$statusSQLDB\""
				cmdRes="$(sshSendCmd $syncSrvIp root "${sshCmd}")"
				sqlExecRes="$cmdRes"
				# sqlExecRes="$(sqlUpdateJobStatus "$JobHexID" "$statusSQLDB")"
				dmsg inform "$sqlExecRes"
				privateNumAssign "sqlExitStatus" "$sqlExecRes"
			fi
			if [ $sqlExecRes -le 0 ]; then
				except "sqlFunc:$sqlFunc exited with status: $sqlExecRes"
			else
				dmsg echo "  sql exit status: $sqlExecRes"
			fi
		;;
		addJob)	
			echo "Adding SQL job: $TNSQLDB,$PNSQLDB,$MACSQLDB,$srvHexIDSQLDB,$slotNumSQLDB,$totalRunsSQLDB"
			if [ -z "$TNSQLDB" -o -z "$PNSQLDB" -o -z "$srvHexIDSQLDB" -o -z "$slotNumSQLDB" -o -z "$totalRunsSQLDB" ]; then
				if [ -z "$MACSQLDB" ]; then	MACSQLDB="-"; fi
				except "input parameters undefined for sqlFunc: $sqlFunc"
			else
				sshCmd='source /root/multiCard/sqlLib.sh &>/dev/null; '"sqlCreateJob \"$JobHexID\" \"$TNSQLDB\" \"$PNSQLDB\" \"$MACSQLDB\" \"$srvHexIDSQLDB\" $slotNumSQLDB $totalRunsSQLDB"
				cmdRes="$(sshSendCmd $syncSrvIp root "${sshCmd}")"
				sqlExecRes="$cmdRes"
				# sqlExecRes="$(sqlCreateJob "$JobHexID" "$TNSQLDB" "$PNSQLDB" "$MACSQLDB" "$srvHexIDSQLDB" $slotNumSQLDB $totalRunsSQLDB)"
				dmsg inform "$sqlExecRes"
				privateNumAssign "sqlExitStatus" "$sqlExecRes"
			fi
			if [ $sqlExecRes -le 0 ]; then
				except "sqlFunc:$sqlFunc exited with status: $sqlExecRes"
			else
				dmsg echo "  sql exit status: $sqlExecRes"
			fi
		;;
		*) except "Unknown sqlFunc: $sqlFunc"
	esac

}

writeDB() {
	local slotIdx targLine KEY VALUE lockFilePath paramIdx jobID
	privateNumAssign "slotIdx" "$1"; shift
	lockFilePath=$jobDBPath.lock

	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			db-id)			let paramIdx=99 ;;
			slot-num) 		let paramIdx=0 ;;
			pn) 			let paramIdx=1 ;;
			tn) 			let paramIdx=2 ;;
			mac) 			let paramIdx=3 ;;
			pci-test) 		let paramIdx=10 ;;
			link-test) 		let paramIdx=11 ;;
			job-id) 		let paramIdx=19 ;;
			test-start) 	let paramIdx=20 ;;
			test-end) 		let paramIdx=21 ;;
			test-result) 	let paramIdx=22 ;;
			pass-runs) 		let paramIdx=23 ;;
			fail-runs) 		let paramIdx=24 ;;
			total-runs) 	let paramIdx=25 ;;
			current-run) 	let paramIdx=26 ;;
			runs-left) 		let paramIdx=27 ;;
			last-run-log) 	let paramIdx=28 ;;
			total-log) 		let paramIdx=29 ;;
			global-log) 	let paramIdx=30 ;;
			*) except "Unknown DB key: $ARG"
		esac
		jobID=${slotMatrix[$slotIdx,19]}
		targLine="slotMatrix[$slotIdx,$paramIdx]"
		targLineMasked='slotMatrix\['$slotIdx','$paramIdx'\]'
		if [ -e "$lockFilePath" ]; then
			failRun "Unable to write to DB file, it is locked"
		else
			dmsg echo "  Locking DB"
			echo "JobID: $jobID">$lockFilePath
			if [ ! -z "$jobID" ]; then addSQLLogRecord $syncSrvIp $jobID --db-locked; fi
		fi

		dmsg echo "  Updating $KEY to ${VALUE} (line: $targLine)"
		newLine="$targLineMasked=${VALUE}"
		dmsg echo "  New line: $newLine"
		sed -i "s/$targLineMasked.*/$newLine/" /root/multiCard/job.DB
		dmsg echo "  Updating array idx=$slotIdx prm=$paramIdx to ${VALUE}"
		slotMatrix[$slotIdx,$paramIdx]=${VALUE}
	done
	dmsg echo "  Unlocking DB"
	rm -f "$lockFilePath"
	if [ ! -e "$lockFilePath" ]; then
		if [ ! -z "$jobID" ]; then addSQLLogRecord $syncSrvIp $jobID --db-unlocked; fi
	fi
}

function clearSlotDB() {
	local slotArg retRes forceClear testResultDB
	let retRes=0
	slotArg=$1
	forceClear=$2
	if [ ! -z "$(readDB $slotSel --pn)" ]; then
		if [ -z "$forceClear" ]; then 
			privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotSel --test-result)"
		else
			testResultDB="null"
		fi
		case "$testResultDB" in 
			"null"|"CLOSED"|"REMOVED")
				writeDB $slotArg --pn=""
				writeDB $slotArg --tn=""
				writeDB $slotArg --mac=""
				writeDB $slotArg --pci-test=null
				writeDB $slotArg --link-test=0
				writeDB $slotArg --test-start=0
				writeDB $slotArg --test-end=0
				writeDB $slotArg --test-result=null
				writeDB $slotArg --pass-runs=0
				writeDB $slotArg --fail-runs=0
				writeDB $slotArg --total-runs=0
				writeDB $slotArg --current-run=0
				writeDB $slotArg --runs-left=0
				writeDB $slotArg --last-run-log=null
				writeDB $slotArg --total-log=""
				writeDB $slotArg --job-id=""
			;;
			"READY"|"STARTED"|"ENDED"|"FINALIZED") 
				let retRes+=1
				critWarn "   Job is in incorrect state cant clear slot, skipping"
			;;
			*) critWarn "   unexpected testResultDB value: $testResultDB, skipping";;
		esac
	fi
	return $retRes
}

clearAllDB() {
	local slotCounter
	echo "   Clearing all DB.."
	for ((slotCounter=0;slotCounter<=$maxSlots;slotCounter++))
	do
		echo -e "\n  ========"
		echo -e "   Slot $(readDB $slotCounter --slot-num)    "
		clearSlotDB $slotCounter --force
		echo -e "  ========"
		echo -e "    Clearing.."
	done
	echo -e "   Done.\n\n"
}

function selectSlotForJob () {
	local options
	echo -e "\n  Select slot:"
	case $maxSlots in
		5)	options=("Slot 1" "Slot 2" "Slot 3" "Slot 4" "Slot 5" "Slot 6" "Save and exit");;
		6)	options=("Slot 1" "Slot 2" "Slot 3" "Slot 4" "Slot 5" "Slot 6" "Slot 7" "Save and exit");;
		*) except "unknown amount of slots"
	esac
	return `select_opt "${options[@]}"`
}

createJobsLoop() {
	local slotSel exitIdx options testResultDB cnfInput
	while true
	do
		checkJobStatesInfo
		selectSlotForJob
		privateNumAssign slotSel $?
		let exitIdx=$maxSlots+1
		if [ $slotSel -eq $exitIdx ]; then
			echo "slotSel=$slotSel exitIdx=$exitIdx maxSlots=$maxSlots"
			exit
		fi
		echo -e "\n  Select action:"
		options=("Add slot job" "Close job" "End job" "Verify job" "Select different slot" "Clear all DB" "Save and exit")
		case `select_opt "${options[@]}"` in
			0) 
				echo "  Add slot job selected"
				clearSlotDB $slotSel
				if [ $? -eq 0 ]; then 
					createSlotJob $slotSel
				else
					privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotSel --test-result)"
					echo "  Slot was unable to be cleared before creation, job state is not correct: $testResultDB"
				fi
			;;
			1) 
				echo "  Closing job on slot $(($slotSel+1))"
				closeJob $slotSel
			;;
			2) 
				privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotSel --test-result)"
				case "$testResultDB" in 
					"null")	warn "   Job test result is unset, skipping";;
					"READY"|"STARTED") 
						echo "  End the job on slot $(($slotSel+1))?"
						closePrompt=("Yes" "No")
						if [ "`select_opt "${closePrompt[@]}"`" = "0" ]; then
							changeSlotStatus $slotSel "ENDED"
							closeJob $slotSel
						fi
					;;
					"ENDED") warn "   Job is already ended, skipping";;
					"FINALIZED") warn "   Job is already finalized, skipping";;
					"CLOSED") warn "   Job is already closed, skipping"; clearSlotDB $slotSel;;
					"REMOVED") warn "   Job is already removed, skipping"; clearSlotDB $slotSel;;
					*) critWarn "   unexpected testResultDB value: $testResultDB, skipping";;
				esac
			;;
			3) 
				echo "  Verifying job on slot $(($slotSel+1))"
				verifySlot $slotSel 
			;;
			4) 
				echo "  Select different slot"
			;;
			5) 
				
				echo "  Enter 'CONFIRM_CLEAR' to clear all DB"
				read -r cnfInput
				if [ "$cnfInput" = "CONFIRM_CLEAR" ]; then
					echo "  Clearing all DB"
					clearAllDB
				fi
			;;
			6) 
				echo "  Saving and exiting"
				exit
			;;
			*) except "Unknown action";;
		esac
	done
}

closeJob() {
	local slotSel testResultDB
	privateNumAssign slotSel $1
	if [ ! -z "$(readDB $slotSel --pn)" ]; then
		privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotSel --test-result)"
		case "$testResultDB" in 
			"null")	critWarn "   Job test result is unset, skipping";;
			"READY")  critWarn "   Job is in incorrect state, skipping";;
			"STARTED") critWarn "   Job is in incorrect state, skipping";;
			"ENDED")
				echo "   Job on slot $(($slotSel+1)) has ended and have to be finalized, verification required"
				verifySlot $slotSel 
			;;
			"FINALIZED")
				echo "Closing slot job for slot $(($slotSel+1))"
				closeSlotJob $slotSel
			;;
			"CLOSED") critWarn "   Job is already closed, skipping";;
			"REMOVED") critWarn "   Job is already closed, skipping"; clearSlotDB $slotSel;;
			*) critWarn "   unexpected testResultDB value: $testResultDB, skipping";;
		esac
	else
		critWarn "   There is no job on this slot"
	fi
}

closeSlotJob() {
	local targSlot closePrompt shareLink cmdRes
	local uutSlotNum uutPn uutTn jobIDDB failRunsDB passRunsDB dbID totalRunsDB runsLeftDB currentRunDB uutMac sshCmd curTTY syncFailRes
	privateNumAssign targSlot $1
	
	publicVarAssign fatal uutSlotNum $(readDB $targSlot --slot-num)
	publicVarAssign fatal uutPn $(readDB $targSlot --pn)
	publicVarAssign fatal uutTn $(readDB $targSlot --tn)
	publicVarAssign warn uutMac $(readDB $targSlot --mac)
	publicVarAssign fatal jobIDDB $(readDB $targSlot --job-id)
	publicVarAssign fatal dbID $(readDB 99 --db-id)
	publicNumAssign failRunsDB $(readDB $targSlot --fail-runs)
	publicNumAssign passRunsDB $(readDB $targSlot --pass-runs)
	publicNumAssign totalRunsDB $(readDB $targSlot --total-runs)
	publicNumAssign currentRunDB $(readDB $targSlot --current-run)
	publicNumAssign runsLeftDB $(readDB $targSlot --runs-left)

	echo -e "\n\n Closing slot job for slot $uutSlotNum"
	echo " Slot info:"
	echo "  PN: $uutPn"
	echo "  TN: $uutTn"
	echo "  MAC: $uutMac"
	echo "  JobID: $jobIDDB"
	echo "  DBID: $dbID"
	echo "  Total runs: $totalRunsDB"
	echo "  Failed runs: $failRunsDB"
	echo "  Runs left: $runsLeftDB"
	echo -e " --END--\n"

	echo "  Close the job?"
	closePrompt=("Yes" "No")
	case `select_opt "${closePrompt[@]}"` in
		0)
			echo "   Closing the job."
			changeSlotStatus $targSlot "CLOSED"
			echo "    Clearing runs left counter"
			writeDB $targSlot --runs-left=0
			updateSqlCounters $targSlot

			echo "    Syncing OneDrive logs"
			if [ $failRunsDB -gt 0 ]; then
				echo "    Job did fail, syncing FailLogs folder"
				sshCmd="/root/multiCard/onedriveSyncUtility.sh --lock-contents=$dbID --upload-path=\"LogStorage/FailLogs/$jobIDDB\" --retry-count=480 --retry-timeout=1"
			else
				echo "    Job did not fail, syncing JobStorage folder"
				sshCmd="/root/multiCard/onedriveSyncUtility.sh --lock-contents=$dbID --upload-path=\"LogStorage/JobStorage/$jobIDDB\" --retry-count=480 --retry-timeout=1"
			fi
			syncFailRes="$(sshSendCmd $syncSrvIp root "${sshCmd}")"
			echo "$cmdRes"
			syncFailRes=$(grep 'aborting onedrive sync.' <<<$syncFailRes)

			if [ ! -z "$syncFailRes" ]; then 
				echo "   Rolling back slot status to finalized, as the sync failed"
				changeSlotStatus $targSlot "FINALIZED" --rollback
			else
				if [ $failRunsDB -gt 0 ]; then
					echo "    Job did fail, sharing FailLogs folder"
					echo "    Creating share link"
					sshCmd='source /root/multiCard/arturLib.sh &>/dev/null; '"sharePathOnedrive /LogStorage/FailLogs/$jobIDDB"
				else
					echo "    Job did not fail, sharing JobStorage folder"
					sshCmd='source /root/multiCard/arturLib.sh &>/dev/null; '"sharePathOnedrive /LogStorage/JobStorage/$jobIDDB"
				fi
				cmdRes="$(sshSendCmd $syncSrvIp root "${sshCmd}")"
				echo "$cmdRes"
				shareLink=$(echo -n "$cmdRes" |grep 'Created link:' |cut -d: -f2- | cut -c2- |grep http)
				if [ -z "$shareLink" ]; then
					critWarn "Unable to create shared link!"
					echo "   Rolling back slot status to finalized, as the sync failed"
					changeSlotStatus $targSlot "FINALIZED" --rollback
				else
					echo "    Share link: $shareLink"
					echo "    PN: $uutPn"
					echo "    TN: $uutTn"
					echo "    MAC: $uutMac"
					echo "    JobID: $jobIDDB"
					echo "    DBID: $dbID"
					echo "    Total runs: $totalRunsDB"
					echo "    Failed runs: $failRunsDB"
					echo "    Runs left: $runsLeftDB"
					echo "  Remove slot job from DB?"
					case `select_opt "${closePrompt[@]}"` in
						0) 
							changeSlotStatus $targSlot "REMOVED"
							clearSlotDB $targSlot
						;;
						1) ;;
						*) except "closePrompt for clear slot unknown exception" 
					esac
				fi
			fi

			echo "   Done."
		;;
		1)
		
		;;
		*) except "closePrompt unknown exception" 
	esac
	echo "   Done."
}

createSlotJob() {
	local targSlot totalRunsTrg testSel randHexLong dbID queueLogPathFull globalLogPathFull slotNum testResDB
	privateNumAssign targSlot $1
	echo " Creating new job for slot $(readDB $targSlot --slot-num)"
	echo -e -n "  Enter PN: "
	read -r pnInput
	pnInput=$(echo -n $pnInput|cut -d'#' -f2-)
	if [[ " ${pnArr[*]} " =~ " ${pnInput} " ]]; then
		echo -e "  PN: $pnInput - ok."
		getTracking
		case "$?" in
			0) echo -e "  TN: $trackNum - ok." ;;
			1) except "Incorrect tracking number ($trackNum)" ;;
			2) except "Empty tracking number" ;;
			*) except "Get tracking unknown exception" 
		esac
		echo -e -n "  Enter first MAC address: "; read -r macInput
		verifyMac $macInput
		echo -e "  Select test:"
		testOptions=("PCI tests" "Dump test" "BP Test" "Data Rate test" "Traffic test" "PCI + Traffic test")
		case `select_opt "${testOptions[@]}"` in
			0) testSel="pciTest";;
			1) testSel="dumpTest";;
			2) testSel="bpTest";;
			3) testSel="drateTest";;
			4) testSel="trfTest";;
			5) testSel="pciTrfTest";;
			*) except "Select test unknown exception" 
		esac
		acquireVal "Total runs" totalRunsTrg totalRunsTrg
		checkIfNumber $totalRunsTrg
		if [ $totalRunsTrg -lt 0 ]; then
			except "Selected test count cant be less than zero" 
		fi
		writeDB $targSlot --pn="$pnInput"
		writeDB $targSlot --tn="$trackNum"
		writeDB $targSlot --mac="$macInput"
		writeDB $targSlot --pci-test="$testSel"
		# writeDB $targSlot --test-result="READY"
		writeDB $targSlot --runs-left=$totalRunsTrg
		randHexLong=$(xxd -u -l 16 -p /dev/urandom)
		writeDB $targSlot --job-id=$randHexLong
		privateVarAssign "${FUNCNAME[0]}" dbID $(readDB 99 --db-id)
		privateVarAssign "${FUNCNAME[0]}" slotNum $(readDB $targSlot --slot-num)

		writeSQLDB "$randHexLong" --add-job --TN=$trackNum --PN=$pnInput --MAC=$macInput --srvHexID=$dbID --slotNum=$slotNum --totalRuns=$totalRunsTrg
		changeSlotStatus $targSlot "READY"
	else
		echo "DEBUG: pnArr: ${pnArr[*]} "
		echo "DEBUG: pnInput=${pnInput}"
		except "PN: $pnInput is not in allowed PN list."
	fi

	
}

changeSlotStatus() {
	local targSlotIdx slotNum dbID testResDB queueLogPathFull globalLogPathFull
	local uutPn uutTn macDB passRunsDB failRunsDB totalRunsDB runsLeftDB jobIDDB
	privateNumAssign targSlotIdx $1
	privateVarAssign "${FUNCNAME[0]}" targetStatus "$2"
	rollbackStatus=$3

	case "$targetStatus" in 
		"READY"|"STARTED"|"ENDED"|"FINALIZED"|"CLOSED"|"REMOVED")
			echo "  Changing slot to status: $targetStatus"
			writeDB $targSlotIdx --test-result="$targetStatus"
			loadCfg
			publicVarAssign fatal uutPn $(readDB $targSlotIdx --pn)
			publicVarAssign fatal uutTn $(readDB $targSlotIdx --tn)
			publicVarAssign warn macDB $(readDB $targSlotIdx --mac)
			publicNumAssign passRunsDB $(readDB $targSlotIdx --pass-runs)
			publicNumAssign failRunsDB $(readDB $targSlotIdx --fail-runs)
			publicNumAssign totalRunsDB $(readDB $targSlotIdx --total-runs)
			publicNumAssign runsLeftDB $(readDB $targSlotIdx --runs-left)
			publicVarAssign warn jobIDDB $(readDB $targSlotIdx --job-id)
			publicVarAssign fatal slotNum $(readDB $targSlotIdx --slot-num)
			publicVarAssign fatal dbID $(readDB 99 --db-id)
			publicVarAssign fatal testResDB $(readDB $targSlotIdx --test-result)
			publicVarAssign fatal queueLogPathFull "/tmp/$dbID.csvDB"
			publicVarAssign fatal globalLogPathFull "/root/multiCard/LogStorage/GlobalLogs/$(readDB $targSlotIdx --global-log)"
			writeSQLDB "$jobIDDB" --update-job-status --status=$targetStatus
			if [ -z "$rollbackStatus" ]; then
				echo "$jobIDDB;$uutPn;$uutTn;$slotNum;STATUS_CHANGE;$testResDB;$passRunsDB;$failRunsDB;$runsLeftDB;;;;;$dbID;$macDB" 2>&1 |& tee -a "$globalLogPathFull" "$queueLogPathFull" >/dev/null
				uploadLogSyncServer $syncSrvIp "$globalLogPathFull" "GlobalLogs"
				if [ -e "$queueLogPathFull" ]; then
					sshSendCmdNohup $syncSrvIp $syncSrvUser '/root/multiCard/sheetsSyncUtility.sh'
					# uploadQueueSyncServer $syncSrvIp "$queueLogPathFull"
					echo "  Clearing queue log"; rm -f $queueLogPathFull 2>&1 > /dev/null
				fi
			else
				echo "  Rollback mode, sheets update and sync are disabled"
			fi
		;;
		*) critWarn "   unexpected targetStatus value: $targetStatus, skipping";;
	esac
}

function checkSlotJobShort () {
	local slotIdx pciTestDB pnDB tnDB exitStatus linkTestDB failRunsDB totalRunsDB runsLeftDB testResultDB testResMsg
	privateNumAssign "slotIdx" "$1"
	exitStatus=1
	if [[ ! -z "${slotMatrix[$slotIdx,1]}" ]]; then 
		exitStatus=0
		pnDB=$(readDB $slotIdx --pn)
		tnDB=$(readDB $slotIdx --tn)
		pciTestDB=$(readDB $slotIdx --pci-test)
		linkTestDB=$(readDB $slotIdx --link-test)
		testResultDB=$(readDB $slotIdx --test-result)
		failRunsDB=$(readDB $slotIdx --fail-runs)
		totalRunsDB=$(readDB $slotIdx --total-runs)
		runsLeftDB=$(readDB $slotIdx --runs-left)

		case "$testResultDB" in 
			"null")	testResMsg="$rd$testResultDB$ec";;
			"READY") testResMsg="$yl$testResultDB$ec";;
			"STARTED") testResMsg="$gr$testResultDB$ec";;
			"ENDED") testResMsg="$yl$testResultDB$ec";;
			"FINALIZED") testResMsg="$gr$testResultDB$ec";;
			"CLOSED") testResMsg="$gr$testResultDB$ec";;
			"REMOVED") testResMsg="$gr$testResultDB$ec";;
			*) critWarn "   unexpected testResultDB value: $testResultDB, skipping";;
		esac

		echo "    PN: $pnDB    TN: $tnDB   Total runs: $totalRunsDB   Fail runs: $failRunsDB  Runs left: $runsLeftDB"
		echo -e "    PCI Test required: $pciTestDB    Link Test required: $linkTestDB   Test status: $testResMsg"
	else
		warn "   No jobs."
	fi
	return $exitStatus
}

function verifySlotData () {
	local slotIdx pciTestDB pnDB tnDB macDB exitStatus linkTestDB macInput testResultDB
	privateNumAssign "slotIdx" "$1"
	let exitStatus=0
	if [ -z "$noVerify" ]; then
		echo "   Verify of the slot required.."
		echo -e -n "  Enter PN: "
		read -r pnInput
		pnInput=$(echo -n $pnInput|cut -d'#' -f2-)
		if [[ " ${pnArr[*]} " =~ " ${pnInput} " ]]; then
			echo -e "  PN: $pnInput - ok."
			getTracking
			case "$?" in
				0) echo -e "  TN: $trackNum - ok." ;;
				1) except "Incorrect tracking number ($trackNum)" ;;
				2) except "Empty tracking number" ;;
				*) except "Get tracking unknown exception" 
			esac
			echo -e -n "  Enter first MAC address: "; read -r macInput
			verifyMac $macInput
		fi
		if [[ ! -z "${slotMatrix[$slotIdx,1]}" ]]; then 
			testResultDB=$(readDB $slotIdx --test-result)
			pnDB=$(readDB $slotIdx --pn)
			tnDB=$(readDB $slotIdx --tn)
			macDB=$(readDB $slotIdx --mac)
			if ! [ "$pnInput" = "$pnDB" ]; then let exitStatus++; echo "    PN: FAIL"; else echo "    PN: $pnInput - OK"; fi
			if ! [ "$trackNum" = "$tnDB" ]; then let exitStatus++; echo "    TN: FAIL"; else echo "    TN: $trackNum - OK"; fi
			if ! [ "$macInput" = "$macDB" ]; then let exitStatus++; echo "    MAC: FAIL"; else echo "    MAC: $macInput - OK"; fi
			echo "   Done."
		else
			let exitStatus++
			warn "   No jobs."
		fi
	fi
	return $exitStatus
}

function checkSlotJob () {
	local slotIdx pciTestDB pnDB exitStatus linkTestDB
	privateNumAssign "slotIdx" "$1"
	exitStatus=1
	echo "   Checking jobs.."
	if [[ ! -z "${slotMatrix[$slotIdx,1]}" ]]; then 
		exitStatus=0
		pnDB=$(readDB $slotIdx --pn)
		pciTestDB=$(readDB $slotIdx --pci-test)
		linkTestDB=$(readDB $slotIdx --link-test)

		echo "    PN: $pnDB"
		echo "    PCI Test required: $pciTestDB"
		echo "    Link Test required: $linkTestDB"
		echo "   Done."
	else
		warn "   No jobs."
	fi
	return $exitStatus
}

printSlotTestsStatus() {
	local slotIdx pciTestDB pnDB
	privateNumAssign "slotIdx" "$1"

	echo "   Checking tests status.."
	if [[ ! -z "$(readDB $slotIdx --pn)" ]]; then 
		testStartDB=$(readDB $slotIdx --test-start)
		testEndDB=$(readDB $slotIdx --test-end)
		#	Ready, Started, Ended, Finalized, Closed
		testResultDB=$(readDB $slotIdx --test-result)
		passRunsDB=$(readDB $slotIdx --pass-runs)
		failRunsDB=$(readDB $slotIdx --fail-runs)
		totalRunsDB=$(readDB $slotIdx --total-runs)
		currentRunDB=$(readDB $slotIdx --current-run)
		runsLeftDB=$(readDB $slotIdx --runs-left)
		jobIDDB=$(readDB $slotIdx --job-id)
		
		echo "    Test started: $testStartDB"
		echo "    Test ended: $testEndDB"
		echo "    Test result: $testResultDB"
		echo "    Passed runs: $passRunsDB"
		echo "    Failed runs: $failRunsDB"
		echo "    Total runs: $totalRunsDB"
		echo "    Current run: $currentRunDB"
		echo "    Runs left: $runsLeftDB"
		echo "    Job ID: $jobIDDB"
	fi
	echo "   Done."
}

checkJobStatesInfo() {
	local slotCounter rebootRequired
	loadCfg $jobDBPath
	for ((slotCounter=0;slotCounter<=$maxSlots;slotCounter++))
	do
		echo -e "\n  ========"
		echo -e "   Slot $(readDB $slotCounter --slot-num)    "
		echo -e "  ========"
		checkSlotJobShort $slotCounter
	done
	echo -e "\n"
}

checkJobStates() {
	local slotCounter rebootRequired dbID testResultDB verifySlotRes
	loadCfg $jobDBPath
	publicVarAssign fatal dbID $(readDB 99 --db-id)
	publicVarAssign fatal queueLogPathFull "/tmp/$dbID.csvDB"
	addSQLLogRecord $syncSrvIp $dbID --cycle-started
	echo "  Clearing queue log"; rm -f $queueLogPathFull 2>&1 > /dev/null
	echo -e "  Checking jobs for all slots.."
	for ((slotCounter=0;slotCounter<=$maxSlots;slotCounter++))
	do
		echo -e "\n  ========"
		echo -e "   Slot $(readDB $slotCounter --slot-num)    "
		echo -e "  ========"
		checkSlotJob $slotCounter
		if [ $? -eq 0 ]; then printSlotTestsStatus $slotCounter; fi
		if [ ! -z "$(readDB $slotCounter --pn)" ]; then
			publicVarAssign fatal testResultDB "$(readDB $slotCounter --test-result)"
			case "$testResultDB" in 
				"null")	warn "   Job test result is unset, skipping";;
				"READY") jobReadyLoop ;;
				"STARTED")
					if ! [ "$(readDB $slotCounter --runs-left)" = "0" ]; then
						startSlotJob $slotCounter
						rebootRequired=1
					else
						if [ "$testResultDB" = "STARTED" ]; then 
							changeSlotStatus $slotCounter "ENDED"
						fi
						warn "   No runs left, skipping"
					fi
				;;
				"ENDED") warn "   Job has ended, skipping";;
				"FINALIZED") warn "   Job is finalized, skipping";;
				"CLOSED") warn "   Job is closed, skipping";;
				"REMOVED") warn "   Job is removed, skipping"; clearSlotDB $slotCounter;;
				*) critWarn "   unexpected testResultDB value: $testResultDB, skipping";;
			esac
		fi
	done
	addSQLLogRecord $syncSrvIp $dbID --cycle-ended
	if [ -e "$queueLogPathFull" ]; then
		sshSendCmdNohup $syncSrvIp $syncSrvUser '/root/multiCard/sheetsSyncUtility.sh'
		# uploadSQLToSheetSyncServer $syncSrvIp "/tmp/SQL_$dbID.csvDB"
		# uploadQueueSyncServer $syncSrvIp "$queueLogPathFull"
	fi
	checkHWkey
	if [ $? -eq 0 ]; then 
		if [ -z "$noReboot" ]; then 
			if [ ! -z "$rebootRequired" ]; then
				local sshIPDB sshUserDB ipmiIPDB ipmiUserDB ipmiPassDB

				publicVarAssign fatal sshIPDB $(readDB 99 --ssh-ip)
				publicVarAssign fatal sshUserDB $(readDB 99 --ssh-user)
				publicVarAssign fatal ipmiIPDB $(readDB 99 --ipmi-ip)
				publicVarAssign fatal ipmiUserDB $(readDB 99 --ipmi-user)
				publicVarAssign fatal ipmiPassDB $(readDB 99 --ipmi-pass)
				countDownDelay 5 "  Sending request to reboot server ($rebootServerUser@$rebootServerIp) for a system reboot.."
				sshSendCmdNohup $rebootServerIp $rebootServerUser '/root/multiCard/rebootUtility.sh '"--ssh-ip=$sshIPDB --ssh-user=$sshUserDB --ipmi-ip=$ipmiIPDB --ipmi-user=$ipmiUserDB --ipmi-pass=$ipmiPassDB"
			else
				testEndLoop
			fi
		fi
	else
		testHaltLoop
	fi
}

verifySlot() {
	local testResultDB slotIdx
	privateNumAssign "slotIdx" "$1"
	privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotIdx --test-result)"
	case "$testResultDB" in 
		"null")	critWarn "   Job test result is unset, skipping";;
		"READY")
			echo "   Job is ready but needs to be verified."
			verifySlotData $slotIdx; let verifySlotRes=$?
			if [ $verifySlotRes -eq 0 ]; then 
				changeSlotStatus $slotIdx "STARTED"
				privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotIdx --test-result)"
			else
				critWarn "Slot verification failed."
			fi
		;;
		"STARTED") critWarn "   Job is already started, skipping";;
		"ENDED")
			echo "   Job has ended and needs to be verified."
			verifySlotData $slotIdx; let verifySlotRes=$?
			if [ $verifySlotRes -eq 0 ]; then 
				changeSlotStatus $slotIdx "FINALIZED"
				privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotIdx --test-result)"
			else
				critWarn "Slot verification failed."
			fi
		;;
		"FINALIZED") critWarn "   Job is finalized, skipping";;
		"CLOSED") critWarn "   Job is closed, skipping";;
		"REMOVED") clearSlotDB $slotIdx; critWarn "   Job is closed, skipping";;
		*) critWarn "   unexpected testResultDB value: $testResultDB, skipping";;
	esac
}

startSlotJob() {
	local slotIdx pciTestDB linkTestDB macDB uutSlotNum logPath uutPn uutTn randHex currentRunDB slotLogPath testRes slotLogPathFull
	local logCleanup debugInfoPath debugInfoPathFull randHexLong dbID
	privateNumAssign "slotIdx" "$1"

	echo "   Starting jobs for slot $(readDB $slotIdx --slot-num), runs left: $(readDB $slotCounter --runs-left)"

	publicVarAssign fatal uutSlotNum $(readDB $slotIdx --slot-num)
	publicVarAssign fatal uutPn $(readDB $slotIdx --pn)
	publicVarAssign fatal uutTn $(readDB $slotIdx --tn)
	publicVarAssign warn macDB $(readDB $slotIdx --mac)
	publicVarAssign fatal pciTestDB $(readDB $slotIdx --pci-test)
	publicVarAssign fatal linkTestDB $(readDB $slotIdx --link-test)

	publicVarAssign fatal testStartDB $(readDB $slotIdx --test-start)
	publicVarAssign fatal testEndDB $(readDB $slotIdx --test-end)
	publicVarAssign fatal testResultDB $(readDB $slotIdx --test-result)
	publicNumAssign passRunsDB $(readDB $slotIdx --pass-runs)
	publicNumAssign failRunsDB $(readDB $slotIdx --fail-runs)
	publicNumAssign totalRunsDB $(readDB $slotIdx --total-runs)
	publicNumAssign currentRunDB $(readDB $slotIdx --current-run)
	publicNumAssign runsLeftDB $(readDB $slotIdx --runs-left)
	publicVarAssign warn totalLogDB $(readDB $slotIdx --total-log)
	publicVarAssign fatal jobIDDB $(readDB $slotIdx --job-id)
	dbID=$(readDB 99 --db-id)

	writeDB $slotIdx --test-start=1
	let currentRunDB=$(($currentRunDB+1))
	writeDB $slotIdx --current-run=$currentRunDB
	let runsLeftDB=$(($runsLeftDB-1))
	writeDB $slotIdx --runs-left=$runsLeftDB

	critWarn --sil "SORT OUT proper log path determination"
	randHex=$(xxd -u -l 4 -p /dev/urandom)
	# logPath="/root/multiCard/$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'$randHex.log

	addSQLLogRecord $syncSrvIp $jobIDDB --run-started

	logPath="$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'$jobIDDB.log
	echo -e -n "  Creating job logs folder /root/multiCard/LogStorage/JobStorage/$jobIDDB: "; echoRes "mkdir -p /root/multiCard/LogStorage/JobStorage/$jobIDDB"
	publicVarAssign fatal logPathFull "/root/multiCard/LogStorage/JobStorage/$jobIDDB/$logPath"
	writeDB $slotIdx --last-run-log=$logPath
	dmsg critWarn --sil "SORT OUT multiple tests selects in one argument"
	/root/multiCard/menu.sh --silent --uut-slot-num=$uutSlotNum --PN-choice=$uutPn --uut-pn=$uutPn --test-sel=$pciTestDB --noMasterMode --slDupSkp --ignore-dumps-fail --minor-launch 2>&1 |& tee $logPathFull
	
	echo "  Clening up log from excess symbols"
	logCleanup=$(cat $logPathFull | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' 2>&1)
	if [ -z "$logCleanup" ]; then
		inform "  Log cleanup result is empty, retrying.."
		logCleanup=$(cat $logPathFull | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' 2>&1)
		if [ -z "$logCleanup" ]; then
			inform "  Log cleanup result is empty, skipping."
		else
			echo "  Log cleanup ok, rewriting log file"
			echo "$logCleanup" &> $logPathFull
		fi
	else
		echo "  Log cleanup ok, rewriting log file"
		echo "$logCleanup" &> $logPathFull
	fi
	# cat $logPathFull | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' 2>&1 |& tee $logPathFull > /dev/null
	
	if [ -z "$(readDB $slotIdx --total-log)" ]; then
		echo "  Total log does not exist, creating."
		publicVarAssign fatal slotLogPath "$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"TOTAL-LOG_"$jobIDDB.log
		writeDB $slotIdx --total-log=$slotLogPath
	else
		publicVarAssign fatal slotLogPathFull "/root/multiCard/LogStorage/JobStorage/$jobIDDB/$(readDB $slotIdx --total-log)"
		echo "  Checking total log path: $slotLogPathFull"
		if ! [ -e "$slotLogPathFull" ]; then
			echo "  Total log path is non-existent, recreating."
			publicVarAssign fatal slotLogPath "$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"TOTAL-LOG_"$jobIDDB.log
			writeDB $slotIdx --total-log=$slotLogPath
		fi
	fi

	publicVarAssign fatal globalLogPathFull "/root/multiCard/LogStorage/GlobalLogs/$(readDB $slotIdx --global-log)"

	let totalRunsDB=$(($totalRunsDB+1))
	writeDB $slotIdx --total-runs=$totalRunsDB

	slotLogPathFull="/root/multiCard/LogStorage/JobStorage/$jobIDDB/$(readDB $slotIdx --total-log)"
	dmsg echo "TOTAL LOG: $slotLogPathFull"

	testRes="$(cat $logPathFull |grep "Total Summary: ALL TESTS PASSED")"
	echo -n "  Appending log: "
	if [ -z "$testRes" ]; then
		let failRunsDB=$(($failRunsDB+1))
		writeDB $slotIdx --fail-runs=$failRunsDB
		testResVerb="FAILED"
		if [ -z "$noDebug" ]; then
			debugInfoPath="$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'debugInfo.log
			publicVarAssign fatal debugInfoPathFull "/root/multiCard/LogStorage/JobStorage/$jobIDDB/$debugInfoPath"
			getDebugInfo 2>&1 |& tee $debugInfoPathFull
		fi
	else
		let passRunsDB=$(($passRunsDB+1))
		writeDB $slotIdx --pass-runs=$passRunsDB
		testResVerb="PASSED"
	fi

	updateSqlCounters $slotIdx

	echo "Run: $currentRunDB, Test result: $testResVerb, Passed runs: $passRunsDB, Failed runs: $failRunsDB, Runs left: $runsLeftDB" 2>&1 |tee -a "$slotLogPathFull"
	
	if [ "$pciTestDB" = "lisbonPciTest" ]; then
		unset thermalDataCsv
		unset logCleanup
		thermLogPath=/root/multiCard/LogStorage/JobStorage/$jobIDDB/$(xxd -u -l 16 -p /dev/urandom).log
		/root/multiCard/menu.sh --uut-slot-num=$uutSlotNum --PN-choice=$uutPn --uut-pn=$uutPn --test-sel=thermalData --noMasterMode --slDupSkp --ignore-dumps-fail --minor-launch 2>&1 |& tee $thermLogPath
		thermalDataCsv=$(cat $thermLogPath |grep -m1 'thermalDataCsv=' |cut -d= -f2)
		echo "  Thermal data: $thermalDataCsv"
		echo "  Clening up log from excess symbols"
		logCleanup=$(cat $thermLogPath | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' 2>&1)
		if [ -z "$logCleanup" ]; then
			inform "  Log cleanup result is empty, retrying.."
			logCleanup=$(cat $thermLogPath | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' 2>&1)
			if [ -z "$logCleanup" ]; then
				inform "  Log cleanup result is empty, skipping."
			else
				echo "  Log cleanup ok, rewriting thermal log file"
				echo "$logCleanup" &> $thermLogPath
			fi
		else
			echo "  Log cleanup ok, rewriting log file"
			echo "$logCleanup" &> $thermLogPath
		fi

		echo -e "\n\n\tTHERMAL LOG START:\n" &>> $logPathFull
		cat "$thermLogPath" &>> $logPathFull
		rm -f "$thermLogPath"
		echo "$jobIDDB;$uutPn;$uutTn;$uutSlotNum;$currentRunDB;$testResVerb;$passRunsDB;$failRunsDB;$runsLeftDB;$thermalDataCsv;$dbID;$macDB" 2>&1 |& tee -a "$globalLogPathFull" "$queueLogPathFull" >/dev/null
	else
		echo "$jobIDDB;$uutPn;$uutTn;$uutSlotNum;$currentRunDB;$testResVerb;$passRunsDB;$failRunsDB;$runsLeftDB;;;;;$dbID;$macDB" 2>&1 |& tee -a "$globalLogPathFull" "$queueLogPathFull" >/dev/null
	fi 
	addSQLLogRecord $syncSrvIp $jobIDDB --run-ended
	if [ -z "$globalLogPathFull" ]; then
		critWarn "globalLogPathFull path in unknown, skipping upload"
	else
		uploadLogSyncServer $syncSrvIp "$logPathFull" "JobStorage/$jobIDDB"
		uploadLogSyncServer $syncSrvIp "$slotLogPathFull" "JobStorage/$jobIDDB"
		uploadLogSyncServer $syncSrvIp "$globalLogPathFull" "GlobalLogs"
		echo "  Sending OneDrive sync request to sync JobStorage and GlobalLogs on server: $syncSrvIp"
		sshSendCmdNohup $syncSrvIp $syncSrvUser "/root/multiCard/onedriveSyncUtility.sh --lock-contents=$dbID --upload-path=\"LogStorage/JobStorage/$jobIDDB\" --retry-count=480 --retry-timeout=1"
		sshSendCmdNohup $syncSrvIp $syncSrvUser "/root/multiCard/onedriveSyncUtility.sh --lock-contents=$dbID --upload-path=\"LogStorage/GlobalLogs\" --retry-count=480 --retry-timeout=1"
		if [ ! -z "$debugInfoPathFull" ]; then 
			addSQLLogRecord $syncSrvIp $jobIDDB --run-failed
			sendAlert 'Run failed!'"\nJob: $jobIDDB\nPN: $uutPn\nTN: $uutTn\nRun result: $testResVerb\nRuns left: $runsLeftDB"
			uploadLogSyncServer $syncSrvIp "$debugInfoPathFull" "JobStorage/$jobIDDB"
			uploadLogSyncServer $syncSrvIp "$logPathFull" "FailLogs/$jobIDDB"
			uploadLogSyncServer $syncSrvIp "$slotLogPathFull" "FailLogs/$jobIDDB"
			uploadLogSyncServer $syncSrvIp "$debugInfoPathFull" "FailLogs/$jobIDDB"
			uploadLogSyncServer $syncSrvIp "$globalLogPathFull" "FailLogs/$jobIDDB"
			echo "  Sending OneDrive sync request to sync FailLogs on server: $syncSrvIp"
			sshSendCmdNohup $syncSrvIp $syncSrvUser "/root/multiCard/onedriveSyncUtility.sh --lock-contents=$dbID --upload-path=\"LogStorage/FailLogs/$jobIDDB\" --retry-count=480 --retry-timeout=1"
		else
			addSQLLogRecord $syncSrvIp $jobIDDB --run-passed
		fi
	fi

	echo "   Returned to the caller, func: ${FUNCNAME[1]}"
}

updateSqlCounters() {
	local slotIdx
	local passRunsDB failRunsDB totalRunsDB currentRunDB runsLeftDB jobHexIDDB
	privateNumAssign "slotIdx" "$1"
	publicVarAssign fatal jobHexIDDB $(readDB $slotIdx --job-id)
	publicNumAssign passRunsDB $(readDB $slotIdx --pass-runs)
	publicNumAssign failRunsDB $(readDB $slotIdx --fail-runs)
	publicNumAssign totalRunsDB $(readDB $slotIdx --total-runs)
	publicNumAssign currentRunDB $(readDB $slotIdx --current-run)
	publicNumAssign runsLeftDB $(readDB $slotIdx --runs-left)
	writeSQLDB "$jobHexIDDB" --update-job-counters --totalRuns=$totalRunsDB --currentRun=$currentRunDB --runsLeft=$runsLeftDB --passedRuns=$passRunsDB --failedRuns=$failRunsDB
	sshSendCmdNohup $syncSrvIp $syncSrvUser '/root/multiCard/sheetsSyncUtility.sh'
}

failRun() {
	local failDesc
	privateVarAssign "${FUNCNAME[0]}" "failDesc" "$1"
	echo -ne "\n   "
	critWarn "PLACEHOLDER, RUN FAILED: $failDesc"
	exit
}

finishRun() {
	critwarn "unfinished"
}

testHaltLoop() {
	sshSendCmdNohup $syncSrvIp $syncSrvUser '/root/multiCard/sheetsSyncUtility.sh'
	echo -ne "\r\n"
	while true; do
		printf '\e[A\e[K'
		beepSpk headsUp
		countDownDelay 20 "  Test stopped, because HW key is present.."
		sleep 1
		checkHWkey
		if [ $? -eq 0 ]; then 
			reboot
		fi
	done
}

testEndLoop() {
	sshSendCmdNohup $syncSrvIp $syncSrvUser '/root/multiCard/sheetsSyncUtility.sh'
	echo -ne "\r\n"
	while true; do
		printf '\e[A\e[K'
		beepSpk headsUp
		countDownDelay 90 "  Waiting for operator acknowlegment of the end of the test.."
		sleep 1
	done
}

jobReadyLoop() {
	local readySlots slotCounter testResultDB
	sshSendCmdNohup $syncSrvIp $syncSrvUser '/root/multiCard/sheetsSyncUtility.sh'
	echo "  There are slots in state READY.. Waiting for user"
	for ((slotCounter=0;slotCounter<=$maxSlots;slotCounter++))
	do
		if [ ! -z "$(readDB $slotCounter --pn)" ]; then
			privateVarAssign "${FUNCNAME[0]}" testResultDB "$(readDB $slotCounter --test-result)"
			if [ "$testResultDB" = "READY" ]; then
				readySlots+=($(readDB $slotCounter --slot-num))
			fi
		fi
	done


	echo -ne "\r\n"
	while true; do
		printf '\e[A\e[K'
		beepSpk warnHeadsUp
		blinkAllEthOnSlotList ${readySlots[@]} > /dev/null 2>&1
		blinkAllEthOnSlotList ${readySlots[@]} > /dev/null 2>&1
		blinkAllEthOnSlotList ${readySlots[@]} > /dev/null 2>&1
		sleep 2
		printf '\e[A\e[K'
		countDownDelay 10 "  Waiting for operator to confirm data enter of the slot.."
		sleep 1
	done
}

getCsvValues() {
	local testResReq slotReq tnReq jobIDReq filePath
	local testRes
	if [ -z "$*" ]; then except "input args are undefined"; fi
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		case "$KEY" in
			test-result) 	testResReq=${VALUE} ;;
			slot) 			slotReq=${VALUE} ;;
			tn) 			tnReq=${VALUE} ;;
			job-id) 		jobIDReq=${VALUE} ;;
			file-path)		
				filePath=${VALUE} 
				testFileExist "$filePath"
			;;
			*) except "Unknown DB key: $ARG"
		esac
	done

	while read -r line
	do
		if [ ! -z "$testResReq" ]; then testRes=$(echo -n $line |cut -d';' -f6); fi
		if [ ! -z "$slotReq" ]; then testRes=$(echo -n $line |cut -d';' -f4); fi
		if [ ! -z "$tnReq" ]; then testRes=$(echo -n $line |cut -d';' -f3); fi
		if [ ! -z "$jobIDReq" ]; then testRes=$(echo -n $line |cut -d';' -f1); fi
	done < "$filePath"
}

binPathSetup() {
	if [[ ! -e "/bin/bootLauncher" ]]; then 
		echo "  Seting up symlink to bin"
		ln -s "/root/multiCard/bootLauncher.sh" "/bin/bootLauncher"
	else
		echo "  Skipping symlink setup, already set up"
	fi
}

checkHWkey() {
	local usbAddr retRes dmesgSerial
	let retRes=0
	usbAddr=$(grep PRODUCT /sys/bus/usb/devices/*/uevent |grep -m1 '781/5597' |cut -d/ -f6 |cut -d: -f1)
	if [ ! -z "$usbAddr" ]; then
		dmesgSerial=$(dmesg |grep "$usbAddr" |grep SerialNumber: |cut -d: -f3 |awk '$1=$1')	
		if [[ " ${hwKeySerialArr[*]} " =~ " ${dmesgSerial} " ]]; then
			let retRes++
		fi
	fi
	return $retRes
}

sendAlert() {
	local msgSend
	privateVarAssign "${FUNCNAME[0]}" "msgSend" "$*"
	sendTgMsg $syncSrvIp "smbLogs/.tg" "/root/tg_tmp" "$msgSend"
}



export MC_SCRIPT_PATH=/root/multiCard
source ${MC_SCRIPT_PATH}/arturLib.sh; let loadStatus+=$?
source ${MC_SCRIPT_PATH}/graphicsLib.sh; let loadStatus+=$?
source ${MC_SCRIPT_PATH}/sqlLib.sh; let loadStatus+=$?

if [[ ! "$loadStatus" = "0" ]]; then 
	echo -e "\t\e[0;31mLIBRARIES ARE NOT LOADED! UNABLE TO PROCEED\n\e[m"
	exit 1
else
	if (return 0 2>/dev/null) ; then
		echo -e '  Loaded module: \tbootLauncher (support: arturd@silicom.co.il)'
		testFileExist "/root/multiCard/sfpLinkTest.sh"
		setEmptyDefaults
		declareVars
	else	
		echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
		trap "exit 1" 10
		PROC="$$"
		testFileExist "${MC_SCRIPT_PATH}/sfpLinkTest.sh"
		binPathSetup
		setEmptyDefaults
		loadCfg
		declareVars
		echoHeader "$toolName" "$ver"
		echoSection "Startup.."
		parseArgs "$@"
		startupInit
		main "$@"
	fi
fi