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
				echo -e "sep=;\nJobID;PN;TN;Slot;CurrentRun;TestResult;PassedRuns;FailedRuns;RunsLeft;Temp1;Temp2;Temp3;Temp4" 2>&1 |& tee -a "$logPath" >/dev/null
			else
				critWarn "log: $logPath exists and is corrupted or formatted wrong"
			fi
		else
			echo "validated, not empty"
		fi
	else
		echo "non existent, created."
		echo -e "sep=;\nJobID;PN;TN;Slot;CurrentRun;TestResult;PassedRuns;FailedRuns;RunsLeft;Temp1;Temp2;Temp3;Temp4" 2>&1 |& tee -a "$logPath" >/dev/null
	fi
}

loadCfg() {
	local cfgPath srcRes cfgPathArg dbID randHexLong idx globalLogName globalLogPath
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
						for ((idx=0;idx<=5;idx++)); do 
							echo -n "    Slot $(($idx+1)): "
							globalLogName=$(readDB $idx --global-log)
							if [ -z "$globalLogName" ]; then
								critWarn "NULL"
							else
								mkdir -p /root/multiCard/LogStorage &> /dev/null
								if [ "$globalLogName" = "GLOBAL-LOG.csv" ]; then
									echo -n "not set, setting: "
									globalLogName=$(echo -n "$globalLogName" |cut -d. -f1)_$dbID.csvDB
									writeDB $idx --global-log=$globalLogName
									echo -n "$(readDB $idx --global-log). Contents: "
									privateVarAssign "${FUNCNAME[0]}" "globalLogPath" "/root/multiCard/LogStorage/$globalLogName"
									createGlobalLog $globalLogPath
								else
									echo -n "set, validating: "
									if [ ! -z "$(echo -n $globalLogName |grep $dbID)" ]; then
										echo -n "validated. Contents: "
										privateVarAssign "${FUNCNAME[0]}" "globalLogPath" "/root/multiCard/LogStorage/$globalLogName"
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
			warn "Invalid, empty file, skipping"
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
	loadCfg $jobDBPath
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
	# getTracking
	# createLog
	if [ ! -z "$autostartMode" ]; then
		checkJobStates
	else
		echo -e "\n  Select action:"
		options=("Create or manage job" "Close job" "Normal startup")
		case `select_opt "${options[@]}"` in
			0) jobCreate=1;;
			1) closeJobsLoop;;
			2) defStartup=1;;
			*) except "Unknown action";;
		esac
		if [ ! -z "$jobCreate" ]; then
			echoSection "Job creation"
			createJobsLoop
		fi
		if [ ! -z "$defStartup" ]; then
			checkJobStates 
		fi
	fi
	# uploadLog
}

readDB() {
	local slotIdx resPrint
	privateNumAssign "slotIdx" "$1"; shift
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		case "$KEY" in
			db-id)			resPrint=${slotMatrix[$slotIdx,99]} ;;
			slot-num) 		resPrint=${slotMatrix[$slotIdx,0]} ;;
			pn) 			resPrint=${slotMatrix[$slotIdx,1]} ;;
			tn) 			resPrint=${slotMatrix[$slotIdx,2]} ;;
			pci-test) 		resPrint=${slotMatrix[$slotIdx,3]} ;;
			link-test) 		resPrint=${slotMatrix[$slotIdx,4]} ;;
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


writeDB() {
	local slotIdx targLine KEY VALUE lockFilePath paramIdx
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
			pci-test) 		let paramIdx=3 ;;
			link-test) 		let paramIdx=4 ;;
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
		targLine="slotMatrix[$slotIdx,$paramIdx]"
		targLineMasked='slotMatrix\['$slotIdx','$paramIdx'\]'
		if [ -e "$lockFilePath" ]; then
			failRun "Unable to write to DB file, it is locked"
		else
			dmsg echo "  Locking DB"
			echo 1>$lockFilePath
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
}

clearSlotDB() {
	local slotArg
	slotArg=$1
	writeDB $slotArg --pn=""
	writeDB $slotArg --tn=""
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
}

