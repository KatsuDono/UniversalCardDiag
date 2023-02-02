#!/bin/bash

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			debug) debugMode=1 ;;
			autostart) autostartMode=1 ;;
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

loadCfg() {
	local cfgPath srcRes cfgPathArg
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
			if [ -z "$srcRes" ]; then echo "config loaded"; else critWarn "config file is corrupted"; fi
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
	loadCfg $jobDBPath
}

main() {
	local jobCreate defStartup
	# getTracking
	# createLog
	if [ ! -z "$autostartMode" ]; then
		checkJobStates
	else
		echo -e "\n  Select action:"
		options=("Create job" "Normal startup")
		case `select_opt "${options[@]}"` in
			0) jobCreate=1;;
			1) defStartup=1;;
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
			slot-num) 		resPrint=${slotMatrix[$slotIdx,0]} ;;
			pn) 			resPrint=${slotMatrix[$slotIdx,1]} ;;
			tn) 			resPrint=${slotMatrix[$slotIdx,2]} ;;
			pci-test) 		resPrint=${slotMatrix[$slotIdx,3]} ;;
			link-test) 		resPrint=${slotMatrix[$slotIdx,4]} ;;
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
			slot-num) 		let paramIdx=0 ;;
			pn) 			let paramIdx=1 ;;
			tn) 			let paramIdx=2 ;;
			pci-test) 		let paramIdx=3 ;;
			link-test) 		let paramIdx=4 ;;
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
	options=("Slot 1" "Slot 2" "Slot 3" "Slot 4" "Slot 5" "Slot 6")
	return `select_opt "${options[@]}"`
}

createJobsLoop() {
	local slotSel
	clearAllDB
	while true
	do
		checkJobStatesInfo
		selectSlotForJob
		privateNumAssign slotSel $?
		echo -e "\n  Select action:"
		options=("Add slot job" "Remove slot job" "Select different slot" "Save and exit")
		case `select_opt "${options[@]}"` in
			0) 
				echo "Add slot job selected"
				clearSlotDB $slotSel
				createSlotJob $slotSel
			;;
			1) 
				echo "Remove slot job selected"
				clearSlotDB $slotSel
			;;
			2) 
				echo "Different slot selected"
			;;
			3) 
				echo "Save and exit selected"
				exit
			;;
			*) except "Unknown action";;
		esac
	done
}

createSlotJob() {
	local targSlot
	targSlot=$1
	echo "   Creating new job for slot $targSlot"
	
}


function checkSlotJobShort () {
	local slotIdx pciTestDB pnDB tnDB exitStatus linkTestDB
	privateNumAssign "slotIdx" "$1"
	exitStatus=1
	if [[ ! -z "${slotMatrix[$slotIdx,1]}" ]]; then 
		exitStatus=0
		pnDB=$(readDB $slotIdx --pn)
		tnDB=$(readDB $slotIdx --tn)
		pciTestDB=$(readDB $slotIdx --pci-test)
		linkTestDB=$(readDB $slotIdx --link-test)

		echo "    PN: $pnDB    TN: $tnDB"
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
		
		echo "    Test started: $testStartDB"
		echo "    Test ended: $testEndDB"
		echo "    Test result: $testResultDB"
		echo "    Passed runs: $passRunsDB"
		echo "    Failed runs: $failRunsDB"
		echo "    Total runs: $totalRunsDB"
		echo "    Current run: $currentRunDB"
		echo "    Runs left: $runsLeftDB"
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
	if [ ! -z "$rebootRequired" ]; then
		countDownDelay 5 "  Sending system to reboot.."
		reboot
	else
		testEndLoop
	fi
}