clearAllDB() {
	local slotCounter
	echo "   Clearing all DB.."
	for ((slotCounter=0;slotCounter<=5;slotCounter++))
	do
		echo -e "\n  ========"
		echo -e "   Slot $(readDB $slotCounter --slot-num)    "
		clearSlotDB $slotCounter
		echo -e "  ========"
		echo -e "    Clearing.."
	done
	echo -e "   Done.\n\n"
}

function selectSlotForJob () {
	echo -e "\n  Select slot:"
	options=("Slot 1" "Slot 2" "Slot 3" "Slot 4" "Slot 5" "Slot 6" "Save and exit")
	return `select_opt "${options[@]}"`
}

createJobsLoop() {
	local slotSel
	while true
	do
		checkJobStatesInfo
		selectSlotForJob
		privateNumAssign slotSel $?
		if [ $slotSel -eq 6 ]; then exit; fi
		echo -e "\n  Select action:"
		options=("Add slot job" "Remove slot job" "Select different slot" "Clear all DB" "Save and exit")
		case `select_opt "${options[@]}"` in
			0) 
				echo "  Add slot job selected"
				clearSlotDB $slotSel
				createSlotJob $slotSel
			;;
			1) 
				echo "  Removing slot job on slot $(($slotSel+1))"
				clearSlotDB $slotSel 
			;;
			2) 
				echo "  Select different slot"
			;;
			3) 
				echo "  Clearing all DB"
				clearAllDB
			;;
			4) 
				echo "  Saving and exiting"
				exit
			;;
			*) except "Unknown action";;
		esac
	done
}

closeJobsLoop() {
	local slotSel
	while true
	do
		checkJobStatesInfo
		selectSlotForJob
		privateNumAssign slotSel $?
		if [ $slotSel -eq 6 ]; then exit; fi
		echo -e "\n  Select action:"
		options=("Close slot job" "Select different slot" "Save and exit")
		case `select_opt "${options[@]}"` in
			0) 
				echo "Closing slot job for slot $(($slotSel+1))"
				closeSlotJob $slotSel
			;;
			1) 
				echo "Select different slot"
			;;
			2) 
				echo "Saving and exiting.."
				exit
			;;
			*) except "Unknown action";;
		esac
	done
}