startSlotJob() {
	local slotIdx pciTestDB linkTestDB uutSlotNum logPath uutPn uutTn randHex currentRunDB slotLogPath testRes slotLogPathFull
	local logCleanup
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

	writeDB $slotIdx --test-start=1
	let currentRunDB=$(($currentRunDB+1))
	writeDB $slotIdx --current-run=$currentRunDB
	let runsLeftDB=$(($runsLeftDB-1))
	writeDB $slotIdx --runs-left=$runsLeftDB

	critWarn --sil "SORT OUT proper log path determination"
	randHex=$(xxd -u -l 4 -p /dev/urandom)
	# logPath="/root/multiCard/$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'$randHex.log
	
	logPath="$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"Run-"$currentRunDB'_'$randHex.log
	publicVarAssign fatal logPathFull "/root/multiCard/$logPath"
	writeDB $slotIdx --last-run-log=$logPath
	critWarn --sil "SORT OUT multiple tests selects in one argument"
	/root/multiCard/menu.sh --uut-slot-num=$uutSlotNum --PN-choice=$uutPn --uut-pn=$uutPn --test-sel=$pciTestDB --noMasterMode --slDupSkp --minor-launch 2>&1 |& tee $logPathFull
	echo "  Clening up log from excess symbols"

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
		randHex=$(xxd -u -l 4 -p /dev/urandom)
		slotLogPath="$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"TOTAL-LOG_"$randHex.log
		writeDB $slotIdx --total-log=$slotLogPath
	else
		slotLogPathFull="/root/multiCard/$(readDB $slotIdx --total-log)"
		globalLogPathFull="/root/multiCard/$(readDB $slotIdx --global-log)"
		echo "  Checking total log path: $slotLogPathFull"
		if ! [ -e "$slotLogPathFull" ]; then
			echo "  Total log path is non-existent, recreating."
			randHex=$(xxd -u -l 4 -p /dev/urandom)
			slotLogPath="$uutTn"'_'"PN-$uutPn"'_'"Slot-$uutSlotNum"'_'"TOTAL-LOG_"$randHex.log
			writeDB $slotIdx --total-log=$slotLogPath
		fi
	fi

	let totalRunsDB=$(($totalRunsDB+1))
	writeDB $slotIdx --total-runs=$totalRunsDB

	slotLogPathFull="/root/multiCard/$(readDB $slotIdx --total-log)"
	dmsg echo "TOTAL LOG: $slotLogPathFull"

	testRes="$(cat $logPathFull |grep "Total Summary: ALL TESTS PASSED")"
	echo -n "  Appending log: "
	if [ -z "$testRes" ]; then
		let failRunsDB=$(($failRunsDB+1))
		writeDB $slotIdx --fail-runs=$failRunsDB
		testResVerb="FAILED"
	else
		let passRunsDB=$(($passRunsDB+1))
		writeDB $slotIdx --pass-runs=$passRunsDB
		testResVerb="PASSED"
	fi

	echo "Run: $currentRunDB, Test result: $testResVerb, Passed runs: $passRunsDB, Failed runs: $failRunsDB, Runs left: $runsLeftDB" 2>&1 |tee -a "$slotLogPathFull"
	
	unset thermalDataCsv
	unset logCleanup
	thermLogPath=/root/multiCard/$(xxd -u -l 16 -p /dev/urandom).log
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

	echo "$uutPn;$uutTn;$uutSlotNum;$currentRunDB;$testResVerb;$passRunsDB;$failRunsDB;$runsLeftDB;$thermalDataCsv" 2>&1 |& tee -a "$globalLogPathFull" >/dev/null
	

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
	while true; do
		beepSpk headsUp
		countDownDelay 120 "  Waiting for operator acknowlegment of the end of the test.."
	done
}

binPathSetup() {
	if [[ ! -e "/bin/bootLauncher" ]]; then 
		echo "  Seting up symlink to bin"
		ln -s "/root/multiCard/bootLauncher.sh" "/bin/bootLauncher"
	else
		echo "  Skipping symlink setup, already set up"
	fi
}

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
	main "$@"
else
	echo -e "  \e[0;31mLib not found by path: $libPath\e[m"
fi