closeSlotJob() {
	local targSlot closePrompt shareLink cmdRes
	local uutSlotNum uutPn uutTn jobIDDB failRunsDB dbID totalRunsDB runsLeftDB
	privateNumAssign targSlot $1
	
	publicVarAssign fatal uutSlotNum $(readDB $targSlot --slot-num)
	publicVarAssign fatal uutPn $(readDB $targSlot --pn)
	publicVarAssign fatal uutTn $(readDB $targSlot --tn)
	publicVarAssign fatal jobIDDB $(readDB $targSlot --job-id)
	publicVarAssign fatal dbID $(readDB 99 --db-id)
	publicNumAssign failRunsDB $(readDB $targSlot --fail-runs)
	publicNumAssign totalRunsDB $(readDB $targSlot --total-runs)
	publicNumAssign runsLeftDB $(readDB $targSlot --runs-left)

	echo -e "\n\n Closing slot job for slot $uutSlotNum"
	echo " Slot info:"
	echo "  PN: $uutPn"
	echo "  TN: $uutTn"
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
			echo "    Clearing runs left counter"
			writeDB $targSlot --runs-left=0
			echo "    Syncing OneDrive logs"
			syncLogsOnedrive
			if [ $failRunsDB -gt 0 ]; then
				echo "    Job did fail, sharing FailLogs folder"
				shareLink=$(sharePathOnedrive "/LogStorage/FailLogs/$jobIDDB" |grep 'Created link:' |cut -d: -f2- | cut -c2- |grep http)
			else
				echo "    Job did not fail, sharing JobStorage folder"
				cmdRes="$(sharePathOnedrive "/LogStorage/JobStorage/$jobIDDB")"
				shareLink=$(echo -n "$cmdRes" |grep 'Created link:' |cut -d: -f2- | cut -c2- |grep http)
			fi
			if [ -z "$shareLink" ]; then
				critWarn "Unable to create shared link!"
				echo -e "Full log:\n$cmdRes"
			else
				echo "    Share link: $shareLink"
				echo "    PN: $uutPn"
				echo "    TN: $uutTn"
				echo "    JobID: $jobIDDB"
				echo "    DBID: $dbID"
				echo "    Total runs: $totalRunsDB"
				echo "    Failed runs: $failRunsDB"
				echo "    Runs left: $runsLeftDB"
				echo "  Clear slot job from DB?"
				case `select_opt "${closePrompt[@]}"` in
					0) clearSlotDB $targSlot;;
					1) ;;
					*) except "closePrompt for clear slot unknown exception" 
				esac
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
	local targSlot totalRunsTrg testSel randHexLong
	privateNumAssign targSlot $1
	echo " Creating new job for slot $(readDB $targSlot --slot-num)"
	echo -e -n "  Enter PN: "
	read -r pnInput
	if [[ " ${pnArr[*]} " =~ " ${pnInput} " ]]; then
		echo -e "  PN: $pnInput - ok."
		getTracking
		case "$?" in
			0) echo -e "  TN: $trackNum - ok." ;;
			1) except "Incorrect tracking number ($trackNum)" ;;
			2) except "Empty tracking number" ;;
			*) except "Get tracking unknown exception" 
		esac
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
		writeDB $targSlot --pci-test="$testSel"
		writeDB $targSlot --runs-left=$totalRunsTrg
		randHexLong=$(xxd -u -l 16 -p /dev/urandom)
		writeDB $targSlot --job-id=$randHexLong
	else
		echo "DEBUG: pnArr: ${pnArr[*]} "
		echo "DEBUG: pnInput=${pnInput}"
		except "PN: $pnInput is not in allowed PN list."
	fi

	
}

function checkSlotJobShort () {
	local slotIdx pciTestDB pnDB tnDB exitStatus linkTestDB failRunsDB totalRunsDB runsLeftDB
	privateNumAssign "slotIdx" "$1"
	exitStatus=1
	if [[ ! -z "${slotMatrix[$slotIdx,1]}" ]]; then 
		exitStatus=0
		pnDB=$(readDB $slotIdx --pn)
		tnDB=$(readDB $slotIdx --tn)
		pciTestDB=$(readDB $slotIdx --pci-test)
		linkTestDB=$(readDB $slotIdx --link-test)
		failRunsDB=$(readDB $slotIdx --fail-runs)
		totalRunsDB=$(readDB $slotIdx --total-runs)
		runsLeftDB=$(readDB $slotIdx --runs-left)

		echo "    PN: $pnDB    TN: $tnDB   Total runs: $totalRunsDB   Fail runs: $failRunsDB  Runs left: $runsLeftDB"
		echo "    PCI Test required: $pciTestDB    Link Test required: $linkTestDB"
	else
		warn "   No jobs."
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

checkSlotTestsStatus() {
	local slotIdx pciTestDB pnDB
	privateNumAssign "slotIdx" "$1"

	echo "   Checking tests status.."
	if [[ ! -z "$(readDB $slotIdx --pn)" ]]; then 
		testStartDB=$(readDB $slotIdx --test-start)
		testEndDB=$(readDB $slotIdx --test-end)
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
	for ((slotCounter=0;slotCounter<=5;slotCounter++))
	do
		echo -e "\n  ========"
		echo -e "   Slot $(readDB $slotCounter --slot-num)    "
		echo -e "  ========"
		checkSlotJobShort $slotCounter
	done
	echo -e "\n"
}

checkJobStates() {
	local slotCounter rebootRequired
	loadCfg $jobDBPath
	echo -e "  Checking jobs for all slots.."
	for ((slotCounter=0;slotCounter<=5;slotCounter++))
	do
		echo -e "\n  ========"
		echo -e "   Slot $(readDB $slotCounter --slot-num)    "
		echo -e "  ========"
		checkSlotJob $slotCounter
		if [ $? -eq 0 ]; then checkSlotTestsStatus $slotCounter; fi
		if [ ! -z "$(readDB $slotCounter --pn)" ]; then
			if ! [ "$(readDB $slotCounter --runs-left)" = "0" ]; then
				startSlotJob $slotCounter
				rebootRequired=1
			else
				warn "   No runs left, skipping"
			fi
		fi
	done
	if [ -z "$noReboot" ]; then 
		if [ ! -z "$rebootRequired" ]; then
			countDownDelay 5 "  Sending request to reboot server ($rebootServerUser@$rebootServerIp) for a system reboot.."
			sshSendCmdNohup $rebootServerIp $rebootServerUser '/root/multiCard/rebootUtility.sh --ssh-ip=172.30.7.24 --ssh-user=root --ipmi-ip=172.30.7.25 --ipmi-user=ADMIN --ipmi-pass=QLGADZQAWW'
		else
			testEndLoop
		fi
	fi
}

startSlotJob() {
	local slotIdx pciTestDB linkTestDB uutSlotNum logPath uutPn uutTn randHex currentRunDB slotLogPath testRes slotLogPathFull
	local logCleanup debugInfoPath debugInfoPathFull randHexLong dbID
	privateNumAssign "slotIdx" "$1"

	echo "   Starting jobs for slot $(readDB $slotIdx --slot-num), runs left: $(readDB $slotCounter --runs-left)"

	publicVarAssign fatal uutSlotNum $(readDB $slotIdx --slot-num)
	publicVarAssign fatal uutPn $(readDB $slotIdx --pn)
	publicVarAssign fatal uutTn $(readDB $slotIdx --tn)
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
	publicVarAssign warn jobIDDB $(readDB $slotIdx --job-id)
	dbID=$(readDB 99 --db-id)

	writeDB $slotIdx --test-start=1
	let currentRunDB=$(($currentRunDB+1))
	writeDB $slotIdx --current-run=$currentRunDB
	let runsLeftDB=$(($runsLeftDB-1))
	writeDB $slotIdx --runs-left=$runsLeftDB

	critWarn --sil "SORT OUT proper log path determination"
	randHex=$(xxd -u -l 4 -p /dev/urandom)
	# logPath="/root/multiCard/$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'$randHex.log
	
	if [ "$jobIDDB" = "0" ]; then unset jobIDDB; fi
	if [ -z "$jobIDDB" ]; then
		echo "  Job ID does not exist, creating..."
		randHexLong=$(xxd -u -l 16 -p /dev/urandom)
		writeDB $slotIdx --job-id=$randHexLong
		publicVarAssign fatal jobIDDB $(readDB $slotIdx --job-id)
	fi

	logPath="$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'$jobIDDB.log
	echo -e -n "  Creating job logs folder /root/multiCard/LogStorage/JobStorage/$jobIDDB: "; echoRes "mkdir -p /root/multiCard/LogStorage/JobStorage/$jobIDDB"
	publicVarAssign fatal logPathFull "/root/multiCard/LogStorage/JobStorage/$jobIDDB/$logPath"
	writeDB $slotIdx --last-run-log=$logPath
	critWarn --sil "SORT OUT multiple tests selects in one argument"
	/root/multiCard/menu.sh --uut-slot-num=$uutSlotNum --PN-choice=$uutPn --uut-pn=$uutPn --test-sel=$pciTestDB --noMasterMode --slDupSkp --minor-launch 2>&1 |& tee $logPathFull
	
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

	echo "Run: $currentRunDB, Test result: $testResVerb, Passed runs: $passRunsDB, Failed runs: $failRunsDB, Runs left: $runsLeftDB" 2>&1 |tee -a "$slotLogPathFull"
	
	if [ "$pciTestDB" = "lisbonPciTest" ]; then
		unset thermalDataCsv
		unset logCleanup
		thermLogPath=/root/multiCard/LogStorage/JobStorage/$jobIDDB/$(xxd -u -l 16 -p /dev/urandom).log
		/root/multiCard/menu.sh --uut-slot-num=$uutSlotNum --PN-choice=$uutPn --uut-pn=$uutPn --test-sel=thermalData --noMasterMode --slDupSkp --minor-launch 2>&1 |& tee $thermLogPath
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
		echo "$jobIDDB;$uutPn;$uutTn;$uutSlotNum;$currentRunDB;$testResVerb;$passRunsDB;$failRunsDB;$runsLeftDB;$thermalDataCsv" 2>&1 |& tee -a "$globalLogPathFull" >/dev/null
	else
		echo "$jobIDDB;$uutPn;$uutTn;$uutSlotNum;$currentRunDB;$testResVerb;$passRunsDB;$failRunsDB;$runsLeftDB;;;;;$dbID" 2>&1 |& tee -a "$globalLogPathFull" >/dev/null
	fi 
	if [ -z "$globalLogPathFull" ]; then
		warn "globalLogPathFull path in unknown, skipping upload"
	else
		uploadLogSmb 172.30.4.236 $logPathFull
		uploadLogSmb 172.30.4.236 $slotLogPathFull
		uploadLogSmb 172.30.4.236 $globalLogPathFull
		if [ ! -z "$debugInfoPathFull" ]; then 
			uploadLogSmb 172.30.4.236 $debugInfoPathFull
			uploadLogOnedrive "$logPathFull" "JobStorage/$jobIDDB" --no-sync
			uploadLogOnedrive "$slotLogPathFull" "JobStorage/$jobIDDB" --no-sync
			uploadLogOnedrive "$debugInfoPathFull" "JobStorage/$jobIDDB" --no-sync
			uploadLogOnedrive "$globalLogPathFull" "GlobalLogs" --no-sync

			uploadLogOnedrive "$logPathFull" "FailLogs/$jobIDDB" --no-sync
			uploadLogOnedrive "$slotLogPathFull" "FailLogs/$jobIDDB" --no-sync
			uploadLogOnedrive "$debugInfoPathFull" "FailLogs/$jobIDDB" --no-sync
			uploadLogOnedrive "$globalLogPathFull" "FailLogs/$jobIDDB"
		else
			uploadLogOnedrive "$logPathFull" "JobStorage/$jobIDDB" --no-sync
			uploadLogOnedrive "$slotLogPathFull" "JobStorage/$jobIDDB" --no-sync
			uploadLogOnedrive "$globalLogPathFull" "GlobalLogs" --no-sync
		fi
	fi

	echo "   Returned to the caller, func: ${FUNCNAME[1]}"
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

testEndLoop() {
	echo -ne "\r\n"
	while true; do
		printf '\e[A\e[K'
		beepSpk headsUp
		countDownDelay 120 "  Waiting for operator acknowlegment of the end of the test.."
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

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tbootLauncher (support: arturd@silicom.co.il)'
	libPath="/root/multiCard/arturLib.sh"
	export MC_SCRIPT_PATH=/root/multiCard
	if [[ -e "$libPath" ]]; then 
		echo -e "  \e[0;32mLib found.\e[m"
		source $libPath
		source /root/multiCard/graphicsLib.sh
		testFileExist "/root/multiCard/sfpLinkTest.sh"
		declareVars
	else
		echo -e "  \e[0;31mLib not found by path: $libPath\e[m"
	fi
else	
	echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
	trap "exit 1" 10
	PROC="$$"
	libPath="/root/multiCard/arturLib.sh"
	export MC_SCRIPT_PATH=/root/multiCard
	if [[ -e "$libPath" ]]; then 
		echo -e "  \e[0;32mLib found.\e[m"
		source $libPath
		source /root/multiCard/graphicsLib.sh
		testFileExist "/root/multiCard/sfpLinkTest.sh"
		binPathSetup
		loadCfg
		declareVars
		echoHeader "$toolName" "$ver"
		echoSection "Startup.."
		parseArgs "$@"
		setEmptyDefaults
		startupInit
		main "$@"
	else
		echo -e "  \e[0;31mLib not found by path: $libPath\e[m"
	fi
fi