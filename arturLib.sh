#!/bin/bash

echoHeader() {
	local addEl hdrText toolName ver
	toolName="$1"
	ver="$2"
	hdrTest="$toolName  $ver"
	for ((e=0;e<=${#hdrTest};e++)); do addEl="$addEl="; done		
	echo -e "\n\t  =====$addEl====="
	echo -e "\t  ░░   $hdrTest    ░░"
	echo -e "\t  =====$addEl=====\n"
}

echoPass() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\n\e[0;32m     ██████╗░░█████╗░░██████╗░██████╗"
	echo "     ██╔══██╗██╔══██╗██╔════╝██╔════╝"
	echo "     ██████╔╝███████║╚█████╗░╚█████╗░"
	echo "     ██╔═══╝░██╔══██║░╚═══██╗░╚═══██╗"
	echo "     ██║░░░░░██║░░██║██████╔╝██████╔╝"
	echo -e "     ╚═╝░░░░░╚═╝░░╚═╝╚═════╝░╚═════╝░\e[m\n\n"
}

echoFail() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\n\e[0;31m     ███████╗░█████╗░██╗██╗░░░░░" 1>&2
	echo "     ██╔════╝██╔══██╗██║██║░░░░░" 1>&2
	echo "     █████╗░░███████║██║██║░░░░░" 1>&2
	echo "     ██╔══╝░░██╔══██║██║██║░░░░░" 1>&2
	echo "     ██║░░░░░██║░░██║██║███████╗" 1>&2
	echo -e "     ╚═╝░░░░░╚═╝░░╚═╝╚═╝╚══════╝\e[m\n\n" 1>&2
}
echoSection() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"		
	local addEl
	sendToKmsg 'Section "'$yl$1$ec'" has started..'
	for ((e=0;e<=${#1};e++)); do addEl="$addEl="; done		
	echo -e "\n  =====$addEl====="
	echo -e "  ░░   $1    ░░"
	echo -e "  =====$addEl=====\n"
}

killAllScripts() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local procId scriptN scriptsN
	#privateVarAssign "killAllScripts" "procId" "$1"
	#kill -10 $procId
	#kill -9 $procId
	#kill -10 $$
	#kill -9 $$
	test -z "$1" && {
		declare -a scriptsN=(
			"sfpLinkTest.sh"
			"acc_diag_lib.sh"
		)
	} || {
		declare -a scriptsN=$*
	}
	for scriptN in "${scriptsN[@]}"; do
		instancesPIDs=$(pgrep $scriptN)
		#echo "DEBUG: instancesPIDs=$instancesPIDs  scriptN=$scriptN   "'${scriptsN[@]}='"${scriptsN[@]}"
		test -z "$instancesPIDs" || {
			for instancePID in $instancesPIDs; do 
				kill -9 $instancePID
			done
		}
	done
}

function killProcess(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local procN procNameList procPid procPidList status sigN sigList pidKilled
	privateVarAssign "${FUNCNAME[0]}" "procNameList" "$*"
	sigList="INT TERM KILL"
	let status=0

	for procN in $procNameList; do
		procPidList=$(pidof -x $procN)
		if isDefined procPidList; then
			for procPid in $procPidList; do
				let pidKilled=0
				for sigN in $sigList; do
					if [ -e /proc/$procPid ]; then 
						kill -$sigN "$procPid" &>/dev/null
						sleep 0.4
						if [ ! -e /proc/$procPid ]; then 
							let pidKilled++
							break
						fi
					else
						let pidKilled++
						break
					fi
				done
				if [ $pidKilled -eq 0 ]; then
					let status++
				fi
			done
		fi
	done
	return $status
}

exitFail() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local procId parentFunc exitDisable childPids
	dmsg "exitExec=$exitExec procId=$procId"
	procPIDArg=$2
	test -z "$procPIDArg" && procId=$PROC || procId=$procPIDArg
	if [ -z "$procId" ]; then
		echo -e "\t\e[1;41;33mexitFail exception, procId not specified\e[m"
		echo -e "\t\e[1;41;33mPossibly run as a function, so not executing exit\e[m"
		exitDisable=1
	fi
	test -z "$guiMode" && echo -e "\t\e[1;41;33m$1\e[m\n" 1>&2 || msgBox "$1"
	if [ ! -z "$minorLaunch" ]; then 
		echo -e "\n\tTotal Summary: \e[0;31mTESTS FAILED\e[m" 1>&2
		if [ ! -z "$procPIDArg" ]; then
			# sendToKmsg "PStree of main pid: ${PIDStackArr[0]}"
			# sendToKmsg "\n$(ps -o pid,ppid,cmd --ppid "${PIDStackArr[0]}" --forest 2>&1)"
			# sendToKmsg "PStree of killable pid: $procPIDArg"
			# sendToKmsg "\n$(ps -o pid,ppid,cmd --ppid "$procPIDArg" --forest 2>&1)"
			childPids=$(pgrep -P "$procId" |tr '\n' ' ')
			if [ ! -z "$childPids" ]; then
				sendToKmsg "killing child pids of PID: $procPIDArg ($childPids)"
			fi
			sendToKmsg `kill -9 $childPids 2>&1`
			sendToKmsg "killing PID: $procPIDArg"
			sendToKmsg `kill -9 $procPIDArg 2>&1`
			# sendToKmsg "PStree of main pid after kill: ${PIDStackArr[0]}"
			# sendToKmsg "\n$(ps -o pid,ppid,cmd --ppid "${PIDStackArr[0]}" --forest 2>&1)"
		fi
	fi
	echo -e "\n"
	test "$exitExec" = "3" && {
		critWarn "\t Exit loop detected, exiting forced."
		kill -9 $procId
		killAllScripts
	}
	parentFunc=$(printCallstack |cut -d: -f2 |cut -d '>' -f1 |awk '{print $1=$1}')c
	dmsg "parentFunc=$parentFunc"
	if ! [[ -e "/tmp/exitMsgExec" ]]; then 
		echo a>/tmp/exitMsgExec
		if [ -z "$minorLaunch" ]; then 
			echoFail
			beepSpk fatal 3
		fi
	fi
	if [ -z "$noExit" -a -z "$exitDisable" ]; then 
		sendToKmsg "Exiting.."
		exit 1
	fi
}

sendToKmsg() {
	if [ ! -z "$1" ]; then
		echo -e "[${cy}multiCard$ec][$yl${FUNCNAME[1]}$ec]:\t $*" |& tee /dev/kmsg &> /dev/null
	fi
}

dbgWarn() {	#nnl = no new line
	test -z "$2" && echo -e "$blw$1$ec" || {
		test "$2"="nnl" && echo -e -n "$blw$1$ec" 1>&2 || echo -e "$blw$1$ec" 1>&2
	}
	test -z "$(echo "$*" |grep "\-\-sil")" && beepSpk crit
}

critWarn() {  #nnl = no new line
	sendToKmsg "$1"
	test -z "$2" && echo -e "\e[0;47;31m$1\e[m" 1>&2 || {
		test "$2"="nnl" && echo -e -n "\e[0;47;31m$1\e[m" 1>&2 || echo -e "\e[0;47;31m$1\e[m" 1>&2
	}
	test -z "$(echo "$*" |grep "\-\-sil")" && beepSpk crit
}

warn() {	#nnl = no new line  #sil = silent mode
	sendToKmsg "$1"
	if [ -z "$2" ]; then
		echo -e "\e[0;33m$1\e[m" 1>&2
	else
		if [ "$2"="nnl" ]; then
			echo -e -n "\e[0;33m$1\e[m" 1>&2
		else
			echo -e "\e[0;33m$1\e[m" 1>&2
		fi
	fi
	test "$3"="sil" || beepSpk warn
}

inform() {	#nnl = no new line  #sil = silent mode
	local nnlEn silEn arg key msgNoKeys
	
	msgNoKeys="$@"
	for arg in "$@"
	do
		key=$(echo $arg|cut -c3-)
		case "$key" in
			sil) silEn=1; msgNoKeys="$(echo "$msgNoKeys"| sed s/"--sil "//)";;
			nnl) nnlEn=1; msgNoKeys="$(echo "$msgNoKeys"| sed s/"--nnl "//)";;
		esac
	done

	echo -e -n "\e[0;33m$msgNoKeys\e[m" 1>&2

	if [ -z "$nnlEn" ]; then
		echo -n -e "\n" 1>&2
	fi
	if [ -z "$silEn" -a -z "$silentMode" ]; then
		beepSpk info
	fi
}

passMsg() { #nnl = no new line  #sil = silent mode
	test -z "$2" && echo -e "\t\e[0;32m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\t\e[0;32m$1\e[m" || echo -e "\t\e[0;32m$1\e[m"
	}
	echo -e "\n"
	if [ -z "$minorLaunch" ]; then 
		echoPass
	else
		echo -e "\tTotal Summary: \e[0;32mALL TESTS PASSED\e[m"
	fi
	sendToKmsg "Finished tests, exiting.."
	beepSpk pass
}

printDmsgStack() {
	local idxOrder idx dmsgStackIdx stackMsgId
	if [ "$dmsgStack" == "1" ]; then
		let stackMsgId=0
		if [ ! -z "${dmsgStackArr[*]}" ]; then
			let dmsgStackIdx=${dmsgStackArr[99]}
			
			warn "\tPRINTING DMSG MESSAGE STACK>>>" 1>&2
			idxOrder=$(seq $(($dmsgStackIdx+1)) 1 30;seq 0 1 $dmsgStackIdx)
			for idx in $idxOrder; do
				let stackMsgId++
				echo "DMSG $stackMsgId> ${dmsgStackArr[$idx]}" 1>&2
			done
			warn "\t<<<DMSG MESSAGE STACK END\n" 1>&2
		else
			critWarn "\tDMSG stack is empty or no index: \n stack: ${dmsgStackArr[*]}\n counter:${dmsgStackArr[99]}" 1>&2
		fi
	fi
	unset dmsgStackArr
	
}

dmsg() {
	local addArg callerFunc dmsgStackIdx
	if [[ ! -z "$@" ]]; then
		if [ "$debugMode" == "1" -o "$dmsgStack" == "1" ]; then
			if [[ -z "${FUNCNAME[1]}" ]]; then callerFunc="  undefinedCallerFunc> "; else callerFunc="  ${FUNCNAME[1]}> "; fi
			if [ "$(type -t $(echo "$@"|awk '{print $1}') 2>&1)" == "function" ]; then 
				addArg="inform "
			else
				if [ "$(type -t $(echo "$@"|awk '{print $1}') 2>&1)" == "" ]; then 
					addArg="inform "
				else
					unset addArg
				fi
			fi
			if [ "$debugMode" == "1" ]; then
				if [ "$debugBrackets" == "0" ]; then
					echo -e -n "dbg>$callerFunc" 1>&2; $addArg"$@" 1>&2
				else
					inform "DEBUG>$callerFunc" --nnl 1>&2
					$addArg"$addArg$@" 1>&2
					inform "< DEBUG END" 1>&2
				fi
			else
				if [ ! -z "$dmsgStack" ]; then
					if [ ! -z "${dmsgStackArr[*]}" ]; then
						let dmsgStackIdx=${dmsgStackArr[99]}
						if [ $dmsgStackIdx -eq 30 ]; then 
							let dmsgStackArr[99]=0
							let dmsgStackIdx=0
						else 
							let dmsgStackIdx++
							let dmsgStackArr[99]=$dmsgStackIdx
						fi
						dmsgStackArr[$dmsgStackIdx]="$(echo -e -n "dbg>$callerFunc"  2>&1; $addArg"$@"  2>&1)"
					else
						echo -e "DMSG> DMSG stack is empty or no index: \n stack: ${dmsgStackArr[*]}\n counter:$dmsgStackIdx" 1>&2
					fi
				fi
			fi
		fi
	else
		echo "dmsg exception, input parameters undefined!" 1>&2
	fi
}

setPromptCmd() {
	local newPrompt basePrompt inputPrompt args
	if [ ! -z "$1" ]; then
		echo "  Setting prompt.. (old: $PROMPT_COMMAND)"
		args=$*
		inputPrompt=$(tr -d '\r' <<<$(echo "$args")|tr -d '\n')
		newPrompt='echo -ne "\033]0 ${USER}@${HOSTNAME%%.*} ${PWD/#$HOME/~} '$inputPrompt'\007"'
		export PROMPT_COMMAND=$newPrompt
		echo "  Setting prompt.. (new: $PROMPT_COMMAND)"
	fi
}

updateBottomStatusBar() {
	local status="$1"
	local ui_lines=3	# Number of lines in the UI bar
	local wallSymbol="~"
	local last_row=$(tput lines)
	local startOfBar=$((last_row - ui_lines))
	local width=$(tput cols)
	local line
	local top_bottom_symbols=$(printf "$wallSymbol%.0s" $(seq 1 $width)) # Create top and bottom symbols

	tput sc								# Save current cursor position
	tput cup $startOfBar 0 				# Move the cursor to the UI bar location
	tput setab 4						# Set background color to dark blue
	tput setaf 7						# Set font color to white
	for ((line=$startOfBar; line<=$last_row; line++)); do
		tput cup $line 0
		tput el
	done							# Clear the UI bar
	tput cup $startOfBar 0				# Move the cursor back to the UI bar location
    exec 5>&1
	echo "$top_bottom_symbols" >&5
	echo -n "$wallSymbol$wallSymbol" >&5
	tput cuf 2
    echo -n "MSG: $status" >&5
	tput cr
	tput cuf $((width - 2))
	echo "$wallSymbol$wallSymbol" >&5
    echo -n "$top_bottom_symbols" >&5
	exec 5>&-
	tput rc								# Restore saved cursor position
	tput sgr0
}

updateTopStatusBar() {
	local status=$*
	local ui_lines=3	# Number of lines in the UI bar
	local wallSymbol="~"
	local width=$(tput cols)
	local line
	local top_bottom_symbols=$(printf "$wallSymbol%.0s" $(seq 1 $width)) # Create top and bottom symbols

	tput sc								# Save current cursor position
	tput cup 0 0 				# Move the cursor to the UI bar location
	tput setab 4						# Set background color to dark blue
	tput setaf 7						# Set font color to white
	for ((line=0; line<$ui_lines; line++)); do
		tput cup $line 0
		tput el
	done							# Clear the UI bar
	tput cup 0 0				# Move the cursor back to the UI bar location
    exec 5>&1
	echo "$top_bottom_symbols" >&5
	echo -n "$wallSymbol$wallSymbol" >&5
	tput cuf 2
    echo -n "$status" >&5
	tput cr
	tput cuf $((width - 2))
	echo "$wallSymbol$wallSymbol" >&5
    echo -n "$top_bottom_symbols" >&5
	exec 5>&-
	tput rc								# Restore saved cursor position
	tput sgr0
}

updateTopStatusBarTMUX() {
	local status="$1"
	local wallSymbol="~"
	if [[ -n "$TMUX" ]]; then
		local width=$(tmux display-message -p "#{pane_width}")
		local top_bottom_symbols=$(printf "$wallSymbol%.0s" $(seq 1 $width)) # Create top and bottom symbols

		tmux set-option -g status off         # Disable the default status line

		# Update the status line content
		tmux set-option -g status-left-length $((width - 4))
		tmux set-option -g status-right-length $((width - 4))
		tmux set-option -g status-interval 1

		# Print the status message
		tmux set-option -g status-left "#[bg=blue,fg=white] MSG: $status"
		tmux set-option -g status-right "#[bg=blue,fg=white] MSG: $status"

		tmux set-option -g status on
		tmux refresh-client -S                 # Refresh the tmux client to display changes
	fi
}

createRamdisk() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local ramdiskSize totalMem readyToMount
	privateNumAssign "ramdiskSize" "$1"
	privateVarAssign "${FUNCNAME[0]}" "ramdiskPath" "$2"
	let readyToMount=0
    if [ -e "$ramdiskPath" ]; then
		if mountpoint -q $ramdiskPath; then
			freeRamdisk "$ramdiskPath"
		fi
        if [ ! -z "$(ls -A "$ramdiskPath" 2>/dev/null)" ]; then
			let ++readyToMount
			except "Unable to create ramdisk path: $ramdiskPath"
        fi
	fi
	mkdir -p "$ramdiskPath" 2>/dev/null
	if [ $readyToMount -eq 0 ]; then
		#local freeMemReq=32768
		local freeMemReq=16768
		local totalMem=$(free -m | awk '/^Mem:/{print $2}')
		if (( totalMem - ramdiskSize >= freeMemReq )); then
			mount -t tmpfs -o size="${ramdiskSize}M" tmpfs $ramdiskPath
			if [ $? -eq 0 ]; then
				dmsg inform "Ramdisk ($ramdiskPath) created with size ${ramdiskSize}MB."
			else
				except "Unable to create ramdisk: $ramdiskPath"
			fi
		else
			except "Not enough free RAM to create the RAM disk."
		fi
	else
		except "Skipping creation of ramdisk: $ramdiskPath"
	fi
}

freeRamdisk() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local ramdiskPath
	privateVarAssign "${FUNCNAME[0]}" "ramdiskPath" "$1"
	if [ -e "$ramdiskPath" ]; then
		if mountpoint -q $ramdiskPath; then
			local busyPids=$(lsof +c0 +D $ramdiskPath  |awk 'NR>1 {print $1" "$2}' |grep -v 'awk\|lsof\|grep\|bash' |cut -d' ' -f2)
			if isDefined busyPids; then
				kill $busyPids
			fi
			busyPids=$(lsof +c0 +D $ramdiskPath  |awk 'NR>1 {print $1" "$2}' |grep -v 'awk\|lsof\|grep\|bash' |cut -d' ' -f2)
			if ! isDefined busyPids; then
				# Unmount RAM disk
				umount $ramdiskPath
				if [ $? -eq 0 ]; then
					dmsg inform "Ramdisk ($ramdiskPath) unmounted."
					# Remove RAM disk directory
					rmdir $ramdiskPath
					if [ $? -eq 0 ]; then
						dmsg inform "Ramdisk ($ramdiskPath) directory removed."
					else
						except "Unable to remove ramdisk folder: $ramdiskPath"
					fi
				else
					except "Unable to unmount ramdisk: $ramdiskPath"
				fi
			else
				except "Unable to kill some pids ($(lsof +c0 +D $ramdiskPath |awk 'NR>1 {print $1" "$2}' |grep -v 'awk\|lsof\|grep\|bash')) while trying to free ramdisk folder: $ramdiskPath"
			fi
		else
			dmsg inform "Ramdisk ($ramdiskPath) is not currently mounted."
		fi
	else
		dmsg inform "Ramdisk path ($ramdiskPath) is nonexistent, skipping"
	fi
}

function initTmp() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local tmpPath="$1"
	if ! isDefined tmpPath; then tmpPath="/root/tmpStor"; fi
	if [ -e "$tmpPath" ]; then
		tmpMounted="$(mount |grep "$tmpPath" 2>/dev/null)"
		if ! isDefined tmpMounted; then
			createTempPath "$tmpPath"
		fi
	else
		createTempPath "$tmpPath"
	fi
}

function createTempPath () {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local tmpPath tmpMounted testFile
	tmpPath="$1"
	if ! isDefined tmpPath; then tmpPath="/root/tmpStor"; fi
	if [ ! -e "$tmpPath" ]; then mkdir -p $tmpPath; fi
	testFile="$tmpPath/test.file"
	tmpMounted="$(mount |grep "$tmpPath" 2>/dev/null)"
	if isDefined tmpMounted; then
		umount /root/tmpStor &>/dev/null
		if [ $? -ne 0 ]; then except "Unable to unmount path: $tmpPath"; fi 
	fi
	mount -t tmpfs -o size=100M tmpfs $tmpPath
	if [ $? -ne 0 ]; then except "Unable to mount temporary path: $tmpPath"; fi 
	echo "test">$testFile
	if [ ! -e "$testFile" ]; then
		except "Unable to create test file: $testFile"
	else
		rm -f "$testFile"
	fi
}

function createLog () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local pingTest localTime ntpTime status ntpRet

	for ARG in "$@"; do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			debug) debugMode=1 ;;
			help)
				echoSection "ACC diagnostics"
				${MC_SCRIPT_PATH}/acc_diag_lib.sh --help
				echoSection "SFP diagnostics"
				${MC_SCRIPT_PATH}/sfpLinkTest.sh --help
				exit
			;;
			menu-choice) menuChoice=${VALUE} ;;
			*) dmsg echo "Unknown arg: $ARG"
		esac
	done

	echo "Creating log.."
	if [[ ! -z "$1" ]]; then
		logPath=$1
		logPn=$2
	fi
	logFile="'/tmp/'"$trackNum"_"
	localTime=$(date --date="+2 hours" '+%d-%m-%Y_%H-%M')
	if [[ -z "$localTime" ]]; then 
		echo "Local date cannot be acquired!"
		status+=1
	fi
	pingTest=$(echo -n "$(ping -c1 -w1 8.8.8.8 2>&1)" |grep 'ttl=')
	if [[ ! -z "$pingTest" ]]; then
		ntpRet=$(rdate -p time.nist.gov 2>&1)
		if [[ "$?" = "0" ]]; then
			ntpTime=$(date --date="$ntpRet +2 hours" '+%d-%m-%Y_%H-%M')
			if [[ "$(echo -n "$localTime" |cut -c1-10)" = "$(echo -n "$ntpTime" |cut -c1-10)" ]]; then 
				echo " Local time validated by NTP."
				logFile+="$localTime"
				status+=0
			else 
				echo " Local time cant be trusted, using NTP!"
				logFile+="$ntpTime"
				status+=0
			fi
		else
			echo " NTP could not return time!"
		fi
	else
		echo -e ' NO INTERNET CONNECTION!'
	fi

	if [[ -z "$ntpTime" ]]; then
		echo -e ' Fallback to local..'
		if [ $(date --date="+2 hours" '+%Y') -lt 2022 ]; then 
			echo " Local date is lesser than year 2022 and cannot be trusted!"
			logFile+="UNKNOWN-DATE"
			status+=0
		else 
			echo " Local time validated by year."
			logFile+="$localTime"
			status+=0
		fi
	fi

	logFile+=".log"
	echo -e "Log created.\nLog file: $logFile\n"
	return $status
}

function getTracking () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	unset trackNum
	if [ -z "$1" ]; then
		echo -e -n "  Enter tracking: "
		read -r trackNum
	else
		trackNum=$1
	fi
	if [[ "${#trackNum}" = "13" ]]; then
		# echo "DEBUG: track symb count: ${#trackNum} val: $trackNum  returning 0"
		return 0
	else 
		# echo "DEBUG: track symb count: ${#trackNum} val: $trackNum  returning 1"
		if [[ "${#trackNum}" = "0" ]]; then
			return 2
		fi
		return 1
	fi
}

testFolderExist() {
	local filePath returnOnly silent
	filePath="$1"
	returnOnly="$2"
	silent="$3"
	test -z "$silent" && echo -e -n "  Checking folder path: $filePath"
	if [[ -e "$filePath" ]]; then 
		test "$returnOnly" = "true" && return 0
		test -z "$silent" && echo -e "  \e[0;32mok.\e[m"
	else
		test "$returnOnly" = "true" && return 1 || exitFail "Folder $filePath does not exists!"
	fi
}

testFileExist() {
	local filePath returnOnly silent
	filePath="$1"
	returnOnly="$2"
	silent="$3"
	test -z "$silent" && echo -e -n "  Checking path: $filePath"
	if [[ -e "$filePath" ]]; then 
		test "$returnOnly" = "true" && return 0
		test -z "$silent" && echo -e "  \e[0;32mok.\e[m"
	else
		test "$returnOnly" = "true" && return 1 || exitFail "File $filePath does not exists!"
	fi
}

checkIfacesExist() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local iface ifaceList
	privateVarAssign "${FUNCNAME[0]}" "ifaceList" "$*"
	for iface in $ifaceList; do
		if ! ifaceExist "$iface"; then
			except "Non existent ethernet interface: $iface"
		fi
	done
}

beepNoExec() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local beepCount ttyName
	let beepCount=$1
	if [ -z "$beepCount" ]; then echo "beepNoExec> beepCount is zero!"; fi
	test "$silentMode" = "1" || {
		ttyName=$(ls /dev/tty6* |uniq |tail -n 1)
		for ((b=1;b<=$beepCount;b++)); do 
			echo -ne "\a" > $ttyName
			sleep 0.13
		done
	}
}

function installBeep {
	local makeRes
	
	testFileExist "/root/multiCard/beep-master" "true" 2>&1 > /dev/null
	test "$?" = "1" && {
		warn "\tinstallBeep exception, package path does not exist, installation aborted" 
		return 1
	} || {
		makeRes="$(cd /root/multiCard/beep-master; make 2>&1; echo "beepMakeRes=$?")"
		test ! -z "$(echo "$makeRes" |grep beepMakeRes=0)" && {
			makeRes="$(cd /root/multiCard/beep-master; make install 2>&1; echo "beepInstallRes=$?")"
			test ! -z "$(echo "$makeRes" |grep beepInstallRes=0)" && return 0 || {
				warn "\tinstallBeep exception, install failed"
				return 1
			}
		} || {
			warn "\tinstallBeep exception, make failed"
			return 1
		}
	}
}

beepSpk() {
	local beepMode beepCount
	privateVarAssign "beepSpk" "beepMode" "$1"
	if [ -z "$debugMode" -a -z "$globalMute" ]; then
		test -z "$2" && let beepCount=1 || let beepCount=$1
		if command -v beep > /dev/null 2>&1; then 
			let beepInstalled=1
		else
			installBeep
			test "$?" = "0" && let beepInstalled=1 || let beepInstalled=0
		fi
		case "$beepMode" in
			fatal) test "$beepInstalled" = "0" && beepNoExec 5 || {
				beep -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6
				sleep 0.1
				beep -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6
				sleep 0.1
				beep -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6
			};;
			crit) test "$beepInstalled" = "0" && beepNoExec 3 || beep -f 783 -l 20 -n -f 830 -l 20 -n -f 783 -l 20 -n -f 830 -l 20 -n -f 783 -l 20 -n -f 830 -l 20;;
			warn)
				if [ -z "$silentMode" ]; then
					if [ "$beepInstalled" = "0" ]; then 
						beepNoExec 2
					else
						beep -f 783 -l 20 -n -f 830 -l 20
					fi
				fi
			;;
			info)
				if [ -z "$silentMode" ]; then
					if [ "$beepInstalled" = "0" ]; then 
						beepNoExec 1
					else
						beep -f 783 -l 20
					fi
				fi
			;;
			pass) 
				if [ -z "$silentMode" ]; then
					if [ "$beepInstalled" = "0" ]; then 
						beepNoExec 2
					else
						beep -f 523 -l 90 -n -f 659 -l 90 -n -f 783 -l 90 -n -f 1046 -l 90
					fi
				fi
			;;
			headsUp) test "$beepInstalled" = "0" && beepNoExec 1 || {
				beep -f 523 -l 1000
				sleep 0.05
				beep -f 1046 -l 15 -n -f 1046 -l 10
				sleep 0.08
				beep -f 1046 -l 15 -n -f 1046 -l 10
				sleep 0.08
				beep -f 1046 -l 15 -n -f 1046 -l 10
				sleep 0.05
				beep -f 1046 -l 140 -n -f 1046 -l 140
			};;
			warnHeadsUp) test "$beepInstalled" = "0" && beepNoExec 1 || {
				local lN mN hN dl rpt
				let lN=196;let mN=415;let hN=880;let dl=20
				for ((rpt=1; rpt<=4; rpt++)) ; do 
					beep -f $lN -l $dl -n -f $mN -l $dl -n -f $hN -l $dl -n -f $lN -l $dl -n -f $mN -l $dl -n -f $hN -l $dl
					sleep 0.02
					beep -f $(($lN*2)) -l $dl -n -f $(($mN*2)) -l $dl -n -f $(($hN*2)) -l $dl -n -f $(($lN*2)) -l $dl -n -f $(($mN*2)) -l $dl -n -f $(($hN*2)) -l $dl
				done
			};;
			*) exitFail "beepSpk exception, unknown beepMode: $beepMode"
		esac
	fi
}

beepLegacy() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	test -z "$1" && let beepCount=1 || let beepCount=$1
	if ! [ "$silentMode" = "1" ]; then
		ttyName=$(ls /dev/tty6* |uniq |tail -n 1)
		for ((b=1;b<=$beepCount;b++)); do 
			echo -ne "\a" > $ttyName
			sleep 0.13
		done
	fi
}

execScript() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local scriptPath scriptArgs scriptExpect scriptTraceKeyw scriptFailDesc retStatus nonVerb traceSnip
	declare -a scriptExpect
	declare -a scriptPrint
	let retStatus=0
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			exp-kw) scriptExpect+=("${VALUE}") ;;	
			verb-kw) scriptPrint+=("${VALUE}") ;;
			nonVerb) nonVerb=1 ;;
		esac
	done

	scriptPath="$1"
	scriptArgs="$2"
	scriptTraceKeyw="$3"
	scriptFailDesc="$4"
	dmsg "scriptExpect=$scriptExpect"
	dmsg "cmd=$scriptPath $scriptArgs"
	cmdRes="$($scriptPath $scriptArgs 2>&1)"
	for expKw in "${scriptExpect[@]}"; do
		dmsg "procerssing kw=>$expKw<"
		if [[ ! $(echo "$cmdRes" |tail -n 10) =~ $expKw ]]; then
			critWarn "\tTest: $expKw - NO"
			dmsg ">${expKw}< wasnt found in $(echo "$cmdRes" |tail -n 10)"
			test -z "$debugMode" || {
				inform "pwd=$(pwd)"
				echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
				echo -e "$cmdRes"
				echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
			}
			let retStatus++
		else
			if [[ -z "$nonVerb" ]]; then
				inform "\tTest: $expKw - YES"
			fi
			test -z "$debugMode" || {
				echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
				echo -e "$cmdRes"
				echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
			}
		fi
	done
	if [[ ! "$retStatus" = "0" ]]; then
		echo -e "\n\t\e[0;31m -- TRACE START --\e[0;33m\n"
		traceSnip="$(echo "$cmdRes" |grep -B 99 -A 99 -w "$scriptTraceKeyw")"
		if [[ -z "$traceSnip" ]]; then 
			echo -e "$(echo "$cmdRes")"
		else
			echo -e "$(echo "$cmdRes" |grep -B 99 -A 99 -w "$scriptTraceKeyw")"
		fi
		echo -e "\n\t\e[0;31m --- TRACE END ---\e[m\n"
	fi
	unset cmdRes
	return $retStatus
}

function select_option_adv {

	#	EXAMPLE USAGE
	# -----------------------------------------------
	# options=("one" "two" "three")

	# select_option "${options[@]}"
	# choice=$?

	# echo "Choosen index = $choice"
	# echo "        value = ${options[$choice]}"
	# -----------------------------------------------

	ESC=$( printf "\033")
	cursor_blink_on()		{ printf "$ESC[?25h"; }
	cursor_blink_off()		{ printf "$ESC[?25l"; }
	cursor_to()				{ printf "$ESC[$1;${2:-1}H"; }
	print_option()			{ printf "   $1  "; }
	print_option_hlt()     { printf "   $ESC[7m$bwt$1$ec$ESC[27m "; }
	print_selected()		{ printf "  $ESC[7m $1 $ESC[27m"; }
	print_selected_alt()	{ printf "  $ESC[7m $1 $ESC[27m"; }
	print_selected_final()	{ printf "  $blb $1 $ec  "; }
	get_cursor_row()		{ IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
	key_input()				{ read -s -n3 key 2>/dev/null >&2
							if [[ $key = $ESC[A ]]; then echo up;    fi
							if [[ $key = $ESC[B ]]; then echo down;  fi
							if [[ $key = ""     ]]; then echo enter; fi; }

	# initially print empty new lines (scroll down if at bottom of screen)
	for opt; do printf "\n"; done

	# determine current screen position for overwriting the options
	local lastrow=`get_cursor_row`
	local startrow=$(($lastrow - $#))

	# ensure cursor and input echoing back on upon a ctrl+c during read -s
	trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
	cursor_blink_off

	local selected=0
	while true; do
		# print options by overwriting the last lines
		local idx=0
		for opt; do
			cursor_to $(($startrow + $idx))
			if [ $idx -eq $selected ]; then
				print_selected_alt "$opt"
				local selOpt=$opt
			else
				print_option "$opt"
			fi
			((idx++))
		done

		# user key control
		case `key_input` in
			enter) 
				cursor_to $(($startrow + $selected))
				print_option_hlt "$selOpt"
				sleep 0.1
				cursor_to $(($startrow + $selected))
				print_selected_final "$selOpt"
				sleep 0.05
				break
			;;
			up)    ((selected--));
				if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
			down)  ((selected++));
				if [ $selected -ge $# ]; then selected=0; fi;;
		esac
	done

	# cursor position back to normal
	cursor_to $lastrow
	printf "\n"
	cursor_blink_on

	return $selected
}

function select_option {

	#	EXAMPLE USAGE
	# -----------------------------------------------
	# options=("one" "two" "three")

	# select_option "${options[@]}"
	# choice=$?

	# echo "Choosen index = $choice"
	# echo "        value = ${options[$choice]}"
	# -----------------------------------------------

    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

function select_opt {

		# EXAMPLE USAGE
	# -----------------------------------------------
	# options=("Yes" "No" "${array[@]}") # join arrays to add some variable array
	# case `select_opt "${options[@]}"` in
		# 0) echo "selected Yes";;
		# 1) echo "selected No";;
		# *) echo "selected ${options[$?]}";;
	# esac
	# -----------------------------------------------

    select_option "$@" 1>&2
    local result=$?
    echo $result
    return $result
}

function select_opt_adv {

    select_option_adv "$@" 1>&12 #redirecting prompts in stdout to special descriptor 12 for prompts
    local result=$?
	echo $result >&13
    return $result
}

assignBusesInfo() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local bpCtlRes
	bpCtlRes=$(bpctl_start 2>&1 > /dev/null)
	bpCtlRes=$(bprdctl_start 2>&1 > /dev/null)	

	for ARG in "$@"
	do	
		dmsg inform "ASSIGNING BUS: $ARG"
		case "$ARG" in
			spc) publicVarAssign silent spcBuses $(grep '1180' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;	
			eth) publicVarAssign silent ethBuses $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			plx) publicVarAssign silent plxBuses $(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			acc) publicVarAssign silent accBuses $(grep '0b40\|1200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			bp) 
				publicVarAssign silent bpBuses $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1)
				publicVarAssign silent bprdBuses $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1)
			;;
			*) exitFail "assignBuses exception, unknown bus type: $ARG"
		esac
	done
}

drawPciSlot() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"		
	local addEl addElDash addElSpace excessSymb cutText color slotWidthInfo pciInfoRes curLine curLineCut widthLocal cutAddExp addElDashSp
	if [[ ! -z "$globDrawWidthAdj" ]]; then let widthLocal=$globDrawWidthAdj; else let widthLocal=15; fi
	dmsg inform "args=$*"
	slotNum=$1
	shift
	test ! -z "$(echo $* |grep '\-\- Empty ')" || {
		widthInfo=$1
		shift
		slotWidthInfo="  Width Cap: $widthInfo"
	}
	let cutAdd=56+$widthLocal
	cutText=$(echo $* |cut -c1-$cutAdd)
	let excessSymb=$widthLocal+56-${#cutText}
	for ((e=0;e<=$excessSymb;e++)); do addEl="$addEl "; done
	for ((e=0;e<$widthLocal;e++)); do addElDash="$addElDash-"; done
	for ((e=-1;e<$widthLocal;e++)); do addElDashSp="$addElDashSp "; done
	for ((e=0;e<$widthLocal;e++)); do addElSpace="$addElSpace "; done
	test ! -z "$(echo $cutText |grep '\-\- Empty ')" && color='\e[0;31m' || color='\e[0;32m'
	#test "$cutText" = "-- Empty --" && color='\e[0;31m' || color='\e[0;32m'

	echo -e "\n\t-------------------------------------------------------------------------$addElDash"
	echo -e "\t░ Slot: $slotNum  ░  $color$cutText$addEl\e[m ░  $slotWidthInfo"
	test -z "$pciArgs" || {
		echo -e "\t░      - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -    $addElDashSp ░"
		dmsg inform "${pciArgs[@]}"
		pciInfoRes="$(listDevsPciLib "${pciArgs[@]}")"
		unset pciArgs
		echo "${pciInfoRes[@]}" | while read curLine ; do	
			addEl=""
			let cutAddExp=$cutAdd+12+11
			curLineCut=$(echo $curLine |cut -c1-$cutAddExp)
			curLineCutCount=$(echo $curLine |cut -c1-$cutAddExp | sed 's/\x1b\[[0-9;]*m//g')
			let excessSymb=$widthLocal+10+58-${#curLineCutCount}
			for ((e=0;e<=$excessSymb;e++)); do addEl="$addEl "; done
			echo -e "\t░ $curLineCut$addEl ░"
		done

	}
	echo -e -n "\t-------------------------------------------------------------------------$addElDash"
}


showPciSlots() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slotBuses slotNum slotBusRoot bpBusesTotal 
	local pciBridges pciBr slotBrPhysNum pciBrInfo rootBus slotArr dmiSlotInfo minimalMode
	local secBusArg secBusAddr firstDevInfo secDevInfo secDevSlotInfo
	local mbType slotList

	if [[ "$1" = "--minimalMode" ]]; then minimalMode=1; else unset minimalMode; fi

	echoSection "PCI Slots"
	slotBuses=$(getDmiSlotBuses)
	let slotNum=0
	let maxSlots=$(getMaxSlots)
	declare -A slotArr
	assignBusesInfo spc eth plx acc bp 2>&1 > /dev/null	
	bpBusesTotal=$bpBuses
	if [[ ! -z "$bprdBuses" ]]; then
		test -z "$bpBusesTotal" && bpBusesTotal=$bprdBuses || bpBusesTotal="$bpBuses $bprdBuses"
	fi
	
	for slotBus in $slotBuses; do
		if [[ ! "$slotBus" = "ff" ]]; then 
			falseDetect=$(ls /sys/bus/pci/devices/ |grep -w "0000:$slotBus")
			rootBus=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' |grep -v pci )
			dmsg inform rootBus=$rootBus
			if [ -z "$falseDetect" -o -z "$rootBus" ]; then
				dmsg inform "populatedRootBuses false deteted slotbus $slotBus, skipping"
				emptySlotBuses+=( "$slotBus" )
			else
				populatedRootBuses+=( "$rootBus" )
				dmsg inform "Added $rootBus (on slotBus=$slotBus) to populatedRootBuses"
			fi
		fi	
	done

	pciBridges=$( echo -n "${populatedRootBuses[@]}" |tr ' ' '\n' |sort |uniq)
	dmsg inform "pciBridges="$pciBridges
	dmsg inform "emptySlotBuses="$( echo -n "${emptySlotBuses[@]}" |tr ' ' '\n' |sort |uniq)
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	case "$mbType" in
		X10DRi) 
			for pciBr in $pciBridges; do
				pciBrInfo="$(lspci -vvvs $pciBr)"
				
				slotBrPhysNum=$(echo "$pciBrInfo" |grep SltCap -A1 |tail -n 1 |cut -d# -f2 |cut -c1)
				if [ -z "$slotBrPhysNum" ]; then
					dmsg inform "slotBrPhysNum is empty, retrying to get slot num by root portion of bridge address"
					pciBrInfo="$(lspci -vvvs $(echo -n $pciBr |cut -d. -f1).0)"
					slotBrPhysNum=$(echo "$pciBrInfo" |grep SltCap -A1 |tail -n 1 |cut -d# -f2 |cut -c1)
					if [ -z "$slotBrPhysNum" ]; then except "unable to get slot number on pci bridge: $pciBr"; fi
				fi
				slotWidthCap=$(echo "$pciBrInfo" |grep -m1 LnkCap: |awk '{print $7}' |cut -d, -f1 |cut -c2-)

				slotArr[0,$slotBrPhysNum]=$slotWidthCap
				dmsg inform "parsing info for bridge: $pciBr"
				dmsg inform "slotBrPhysNum=$slotBrPhysNum slotWidthCap=$slotWidthCap "
			done
		;;
		X12DAi-N6) 
			slotList=$(getDmiSlotBuses --slotNumList)
			if [ -z "$(echo -n $slotList |awk '{print $6}')" ]; then except "bad slotList: $slotList"; fi
			for pciBr in $pciBridges; do
				pciBrInfo="$(lspci -vvvs $pciBr)"
				
				slotBrPhysNum=$(echo "$pciBrInfo" |grep SltCap -A1 |tail -n 1 |cut -d# -f2 |cut -d, -f1)
				case $slotBrPhysNum in
					$(echo -n $slotList |awk '{print $1}')) slotBrPhysNum=1;;
					$(echo -n $slotList |awk '{print $2}')) slotBrPhysNum=2;;
					$(echo -n $slotList |awk '{print $3}')) slotBrPhysNum=3;;
					$(echo -n $slotList |awk '{print $4}')) slotBrPhysNum=4;;
					$(echo -n $slotList |awk '{print $5}')) slotBrPhysNum=5;;
					$(echo -n $slotList |awk '{print $6}')) slotBrPhysNum=6;;
					*) except "unknown slotBrPhysNum: $slotBrPhysNum"
				esac
				slotWidthCap=$(echo "$pciBrInfo" |grep -m1 LnkCap: |awk '{print $7}' |cut -d, -f1 |cut -c2-)

				slotArr[0,$slotBrPhysNum]=$slotWidthCap
			done
		;;
		X12SPA-TF) 
			for pciBr in $pciBridges; do
				pciBrInfo="$(lspci -vvvs $pciBr)"
				slotBrPhysNum=$(getPciSlotRootBusSlotNum $pciBr)
				slotWidthCap=$(echo "$pciBrInfo" |grep -m1 LnkCap: |awk '{print $7}' |cut -d, -f1 |cut -c2-)
				slotArr[0,$slotBrPhysNum]=$slotWidthCap
			done
		;;
		*) 
			critWarn "Unknown mbType: $mbType, fallback do default data gathering method"
			for pciBr in $pciBridges; do
				pciBrInfo="$(lspci -vvvs $pciBr)"
				
				slotBrPhysNum=$(echo "$pciBrInfo" |grep SltCap -A1 |tail -n 1 |cut -d# -f2 |cut -c1)
				slotWidthCap=$(echo "$pciBrInfo" |grep -m1 LnkCap: |awk '{print $7}' |cut -d, -f1 |cut -c2-)

				slotArr[0,$slotBrPhysNum]=$slotWidthCap
			done
		;;
	esac

	dmidecode -H 0x0000 2>&1 > /dev/null
	let dmiHandleAvbl=$?
	dmiSlotInfo="$(dmidecode -t slot)"
	if [ $dmiHandleAvbl -eq 0 ]; then
		for ((i=1;i<=$maxSlots;i++)) do 
			slotArr[4,$i]=$(echo "$dmiSlotInfo" |grep Handle |head -n$i |tail -n1 |cut -d, -f1 |awk '{print $2}')
			slotArr[2,$i]=$(dmidecode -H ${slotArr[4,$i]} |grep Type |awk '{print $2}' |cut -c2-)
		done
	else
		for ((i=1;i<=$maxSlots;i++)) do 
			slotArr[4,$i]="N/A"
			slotArr[2,$i]=$(grep 'Type:'<<<"$dmiSlotInfo" |head -n$i |tail -n1 |awk '{print $2}' |tr -d '[:alpha:]')
		done
	fi
	



	for ((i=1;i<=$maxSlots;i++)) do 
		dmsg inform "slotArr 0, $i = ${slotArr[0,$i]}   4, $i = ${slotArr[4,$i]}   2, $i = ${slotArr[2,$i]}"
	done

# 		slotArr arraingment		slotArr[dataRow,slotNumber]
# 	----------------------------------------------------------------------------------
#      SLOT>>	1			2			3			4			5			6
# 		0	WidthCap	WidthCap	WidthCap	WidthCap	WidthCap	WidthCap
# 		1	InUse		InUse		InUse		InUse		InUse		InUse
# 		2	MaxSlotWdth	MaxSlotWdth	MaxSlotWdth	MaxSlotWdth	MaxSlotWdth	MaxSlotWdth
# 		3	BusAddr		BusAddr		BusAddr		BusAddr		BusAddr		BusAddr
# 		4	DMI_Handle	DMI_Handle	DMI_Handle	DMI_Handle	DMI_Handle	DMI_Handle
# 	----------------------------------------------------------------------------------

	dmsg critWarn "MAKE sure that in case that +1 by hex address is an actual device, \n
	check that parent bus does not have slot capabilities \n
	moreover, check if slot in theory can have more than 4x or 8x by its length"
	dmsg inform slotBuses=$slotBuses
	for slotBus in $slotBuses; do
		let slotNum=$slotNum+1
		dmsg inform slotNum=$slotNum slotBus=$slotBus
		if [[ "$slotBus" = "ff" ]]; then 
			drawPciSlot $slotNum "-- Empty --" 
		else
			if [[ " ${emptySlotBuses[@]} " =~ " ${slotBus} " ]]; then
				dmsg inform "slotBus=$slotBus correlates to emptySlotBuses"
				drawPciSlot $slotNum "-- Empty --" 
			else
				dmsg inform "slotBus=$slotBus does not correlate to emptySlotBuses"
				falseDetect=$(ls /sys/bus/pci/devices/ |grep -w "0000:$slotBus")
				#slotBusRoot=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
				#test -z "$slotBusRoot" && drawPciSlot $slotNum "-- Empty --" || {
				if [[ -z "$falseDetect" ]]; then
					drawPciSlot $slotNum "-- Empty (dmi failure slotBus:$slotBus) --"
				else
					test -z "$slotBus" && drawPciSlot $slotNum "-- Empty --" || {
						secBusAddr=$(printf '%#X' "$((0x$slotBus + 0x01))" |cut -dX -f2)
						# gatherPciInfo $slotBus
						# dmsg debugPciVars
						unset secBusArg
						if [[ ! -z $(ls /sys/bus/pci/devices/ |grep -w "0000:$secBusAddr") ]]; then 
							firstDevInfo=$(lspci -nns $slotBus:00.0 |cut -d ' ' -f2-)
							secDevInfo=$(lspci -nns $secBusAddr:00.0 |cut -d ' ' -f2-)
							secDevSlotInfo=$(lspci -vvnns $secBusAddr:00.0 |grep 'Physical Slot: 0')
							if [ "$firstDevInfo" = "$secDevInfo" -a ! -z "$secDevSlotInfo" ]; then
								secBusArg="--sec-target-bus=$secBusAddr"
							else
								dmsg critWarn "second bus check failed: secBusAddr=$secBusAddr"
							fi
						fi
						if [[ -z "$minimalMode" ]]; then
							declare -a pciArgs=(
								"--plx-keyw=Physical Slot:"
								"--plx-virt-keyw=ABWMgmt+"
								"--plx-upst-keyw=BwNot-"
								"--spc-buses=$spcBuses"
								"--eth-buses=$ethBuses"
								"--plx-buses=$plxBuses"
								"--acc-buses=$accBuses"
								"--bp-buses=$bpBusesTotal"
								"--info-mode"
								"--target-bus=$slotBus"
								$secBusArg
								"--slot-width-max=${slotArr[0,$slotNum]}"
								"--slot-width-cap=${slotArr[2,$slotNum]}"
							)
						fi
						drawPciSlot $slotNum ${slotArr[0,$slotNum]} $(lspci -s $slotBus:)
					}
				fi
			fi
		fi
	done
	echo -e "\n\n"
}


getMaxSlots() {
	local mbType resSltNum
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	let resSltNum=-1
	case "$mbType" in
		X10DRi) privateNumAssign "resSltNum" "$(dmidecode -t slot |grep Handle |wc -l)";;
		X12DAi-N6) privateNumAssign "resSltNum" "$(dmidecode -t slot |grep Handle |wc -l)";;
		X12SPA-TF) privateNumAssign "resSltNum" "$(dmidecode -t slot  |grep Type: |grep "PCI" |wc -l)";;
		90500-0151-G71) privateNumAssign "resSltNum" "1";;
		*)
			except "Unknown mbType: $mbType"
		;;
	esac
	echo -n "$resSltNum"
}

getPciSlotRootBusSlotNum() {
	local mbType slotRootBusAddr slotRootBusSlotNum slotRootBusAddrUpd checkAddr
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	privateVarAssign critical "slotRootBusAddr" "$1"
	dmsg inform "processing slotRootBusAddr: $slotRootBusAddr"
	case "$mbType" in
		X10DRi) 
			slotRootBusSlotNum=$(lspci -vvvs $slotRootBusAddr |grep -A1 SltCap: |grep Slot |cut -d# -f2 |cut -d, -f1)
		;;
		X12DAi-N6) 
			slotRootBusSlotNum=$(lspci -vvvs $slotRootBusAddr |grep -A1 SltCap: |grep Slot |cut -d# -f2 |cut -d, -f1)
		;;
		X12SPA-TF) 
			checkAddr=$(ls -l /sys/bus/pci/devices/ |grep $slotRootBusAddr)
			if [ -z "$checkAddr" ]; then slotRootBusAddr=ff; fi
			if ! [ "$slotRootBusAddr" = "ff" ]; then 
				slotRootBusSlotNum=$(lspci -vvvs $slotRootBusAddr |grep -A1 SltCap: |grep Slot |cut -d# -f2 |cut -d, -f1)
				if [ -z "$slotRootBusSlotNum" ]; then
					dmsg inform "slotRootBusSlotNum is empty"
					slotRootBusAddr=$(echo -n "$slotRootBusAddr"|rev |cut -d: -f1-2|rev)
					case "$slotRootBusAddr" in
					"89:02.0") echo -n "1";;
					"50:04.0") echo -n "3";;
					"50:02.0") echo -n "3";;
					"17:04.0") echo -n "5";;
					"17:02.0") echo -n "5";;
					"c2:04.0") echo -n "7";;
					"c2:02.0") echo -n "7";;
					*) except "unknown slotRootBusAddr: $slotRootBusAddr"
					esac
				fi
			fi
		;;
		*)
			except "Unknown mbType: $mbType"
		;;
	esac
	echo -n $slotRootBusSlotNum
	dmsg inform "slotRootBusSlotNum=$slotRootBusSlotNum"
	
}

getDmiSlotBuses() {
	local mbType slotBusAddrList slotBuses bus rootBusList slotNum slotNumList busN dId rootBus rootBuses rootBusVal slotNumVal
	local slotCheckRes pciDevInfo slotStatus slotBusAddrArr rNum
	local slotDevs launchKey
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	launchKey=$1
	case "$mbType" in
		X10DRi) 
			dmsg inform "mbType=$mbType"
			# echo "$(dmidecode -t slot |grep "Bus Address" |cut -d: -f3)"
			privateVarAssign critical rNum $(lspci -nn |grep '[0604]' |grep -m1 "Xeon\|Haswell" |cut -d'[' -f3 |cut -d: -f2 |cut -c1)
			for dId in 2 4 6 8; do
				rootBus=$(lspci -d 8086:${rNum}f0$dId |grep -m1 00: |awk '{print $1}')
				if [ -z "$rootBus" ]; then rootBusVal="ff"; else rootBusVal="$rootBus"; fi
				if [ -z "$rootBuses" ]; then 
					rootBuses="$rootBusVal"
				else
					rootBuses+=" $rootBusVal"
				fi
			done
			for dId in 2 4 6 8; do
				rootBus=$(lspci -d 8086:${rNum}f0$dId |grep -m1 80: |awk '{print $1}')
				if [ -z "$rootBus" ]; then rootBusVal="ff"; else rootBusVal="$rootBus"; fi
				rootBuses+=" $rootBusVal"
			done
			for bus in ${rootBuses[*]}; do 
				if ! [ "$bus" = "ff" ]; then slotNum=$(getPciSlotRootBusSlotNum $bus); else unset slotNum; fi
				if [ -z "$slotNum" ]; then slotNumVal="ff"; else slotNumVal="$slotNum"; fi
				dmsg inform "processing bus: $bus slotNum=$slotNumVal"
				if [ -z "$slotNumList" ]; then 
					slotNumList="$slotNumVal"
				else
					slotNumList+=" $slotNumVal"
				fi
			done
			slotBusAddrList="$(grep ':' /sys/bus/pci/slots/*/address)"
			for slotNum in $slotNumList; do
				slotBusAddr=$(echo "$slotBusAddrList" |grep -m1 "/$slotNum/" |cut -d: -f3)
				if [ ! -z "$slotBusAddr" ]; then 
					slotBusAddrArr[$slotNum]="$slotBusAddr"
				fi
				dmsg inform "processing slotNum: $slotNum slotBusAddr=$slotBusAddr"
			done
			if ! [ "${slotBusAddrArr[2]}" = "ff" -o -z "${slotBusAddrArr[2]}" ]; then
				dmsg inform "checking slot 2 status"
				slotCheckRes=$(getPciSlotRootBus 0000:${slotBusAddrArr[2]}:00.0)
				if [ -z "$slotCheckRes" ]; then
					dmsg inform "slot 2 was false address (0000:${slotBusAddrArr[2]}:00.0)"
					slotCheckRes=$(grep ':' /sys/bus/pci/slots/*/address |grep -m1 "/0/" |cut -d: -f2-4)
					if [ ! -z "$slotCheckRes" ]; then
						dmsg inform "slotCheckRes passed, address: $slotCheckRes.0"
						pciDevInfo="$(lspci -vvvs $slotCheckRes.0 |grep -m1 "Physical Slot: 0")"
						if [ ! -z "$pciDevInfo" ]; then
							slotBusAddrArr[2]=$(echo -n $slotCheckRes |cut -d: -f2)
							dmsg inform "reassigned slot root bus for slot 2 to ${slotBusAddrArr[2]}"
							
						fi
					fi
				fi
			fi
			for ((slN=1;slN<=6;slN++)); do 
				if [ -z "${slotBusAddrArr[$slN]}" ]; then
					echo "ff"
				else
					echo "${slotBusAddrArr[$slN]}"
				fi
			done
		;;
		X12DAi-N6) 
			dmsg inform "mbType=$mbType"
			rootBusList=(0000:16:02.0 0000:c9:02.0 0000:4a:02.0 0000:b0:02.0 0000:30:02.0 0000:e2:02.0)
			for bus in ${rootBusList[*]}; do 
				dmsg inform "processing bus: $bus"
				checkBus=$(ls -l /sys/bus/pci/devices/ |grep $bus)
				if [ -z "$checkBus" ]; then
					simBus=0000:$(lspci -nn |grep 8086:347 |awk '{print $1}' |grep $(echo -n $bus |cut -c6-9))
					dmsg inform "bus: $bus is nonexistent, found alternative: $simBus"
					if ! [ "$simBus" = "0000:" ]; then
						bus=$simBus
						dmsg inform "updated current bus to: $bus"
					fi
				fi
				slotNum=$(getPciSlotRootBusSlotNum $bus)
				if [ -z "$slotNum" ]; then 
					if [ -z "$slotNumList" ]; then 
						slotNumList="ff"
					else
						slotNumList+=" ff"
					fi
				else
					if [ -z "$slotNumList" ]; then 
						slotNumList="$slotNum"
					else
						slotNumList+=" $slotNum"
					fi
				fi
			done
			checkDefined slotNumList
			slotBusAddrList="$(grep ':' /sys/bus/pci/slots/*/address |grep -v '/0/\|/1/\|/2/\|/3/\|/4/')"
			dmsg inform "slotNumList=$slotNumList"
			for slotNum in $slotNumList; do
				slotBusAddr=$(echo "$slotBusAddrList" |grep -m1 "/$slotNum/" |cut -d: -f3)
				if [ -z "$slotBusAddr" ]; then 
					if [ -z "$slotBuses" ]; then 
						slotBuses="ff"
					else
						slotBuses+=" ff"
					fi
				else
					if [ -z "$slotBuses" ]; then 
						slotBuses="$slotBusAddr"
					else
						slotBuses+=" $slotBusAddr"
					fi
				fi
			done
			if [ "$launchKey" = "--slotNumList" ]; then
				for slotNum in $slotNumList; do
					echo "$slotNum"
				done
			else
				for bus in $slotBuses; do
					echo "$bus"
				done
			fi
		;;
		X12SPA-TF)
			local bus rootBus rootBusList fullRootBusList dmiHandle dmiHandleList dmiSlotBuses sltCap dmiRootBuses busData busIdx
			declare -A busData

			#	busData description
			#
			#	rootBus	slotBus	slotNum	busAddrInSlot 	dmiBus
			#	0		1		2		3				4
			#

			let busIdx=0
			dmiHandleList=(0x000D 0x000E 0x000F 0x0010 0x0011 0x0012 0x0013)
			dmiBuses=$(for dmiHandle in ${dmiHandleList[*]}; do dmidecode -H$dmiHandle; done |grep Bus |cut -d: -f3)
			for bus in $dmiBuses; do
				dmsg inform "processing $bus (busIdx: $busIdx)"
				checkBus=$(ls -l /sys/bus/pci/devices/ |grep $bus)
				if ! [ "$bus" = "ff" -o -z "$checkBus" ]; then
					rootBus=$(getPciSlotRootBus $bus |cut -d: -f2-)
					if [ ! -z "$rootBus" ]; then
						dmsg inform "adding $rootBus to dmiRootBuses"
						dmiRootBuses+=($rootBus)
						busData[$busIdx,0]=$rootBus
						busData[$busIdx,4]=$bus
						sltCap=$(lspci -vs $rootBus |grep "Capabilities: \[40\]" |grep "Slot+")
						if [ ! -z "$sltCap" ]; then
							dmsg inform "adding $rootBus to dmiSlotBuses"
							dmiSlotBuses+=($rootBus)
							busData[$busIdx,1]=$rootBus
						else
							dmsg inform "$rootBus does not have slot capabilities, checking"
							sltCap=$(echo -n "$rootBus" |grep "89:02.0\|50:02.0\|17:02.0\|c2:02.0")
							if [ ! -z "$sltCap" ]; then
								dmsg inform "$rootBus actually have slot capabilities, adding $rootBus to dmiSlotBuses"
								dmiSlotBuses+=($rootBus)
								busData[$busIdx,1]=$rootBus
							else
								dmiSlotBuses+=("ff")
								busData[$busIdx,1]="ff"
								dmsg inform "$rootBus actually does not have slot capabilities"
							fi
						fi
					else
						dmsg inform "rootBus is empty"
					fi
				else
					dmsg inform "bus is empty"
					let prevIdx=$busIdx-1
					if [ $prevIdx -gt 0 ]; then
						dmsg inform "prevIdx > 0"
						if [ "${busData[$prevIdx,1]}" = "ff" ]; then
							dmsg inform "previous bus does not have slot capabilities, moving to current"
							rootBus=$(getPciSlotRootBus ${busData[$prevIdx,4]} |cut -d: -f2-)
							busData[$busIdx,0]=${busData[$prevIdx,0]}
							busData[$busIdx,1]=$rootBus
							dmiSlotBuses+=("$rootBus")
						fi
					fi
					if [ -z "${busData[$busIdx,1]}" ]; then 
						dmsg inform "busData for current index is empty, setting to ff"
						dmiSlotBuses+=("ff")
						busData[$busIdx,1]="ff"
					fi
				fi
				let busIdx++
			done

			dmsg inform "dmiRootBuses=${dmiRootBuses[*]}"
			dmsg inform "dmiSlotBuses=${dmiSlotBuses[*]}"

			# fullRootBusList=(0000:89:02.0 0000:50:04.0 0000:50:02.0 0000:17:04.0 0000:17:02.0 0000:c2:04.0 0000:c2:02.0)
			let busIdx=0
			for bus in ${dmiSlotBuses[*]}; do 
				dmsg inform "processing bus: $bus"
				checkBus=$(ls -l /sys/bus/pci/devices/ |grep $bus)
				if [ -z "$checkBus" ]; then
					simBus=0000:$(lspci -nn |grep 8086:347 |awk '{print $1}' |grep $(echo -n $bus |cut -c6-9))
					dmsg inform "bus: $bus is nonexistent, found alternative: $simBus"
					if ! [ "$simBus" = "0000:" ]; then
						bus=$simBus
						dmsg inform "updated current bus to: $bus"
					fi
				fi
				slotNum=$(getPciSlotRootBusSlotNum $bus)
				if [ -z "$slotNum" ]; then 
					slotNumList+=("ff")
					busData[$busIdx,2]="ff"
				else 
					slotNumList+=("$slotNum")
					busData[$busIdx,2]=$slotNum
				fi
				let busIdx++
			done
			for ((bIdx=0;bIdx<=6;bIdx++)); do dmsg inform "Bus $bIDX: 0:${busData[$bIdx,0]} 1:${busData[$bIdx,1]} 2:${busData[$bIdx,2]} 3:${busData[$bIdx,3]}";	done
			checkDefined slotNumList
			slotBusAddrList="$(grep ':' /sys/bus/pci/slots/*/address)"
			dmsg inform "slotNumList=${slotNumList[*]}"
			let busIdx=0
			for slotNum in ${slotNumList[*]}; do
				dmsg inform "processing slotNum: $slotNum"
				if [ "$slotNum" = "ff" ]; then 
					slotBuses+=("ff")
					busData[$busIdx,3]="ff"
				else
					slotBusAddr=$(echo "$slotBusAddrList" |grep -m1 "/$slotNum/" |cut -d: -f3)
					if [ -z "$slotBusAddr" ]; then 
						dmsg inform "unable to get slotBusAddr for slotNum: $slotNum"
						if ! [ "${busData[$busIdx,1]}" = "ff" ]; then
							case "${busData[$busIdx,1]}" in
								"89:02.0"|"50:02.0"|"17:02.0"|"c2:02.0") 
									dmsg inform "processing root slot: ${busData[$busIdx,1]}"
									busData[$busIdx,1]=$(ls -l /sys/bus/pci/devices/ |grep ${busData[$busIdx,1]} |cut -d/ -f5 |grep -m1 pci)
								;;
								"50:04.0"|"17:04.0"|"c2:04.0") 
									dmsg inform "processing non root slot: ${busData[$busIdx,1]}"
									busData[$busIdx,1]=$(ls -l /sys/bus/pci/devices/ |grep ${busData[$busIdx,1]} |cut -d/ -f5 |grep -m1 pci)
								;;
								*) except "unknown busData[$busIdx,1] value: ${busData[$busIdx,1]}"
							esac
							slotBusAddr=$(ls -l /sys/bus/pci/devices/ |grep ${busData[$busIdx,1]} |cut -d/ -f7 |awk '$1=$1' |head -n1 |cut -d: -f2)
						fi
					fi
					slotBuses+=("$slotBusAddr")
					busData[$busIdx,3]=$slotBusAddr
				fi
				let busIdx++
			done
			for ((bIdx=0;bIdx<=6;bIdx++)); do dmsg inform "Bus $bIDX: 0:${busData[$bIdx,0]} 1:${busData[$bIdx,1]} 2:${busData[$bIdx,2]} 3:${busData[$bIdx,3]}";	done
			if [ "$launchKey" = "--slotNumList" ]; then
				for slotNum in $slotNumList; do
					echo "$slotNum"
				done
			else
				for bus in ${slotBuses[*]}; do
					echo "$bus"
				done
			fi
		;;
		*) 
			dmsg critWarn "Unknown mbType: $mbType"
			echo "$(dmidecode -t slot |grep "Bus Address" |cut -d: -f3)"
		;;
	esac
}

getPciSlotRootBuses() {
	local mbType slotBusAddrList slotBusRootAddr slotBusRootAddrs slotBus
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	case "$mbType" in
		X10DRi) 
			slotBusAddrList="$(getDmiSlotBuses)"
			for slotBus in $slotBusAddrList; do
				if ! [ "$slotBus" = "ff" ]; then
					slotBusRootAddr=$(ls -l /sys/bus/pci/devices/ |grep :$slotBus: |cut -d/ -f6 |head -n1)
					if [ ! -z "$slotBusRootAddr" ]; then 
						if [ -z "$slotBusRootAddrs" ]; then 
							slotBusRootAddrs="$slotBusRootAddr"
						else
							slotBusRootAddrs+=" $slotBusRootAddr"
						fi
					fi
				fi
			done
			for bus in $slotBusRootAddrs; do
				echo "$bus"
			done
		;;
		X12DAi-N6) 
			slotBusAddrList="$(getDmiSlotBuses)"
			for slotBus in $slotBusAddrList; do
				if ! [ "$slotBus" = "ff" ]; then
					slotBusRootAddr=$(ls -l /sys/bus/pci/devices/ |grep :$slotBus: |cut -d/ -f5 |head -n1)
					if [ ! -z "$slotBusRootAddr" ]; then 
						if [ -z "$slotBusRootAddrs" ]; then 
							slotBusRootAddrs="$slotBusRootAddr"
						else
							slotBusRootAddrs+=" $slotBusRootAddr"
						fi
					fi
				fi
			done
			for bus in $slotBusRootAddrs; do
				echo "$bus"
			done
		;;
		X12SPA-TF) 
			slotBusAddrList="$(getDmiSlotBuses)"
			for slotBus in $slotBusAddrList; do
				if ! [ "$slotBus" = "ff" ]; then
					slotBusRootAddr=$(ls -l /sys/bus/pci/devices/ |grep :$slotBus: |cut -d/ -f6 |head -n1)
					if [ ! -z "$slotBusRootAddr" ]; then 
						if [ -z "$slotBusRootAddrs" ]; then 
							slotBusRootAddrs="$slotBusRootAddr"
						else
							slotBusRootAddrs+=" $slotBusRootAddr"
						fi
					fi
				fi
			done
			for bus in $slotBusRootAddrs; do
				echo "$bus"
			done
		;;
		*) 
			dmsg critWarn "Unknown mbType: $mbType"
			# echo "$(dmidecode -t slot |grep "Bus Address" |cut -d: -f3)"
		;;
	esac	
}

getPciSlotRootBus() {
	local mbType slotBus
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	privateVarAssign critical "slotBus" "$1"
	case "$mbType" in
		X10DRi) 
			if [ -z "$(echo -n "$slotBus" |grep 0000:)" ]; then
				ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |cut -d/ -f6 | awk '$1=$1'
			else
				ls -l /sys/bus/pci/devices/ |grep -m1 $slotBus |cut -d/ -f6 | awk '$1=$1'
			fi
		;;
		X12DAi-N6) 
			ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |cut -d/ -f5 | awk '$1=$1'
		;;
		X12SPA-TF)
			if [ -z "$(echo -n "$slotBus" |grep 0000:)" ]; then
				ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |cut -d/ -f6 | awk '$1=$1'
			else
				ls -l /sys/bus/pci/devices/ |grep -m1 $slotBus |cut -d/ -f6 | awk '$1=$1'
			fi
			
		;;
		*) 
			dmsg critWarn "Unknown mbType: $mbType"
			# echo "$(dmidecode -t slot |grep "Bus Address" |cut -d: -f3)"
		;;
	esac	
}

getDevsOnPciRootBus() {
	local mbType pciRootBusAddrList devsOnRootBus pciRootBus devIdList irqList devId extendedNotEqual irqN
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	privateVarAssign critical "pciRootBus" "$1"
	case "$mbType" in
		X10DRi) 
			# pciRootBus=$(echo -n $pciRootBus |cut -d. -f1)
			dmsg inform "rebuilding pciRootBus=$pciRootBus (greping '/$pciRootBus')"
			devsOnRootBus="$(ls -l /sys/bus/pci/devices/ |grep /$pciRootBus |cut -d/ -f7- |awk -F/ '{print $(NF)}' | awk '$1=$1')"
			extendedDevsList="$(ls -l /sys/bus/pci/devices/ |grep /$(echo -n $pciRootBus |cut -d. -f1). |cut -d/ -f7- |awk -F/ '{print $(NF)}' | awk '$1=$1')"
			for dev in $extendedDevsList; do
				devIdList+=($(cat /sys/bus/pci/devices/$dev/uevent |grep PCI_ID |cut -d= -f2))
				irqList+=($(lspci -vvvs $dev 2>&1 |grep "Interrupt:" |awk '{print $7}'))
				dmsg inform "added dev: $dev ID:${devIdList[$((${#devIdList[*]}-1))]} IRQ: ${irqList[$((${#irqList[*]}-1))]}"
			done
			dmsg inform "devIdList=${devIdList[*]}"
			dmsg inform "irqList=${irqList[*]}"
			for devId in "${devIdList[@]}"; do
				if [[ "${devIdList[0]}" != "$devId" ]]; then
					extendedNotEqual=true
				fi
			done
			for irqN in "${irqList[@]}"; do
				if [[ "${irqList[0]}" != "$irqN" ]]; then
					extendedNotEqual=true
				fi
			done

			if [[ -z "$extendedNotEqual" ]]; then
				for dev in $extendedDevsList; do
					echo "$dev"
				done
			else
				for dev in $devsOnRootBus; do
					echo "$dev"
				done
			fi
		;;
		X12DAi-N6) 
			if [ -z "$(echo $pciRootBus |grep pci0000)" ]; then except "bad pciRootBus: $pciRootBus"; else
				devsOnRootBus="$(ls -l /sys/bus/pci/devices/ |grep $pciRootBus |cut -d/ -f7- |awk -F/ '{print $(NF)}' | awk '$1=$1')"
				for dev in $devsOnRootBus; do
					echo "$dev"
				done
			fi
		;;
		X12SPA-TF) 
			if [ ! -z "$(echo $pciRootBus |grep pci0000)" ]; then
				devsOnRootBus="$(ls -l /sys/bus/pci/devices/ |grep $pciRootBus |cut -d/ -f7- |awk '$1=$1')"
			else
				sltCap=$(lspci -vs $pciRootBus |grep "Capabilities: \[40\]" |grep "Slot+")
				if [ -z "$sltCap" ]; then
					pciRootBus=$(ls -l /sys/bus/pci/devices/ |grep -m1 "$pciRootBus" |cut -d/ -f5)
				fi
				devsOnRootBus="$(ls -l /sys/bus/pci/devices/ |grep $pciRootBus |cut -d/ -f7- |awk '$1=$1')"
			fi
			for dev in $devsOnRootBus; do
				echo "$dev"
			done
		;;
		*) 
			dmsg critWarn "Unknown mbType: $mbType"
			# echo "$(dmidecode -t slot |grep "Bus Address" |cut -d: -f3)"
		;;
	esac
}

getIfacesOnSlot() {
	local slotBus bus slotNum
	privateNumAssign slotNum $1
	bus=$(getDmiSlotBuses |head -n $slotNum |tail -n 1)
	if ! [ "$bus" = "ff" -o -z "$bus" ]; then
		privateVarAssign fatal slotBus $(getPciSlotRootBus $bus)
		getIfacesOnSlotBus $slotBus
	fi
}

getIfacesOnSlotBus() {
	local netDevs devsOnBus pciRootBus netOnDev dev
	privateVarAssign critical "pciRootBus" "$1"
	devCheck="$(ls -l /sys/bus/pci/devices/ |grep $pciRootBus)"
	if [ -z "$devCheck" ]; then
		except "device: $pciRootBus does not exist"
	else
		if [ -z "$(echo -n "$pciRootBus"|grep '0000:')" ]; then pciRootBus="0000:$pciRootBus"; fi
		netDevs="$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -v "virtual\|total" |cut -d/ -f5-)"
		devsOnBus=$(getDevsOnPciRootBus $pciRootBus)
		for dev in $devsOnBus; do
			netOnDev=$(echo -n "$netDevs"|grep -m1 "$dev")
			if [ ! -z "$netOnDev" ]; then echo "$netOnDev"|awk -F/ '{print $NF}'; fi
		done
	fi
}

getPciBridgeMemParams() {
	local pciAddr memBehind memBehindStart memBehindEnd prefMemBehind prefMemBehindStart prefMemBehindEnd
	privateVarAssign critical "pciAddr" "$1"
	memBehind=$(lspci -vvvs $pciAddr |grep -m1 'Memory behind' |awk '{print $4}')
	memBehindStart=$(echo -n "$memBehind"|cut -d- -f1)
	memBehindEnd=$(echo -n "$memBehind"|cut -d- -f2)
	prefMemBehind=$(lspci -vvvs $pciAddr |grep -m1 'Prefetchable memory behind' |awk '{print $5}')
	prefMemBehindStart=$(echo -n "$prefMemBehind"|cut -d- -f1)
	prefMemBehindEnd=$(echo -n "$prefMemBehind"|cut -d- -f2)
	echo "memRange=$((16#$memBehindEnd-16#$memBehindStart))"
	echo "prefMemRange=$((16#$prefMemBehindEnd-16#$prefMemBehindStart))"
}

function selectSlot () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slotBuses slotBus busesOnSlots devsOnSlots populatedSlots slotSelRes totalDevList populatedBuses selDesc activeSlots busMode
	
	privateVarAssign "selectSlot" "selDesc" "$1"
	busMode=$2
	if [[ -z "$busMode" ]]; then echo -e "$selDesc";fi

	slotBuses=$(getDmiSlotBuses)
	let slotNum=1

	for slotBus in $slotBuses; do
		if [[ ! "$slotBus" = "ff" ]]; then 
			falseDetect=$(ls /sys/bus/pci/devices/ |grep -w "0000:$slotBus")
			rootBus=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' |grep -v pci )
			dmsg inform rootBus=$rootBus
			if [ -z "$falseDetect" -o -z "$rootBus" ]; then
				dmsg inform "busesOnSlots false deteted slotbus $slotBus, skipping"
			else
				busesOnSlots+=( "$slotBus" )
				devsOnSlots+=( "$(lspci -s $slotBus: |cut -c1-70 |head -n 1)" )
				populatedSlots+=( "$slotNum" )
				dmsg inform "Added $slotBus (on slotNum=$slotNum) to busesOnSlots"
			fi
		fi	
		let slotNum+=1
	done

	if [[ ! -z "${devsOnSlots[@]}" ]]; then
		for ((e=0;e<=${#busesOnSlots[@]};e++)); 
		do 
			if [[ ! -z "${devsOnSlots[$e]}" ]]; then
				populatedBuses+=(${busesOnSlots[$e]})
				activeSlots+=(${populatedSlots[$e]})
				totalDevList+=("Slot ${populatedSlots[$e]} : ${devsOnSlots[$e]}")
			fi
		done
		slotSelRes=$(select_opt "${totalDevList[@]}")
		if [[ "$busMode" = "bus" ]]; then
			echo -n "${populatedBuses[$slotSelRes]}" |cut -d: -f1
		else
			return ${activeSlots[$slotSelRes]}
		fi
	else
		warn "selectSlot exception, no populated slots detected!"
	fi
}

selectUSBTPLink() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubNum usbBusSelRes
	privateVarAssign "${FUNCNAME[0]}" "hubNum" "$1"
	local args="--hub-number=$hubNum --hub-dev-id=bda:411 --hub-dev-id=bda:5411 --minimal --margs=dgc"
	if fdExist 12; then inform "\t${FUNCNAME[0]} >fdExist=yes"; else  inform "\t${FUNCNAME[0]} >fdExist=no"; fi
	# usbBusSelRes=`selectUSBBusFDRedir "$hubNum" "${args}"`
	exec 12>&1
	usbBusSelRes=$(selectUSBBusFDRedir "$hubNum" "${args}")
	echo -e "\t${FUNCNAME[0]} >usbBusSelRes=$usbBusSelRes"
}

function selectUSBBusFDRedir () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubNum usbBusSelRes args
	privateVarAssign "${FUNCNAME[0]}" "hubNum" "$1" ;shift
	local args="$*"

	if ! fdExist 12; then exec 12>&-; fi #closing file descriptor 12 for prompts of select_opt_adv
	exec 12>&1  #opening file descriptor 12 for prompts of select_opt_adv
	echo "$(ls -la /proc/$$/fd/ |grep /dev |awk '{print $9}')" >&2
	usbBusSelRes=$(selectUSBBus "Select USB device on hub $hubNum" "${args}" 13>&1)

	echo -n $usbBusSelRes

	if fdExist 12; then exec 12>&-; fi #closing file descriptor 12 for prompts of select_opt_adv
}

function selectUSBBus () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local selDesc usbDevs usbSelRes usbDevsList usbDevBuses
	local usbArgs dev devsList
	
	if fdExist 12; then inform "\t${FUNCNAME[0]} >fdExist=yes" >&2; else  inform "\t${FUNCNAME[0]} >fdExist=no" >&2; fi
	echo "$(ls -la /proc/$$/fd/ |grep /dev |awk '{print $9}')" >&2
	if ! fdExist 12; then  #checking if file descriptor 12 was opened for prompts of select_opt_adv
		except "File descriptor 12 was not created before execution of ${FUNCNAME[0]}"
	else
		privateVarAssign "${FUNCNAME[0]}" "selDesc" "$1"; shift
		echo -e "$selDesc" >&12 #sending to file descriptor 12 for prompts
		privateVarAssign "${FUNCNAME[0]}" "usbArgs" "$*"
		privateVarAssign "${FUNCNAME[0]}" "devsList" "$(getUsbDevsOnHub $usbArgs |sort)"

		while read dev; 
		do
			if [[ ! -z "$dev" ]]; then
				usbDevs+=( "Port: $(cut -d';' -f1 <<<"$dev") -> $(cut -d';' -f3 <<<"$dev")" )
				usbDevBuses+=( $(cut -d';' -f2 <<<"$dev") )
			fi
		done <<<"$devsList"	

		if [ ${#usbDevs[@]} -eq ${#usbDevBuses[@]} ]; then
			for ((cnt=0;cnt<${#usbDevs[@]};cnt++));
			do
				usbDevsList+=("${usbDevs[$cnt]} (bus: ${usbDevBuses[$cnt]})")
			done
		else
			warn "USB count and USB bus device count does not correspond, skipping verbalization" >&12 #sending to file descriptor 12 for prompts
		fi
		if [[ ! -z "${usbDevs[@]}" ]]; then
			if [ -z "$usbDevsList" ]; then
				usbSelRes=$(select_opt_adv "${usbDevs[@]}" 13>&1) #redirecting all FD 13, which is for the results to the stdout
			else
				usbSelRes=$(select_opt_adv "${usbDevsList[@]}" 13>&1) #redirecting all FD 13, which is for the results to the stdout
			fi
			echo -n "${usbDevBuses[$usbSelRes]}" >&13 #sending to file descriptor 13 for results
		else
			except "no usb devs found!"
		fi
	fi
	
	exec 12>&- #closing file descriptor 12 for prompts of select_opt_adv
}

function selectSerial () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local selDesc serialDevs slotSelRes
	
	privateVarAssign "${FUNCNAME[0]}" "selDesc" "$1"
	echo -e "$selDesc"

	serialDevs+=( $(ls /dev |grep ttyUSB) )
	serialDevsPorts+=( $(find /sys/bus/usb/devices/usb3/ -name dev |grep tty |cut -d/ -f7) )
	if [ ${#serialDevs[@]} -eq ${#serialDevsPorts[@]} ]; then
		for ((cnt=0;cnt<${#serialDevs[@]};cnt++)); 
		do
			serialDevsList+=("${serialDevs[$cnt]} (port: ${serialDevsPorts[$cnt]})")
		done
	else
		warn "Port count and serial device count does not correspond, skipping verbalization"
	fi

	if [[ ! -z "${serialDevs[@]}" ]]; then
		if [ -z "$serialDevsList" ]; then
			slotSelRes=$(select_opt "${serialDevs[@]}")
		else
			slotSelRes=$(select_opt "${serialDevsList[@]}")
		fi
		serDevRet=$(echo ${serialDevs[$slotSelRes]} |cut -dB -f2-)
		return $serDevRet
	else
		except "no serial devs found!"
	fi
}

function ibsSelectMgntMasterPort () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local masterBus devsOnMastBus ethBuses ethBus netSelect ethListOnMaster mastNets ethOnDev
	echo "  Select RJ45 MASTER card"
	masterBus="$(selectSlot "nop" "bus")"
	ethBuses=$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	devsOnMastBus=$(ls -l /sys/bus/pci/devices/ |grep :$masterBus: |awk -F/ '{print $NF}')

	for dev in $devsOnMastBus
	do
		for ethBus in $ethBuses
		do
			ethOnDev=$(echo $dev |cut -d: -f2- |grep -w $ethBus)
			if [[ ! -z "$ethOnDev" ]]; then 
				mastNets+=( $(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent |grep $ethOnDev |cut -d/ -f5) )
				if [[ -z "$ethListOnMaster" ]]; then 
					ethListOnMaster="$ethOnDev"
				else
					ethListOnMaster+=" $ethOnDev"
				fi
			fi
		done
	done

	if [[ ! -z "${mastNets[@]}" ]]; then
		echo "  Select RJ45 port on MASTER card"
		netSelect=$(select_opt "${mastNets[@]}")
		return $(echo -n ${mastNets[$netSelect]} |cut -c4-)
	else
		except "unable to retrieve eth name!"
	fi
}

function selectFileFromFolder() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local folderPath fileList extReq keywReq KEY VALUE ARG grepCmd file fileListArr fileSelectedIdx

	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			dir) privateVarAssign "${FUNCNAME[0]}" "folderPath" "${VALUE}";;
			ext) privateVarAssign "${FUNCNAME[0]}" "extReq" "${VALUE}";;
			keyw) privateVarAssign "${FUNCNAME[0]}" "keywReq" "${VALUE}";;
			*) except "Unknown arg: $ARG"
		esac
	done

	if ! isDefined folderPath; then 
		except "folder path is required"
	else
		lastChar=$(rev <<<"$folderPath" |cut -c1)
		if [ ! "$lastChar" = "/" ]; then folderPath+='/'; fi
	fi

	if isDefined extReq; then 
		grepCmd="ls -p ${folderPath} |egrep '\.$extReq$'"
	else
		grepCmd="ls -p ${folderPath} 2>/dev/null |grep -v '/'"
	fi

	if isDefined keywReq; then 
		grepCmd+="|grep '"$keywReq"'"
	fi

	if [ -d "$folderPath" ]; then
		fileList="$(eval $grepCmd)"
		fileListCount=$(wc -l <<<"$fileList")
		maxLines=$(($(stty size |awk '{print $1}')-4))
		if [ $fileListCount -gt $maxLines ]; then
			except "there are too much files for current tty size (max: $maxLines  actual count: $fileListCount)"
		else
			for file in $fileList; do
				fileListArr+=($file)
			done
			fileSelectedIdx=`select_opt "${fileListArr[@]}"`
			echo -n "$folderPath${fileListArr[$fileSelectedIdx]}"
		fi
	else
		except "folder path:$folderPath does not exist or is not a directory"
	fi
}

function makeFileCrc() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath calcCrc crcFilePath
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	checkPkgExist md5sum

	if [ -e "$filePath" ]; then
		crcFilePath="${filePath}.crc"
		rm -f "$crcFilePath" >/dev/null 2>&1
		calcCrc=$(md5sum "$filePath" |awk '{print $1}'| tr -d '[:cntrl:]')
		if isDefined calcCrc; then
			echo -n "$calcCrc">"$crcFilePath"
			if [ -e "$crcFilePath" ]; then
				return 0
			else
				except "crc file could not be created for file: $filePath"
			fi
		else
			except "crc could not be calculated for file: $filePath"
		fi
	else
		except "file: $filePath does not exist"
	fi
}

function checkFileCrc() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath calcCrc crcFilePath
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	checkPkgExist md5sum

	if [ -e "$filePath" ]; then
		crcFilePath="${filePath}.crc"
		if [ -e "$crcFilePath" ]; then
			calcCrc=$(md5sum "$filePath" |awk '{print $1}'| tr -d '[:cntrl:]')
			mastCrc=$(cat "$crcFilePath")
			if isDefined calcCrc; then
				if isDefined mastCrc; then
					if [ "$calcCrc" = "$mastCrc" ]; then
						return 0
					else
						except "crc check failed for file: $filePath"
					fi
				else
					except "crc from .crc file could not be gathered for file: $filePath"
				fi
			else
				except "crc could not be calculated for file: $filePath"
			fi
		else
			except "crc file for provided file: $filePath does not exist"
		fi
	else
		except "file: $filePath does not exist"
	fi
}

echoRes() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdLn
	cmdLn="$@"
	cmdRes="$($cmdLn; echo "res:$?")"
	test -z "$(echo "$cmdRes" |grep -w 'res:1')" && echo -n -e "\e[0;32mOK\e[m\n" || echo -n -e "\e[0;31mFAIL"'!'"\e[m\n"
}

createFtpShare() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ftpSharePath
	privateVarAssign "${FUNCNAME[0]}" "ftpSharePath" "$1"	
	echo "  Creating FTP share on server: $ftpSharePath"
	if ! command -v vsftpd &> /dev/null; then
		except "vsftpd not found"
	else
		echo -e -n "    Stopping vsftpd: "; echoRes "service vsftpd stop"
		echo -e -n "    Backing up current config: "; echoRes "cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak"
		mkdir -p /var/run/vsftpd/empty
		
		echo "listen=YES
		anonymous_enable=YES
		write_enable=YES
		anon_upload_enable=YES
		anon_mkdir_write_enable=YES
		chroot_local_user=YES
		local_enable=NO
		secure_chroot_dir=/var/run/vsftpd/empty
		pasv_min_port=40000
		pasv_max_port=50000
		xferlog_enable=YES
		xferlog_file=/var/log/vsftpd.log
		xferlog_std_format=YES
		idle_session_timeout=600
		data_connection_timeout=120
		max_clients=10
		max_per_ip=5
		local_umask=022
		file_open_mode=0666
		anon_root=$ftpSharePath
		" > /etc/vsftpd/vsftpd.conf
		# echo -e -n "    Creating PN folder /root/$syncPn: "; echoRes "mkdir -p /root/$syncPn"
		# echo -e -n "    Creating PN folder /root/$syncPn: "; echoRes "mkdir -p /root/$syncPn"
		# echo -e -n "    Creating PN folder /root/$syncPn: "; echoRes "mkdir -p /root/$syncPn"
		# echo -e -n "    Creating PN folder /root/$syncPn: "; echoRes "mkdir -p /root/$syncPn"
		# Create a directory for the FTP share and set its permissions
		sudo mkdir -p $ftpSharePath
		sudo chmod a-w $ftpSharePath
		sudo chown nobody:nogroup $ftpSharePath
		service vsftpd start
	fi
	echo "  Done."
}

closeFtpShare() {
	if [ -e "/etc/vsftpd/vsftpd.conf.bak" ]; then
		service vsftpd stop
		cp -f /etc/vsftpd/vsftpd.conf.bak /etc/vsftpd/vsftpd.conf
		service vsftpd start
	fi
}

syncFilesFromServ() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local forcedExec
	forcedExec="$3"
	test -z "$forcedExec" || {
		let syncExecuted=0
	}
	test ! "$syncExecuted" = "1" && {
		local seqPn syncPn 
		seqPn="$1"
		syncPn="$2"
		
		
		test -z "$seqPn" && exitFail "syncFilesFromServ exception, seqPn undefined!"
		test -z "$syncPn" && exitFail "syncFilesFromServ exception, syncPn undefined!"
		
		echo -e "   Syncing files from server.."
		
		echo -e -n "    Creating PN folder /root/$syncPn: "; echoRes "mkdir -p /root/$syncPn"
		echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
		echo -e -n "    Creating PN folder /mnt/$syncPn: "; echoRes "mkdir -p /mnt/$syncPn"
		
		echo -e -n "    Mounting scripts to /mnt/$syncPn: "; echoRes "mount.cifs \\\\172.30.0.4\\e\\Seq_DB\\Scripts /mnt/$syncPn"' -o user=LinuxCopy,pass=LnX5CpY'
		echo -e -n "    Syncing scripts to /root/$syncPn: "; echoRes "rsync -r --ignore-existing --chmod=D=rwx,F=rw /mnt/$syncPn/ /root/$syncPn"
		echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
		
		echo -e -n "    Mounting $seqPn folder: "; echoRes "mount.cifs \\\\172.30.0.4\\e\\Seq_DB\\$seqPn /mnt/$syncPn"' -o user=LinuxCopy,pass=LnX5CpY'
		echo -e -n "    Syncing $seqPn to root: "; echoRes "rsync -r --chmod=D=rwx,F=rw /mnt/$syncPn/ /root/$syncPn"
		echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
		
		echo -e -n "    Changing all permissions in /root/$syncPn: "; echoRes "chmod 755 /root/$syncPn/*"
		test -z "$forcedExec" && echo -e -n "    Starting iqvlinux in /root/$syncPn: "; echoRes "/root/$syncPn/iqvlinux.sh /root/$syncPn/."

		echo -e "   Done."
		test "$seqPn" = "Scripts" || let syncExecuted=1
		type checkRequiredFiles >/dev/null 2>&1 && checkRequiredFiles
	} || exitFail "Repetative sync requested. Seems that declared files requirments cant be met. Call for help"
}



checkOnedrivePkg() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo " Checking Onedrive pkg.."
	which onedrive 2>&1 > /dev/null
	if [ $? -eq 0 ]; then 
		echo "  Onedrive pkg present, ok"	
		echo -n "  Checking Onedrive service status: "
		serviceStatus="$(systemctl status onedrive |grep 'inactive (dead)')"
		if [ -z "$serviceStatus" ]; then
			echo "  running." 
			echo -n "  Stopping Onedrive service."
			systemctl stop onedrive
		else
			echo "  Onedrive service stopped, ok"
		fi
	else 
		except "  Onedrive pkg is not installed! Reffer to https://github.com/abraunegg/onedrive"
	fi
	echo " Done."
}

sharePathOnedrive() {
	local filePath srvIp msg logPath cmdRes lnkPath
	checkOnedrivePkg
	privateVarAssign "${FUNCNAME[0]}" "targetPath" "$1"

	dmsg inform "in case of sync issues 'onedrive --resync --single-directory LogStorage' may have be used"

	if ! ping -c 1 google.com &> /dev/null; then
		warn "  google.com is unreachable, skipping OneDrive path share"
	else
		echo -e " Creating share on Onedrive path.."
		syncPath="/$(onedrive --display-config |grep "'sync_dir'" |cut -d/ -f2-)"
		if [ "$syncPath" = "/" ]; then
			critWarn "unable to get sync directory"
		else
			# echo "  Starting sync on LogStorage."
			# onedrive --synchronize --upload-only --no-remote-delete --verbose --single-directory "LogStorage"
			echo "  Creating shared permissions."
			cmdRes="$(onedrive --create-share-link "$targetPath" 2>&1)"
			lnkPath="$(echo -n "$cmdRes" |grep 'File Shareable Link:' |cut -d: -f2- | cut -c2-)"
			lnkValid="$(echo -n "$lnkPath" |grep 'sharepoint')"
			if [ ! -z "$lnkValid" ]; then
				echo "  Created link: $lnkPath"
			else
				critWarn "${FUNCNAME[2]}> ${FUNCNAME[1]}> ${FUNCNAME[0]}> unable to create shared link on target path: $targetPath"
				echo -e "Full log: \n$cmdRes"
			fi
		fi
		echo -e " Done."
	fi
}

uploadLogOnedrive() {
	local filePath srvIp msg logPath cmdRes lnkPath
	checkOnedrivePkg
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targetPath" "$2"
	noSync="$3"

	dmsg inform "in case of sync issues 'onedrive --resync --single-directory LogStorage' may have be used"

	if ! ping -c 1 google.com &> /dev/null; then
		warn "  google.com is unreachable, skipping OneDrive upload"
	else
		echo -e " Uploading log to Onedrive.."
		echo "  Log file: $filePath"
		syncPath="/$(onedrive --display-config |grep "'sync_dir'" |cut -d/ -f2-)"
		if [ "$syncPath" = "/" ]; then
			critWarn "unable to get sync directory"
		else
			echo -e -n "  Creating log folder $syncPath/LogStorage: "; echoRes "mkdir -p $syncPath/LogStorage"
			echo -e -n "  Creating log folder $syncPath/LogStorage/$targetPath: "; echoRes "mkdir -p $syncPath/LogStorage/$targetPath"
			echo -e -n "  Copying log to sync folder: "; echoRes "cp -f "$filePath" "$syncPath/LogStorage/$targetPath/$(basename $filePath)""
			echo -n "  Checking file exists: "
			if [ ! -e "$syncPath/LogStorage/$targetPath/$(basename $filePath)" ]; then
				critWarn "unable to copy file to target directory: $syncPath/LogStorage/$targetPath/$(basename $filePath)"
			else
				echo "exists."
				if [ "$noSync" = "--no-sync" ]; then
					echo "  Skipping sync, '--no-sync' key is used."
				else
					echo -e -n "  Starting sync on LogStorage: "; echoRes "onedrive --synchronize --upload-only --no-remote-delete --verbose --single-directory "LogStorage""
					echo "  Creating shared permissions."
					cmdRes="$(onedrive --create-share-link "/LogStorage/$targetPath/$(basename $filePath)" 2>&1)"
					lnkPath="$(echo -n "$cmdRes" |grep 'File Shareable Link:' |cut -d: -f2- | cut -c2-)"
					lnkValid="$(echo -n "$lnkPath" |grep 'sharepoint')"
					if [ ! -z "$lnkValid" ]; then
						echo "  Created link: $lnkPath"
					else
						critWarn "${FUNCNAME[2]}> ${FUNCNAME[1]}> ${FUNCNAME[0]}> unable to create shared link on target path: $targetPath"
					fi
				fi
			fi
		fi
		echo -e " Done."
	fi
}

syncLogsOnedrive() {
	local filePath srvIp msg logPath cmdRes lnkPath dirSyncPath
	checkOnedrivePkg

	if ! ping -c 1 google.com &> /dev/null; then
		warn "  google.com is unreachable, skipping OneDrive upload"
	else
		echo -e " Syncing logs to Onedrive.."
		echo "  Starting sync on LogStorage."
		if [ -z "$1" ]; then 
			dirSyncPath="LogStorage"
		else
			dirSyncPath="$1"
		fi
		echo "  Sync path: $dirSyncPath"
		onedrive --synchronize --upload-only --no-remote-delete --single-directory $dirSyncPath
		echo -e " Done."
	fi
}

function sendTgMsg() {
	# local mount_point="/tmp/tg_tmp"
	local sendRes remoteIP remotePath localPath msgSend smbShare mntOk
	privateVarAssign "${FUNCNAME[0]}" "remoteIP" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "remotePath" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "localPath" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "msgSend" "$*"
	let mntOk=0

	smbShare="//$remoteIP/$remotePath/"
	dmsg inform "smbShare=$smbShare"
	dmsg inform "localPath=$localPath"
	msgSend="$(echo -ne "$msgSend")"

	if [ ! -e "${localPath}/tokenGen.sh" ]; then
		if [ ! -d "${localPath}" ]; then
			mkdir -p "${localPath}"
		fi
		umount "${localPath}" &>/dev/null
		mount.cifs "${smbShare}" "${localPath}" -o "user=smbLogs,password=smbLogs"
		let mntOk+=$?
	fi
	if [ $mntOk -eq 0 ]; then
		source "${localPath}/tokenGen.sh"
		if [ $? -eq 0 ]; then
			sendRes="$(curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
				-d "chat_id=${TG_CHAT_ID}" \
				--data-urlencode "text=$msgSend" \
			)"
			dmsg inform "RESP: $sendRes"
		else
			dmsg inform "env variable not set"
		fi
	else
		dmsg inform "mount failed."
	fi
	umount "${localPath}" &>/dev/null
}

addSQLLogRecord() {
	local hexID recordValue syncSrvIp
	source sqlLib &> /dev/null
	if [ $? -eq 0 ]; then
		privateVarAssign "${FUNCNAME[0]}" "sqlSrvIp" "$1"
		privateVarAssign "${FUNCNAME[0]}" "hexID" "$2"
		privateVarAssign "${FUNCNAME[0]}" "recordValue" "$3"
		dmsg echo "Adding SQL record: $recordValue on $hexID"
		sshCmd='source /root/multiCard/sqlLib.sh;'"sqlAddRecord \"$hexID\" $recordValue"
		sshSendCmdBlockNohup $sqlSrvIp root "${sshCmd}"
	else
		except "sqlLib is not sourced"
	fi
}

createPathForFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath folderArr fileExt dirList dir curPath
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	echo -e "    Creating path for file: $filePath"
	fileExt=$(echo -n $filePath|awk -F/ '{print $NF}' |cut -d. -f2)
	echo -e "     Extension: $fileExt"
	if [ ! -z "$fileExt" ]; then 
		filePath=$(dirname $filePath)
	fi
	echo -e "     File path: $filePath"
	if [ ! -e $filePath ]; then
		echo -e "     File path $filePath does not exist, creating"
		dirList=$(echo -n $filePath |cut -d/ -f2- | sed "s,/, ,g")
		curPath="/"
		for dir in $dirList; do 
			curPath+="$dir/"
			if [ -e $curPath ]; then
				echo -e "     Folder path $curPath exist, skipping"
			else
				echo -ne "     Folder path $curPath does not exist, creating: "
				echoRes "mkdir -p $curPath"
			fi
		done
	else
		echo -e "     File path $filePath exist, skipping"
	fi
	echo -e "    Done."
}

uploadQueueSyncServer() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath srvIp msg remotePath re couterList el targetPath
	privateVarAssign "${FUNCNAME[0]}" "srvIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$2"
	let lastCounter=-1
	verifyIp "${FUNCNAME[0]}" $srvIp
	sshWaitForPing 30 $srvIp 1
	if [ $? -eq 0 ]; then echo "   Log sync server $srvIp is up."; else except "Log sync server $srvIp is down!"; fi

	echo -e "   Uploading log to server.."
	echo "    Log file: $filePath"
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"	
	echo -e -n "    Creating log folder /mnt/SheetQueue: "; echoRes "mkdir -p /mnt/SheetQueue"	
	echo -e -n "    Mounting log folder to /mnt/SheetQueue: "; echoRes "mount.cifs \\\\$srvIp\\SheetQueue /mnt/SheetQueue"' -o user=smbLogs,pass=smbLogs'
	couterList=$(ls -l /mnt/SheetQueue/ |grep '.csvDB' |awk -F_ '{print $NF}' |cut -d. -f1 |sort |awk '{print $1}')
	if [ ! -z "$couterList" ]; then 
		re='^[0-9]+$'
		for el in $couterList; do
			if [[ $el =~ $re ]] ; then
				if [ $el -gt $lastCounter ]; then
					let lastCounter=$el
				fi
			fi
		done
	fi
	if [ $lastCounter -lt 0 ]; then let lastCounter=0; fi

	echo "    Last file index in queue: $lastCounter"
	let lastCounter++
	remoteFileName=$(echo -n "$(basename $filePath|rev |cut -d. -f2- |rev)_$lastCounter.$(basename $filePath|rev |cut -d. -f1 |rev)")
	targetPath="/mnt/SheetQueue/$remoteFileName"
	remotePath="/home/smbLogs/SheetQueue/$remoteFileName"
	echo "    Remote file path: $remotePath"
	echo "    Target file path: $targetPath"
	createPathForFile $targetPath
	echo -e -n "    Copying $filePath to $targetPath: "; echoRes "cp -f "$filePath" "$targetPath""
	echo "  Sending Spreadsheet sync request to sync server: $syncSrvIp"
	sshSendCmdNohup $syncSrvIp $syncSrvUser "python3 /root/multiCard/sheetUpdateUtilityNEW.py $remotePath"
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
	echo -e "   Done."
}

uploadSQLSheetSyncServer() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath srvIp msg remotePath re couterList el targetPath sshCmd
	privateVarAssign "${FUNCNAME[0]}" "srvIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$2"
	verifyIp "${FUNCNAME[0]}" $srvIp
	sshWaitForPing 30 $srvIp 1
	if [ $? -eq 0 ]; then echo "   Log sync server $srvIp is up."; else except "Log sync server $srvIp is down!"; fi

	echo -e "   Uploading SQL to sheets.."
	echo "    Log file: $filePath"
	echo "  Running SQL Spreadsheet sync on sync server: $syncSrvIp"
	sshCmd='source /root/multiCard/sqlLib.sh &>/dev/null; '"sqlExportViewCSV \"SlotJobsView\" |& tee $filePath"
	sshSendCmd $syncSrvIp $syncSrvUser "${sshCmd}"
	sshSendCmd $syncSrvIp $syncSrvUser "python3 /root/multiCard/sheetSQLUpdateUtility.py $filePath"
	echo -e "   Done."
}

uploadLogSyncServer() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath srvIp msg remotePath
	privateVarAssign "${FUNCNAME[0]}" "srvIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$2"
	privateVarAssign "${FUNCNAME[0]}" "targetPath" "$3"

	verifyIp "${FUNCNAME[0]}" $srvIp
	sshWaitForPing 30 $srvIp 1
	if [ $? -eq 0 ]; then echo "   Log sync server $srvIp is up."; else except "Log sync server $srvIp is down!"; fi

	echo -e "   Uploading log to server.."
	echo "    Log file: $filePath"
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"	
	echo -e -n "    Creating log folder /mnt/LogStorage: "; echoRes "mkdir -p /mnt/LogStorage"	
	echo -e -n "    Mounting log folder to /mnt/LogStorage: "; echoRes "mount.cifs \\\\$srvIp\\LogStorage /mnt/LogStorage"' -o user=smbLogs,pass=smbLogs'
	remotePath="/mnt/LogStorage/$targetPath/$(basename $filePath)"
	echo "    Remote file path: $remotePath"
	createPathForFile $remotePath
	echo -e -n "    Copying $filePath to $remotePath: "; echoRes "cp -f "$filePath" "$remotePath""
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
	echo -e "   Done."
}

uploadLogSmb() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath srvIp msg logPath
	privateVarAssign "${FUNCNAME[0]}" "srvIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$2"

	verifyIp "${FUNCNAME[0]}" $srvIp
	sshWaitForPing 30 $srvIp 1
	if [ $? -eq 0 ]; then echo "   Smb server $srvIp is up."; else except "Smb server $srvIp is down!"; fi

	echo -e "   Uploading log to server.."
	echo "    Log file: $filePath"
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"	
	echo -e -n "    Creating log folder /mnt/LogSync: "; echoRes "mkdir -p /mnt/LogSync"	
	if [ -z "$(echo -n "$filePath |grep '_Slot-'")" ]; then unset logPath; else logPath="\\SlotLogs"; msg=" slot"; fi
	echo -e -n "    Mounting$msg log folder to /mnt/LogSync: "; echoRes "mount.cifs \\\\$srvIp\\LOGS$logPath /mnt/LogSync"' -o user=Logs,pass=12345'
	echo -e -n "    Copying$msg log to /mnt/LogSync: "; echoRes "cp -f "$filePath" "/mnt/LogSync/$(basename $filePath)""
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
	echo -e "   Done."
}

blinkAllEthOnSlotList() {
	local slot eth slotList ethArr slotIdx netIdx cmdE slotNum maxEthQty
	privateVarAssign fatal slotList "$*"
	declare -A ethArr
	let maxEthQty=slotIdx=0
	for slot in $slotList; do
		let netIdx=0
		ethList=$(getIfacesOnSlot $slot)
		if [ ! -z "$ethList" ]; then
			for eth in $ethList; do
				if [ $maxEthQty -lt $netIdx ]; then let maxEthQty=$netIdx; fi
				ethArr[$slotIdx,$netIdx]=$eth
				let netIdx++
			done
		fi
		let slotIdx++
	done

	for ((netIdx=0; netIdx<=$maxEthQty; netIdx++)) ; do
		for ((slotNum=0; slotNum<=$slotIdx; slotNum++)) ; do
			eth=${ethArr[$slotNum,$netIdx]}
			if [ ! -z "$eth" ]; then 
				cmdE="ethtool -p $eth 1"
				(${cmdE} & sleep 0.1 && kill $!) > /dev/null 2>&1 &
				sleep 0.1
			fi
		done
	done
}

blinkAllEthOnSlot() {
	local slotNum eth ethList
	privateVarAssign fatal slotNum "$1"
	ethList=$(getIfacesOnSlot $slotNum)
	for eth in $ethList; do
		cmdE="ethtool -p $eth 1"
		(${cmdE} & sleep 0.1 && kill $!) &
		sleep 0.1
	done
}

blinkEthList() {
	local slotNum eth ethList
	privateVarAssign fatal ethList "$*"
	for eth in $ethList; do
		cmdE="ethtool -p $eth 1"
		(${cmdE} & sleep 0.05 && kill $!) &
		sleep 0.10
	done
}

blinkAllEth() {
	local ethList eth
	ethList=$(printNetsTree |grep 00E0 |awk '{print $4}')
	while true; do blinkEth $ethList; done
}

blinkEth() {
	local ethList eth
	ethList=$*
	for eth in $ethList; do
		echo -n "Blinking $eth: "
		ethtool -p $eth 1
		echo "done."
	done
}

printNetsTree() {
	local netDevs netDev netDevsMacs devPath ethDev net mac line
	netDevs="$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -v "virtual\|total" |cut -d/ -f5-)"
	for netDev in $netDevs; do
		dmsg inform "processing $netDev"
		devPath=$(echo -n "$netDev" |rev |cut -d/ -f3- |rev)
		ethDev=$(echo -n "$devPath" |awk -F/ '{print $(NF)}')
		net=$(echo -n "$netDev" |awk -F/ '{print $(NF)}')
		mac=$(ip a |grep -A1 $net: |tail -n1 |awk '{print $2}' |sed 's/://g' | tr '[:lower:]' '[:upper:]')
		netDevsMacs+=("  Device: $ethDev\tNet: $net\tMAC: $mac\tPci path: $devPath")
	done
	for line in "${netDevsMacs[@]}"; do
		echo -e "$line"
	done
}

printNetsStats() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local netDevs netDev netDevsMacs devPath ethDev net line netsReq speedsReq netDevIdx ethtoolRes netSpeed
	local netLnk netOK
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			nets-req) 
				if [ ! -z "${VALUE}" ]; then
					for netReq in ${VALUE}; do netsReq+=($netReq); done
				fi
			;;	
			speeds-req) 
				if [ ! -z "${VALUE}" ]; then
					for speedReq in ${VALUE}; do speedsReq+=($speedReq); done
				fi			
			;;
			*) echo "Unknown arg: $ARG"
		esac
	done

	if [ ! -z "$netsReq" -a ! -z "$speedsReq" ]; then
		if [ ${#netsReq[*]} -eq ${#speedsReq[*]} ]; then
			for iface in ${netsReq[*]}; do
				netDevWithPath=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -v "virtual\|total" |cut -d/ -f5- |grep $iface)
				if [ -z "$netDevWithPath" ]; then
					echo -e -n "\e[0;31mInterface $iface does not exist!\e[m" 
				else
					netDevs+="$netDevWithPath "
				fi
			done
		else
			echo -e -n "\e[0;31mNets required or speed required do not match argument counts\e[m\n" 
			echo "netsReq=${netsReq[*]}"
			echo "speedsReq=${speedsReq[*]}"
		fi
	else
		if isDefined netsReq; then
			for iface in ${netsReq[*]}; do
				netDevWithPath=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -v "virtual\|total" |cut -d/ -f5- |grep $iface)
				if [ -z "$netDevWithPath" ]; then
					echo -e -n "\e[0;31mInterface $iface does not exist!\e[m" 
				else
					netDevs+="$netDevWithPath "
				fi
			done
		else
			netDevs="$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -v "virtual\|total" |cut -d/ -f5-)"
		fi
	fi
	
	let netDevIdx=0
	for netDev in $netDevs; do
		dmsg inform "processing $netDev"
		devPath=$(echo -n "$netDev" |rev |cut -d/ -f3- |rev)
		ethDev=$(echo -n "$devPath" |awk -F/ '{print $(NF)}')
		net=$(echo -n "$netDev" |awk -F/ '{print $(NF)}')
		ethtoolRes="$(ethtool $net)"
		netSpeed="$(grep 'Speed:'<<<"$ethtoolRes" |awk '{print $2}')"

		if [[ ! -z "$netSpeed" ]]; then
			if [ ! -z "${speedsReq[$netDevIdx]}" ]; then
				if [[ -z "$(echo $netSpeed |sed 's/[^0-9]*//g' |grep -x ${speedsReq[$netDevIdx]})" ]]; then
					netSpeed="\e[0;31m$(echo $netSpeed |cut -d: -f2-) (FAIL)\e[m" 
				else
					netSpeed="\e[0;32m$(echo $netSpeed |cut -d: -f2-)\e[m"
				fi
			else
				netSpeed=$(sed 's/[^0-9]*//g' <<<"$netSpeed")
			fi
		else
			netSpeed="\e[0;31mNO DATA\e[m" 
		fi

		netLnk="$(grep 'Link detected:'<<<"$ethtoolRes" |awk '{print $3}' |tr -d '\r\n')"
		netOK=$(grep 'yes'<<<"$netLnk")
		if [ -z "$netOK" ]; then netLnk="\e[0;31mDOWN\e[m"; else netLnk="\e[0;32mUP\e[m" ; fi
		netDevsMacs+=("  Device: $ethDev\tNet: $net\tLink: $netLnk\tSpeed: $netSpeed")
		let netDevIdx++
	done
	for line in "${netDevsMacs[@]}"; do
		echo -e "$line"
	done

}

netMonitorLoop() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local net nets devIpInfo
	local pauseParamsCmdRes globAutoNegParamsCmdRes pauseRxStateOn pauseTxStateOn pauseAutoNegStateOn globAutoNegStateOn
	local netStatsRes devPauseInfo devIpInfo loopCounter
	let loopCounter=0
	privateVarAssign "${FUNCNAME[0]}" "nets" "$*"
	if isDefined nets; then
		checkIfacesExist $nets
		echo -e "  Starting net monitor on ifaces: $org"$nets"$ec"
		while true; do
			netStatsRes="$(printNetsStats "--nets-req=$nets")"
			devIpInfo=""
			devPauseInfo=""
			for net in $nets; do
				devPauseInfo+="  $org$net$ec> "
				devIpInfo+="  $(ip a show $net |head -n1)\n"
				privateVarAssign "${FUNCNAME[0]}" "pauseParamsCmdRes" "$(ethtool -a $net)"
				pauseRxStateOn=$(grep -x "^RX.*on" <<<"$pauseParamsCmdRes")
				pauseTxStateOn=$(grep -x "^TX.*on" <<<"$pauseParamsCmdRes")
				pauseAutoNegStateOn=$(grep -x "^Autoneg.*on" <<<"$pauseParamsCmdRes")
				privateVarAssign "${FUNCNAME[0]}" "globAutoNegParamsCmdRes" "$(ethtool $net 2>/dev/null |grep -x ".*Auto.*negotiation:.*")"
				globAutoNegStateOn=$(grep -x "^.*: on$" <<<"$globAutoNegParamsCmdRes")
				
				if isDefined pauseAutoNegStateOn; then devPauseInfo+="AutoNeg: ${gr}ON$ec   "; else devPauseInfo+="AutoNeg: ${rd}OFF$ec  "; fi
				if isDefined pauseRxStateOn; then devPauseInfo+="RX: ${gr}ON$ec  "; else devPauseInfo+="RX: ${rd}OFF$ec "; fi
				if isDefined pauseTxStateOn; then devPauseInfo+="TX: ${gr}ON$ec "; else devPauseInfo+="TX: ${rd}OFF$ec"; fi
				if isDefined globAutoNegStateOn; then devPauseInfo+="  GLOBAL AutoNeg: ${gr}ON$ec   "; else devPauseInfo+="  GLOBAL AutoNeg: ${rd}OFF$ec  "; fi
				devPauseInfo+="\n"
			done
			clear
			echo -e " Loop: $loopCounter\n"
			echo -e "$netStatsRes\n"
			echo -e "\n"
			echo -e "$devIpInfo\n"
			echo -e "Pause params: \n$devPauseInfo\n"
			sleep 1
			let loopCounter++
		done
	fi
}

getDebugInfo() {
	echoSection "PCI List"
	lspci -nn
	echoSection "PCI Ethernet list"
	lspci -nn |grep Eth
	echoSection "PCI Tree"
	lspci -vnnt
	echoSection "Net devices info"
	printNetsTree
	echoSection "Ethernet info"
	ip a
	echoSection "Kernel messages"
	dmesg
	echoSection "Modules"
	lsmod
	echoSection "Full PCI devices info"
	lspci -vvv
}

function selectProgVer () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local subfCount currDir searchDir searchDirFolders
	privateVarAssign "selectProgVer" "fwPath" "$*"

	currDir=$(pwd)
	cd $fwPath
	searchDirFolders=(*/)

	subfCount=${#searchDirFolders[@]}
	if [[ ! -z $subfCount ]]; then
		echo "    here are ${#searchDirFolders[@]} versions available"
		select dir in "${searchDirFolders[@]}"; do 
			echo "    Ver: $(basename ${dir}) selected"'!'
			cd ${dir} >/dev/null
			break
		done
		fwPath=$(pwd)
		return 0
	else
		exitFail "No versions folder found in $(pwd)"
		cd $currDir
		return 1
	fi

}

getFwFromServ() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local seqPn syncPn 
	privateVarAssign "getFwFromServ" "seqPn" "$1"
	privateVarAssign "getFwFromServ" "syncPn" "$2"
	
	echo -e "   Syncing FW files from server.."
	
	echo -e -n "    Creating PN folder /root/$seqPn: "; echoRes "mkdir -p /root/$seqPn"
	echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
	echo -e -n "    Creating PN folder /mnt/$syncPn: "; echoRes "mkdir -p /mnt/$syncPn"
	
	echo -e -n "    Mounting FW folder to /mnt/$syncPn: "; echoRes "mount.cifs \\\\172.30.0.4\\e\\Server_DB\\$syncPn\\PRG /mnt/$syncPn"' -o user=LinuxCopy,pass=LnX5CpY'

	selectProgVer "/mnt/$syncPn"
	selVerRes=$?

	if [[ $selVerRes -eq 0 ]]; then
		
		echo -e -n "    Removing old .bin files from /root/$seqPn: "; echoRes "rm -f /root/$seqPn/*.bin"
		echo -e -n "    Syncing FW files to /root/$seqPn: "; echoRes "rsync -r --ignore-existing --chmod=D=rwx,F=rw $fwPath/ /root/$seqPn"
		echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"
		
		echo -e "   Done."
		cd /root/$seqPn
	else
		exitFail "Failed to select programing FW version!"
	fi
}

acquireVal() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local valDesc varSrc varTarg
	valDesc="$1"
	varSrc="$2"
	varTarg="$3"
	
	test -z "$valDesc" && exitFail "acquireVal exception, valDesc undefined!"
	test -z "$varSrc" && exitFail "acquireVal exception, varSrc undefined!"
	test -z "$varTarg" && exitFail "acquireVal exception, varTarg undefined!"
	
	test -z "${!varSrc}" && {
		read -p "  $valDesc: " varSrcVal
		eval $varTarg=$varSrcVal
	} || {
		eval $varTarg=${!varSrc}
		echo "  $valDesc: ${!varTarg}"
	}
}

publicNumAssign() {
	privateNumAssign "$1" $2
	echo -e "  $1=$2"
}

privateNumAssign() {
	local numInput varName numInput varNameDesc funcName retRes
	let retRes=0
	
	funcName="${FUNCNAME[1]}"
	varName="$1"
	shift
	numInput=$1 ;shift
	if [[ ! -z "$*" ]]; then except "function overloaded"; fi
	if isNumber numInput; then
		if [ ! "$funcName" == "beepSpk" ]; then
			if [ "$debugShowAssignations" = "1" -o -z "$debugMode" ]; then
				dmsg echo "funcName=$funcName  varName=$varName  numInput=$numInput"
			fi
		fi
		if [ -z "$funcName" ]; then
			let retRes++
			except "preEval check, funcName undefined!"
		else
			if [ -z "$varName" ]; then
				let retRes++
				except "preEval check, varName undefined!"
			else
				if [ -z "$numInput" ]; then
					let retRes++
					except "preEval check exception, $funcName: $varName definition failed, new value is undefined!"
				else
					eval "let $varName=\$numInput"
				fi
			fi
		fi
	else
		except "preEval check, new value for $varName: $numInput is not a number!"
	fi
	return $retRes
}

function privateVarAssign() {
	local varName varVal varNameDesc funcName retRes
	let retRes=0
	funcName="$1"
	shift
	varName="$1"
	shift
	varVal="$*"

	if [ ! "$funcName" == "beepSpk" ]; then
		if [ "$debugShowAssignations" = "1" -o -z "$debugMode" ]; then
			dmsg echo "funcName=$funcName  varName=$varName  varVal=$varVal"
		fi
	fi
	
	if [ -z "$funcName" ]; then
		let retRes++
		except "preEval check, funcName undefined!"
	else
		if [ -z "$varName" ]; then
			let retRes++
			except "preEval check, varName undefined!"
		else
			if [ -z "$varVal" ]; then
				let retRes++
				except "preEval check, new value for $varName is undefined!"
			else
				eval $varName=\$varVal
			fi
		fi
	fi
	
	return $retRes
}

publicVarAssign() {
	local varName varVal varNameDesc errMsg retRes
	let retRes=0
	varSeverity="$1"
	shift
	varName="$1"
	shift
	varVal=$@
	varNameDesc="$varName"
	errMsg=""

	if [ -z "$varName" ]; then
		let retRes++
		errMsg="preEval check, varName undefined!"
	else
		if [ -z "$varSeverity" ]; then
			let retRes++
			errMsg="preEval check, varSeverity for $varName undefined!"
		else
			if [ -z "$varVal" ]; then
				let retRes++
				errMsg="preEval check, new value for $varName is undefined!"
			fi
		fi
	fi

	if ! isDefined errMsg; then
		eval $varName=\$varVal
		echo -e "  $varNameDesc=${!varName}"
	else
		case "$varSeverity" in
			fatal) 
				critWarn "\t$(caller): $(printCallstack)"
				exitFail "$errMsg" 
			;;
			critical) critWarn "${FUNCNAME[0]} $errMsg" ;;
			warn) warn "${FUNCNAME[0]} $errMsg" ;;
			silent) ;;
			*) except "varSeverity not in range: $varSeverity"
		esac
	fi

	return $retRes
}

function checkPkgExist() {
	local pkgNameList
	privateVarAssign "${FUNCNAME[0]}" "pkgNameList" "$*"
	for pkg in $pkgNameList; do
		which $pkg >/dev/null 2>&1
		if ! [ $? -eq 0 ]; then 
			except "Package $pkg is not found in PATH, check package exists"
		fi
	done
}

function isBlockDevice() {
	local blockDev=$1 ;shift
	local blockDev statusRes isBlockDev
	let statusRes=0
	if [ -z "$blockDev" ]; then
		let statusRes++
	else
		isBlockDev="$(grep $blockDev<<<"$(ls /sys/class/block/ 2>&1)")"
		if [ -z "$isBlockDev" ]; then
			let statusRes++
		fi
	fi
	return $statusRes
}

function isMMCDevice() {
	local mmcDev=$1 ;shift
	local mmcDev statusRes isMmcDev
	let statusRes=0
	if [ -z "$mmcDev" ]; then
		let statusRes++
	else
		isMmcDev="$(grep $mmcDev<<<"$(ls /sys/class/mmc_host/ 2>&1)")"
		if [ -z "$isMmcDev" ]; then
			let statusRes++
		fi
	fi
	return $statusRes
}

function isNumber() {
	local varList=$*
	local varVal varValEval statusRes
	let statusRes=0
	re='^[+-]?[0-9]+$'
	for varVal in $varList; do
		varValEval=$(eval echo -ne "\$$varVal" 2>/dev/nul) 
		if [ -z "$varValEval" ]; then
			let statusRes++
		else
			if ! [[ $varValEval =~ $re ]] ; then
				let statusRes++
			fi
		fi
	done
	return $statusRes
}

function isDefined() {
	local varList=$*
	local varVal varValEval statusRes
	let statusRes=0

	for varVal in $varList; do
		varValEval=$(eval echo -ne "\$$varVal" 2>/dev/nul) 
		if [ -z "$varValEval" ]; then
			let statusRes++
		fi
	done
	return $statusRes
}

function fdExist() {
	local fdReqList=$*
	local fdReq fdList fdExist statusRes
	let statusRes=0

	fdList=$(ls -la /proc/$$/fd/ |grep /dev |awk '{print $9}')

	for fdReq in $fdReqList; do
		fdExist=$(echo -ne "$fdList" |grep -x "$fdReq" 2>/dev/nul) 
		if [ -z "$fdExist" ]; then
			let statusRes++
		fi
	done
	return $statusRes
}

function ifaceExist() {
	local ifaceReqList=$*
	local ifaceReq statusRes
	let statusRes=0

	for ifaceReq in $ifaceReqList; do
		if ! [ -e "/sys/class/net/$ifaceReq/" ]; then
			let statusRes++
		fi
	done
	return $statusRes
}

function contains() {
	local varReq="$1"; shift
	local varVal="$*"
	local containsValue
	if isDefined varVal; then
		containsValue="$(echo -n "$varVal" |grep "$varReq")"
		if isDefined containsValue; then
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

function checkDefinedVal () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local funcName varVal
	# dmsg inform "DEBUG> ${FUNCNAME[0]}> args: $*"
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	funcName="$1" ;shift
	varName="$1"
	# dmsg inform "DEBUG> ${FUNCNAME[0]}> funcName=$funcName varName=$varName"
	if [[ -z "$varName" ]]; then
		except "in $funcName: varName is undefined!"
	else
		if [[ -z "${!varName}" ]]; then
			except "in $funcName: value for $varName is undefined!"
		else
			return 0
		fi
	fi
}

checkDefined() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local funcName varName
	dmsg "args: $*"
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	varName="$1" ;shift
	checkOverload "$*"
	dmsg "funcName=$funcName varName=$varName"
	if [[ -z "${!varName}" ]]; then
		except "$varName is undefined!"
	fi
}

printCallstack() {
	local arrStart
	echo -n "${FUNCNAME[1]} requested callstack: "
	
	if [ -z "$(grep "ubuntu\|Fedora" /etc/os-release |grep -m1 "ID\|NAME")" ]; then
		let arrStart=${#FUNCNAME[*]:2}-1
	else
		let arrStart=${#FUNCNAME[*]}-3
	fi
	if [ ! -z "$arrStart" ]; then for (( idx=$arrStart ; idx>=1 ; idx-- )) ; do echo -n "${FUNCNAME[idx]}> "; done; fi
	echo -ne "\n"
}

printPIDTree() {
	local pid="$1"
	local indent=0
	local stack=()

	echo -n "$pid "
	# Traverse the call/creator tree iteratively
	while [ -n "$pid" ]; do
		stack+=("$pid") # Add PID to stack
		pid=$(ps -o ppid= -p "$pid") # Get parent PID

		# Print the current PID with appropriate indentation
		# printf "%${indent}s" ""
		# echo "PID: ${stack[-1]}"

		# indent=$((indent + 2)) # Increment indentation level

		echo -n $pid' '
	done
}

except() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local exceptDescr pidOnExcept
	pidOnExcept=$BASHPID
	#exceptParentPid=$(printPIDTree $pidOnExcept 2>/dev/null |awk '{print $4}')
	exceptParentPid=$(ps -o pid,ppid,cmd --ppid "${PIDStackArr[0]}" --forest 2>&1 |grep -v 'statusChk' |grep -m1 "${PIDStackArr[0]}" |awk '{print $1}')
	sendToKmsg `printDmsgStack 2>&1`
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	exceptDescr="$*"
	sendToKmsg "Exception raised: $exceptDescr"
	sendToKmsg "Exception callstack: $(caller): $(printCallstack)"
	sendToKmsg "Subshell level on exception execution: $BASH_SUBSHELL  Except parent PID: $exceptParentPid"
	sendToKmsg "PID tree (from 'except' pid: $pidOnExcept): $(printPIDTree $pidOnExcept 2>/dev/null)"
	if [ ! -z "$PIDStackArr" ]; then 
		sendToKmsg "Main shell parent pid: ${PIDStackArr[*]}"
	fi
	critWarn "\t$(caller): $(printCallstack)"
	if [ $BASH_SUBSHELL -gt 2 ]; then
		if [ ! -z "$exceptParentPid" ]; then
			exitFail "${FUNCNAME[1]} exception> $exceptDescr" $exceptParentPid
		else
			exitFail "${FUNCNAME[1]} exception> $exceptDescr" $BASH_SUBSHELL
		fi
	else
		exitFail "${FUNCNAME[1]} exception> $exceptDescr"
	fi
}

removeArg() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local targArg
	privateVarAssign "removeArg" "targArg" "$1"; shift
	echo -n "$*" | sed 's/'" $targArg"'//g'
}

checkOverload() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local callerFunc funcArgs argsNoFlags optFlag compKey
	callerFunc=${FUNCNAME[1]}
	# funcArgs="$*"

	if [[ ! -z "$*" ]]; then
		except "$callerFunc overloaded with parameters, unexpected args: $*"
	fi
}

speedWidthComp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local reqSpeed actSpeed reqWidth actWidth testSeverity compRule varAssigner
	#echo "speedWidthComp debug:  $1  =   $2  =   $3  =   $4"
	privateVarAssign "speedWidthComp" "reqSpeed" "$1"
	privateVarAssign "speedWidthComp" "actSpeed" "$2"
	privateVarAssign "speedWidthComp" "reqWidth" "$3"
	privateVarAssign "speedWidthComp" "actWidth" "$4"
	test -z "$5" && compRule="strict" || {
		test ! -z "$(echo -n $5 |grep -w 'strict\|minimum')" && {
			case "$5" in
				strict) compRule="strict" ;;	
				minimum) compRule="minimum" ;;
				*) testSeverity=$5 #empty=exit with fail  warn=just warn
			esac
		}
	}
	test -z "echo $1$2$3$4 |grep warn" && exitFail "speedWidthComp exception, var missmatch, possibly some are missing"
	test "$reqSpeed" = "$actSpeed" && {
		echo -e -n "\tSpeed: \e[0;32mOK\e[m"
	} || {
		test "$testSeverity" = "warn" && warn "\tSpeed: FAIL ($actSpeed, but expected: $reqSpeed)" || critWarn "\tSpeed: FAIL ($actSpeed, but expected: $reqSpeed)" $PROC
	}
	
	test "$reqWidth" = "$actWidth" && {
		echo -e -n "\tWidth: \e[0;32mOK\e[m"
	} || {
		test "$testSeverity" = "warn" && warn "\tWidth: FAIL ($actWidth, but expected: $reqWidth)" || critWarn "\tWidth: FAIL ($actWidth, but expected: $reqWidth)" $PROC
	}
}

function testLinks () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local netTarg linkReq uutModel netId retryCount linkAcqRes cmdRes devNumRDIF
	privateVarAssign "${FUNCNAME[0]}" "netTarg" "$1"
	privateVarAssign "${FUNCNAME[0]}" "linkReq" "$2"
	privateVarAssign "${FUNCNAME[0]}" "uutModel" "$3"
	case "$uutModel" in
		PE340G2DBIR|PE3100G2DBIR|PE310G4DBIR|PE310G4DBIR-T)
			privateVarAssign "${FUNCNAME[0]}" "devNumRDIF" "$4"
			privateVarAssign "${FUNCNAME[0]}" "retryCount" "$globLnkAcqRetr"
		;;
		*) 
			test ! -z "$4" && privateVarAssign "testLinks" "retryCount" "$4" || privateVarAssign "testLinks" "retryCount" "$globLnkAcqRetr"
		;;
	esac
	for ((r=0;r<=$retryCount;r++)); do 
		dmsg "try:$r"
		if [ ! "$linkReq" = "$linkAcqRes" ]; then
			if [ $r -gt 0 ]; then 
				inform --sil --nnl "."
				sleep $globLnkUpDel
			fi
			case "$uutModel" in
				PE310G4BPI71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G2BPI71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4I71|PE425G4I71L) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE340G2BPI71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE210G2BPI40) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4BPI40) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4I40) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4DBIR|PE310G4DBIR-T) 
					netId=$(net2bus "$netTarg" |cut -d. -f2)
					dmsg "netId=$netId"
					if [ "$netId" = "0" ]; then 
						linkReq="no"
						linkAcqRes="no"
					else
						linkAcqRes=$(rdifctl dev $devNumRDIF get_port_link $netId |grep UP)
						
						if [[ ! -z "$(echo $linkAcqRes |grep UP)" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
					fi
				;;
				PE340G2DBIR|PE3100G2DBIR|PE310G4DBIR|PE310G4DBIR-T) 
					linkAcqRes=$(rdifctl dev $devNumRDIF get_port_link $netTarg |grep UP)
					if [[ ! -z "$(echo $linkAcqRes |grep UP)" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
				;;
				PE310G4BPI9) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE210G2BPI9) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE210G2SPI9A) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE325G2I71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE31625G4I71L) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				M4E310G4I71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				P425G410G8TS81) linkAcqRes=$(ethtool $netTarg |grep 'Link detected:' |cut -d: -f2 |cut -d ' ' -f2);;
				P410G8TS81-XR) linkAcqRes=$(ethtool $netTarg |grep 'Link detected:' |cut -d: -f2 |cut -d ' ' -f2);;
				PE2G2I35) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE2G4I35) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				acNano) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				IBSGP-T-MC-AM) 
					cmdRes="$(sendIBS $uutSerDev get_link $netTarg |grep -w 'link' |cut -d: -f2- |cut -d. -f1 |awk '{print $2}')"
					if [[ "$cmdRes" = "up" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
				;;
				IBS10GP) 
					cmdRes="$(sendIBS $uutSerDev get_link $netTarg |grep -w 'link' |cut -d: -f2- |cut -d. -f1 |awk '{print $2}')"
					if [[ "$cmdRes" = "up" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
				;;
				IBSGP-T) 
					cmdRes="$(sendIBS $uutSerDev get_link $netTarg |grep -w 'link' |cut -d: -f2- |cut -d. -f1 |awk '{print $2}')"
					if [[ "$cmdRes" = "up" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
				;;
				*) exitFail "testLinks exception, Unknown uutModel: $uutModel"
			esac
			dmsg linkAcqRes=$linkAcqRes
		else
			dmsg "skipped because not empty"
		fi
	done
	if [[ ! -z "$linkAcqRes" ]]; then
		if [[ "$netId" = "0" ]]; then
			echo -e -n "\e[0;32m-\e[m" 
			return 0
		fi
		if [[ ! "$linkAcqRes" = "$linkReq" ]]; then
			echo -e -n "\e[0;31mFAIL\e[m"
			return 1
		else
			echo -e -n "\e[0;32mOK\e[m"
			return 0
		fi
	else
		if [[ "$linkReq" = "yes" ]]; then
			echo -e -n "\e[0;31mFAIL\e[m" 
			return 1
		else
			echo -e -n "\e[0;32mOK\e[m"
			return 0
		fi
	fi
}

getEthRates() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local netTarg speedReq uutModel linkAcqRes netId
	privateVarAssign "getEthRates" "netTarg" "$1"
	privateVarAssign "getEthRates" "speedReq" "$2"
	privateVarAssign "getEthRates" "uutModel" "$3"
	case "$uutModel" in
		PE340G2DBIR|PE3100G2DBIR)
			privateVarAssign "${FUNCNAME[0]}" "devNumRDIF" "$4"
			privateVarAssign "getEthRates" "retryCount" "$globRtAcqRetr"
		;;
		*) 
			if [[ ! -z "$4" ]]; then 
				privateVarAssign "getEthRates" "retryCount" "$4" 
			else
				privateVarAssign "getEthRates" "retryCount" "$globRtAcqRetr"
			fi
		;;
	esac

	
	for ((r=0;r<=$retryCount;r++)); do 
		dmsg "try:$r"
		if [ -z "$linkAcqRes" -a "$speedReq" != "Fail" ] || [ "$speedReq" != "Fail" -a -z "$(echo $linkAcqRes |grep $speedReq)" ]; then
			test $r -gt 0 && sleep 1
			case "$uutModel" in
				PE310G4BPI71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G2BPI71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4I71|PE425G4I71L) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE340G2BPI71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE210G2BPI40) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4BPI40) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4I40) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4DBIR|PE310G4DBIR-T) 
					netId=$(net2bus "$netTarg" |cut -d. -f2)
					test "$netId" = "0" && speedReq="Fail"
					linkAcqRes="Speed: $(rdifctl dev 0 get_port_speed $netId)Mb/s"
				;;
				PE340G2DBIR) 
					linkAcqRes="Speed: $(rdifctl dev $devNumRDIF get_port_speed $netTarg)Mb/s"
				;;
				PE3100G2DBIR) 
					linkAcqRes="Speed: $(rdifctl dev $devNumRDIF get_port_speed $netTarg)Mb/s"
				;;
				PE310G4BPI9) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE210G2BPI9) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE210G2SPI9A) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE325G2I71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE31625G4I71L) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				M4E310G4I71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				P410G8TS81-XR) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				P425G410G8TS81) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE2G2I35) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE2G4I35) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				*) except "unknown uutModel: $uutModel"
			esac
			dmsg linkAcqRes=$linkAcqRes
		else
			dmsg "linkAcqRes=$linkAcqRes"
			dmsg "skipped because not empty"
		fi
	done
	

	if [[ ! -z "$linkAcqRes" ]]; then
		if [[ -z "$(echo $linkAcqRes |sed 's/[^0-9]*//g' |grep -x $speedReq)" ]]; then
			if [[ "$speedReq" = "Fail" ]]; then
				echo -e -n "\e[0;32m-\e[m" 
			else
				echo -e -n "\e[0;31m$(echo $linkAcqRes |cut -d: -f2-) (FAIL)\e[m" 
			fi
		else
			echo -e -n "\e[0;32m$(echo $linkAcqRes |cut -d: -f2-)\e[m"
		fi
	else
		echo -e -n "\e[0;31mNO DATA\e[m" 
	fi
}

getEthSelftest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local netTarg
	privateVarAssign "getEthSelftest" "netTarg" "$1"	
	selftestRes=$(ethtool -t $netTarg |grep result |awk '{print $5}')
	test ! -z "$selftestRes" && {
		test -z "$(echo $selftestRes |grep "PASS")" && {
			echo -e -n "\e[0;31mFAIL\e[m" 
		} || echo -e -n "\e[0;32mPASS\e[m"
	} || {
		echo -e -n "\e[0;31mNO DATA\e[m" 
	}
}

function allNetAct () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local nets act actDesc net status counter
	privateVarAssign "${FUNCNAME[0]}" "nets" "$1"
	shift
	privateVarAssign "${FUNCNAME[0]}" "actDesc" "$1"
	shift
	privateVarAssign "${FUNCNAME[0]}" "act" "$1"
	shift
	privateVarAssign "${FUNCNAME[0]}" "actArgs" "$@"
	dmsg inform "nets:"$nets"  actDesc:"$actDesc"   act:"$act"   actArgs:"$actArgs
	case "$uutModel" in
		PE340G2DBIR|PE3100G2DBIR)
			echo -e -n "\t$actDesc: \n\t\t"; 
			let counter=1
			for net in $nets; do 
				echo -e -n "$net:"
				$act "$counter" $actArgs
				dmsg inform "net:"$net"  act:"$act"  counter:"$counter"  actArgs:"$actArgs
				let status+=$?
				echo -e -n "   "
			done
			echo -e -n "\n\n"
			return $status
		;;
		*) 
			echo -e -n "\t$actDesc: \n\t\t"; 
			for net in $nets; do 
				echo -e -n "$net:"
				$act "$net" $actArgs
				let status+=$?
				echo -e -n "   "
			done
			echo -e -n "\n\n"
			return $status
		;;
	esac
}

net2bus() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local net bus
	net=$1
	checkDefinedVal "${FUNCNAME[0]}" "net"
	bus=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent |grep "$net" |cut -d ':' -f3-)
	test -z "$bus" && except "bus returned nothing!" || echo -e -n "$bus"
}

filterDevsOnBus() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sourceBus filterDevs devsTotal
	if [[ -z "$debugMode" ]]; then  # it is messing up assignBuses because of debug messages
		privateVarAssign "${FUNCNAME[0]}" "sourceBus" "$1"	;shift
		privateVarAssign "${FUNCNAME[0]}" "filterDevs" "$*"
		privateVarAssign "${FUNCNAME[0]}" "devsOnSourceBus" $(ls -l /sys/bus/pci/devices/ |grep $sourceBus |awk -F/ '{print $NF}')
	else
		sourceBus="$1"	;shift
		filterDevs="$*"
		devsOnSourceBus=$(ls -l /sys/bus/pci/devices/ |grep $sourceBus |awk -F/ '{print $NF}')
	fi

	for devName in ${filterDevs[@]}; do
		for devOnSourceBus in "${devsOnSourceBus[@]}"; do
			echo "$devOnSourceBus"
		done | grep "$devName" > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			devsTotal+=( "$devName" )
			#dmsg inform "$devName is from source bus devs list"
		else
			echo -n "" #placeholder
			#dmsg inform "$devName is not related to source bus"
		fi
	done
	if [[ ! -z "$devsTotal" ]]; then 
		echo -n ${devsTotal[@]}
	else
		critWarn "resulting dev count is null" 1>&2
	fi
}

filterBpMast() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sourceBus filterDevs mastDevsTotal bpCmd
	if [[ -z "$debugMode" ]]; then  # it is messing up assignBuses because of debug messages
		privateVarAssign "devsOnBus" "bpCmd" "$1" ;shift
		privateVarAssign "devsOnBus" "filterDevs" "$*"
	else
		bpCmd="$1" ;shift
		filterDevs="$*"
	fi

	for devName in ${filterDevs[@]}; do
		busIsMast=$($bpCmd $devName get_bypass |grep unknown)
		if [[ -z "$busIsMast" ]]; then
			mastDevsTotal+=( "$devName" )
			dmsg inform "$devName is from source bus devs list"
		else
			:
		fi
	done
	if [[ ! -z "$mastDevsTotal" ]]; then echo -n ${mastDevsTotal[@]}; fi
}

clearPciVars() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	fullPciInfo=""
	pciInfoDevDesc=""
	pciInfoDevSubs=""
	pciInfoDevLnkCap=""
	pciInfoDevLnkStaFull=""
	pciInfoDevLnkSta=""
	pciInfoDevSpeed=""
	pciInfoDevWidth=""
	pciInfoDevKernMod=""
	pciInfoDevKernUse=""
	pciInfoDevSubInfo=""
	pciInfoDevSubdev=""
	pciInfoDevSubord=""
}

debugPciVars() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	 echo pciInfoDevDesc: $pciInfoDevDesc
	 echo pciInfoDevSubs: $pciInfoDevSubs
	 echo pciInfoDevLnkCap: $pciInfoDevLnkCap
	 echo pciInfoDevLnkSta: $pciInfoDevLnkSta
	 echo pciInfoDevSpeed: $pciInfoDevSpeed
	 echo pciInfoDevWidth: $pciInfoDevWidth
	 echo pciInfoDevCapSpeed: $pciInfoDevCapSpeed
	 echo pciInfoDevCapWidth: $pciInfoDevCapWidth
	 echo pciInfoDevKernMod: $pciInfoDevKernMod
	 echo pciInfoDevKernUse: $pciInfoDevKernUse
	 echo pciInfoDevSubInfo: $pciInfoDevSubInfo
	 echo pciInfoDevSubdev: $pciInfoDevSubdev
	 echo pciInfoDevSubord: $pciInfoDevSubord
}

gatherPciInfo() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local pciInfoDev nameLine
	pciInfoDev="$1"
	dmsg inform "pciInfoDev=$pciInfoDev"
	test -z "$pciInfoDev" && except "pciInfoDev in undefined" $PROC
	clearPciVars
	if [[ ! "$pciInfoDev" == *":"* ]]; then 
		pciInfoDev="$pciInfoDev:"
		dmsg inform "pciInfoDev appended, : wasnt found"
	fi
	fullPciInfo="$(lspci -nnvvvks $pciInfoDev 2>&1)"
	let nameLine=$(echo "$fullPciInfo" |grep -B9999 -m1 $pciInfoDev |wc -l)
	pciInfoDevDesc=$(echo "$fullPciInfo" |head -n$nameLine |tail -n1 |cut -d ':' -f3- |cut -d ' ' -f1-15)
	pciInfoDevSubs=$(echo "$fullPciInfo" |grep Subsystem: |cut -d ':' -f2- | awk '$1=$1')
	pciInfoDevLnkCap=$(echo "$fullPciInfo" |grep LnkCap: |cut -d ',' -f2-3 | awk '$1=$1')
	pciInfoDevLnkStaFull=$(echo "$fullPciInfo" |grep LnkSta:)
	pciInfoDevLnkSta=$(echo "$fullPciInfo" |grep LnkSta: |cut -d ',' -f1-2 |cut -d ':' -f2- | awk '$1=$1')
	pciInfoDevSpeed=$(echo $pciInfoDevLnkSta |cut -d ',' -f1 |rev |cut -d ' ' -f1 |rev |awk -F 'GT/s' '{print $1}')
	pciInfoDevWidth=$(echo $pciInfoDevLnkSta |cut -d ',' -f2 |awk '{print $2}' |cut -c2-)
	pciInfoDevCapSpeed=$(echo $pciInfoDevLnkCap |cut -d ',' -f1 |rev |cut -d ' ' -f1 |rev |awk -F 'GT/s' '{print $1}')
	pciInfoDevCapWidth=$(echo $pciInfoDevLnkCap |cut -d ',' -f2 |awk '{print $2}' |cut -c2-)
	pciInfoDevKernMod=$(echo "$fullPciInfo" |grep modules: |cut -d ':' -f2- | awk '$1=$1')
	pciInfoDevKernUse=$(echo "$fullPciInfo" |grep use: |cut -d ':' -f2- | awk '$1=$1')
	pciInfoDevPhysSlot=$(echo "$fullPciInfo" |grep "Physical Slot:" |cut -d ':' -f2- |rev |cut -d- -f1 |rev | awk '$1=$1')
	test -z "$(echo "$fullPciInfo" |grep Bus:)" || {
		pciInfoDevSubdev=$(echo "$fullPciInfo" |grep Bus: |cut -d ',' -f2 |cut -d '=' -f2 | awk '$1=$1')
		pciInfoDevSubord=$(echo "$fullPciInfo" |grep Bus: |cut -d ',' -f3 |cut -d '=' -f2 | awk '$1=$1')
		test "$pciInfoDevSubdev" = "$pciInfoDevSubord" && pciInfoDevSubInfo="  SubDevice: $pciInfoDevSubdev" || pciInfoDevSubInfo="  Subordinate: $pciInfoDevSubord  SubDevice: $pciInfoDevSubdev"
	}
}

listDevsPciLib() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local targBus accBuses plxBuses ethBuses bpBuses plxBus ethBus accBus bpBus fullPciInfo busInfo subdevInfo
	local ethKernReq plxKernReq accKernReq bpKernReq accDevArr plxDevArr plxDevSubArr plxDevEmptyArr bpDevArr
	local plxOnDevBus accOnDevBus ethOnDevBus bpOnDevBus
	local ethDevId ethVirtDevId accDevId plxDevId bpDevId
	local ethDevQtyReq ethVirtDevQtyReq accDevQtyReq plxDevQtyReq plxDevSubQtyReq plxDevEmptyQtyReq bpDevQtyReq
	local ethDevSpeed ethDevWidth ethVirtDevSpeed ethVirtDevWidth bpDevSpeed bpDevWidth
	local plxDevSpeed plxDevWidth plxDevSubSpeed plxDevSubWidth plxDevEmptySpeed plxDevEmptyWidth
	local accDevSpeed accDevWidth spcDevSpeed spcDevWidth
	local rootBusWidthCap rootBusSpeedCap
	local spcBuses spcDevId spcDevQtyReq spcKernReq spcDevSpeed spcDevWidth spcOnDevBus
	local plxKeyw plxVirtKeyw plxEmptyKeyw
	local listPciArg argsTotal infoMode noKernelMode
	local netRes slotWidthCap slotWidthMax slotNumLocal
	local secBus
	
	argsTotal=$*
	
	test -z "$argsTotal" && except "argsTotal undefined"
	
	for listPciArg in "$@"
	do
		dmsg inform "processing arg: $listPciArg"
		KEY=$(echo $listPciArg|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $listPciArg |cut -f2 -d=)
		#echo -e "\tlistDevsPciLib debug: processing arg: $listPciArg   KEY:$KEY   VALUE:$VALUE"
		case "$KEY" in
			target-bus) 		targBus=${VALUE} ;;
			sec-target-bus)		secBus=${VALUE} ;;
			acc-buses) 			accBuses=${VALUE} ;;
			spc-buses) 			spcBuses=${VALUE} ;;
			plx-buses) 			plxBuses=${VALUE} ;;
			eth-buses) 			ethBuses=${VALUE} ;;
			bp-buses) 			bpBuses=${VALUE} ;;
			
			eth-dev-id)			ethDevId=${VALUE} ;;
			eth-virt-dev-id)	ethVirtDevId=${VALUE} ;;
			acc-dev-id)			accDevId=${VALUE} ;;
			spc-dev-id)			spcDevId=${VALUE} ;;
			plx-dev-id)			plxDevId=${VALUE} ;;
			bp-dev-id)			bpDevId=${VALUE} ;;
			
			eth-dev-qty)		ethDevQtyReq=${VALUE} ;;
			eth-virt-dev-qty)	ethVirtDevQtyReq=${VALUE} ;;
			acc-dev-qty)		accDevQtyReq=${VALUE} ;;
			spc-dev-qty)		spcDevQtyReq=${VALUE} ;;
			plx-dev-qty)		plxDevQtyReq=${VALUE} ;;
			plx-dev-sub-qty)	plxDevSubQtyReq=${VALUE} ;;
			plx-dev-upst-qty)	plxDevUpstQtyReq=${VALUE} ;;
			plx-dev-empty-qty)	plxDevEmptyQtyReq=${VALUE} ;;
			bp-dev-qty)			bpDevQtyReq=${VALUE} ;;
			
			dev-kernel) 		devKernReq=${VALUE} ;;
			eth-kernel) 		ethKernReq=${VALUE} ;;
			eth-virt-kernel) 	ethVirtKernReq=${VALUE} ;;
			plx-kernel) 		plxKernReq=${VALUE} ;;
			acc-kernel) 		accKernReq=${VALUE} ;;
			spc-kernel) 		spcKernReq=${VALUE} ;;
			bp-kernel) 			bpKernReq=${VALUE} ;;
			
			eth-dev-speed)			ethDevSpeed=${VALUE} ;;
			eth-dev-width)			ethDevWidth=${VALUE} ;;
			eth-virt-dev-speed)		ethVirtDevSpeed=${VALUE} ;;
			eth-virt-dev-width)		ethVirtDevWidth=${VALUE} ;;
			spc-dev-speed)			spcDevSpeed=${VALUE} ;;
			spc-dev-width)			spcDevWidth=${VALUE} ;;
			plx-dev-speed)			plxDevSpeed=${VALUE} ;;
			plx-dev-width)			plxDevWidth=${VALUE} ;;
			plx-dev-sub-speed)		plxDevSubSpeed=${VALUE} ;;
			plx-dev-sub-width)		plxDevSubWidth=${VALUE} ;;
			plx-dev-upst-speed)		plxDevUpstSpeed=${VALUE} ;;
			plx-dev-upst-width)		plxDevUpstWidth=${VALUE} ;;
			plx-dev-empty-speed)	plxDevEmptySpeed=${VALUE} ;;
			plx-dev-empty-width)	plxDevEmptyWidth=${VALUE} ;;
			acc-dev-speed)			accDevSpeed=${VALUE} ;;
			acc-dev-width)			accDevWidth=${VALUE} ;;
			bp-dev-speed)			bpDevSpeed=${VALUE} ;;
			bp-dev-width)			bpDevWidth=${VALUE} ;;
			
			root-bus-speed)			rootBusSpeedCap=${VALUE} ;;
			root-bus-width)			rootBusWidthCap=${VALUE} ;;
			
			plx-keyw)				plxKeyw=${VALUE} ;;
			plx-virt-keyw)			plxVirtKeyw=${VALUE} ;;
			plx-empty-keyw)			plxEmptyKeyw=${VALUE} ;;
			plx-upst-keyw)			plxUpstKeyw=${VALUE} ;;
			
			info-mode)				infoMode="true" ;;
			no-kern)				noKernelMode="true" ;;
			slot-width-cap)			slotWidthCap=${VALUE} ;;
			slot-width-max)			slotWidthMax=${VALUE} ;;
			slot-number)			slotNumLocal=${VALUE} ;;

			*) except "unknown arg: $listPciArg"
		esac
	done
	
	test -z "$debugMode" || {
		dmsg inform "targBus=$targBus"
		dmsg inform "accBuses=$accBuses"
		dmsg inform "spcBuses=$spcBuses"
		dmsg inform "plxBuses=$plxBuses"
		dmsg inform "ethBuses=$ethBuses"
		dmsg inform "bpBuses=$bpBuses"
		dmsg inform "secBusAddr=$secBusAddr"
				
		dmsg inform "ethDevId=$ethDevId"
		dmsg inform "ethVirtDevId=$ethVirtDevId"
		dmsg inform "accDevId=$accDevId"
		dmsg inform "spcDevId=$spcDevId"
		dmsg inform "plxDevId=$plxDevId"
		dmsg inform "bpDevId=$bpDevId"
				
		dmsg inform "ethDevQtyReq=$ethDevQtyReq"
		dmsg inform "ethVirtDevQtyReq=$ethVirtDevQtyReq"
		dmsg inform "accDevQtyReq=$accDevQtyReq"
		dmsg inform "spcDevQtyReq=$spcDevQtyReq"
		dmsg inform "plxDevQtyReq=$plxDevQtyReq"
		dmsg inform "plxDevSubQtyReq=$plxDevSubQtyReq"
		dmsg inform "plxDevUpstQtyReq=$plxDevUpstQtyReq"
		dmsg inform "plxDevEmptyQtyReq=$plxDevEmptyQtyReq"
		dmsg inform "bpDevQtyReq=$bpDevQtyReq"
				
		dmsg inform "devKernReq=$devKernReq"
		dmsg inform "ethKernReq=$ethKernReq"
		dmsg inform "ethVirtKernReq=$ethVirtKernReq"
		dmsg inform "plxKernReq=$plxKernReq"
		dmsg inform "accKernReq=$accKernReq"
		dmsg inform "spcKernReq=$spcKernReq"
		dmsg inform "bpKernReq=$bpKernReq"
				
		dmsg inform "ethDevSpeed=$ethDevSpeed"
		dmsg inform "ethDevWidth=$ethDevWidth"
		dmsg inform "ethVirtDevSpeed=$ethVirtDevSpeed"
		dmsg inform "ethVirtDevWidth=$ethVirtDevWidth"
		dmsg inform "spcDevSpeed=$spcDevSpeed"
		dmsg inform "spcDevWidth=$spcDevWidth"
		dmsg inform "plxDevSpeed=$plxDevSpeed"
		dmsg inform "plxDevWidth=$plxDevWidth"
		dmsg inform "plxDevSubSpeed=$plxDevSubSpeed"
		dmsg inform "plxDevSubWidth=$plxDevSubWidth"
		dmsg inform "plxDevEmptySpeed=$plxDevEmptySpeed"
		dmsg inform "plxDevEmptyWidth=$plxDevEmptyWidth"
		dmsg inform "accDevSpeed=$accDevSpeed"
		dmsg inform "accDevWidth=$accDevWidth"
		dmsg inform "bpDevSpeed=$bpDevSpeed"
		dmsg inform "bpDevWidth=$bpDevWidth"
		dmsg inform "rootBusSpeedCap=$rootBusSpeedCap"
		dmsg inform "rootBusWidthCap=$rootBusWidthCap"
				
		dmsg inform "plxKeyw=$plxKeyw"
		dmsg inform "plxVirtKeyw=$plxVirtKeyw"
		dmsg inform "plxEmptyKeyw=$plxEmptyKeyw"
		dmsg inform "plxUpstKeyw=$plxUpstKeyw"
		
		dmsg inform "infoMode=$infoMode"
		dmsg inform "noKernelMode=$noKernelMode"
		
	}
	
	#devId=$pciDevId

	#pciDevs=$(grep PCI_ID /sys/bus/pci/devices/*/uevent | tr '[:lower:]' '[:upper:]' |grep :$devId |cut -d '/' -f6 |cut -d ':' -f2- |grep $targBus:)
	#test -z "$pciDevs" && {
	#	critWarn "No :$devId devices found on bus $targBus!"
	#	exit 1
	#}
	test -z "$targBus" && except "targBus is undefined"
	# slotBus root is now defined earlier
	dmsg inform "SLOTBUS=$slotBus"
	dmsg inform "targBus=$targBus"
	privateVarAssign "listDevsPciLib" "slotBus" "$(ls -l /sys/bus/pci/devices/ |grep -m1 :$targBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')"

	#slotBus=$targBus
	dmsg inform "slotBus=$slotBus"
	
	if [[ -z $infoMode ]]; then
		if [ -z "$rootBusSpeedCap" -a -z "$rootBusWidthCap" ]; then
			warn "  =========================================================  \n" "sil"
			warn "  ===     PCIe root bus requirments are undefined!!     ===  \n" "sil"
			warn "  =========================================================  \n" "sil"

		else
			echo -e "\n\tPCIe root bus" 
			echo -e "\t -------------------------"
				gatherPciInfo $slotBus
				dmsg debugPciVars
				echo -e "\t "'|'" PCIe root bus: $slotBus"
				echo -e "\t "'|'" Speed required: $rootBusSpeedCap   Width required: $rootBusWidthCap"
				if [ -z "$rootBusSpeedCap" -o -z "$rootBusWidthCap" ]; then
					if [ -z "$rootBusSpeedCap" ]; then
						rootBusSpeedCap=$pciInfoDevCapSpeed
					else
						rootBusWidthCap=$pciInfoDevCapWidth
					fi
				fi
				rootBusSpWdRes="$(speedWidthComp $rootBusSpeedCap $pciInfoDevCapSpeed $rootBusWidthCap $pciInfoDevCapWidth)"
				echo -e -n "\t "'|'" $rootBusSpWdRes\n"
			echo -e "\t -------------------------"
			test ! -z "$(echo "$rootBusSpWdRes" |grep FAIL)" && exitFail "Root bus speed is incorrect! Check PCIe BIOS settings."
		fi
	fi

	dmsg critWarn "check if next hex addr by bus existing and pciInfoDevPhysSlot corresponds to the slotNumLocal"

	test ! -z "$plxBuses" && {
		for bus in $plxBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(getDevsOnPciRootBus $(getPciSlotRootBus $targBus) |grep -w $bus)
			test -z "$exist" || plxOnDevBus=$(echo $plxOnDevBus $bus)
		done
		dmsg inform "plxOnDevBus=$plxOnDevBus"
	}
	test ! -z "$accBuses" && {
		for bus in $accBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(getDevsOnPciRootBus $(getPciSlotRootBus $targBus) |grep -w $bus)
			test -z "$exist" || accOnDevBus=$(echo $accOnDevBus $bus)
		done
		dmsg inform "accOnDevBus=$accOnDevBus"
	}
	test ! -z "$spcBuses" && {
		for bus in $spcBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(getDevsOnPciRootBus $(getPciSlotRootBus $targBus) |grep -w $bus)
			test -z "$exist" || spcOnDevBus=$(echo $spcOnDevBus $bus)
		done
		dmsg inform "spcOnDevBus=$spcOnDevBus"
	}
	test ! -z "$ethBuses" && {
		for bus in $ethBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(getDevsOnPciRootBus $(getPciSlotRootBus $targBus) |grep -w $bus)
			test -z "$exist" || ethOnDevBus=$(echo $ethOnDevBus $bus)
		done
		dmsg inform "ethOnDevBus=$ethOnDevBus"
	}
	test ! -z "$bpBuses" && {
		for bus in $bpBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(getDevsOnPciRootBus $(getPciSlotRootBus $targBus) |grep -w $bus)
			test -z "$exist" || bpOnDevBus=$(echo $bpOnDevBus $bus)
		done
		dmsg inform "bpOnDevBus=$bpOnDevBus"
	}
	
	# dmsg inform "WAITING FOR INPUT1"
	# dmsg read foo
	
	dmsg inform "plxOnDevBus=$plxOnDevBus"
	if [[ -z "$plxOnDevBus" ]]; then
		dmsg inform "plxOnDevBus is empty\ndbg3: >$plxDevQtyReq$plxDevSubQtyReq$plxDevEmptyQtyReq$plxKern$plxDevId<"
		if [ -z "$plxDevSubQtyReq" -a -z "$plxDevQtyReq" -a -z "$plxDevEmptyQtyReq" -a -z "$plxKernReq" -a -z "$plxDevId" ]; then
			dmsg inform "plxOnDevBus empty"
		else
			critWarn "  PLX bus empty! PCI info on PLX failed!"
		fi
	else
		dmsg inform "plxOnDevBus is not empty\nPLX is not empty! there is: >$plxOnDevBus<"
		if [[ -z $infoMode ]]; then
			test -z "$plxDevQtyReq$plxDevSubQtyReq$plxDevEmptyQtyReq" && except "no quantities are defined on PLX!"
			checkDefinedVal "${FUNCNAME[0]}" "plxKernReq" "$plxKernReq"
			if [[ -z "$plxDevQtyReq" ]]; then 
				except "plxDevQtyReq undefined, but devices found"
			else
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSpeed" "$plxDevSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevWidth" "$plxDevWidth"
			fi

			if [[ -z "$plxDevSubQtyReq" ]]; then 
				except "plxDevSubQtyReq undefined, but devices found"
			else
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSubSpeed" "$plxDevSubSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSubWidth" "$plxDevSubWidth"
			fi
			if [[ -z "$plxDevUpstQtyReq" ]]; then 
				except "plxDevUpstQtyReq undefined, but devices found"
			else
				checkDefinedVal "${FUNCNAME[0]}" "plxDevUpstSpeed" "$plxDevUpstSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevUpstWidth" "$plxDevUpstWidth"
			fi			
			if [[ -z "$plxDevEmptyQtyReq" ]]; then 
				except "plxDevEmptyQtyReq undefined, but devices found"
			else
				checkDefinedVal "${FUNCNAME[0]}" "plxDevEmptySpeed" "$plxDevEmptySpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevEmptyWidth" "$plxDevEmptyWidth"
			fi
		fi
		plxDevArr=""
		plxDevSubArr=""
		plxDevEmptyArr=""
		subdevInfo=""
		if [[ -z $infoMode ]]; then
			echo -e "\n\tPLX Devices" 
			echo -e "\t -------------------------"
		fi
		dmsg inform "plxOnDevBus=$plxOnDevBus"
		for plxBus in $plxOnDevBus ; do
			dmsg inform "Processing plxBus=$plxBus"
			gatherPciInfo $plxBus
			# dmsg debugPciVars
			checkDefinedVal "${FUNCNAME[0]}" "plxKeyw" "$plxKeyw"
			dmsg inform " keyw:$plxKeyw fullPciInfo: $(echo "$fullPciInfo" |grep -w "$plxKeyw")"
			#warn "full PCI: $fullPciInfo"
			if [ ! -z "$(echo "$fullPciInfo" |grep -w "$plxKeyw")" ]; then
				dmsg inform ">> $plxBus is physical device"
				plxDevArr="$plxBus $plxDevArr"
				dmsg inform "Added plxBus=$plxBus to plxDevArr=$plxDevArr"
				if [[ -z $infoMode ]]; then
					echo -e "\t "'|'" $plxBus:$cy PLX Physical Device$ec: $pciInfoDevDesc"
					echo -e -n "\t "'|'" $(speedWidthComp $plxDevSpeed $pciInfoDevSpeed $plxDevWidth $pciInfoDevWidth)"
				else
					echo -e "$plxBus:$cy PLX Phys$ec: $pciInfoDevDesc"
					echo -e -n "\t  $pciInfoDevLnkSta"
				fi
			else
				dmsg inform ">> $plxBus is NOT a physical device"
				checkDefinedVal "${FUNCNAME[0]}" "plxVirtKeyw" "$plxVirtKeyw"
				if [ ! -z "$(echo "$fullPciInfo" |grep -w "$plxVirtKeyw")" ]; then
					plxDevSubArr="$plxBus $plxDevSubArr"
					dmsg inform "Added plxBus=$plxBus to plxDevSubArr=$plxDevSubArr"
					if [[ -z $infoMode ]]; then
						echo -e "\t "'|'" $plxBus:$cy PLX Virtual Device$ec: $pciInfoDevDesc"
						echo -e -n "\t "'|'" $(speedWidthComp $plxDevSubSpeed $pciInfoDevSpeed $plxDevSubWidth $pciInfoDevWidth)"
					else
						echo -e "$plxBus:$cy PLX Virt$ec: $pciInfoDevDesc"
						echo -e -n "\t  $pciInfoDevLnkSta"
					fi
					dmsg inform ">> $plxBus have subordinate"
				else
					if [ ! -z "$plxUpstKeyw" ]; then
						dmsg inform "upstream keyword present"
						if [ ! -z "$(echo "$fullPciInfo" |grep -w "$plxUpstKeyw")" ]; then
							plxDevUpstArr="$plxBus $plxDevUpstArr"
							dmsg inform "Added plxBus=$plxBus to plxDevUpstArr=$plxDevUpstArr"
							if [[ -z $infoMode ]]; then
								echo -e "\t "'|'" $plxBus:$cy PLX Upstream Device$ec: $pciInfoDevDesc"
								echo -e -n "\t "'|'" $(speedWidthComp $plxDevUpstSpeed $pciInfoDevSpeed $plxDevUpstWidth $pciInfoDevWidth)"
							else
								echo -e "$plxBus:$cy PLX Upst$ec: $pciInfoDevDesc"
								echo -e -n "\t  $pciInfoDevLnkSta"
							fi
							dmsg inform ">> $plxBus is upstream port"
						else
							plxDevEmptyArr="$plxBus $plxDevEmptyArr"
							dmsg inform "Added plxBus=$plxBus to plxDevEmptyArr=$plxDevEmptyArr"
							if [[ -z $infoMode ]]; then
								echo -e "\t "'|'" $plxBus:$cy PLX Virtual Device $ec\e[0;33m(empty)\e[m: $pciInfoDevDesc"
								echo -e -n "\t "'|'" $(speedWidthComp $plxDevEmptySpeed $pciInfoDevSpeed $plxDevEmptyWidth $pciInfoDevWidth)"
							else
								echo -e "$plxBus:$cy PLX Virt Empty$ec: $pciInfoDevDesc"
								echo -e -n "\t  $pciInfoDevLnkSta"
							fi
							dmsg inform ">> $plxBus is empty"
						fi
					else
						plxDevEmptyArr="$plxBus $plxDevEmptyArr"
						dmsg inform "Added plxBus=$plxBus to plxDevEmptyArr=$plxDevEmptyArr"
						if [[ -z $infoMode ]]; then
							echo -e "\t "'|'" $plxBus:$cy PLX Virtual Device $ec\e[0;33m(empty)\e[m: $pciInfoDevDesc"
							echo -e -n "\t "'|'" $(speedWidthComp $plxDevEmptySpeed $pciInfoDevSpeed $plxDevEmptyWidth $pciInfoDevWidth)"
						else
							echo -e "$plxBus:$cy PLX Virt Empty$ec: $pciInfoDevDesc"
							echo -e -n "\t  $pciInfoDevLnkSta"
						fi
						dmsg inform ">> $plxBus is empty"
					fi
				fi
			fi
			if [[ -z $infoMode ]]; then
				echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse|grep $plxKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
			else
				test -z "$pciInfoDevKernUse" && echo " Kern: not loaded" || echo " Kern: $pciInfoDevKernUse"
			fi
		done
		if [[ -z $infoMode ]]; then
			printf '\033[1A'
			echo -e "\t -------------------------"
			echo -e "\n\n\tPLX Device count" 
			testArrQty "  Physical" "$plxDevArr" "$plxDevQtyReq" "No PLX physical devices found on UUT" "warn"
			testArrQty "  Virtual" "$plxDevSubArr" "$plxDevSubQtyReq" "No PLX virtual devices found on UUT" "warn"
			testArrQty "  Upstream" "$plxDevUpstArr" "$plxDevUpstQtyReq" "No PLX Upstream devices found on UUT" "warn"
			testArrQty "  Virtual (empty)" "$plxDevEmptyArr" "$plxDevEmptyQtyReq" "No PLX virtual devices (empty) found on UUT" "warn"
		fi
	fi
	
	dmsg inform "accOnDevBus=$accOnDevBus"
	if [[ -z "$accOnDevBus" ]]; then
		test -z "$accKernReq$accDevQtyReq$accDevSpeed$accDevWidth" || critWarn "  ACC bus empty! PCI info on ACC failed!"
	else
		if [[ -z $infoMode ]]; then
			if [ -z "$accKernReq" -a -z "$noKernelMode" ]; then except "accKernReq undefined!"; fi
			test -z "$accDevQtyReq" && except "accDevQtyReq undefined, but devices found" || {
				test -z "$accDevSpeed" && except "accDevSpeed undefined!"
				test -z "$accDevWidth" && except "accDevWidth undefined!"
			}
		fi
		accDevArr=""  
		subdevInfo=""
		if [[ -z $infoMode ]]; then
			echo -e "\n\tACC Devices" 
			echo -e "\t -------------------------"
		fi
		for accBus in $accOnDevBus ; do
			gatherPciInfo $accBus
			dmsg inform "Processing accBus=$accBus"
			accDevArr="$accBus $accDevArr"
			dmsg inform "Added accBus=$accBus to accDevArr=$accDevArr"
			if [[ -z $infoMode ]]; then
				echo -e "\t "'|'" $accBus:$pr ACC Device$ec: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $accDevSpeed $pciInfoDevSpeed $accDevWidth $pciInfoDevWidth)"
			else
				echo -e "$accBus:$pr ACC$ec: $pciInfoDevDesc"
				echo -e -n "\t  $pciInfoDevLnkSta"
			fi
			if [[ -z $infoMode ]]; then
				if [[ -z $noKernelMode ]]; then
					echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $accKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
				else
					echo -en "\tKERN: \e[0;33mSKIPPED\e[m\n\t "'|'"\n"
				fi
			else
				test -z "$pciInfoDevKernUse" && echo " Kern: not loaded" || echo " Kern: $pciInfoDevKernUse"
			fi
		done
		if [[ -z $infoMode ]]; then
			printf '\033[1A'
			echo -e "\t -------------------------"
			echo -e "\n\n\tACC Device count" 
			testArrQty "  ACC Devices" "$accDevArr" "$accDevQty" "No ACC devices found on UUT" "warn"
		fi
	fi
	
	dmsg inform "ethOnDevBus=$ethOnDevBus"
	if [[ -z "$ethOnDevBus" ]]; then
		test -z "$ethDevQtyReq$ethVirtDevQtyReq$ethKernReq$ethDevId" || critWarn "  ETH bus empty! PCI info on ETH failed!"
	else
		if [[ -z $infoMode ]]; then
			test -z "$ethDevQtyReq$ethVirtDevQtyReq" && except "no quantities are defined on ETH!"
			if [ -z "$ethKernReq" -a -z "$noKernelMode" ]; then except "ethKernReq undefined!"; fi
			test -z "$ethDevQtyReq" && except "ethDevQtyReq undefined, but devices found" || {
				test -z "$ethDevSpeed" && except "ethDevSpeed undefined!"
				test -z "$ethDevWidth" && exitFail "listDevsPciLib exception, ethDevWidth undefined!"
			}
			test ! -z "$ethVirtDevQtyReq" && {
				test -z "$ethVirtDevSpeed" && exitFail "listDevsPciLib exception, ethVirtDevSpeed undefined!"
				test -z "$ethVirtDevWidth" && exitFail "listDevsPciLib exception, ethVirtDevWidth undefined!"
			}
		fi
		ethDevArr=""
		ethVirtDevArr=""
		if [[ -z $infoMode ]]; then
			echo -e "\n\tETH Devices" 
			echo -e "\t -------------------------"
		fi
		for ethBus in $ethOnDevBus ; do
			gatherPciInfo $ethBus
			dmsg inform "Processing ethBus=$ethBus"
			dmsg debugPciVars
			if [ ! -z "$(echo "$fullPciInfo" |grep 'Capabilities' |grep -w 'Power Management')" ]; then
				#echo "DEBUG: $ethBus is physical device"
				ethDevArr="$ethBus $ethDevArr"
				dmsg inform "Added ethBus=$ethBus to ethDevArr=$ethDevArr"
				if [[ -z $infoMode ]]; then
					echo -e "\t "'|'" $ethBus:$gr ETH Physical Device$ec: $pciInfoDevDesc"
					echo -e -n "\t "'|'" $(speedWidthComp $ethDevSpeed $pciInfoDevSpeed $ethDevWidth $pciInfoDevWidth)"
				else
					netRes=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $ethBus|awk -F/ '{print $NF}')
					echo -e "$ethBus:$gr ETH Phys$ec (\e[0;33m$netRes\e[m): $pciInfoDevDesc"
					echo -e -n "\t  $pciInfoDevLnkSta"
				fi
			else
				ethVirtDevArr="$ethBus $ethVirtDevArr"
				dmsg inform "Added ethBus=$ethBus to ethVirtDevArr=$ethVirtDevArr"
				if [[ -z $infoMode ]]; then
					echo -e "\t "'|'" $ethBus:$gr ETH Virtual Device$ec: $pciInfoDevDesc"
					echo -e -n "\t "'|'" $(speedWidthComp $ethVirtDevSpeed $pciInfoDevSpeed $ethVirtDevWidth $pciInfoDevWidth)"
					#echo "DEBUG: $ethBus have subordinate"
				else
					netRes=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $ethBus|awk -F/ '{print $NF}')
					echo -e "$ethBus:$gr ETH Virt$ec (\e[0;33m$netRes\e[m): $pciInfoDevDesc"
					echo -e -n "\t  $pciInfoDevLnkSta"
				fi
			fi
			if [[ -z $infoMode ]]; then
				echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse|grep $ethKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
			else
				test -z "$pciInfoDevKernUse" && echo " Kern: not loaded" || echo " Kern: $pciInfoDevKernUse"
			fi
			#echo -e "\t--------------"
		done
		if [[ -z $infoMode ]]; then
			printf '\033[1A'
			echo -e "\t -------------------------"
			echo -e "\n\n\tETH Device count" 
			testArrQty "  Physical" "$ethDevArr" "$ethDevQtyReq" "No ETH physical devices found on UUT" "warn"
			testArrQty "  Virtual" "$ethVirtDevArr" "$ethVirtDevQtyReq" "No ETH virtual devices found on UUT" "warn"
		fi
	fi
	
	dmsg inform "bpOnDevBus=$bpOnDevBus"
	if [[ ! -z "$bpOnDevBus" ]]; then
		if [[ -z $infoMode ]]; then
			test -z "$bpDevQtyReq" && except "no quantities are defined on BP!"
			if [ -z "$bpKernReq" -a -z "$noKernelMode" ]; then except "bpKernReq undefined!"; fi
			test -z "$bpDevQtyReq" && except "bpDevQtyReq undefined, but devices found" || {
				test -z "$bpDevSpeed" && except "bpDevSpeed undefined!"
				test -z "$bpDevWidth" && except "bpDevWidth undefined!"
			}
		fi
		bpDevArr=""  
		if [[ -z $infoMode ]]; then
			echo -e "\n\tBP Devices" 
			echo -e "\t -------------------------"
		fi
		for bpBus in $bpOnDevBus ; do
			gatherPciInfo $bpBus
			dmsg inform "Processing bpBus=$bpBus"
			bpDevArr="$bpBus $bpDevArr"
			dmsg inform "Added bpBus=$bpBus to bpDevArr=$bpDevArr"
			if [[ -z $infoMode ]]; then
				echo -e "\t "'|'" $bpBus: $blw"'BP Device'"$ec: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $bpDevSpeed $pciInfoDevSpeed $bpDevWidth $pciInfoDevWidth)"
			else
				echo -e "$bpBus: $blw\BP Dev$ec: $pciInfoDevDesc"
				echo -e -n "\t  $pciInfoDevLnkSta"
			fi
			if [[ -z $infoMode ]]; then
				echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $bpKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
			else
				test -z "$pciInfoDevKernUse" && echo " Kern: not loaded" || echo " Kern: $pciInfoDevKernUse"
			fi			
		done
		if [[ -z $infoMode ]]; then
			printf '\033[1A'
			echo -e "\t -------------------------"
			echo -e "\n\n\tBP Device count" 
			testArrQty " BP Devices" "$bpDevArr" "$bpDevQtyReq" "No BP devices found on UUT" "warn"
		fi
	else
		test -z "$bpDevQtyReq$bpKernReq$bpDevSpeed$bpDevWidth$bpDevId" || critWarn "  BP bus empty! PCI info on BP failed!"
	fi
	
	dmsg inform "spcOnDevBus=$spcOnDevBus"
	if [[ -z "$spcOnDevBus" ]]; then
		test -z "$spcDevQtyReq$spcKernReq$spcDevSpeed$spcDevWidth$spcDevId" || critWarn "  SPC bus empty! PCI info on SPC failed!"
	else
		if [[ -z $infoMode ]]; then
			test -z "$spcDevQtyReq" && exitFail "listDevsPciLib exception, no quantities are defined on SPC!"
			if [ -z "$spcKernReq" -a -z "$noKernelMode" ]; then except "spcKernReq undefined!"; fi
			test -z "$spcDevQtyReq" && exitFail "listDevsPciLib exception, spcDevQtyReq undefined, but devices found" || {
				test -z "$spcDevSpeed" && exitFail "listDevsPciLib exception, spcDevSpeed undefined!"
				test -z "$spcDevWidth" && exitFail "listDevsPciLib exception, spcDevWidth undefined!"
			}
		fi
		spcDevArr=""  
		if [[ -z $infoMode ]]; then
			echo -e "\n\tSPC Devices" 
			echo -e "\t -------------------------"
		fi
		for spcBus in $spcOnDevBus ; do
			gatherPciInfo $spcBus
			dmsg inform "Processing spcBus=$spcBus"
			spcDevArr="$spcBus $spcDevArr"
			dmsg inform "Added spcBus=$spcBus to spcDevArr=$spcDevArr"
			if [[ -z $infoMode ]]; then
				echo -e "\t "'|'" $spcBus:$yl SPC Device$ec: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $spcDevSpeed $pciInfoDevSpeed $spcDevWidth $pciInfoDevWidth)\n\t "'|------'"\n"
			else
				echo -e "$spcBus:$yl SPC Dev$ec: $pciInfoDevDesc"
				echo -e -n "\t  $pciInfoDevLnkSta"			
			fi
			if [[ -z $infoMode ]]; then
				echo null_placeholder > /dev/null
				#echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $spcKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
			else
				test -z "$pciInfoDevKernUse" && echo " Kern: not loaded" || echo " Kern: $pciInfoDevKernUse"
			fi	
			
		done
		if [[ -z $infoMode ]]; then
			printf '\033[1A'
			echo -e "\t -------------------------"
			echo -e "\n\n\tSPC Device count" 
			testArrQty "  SPC Devices" "$spcDevArr" "$spcDevQtyReq" "No SPC devices found on UUT" "warn"
		fi
	fi
}

checkIfContains() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local reqVal actVal compDesc reqValWithDelimeter
	compDesc=$1
	reqValWithDelimeter=$2
	reqVal="$(echo "$reqValWithDelimeter" |cut -c3-)"
	actVal=$3
	severity=$4

	
	if [[ ! -z "$reqVal" ]]; then
		echo -e -n "\t$compDesc: "
		if [[ ! -z "$(echo "$actVal" |grep -m 1 "$reqVal")" ]]; then 
			echo -e "$reqVal \e[0;32mOK\e[m"
		else 
			if [ "$severity" = "warn" ]; then
				echo -e "${yl}WARN$ec ('$reqVal' wasnt found"'!'")"
			else
				echo -e "\e[0;31mFAIL\e[m ('$reqVal' wasnt found"'!'")"
			fi
		fi
	fi
}

qtyComp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local reqQty actQty qtySeverity
	reqQty=$1
	actQty=$2
	qtySeverity=$3 #empty=exit with fail  warn=just warn
	if [ "$reqQty" = "$actQty" ]; then
		echo -e -n "\tQty: \e[0;32mOK\e[m"
	else
		if [ "$qtySeverity" = "warn" ]; then
			warn "\tQty: FAIL (expected: $reqQty)"
		else
			exitFail "\tQty: FAIL (expected: $reqQty)" $PROC
		fi
	fi
}

testArrQty() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local testDesc errDesc testArr exptQty testSeverity
	dmsg inform "1=$1 2=$2 3=$3 4=$4 5=$5 6=$6"
	privateVarAssign "testArrQty" "testDesc" "$1"
	testArr=$2
	exptQty=$3
	privateVarAssign "testArrQty" "errDesc" "$4"
	testSeverity=$5 #empty=exit with fail  warn=just warn
	dmsg inform 'testArr='"$testArr"'< >exptQty='"$exptQty<"
	if [ -z "$exptQty" ]; then
		dmsg inform "$testDesc skipped, no qty defined"
	else
		if [ ! -z "$testArr" ]; then
			echo -e "\t$testDesc: "$testArr" $(qtyComp $exptQty $(echo -e -n "$testArr"| tr " " "\n" | grep -c '^') $testSeverity)"
		else
			exitFail "\tQty check failed! $errDesc!" $PROC
		fi
	fi
}

removePciDev() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local pciAddrs
	privateVarAssign "${FUNCNAME[0]}" "pciAddrs" "$*"
	for pciDev in $pciAddrs
	do
		warn "  Removing $pciDev"
		echo 1 > /sys/bus/pci/devices/0000:$pciDev/remove
	done
}

flashCard() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local flashFile burnBus flashResCmd
	privateVarAssign "${FUNCNAME[0]}" "burnBusHex" "$1"
	privateVarAssign "${FUNCNAME[0]}" "flashFile" "$2"
	testFileExist "$flashFile"
	echo "  Burning card on 0x$burnBusHex with $flashFile"
	echo "   Please wait.."
	flashResCmd="$(eeupdate64e /D $flashFile /DEV=0 /FUN=0 /BUS=0x$burnBusHex)"
	if [[ ! -z "$(echo "$flashResCmd" |grep "updated successfully")" ]]; then
		echo "   Burned successfully"
	else
		echo "$flashResCmd"
		except "   Burn failed."
	fi
}

qatConfig() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local confMode qatPath
	privateVarAssign "qatConfig" "confMode" "$1"
	privateVarAssign "qatConfig" "qatPath" "$2"
	
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			install) confMode="a" ;;
			uninstall) confMode="u" ;;
			*) exitFail "qatConfig exception, unknown arg: $ARG"
		esac
	done
	
	/root/Scripts/qat_update.sh "$confMode" "$qatPath"
}

qatAction() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local qatDev qatAct
	if [[ "$1" = "status" ]]; then
		privateVarAssign "qatAction" "qatAct" "$1"
	else
		privateVarAssign "qatAction" "qatDev" "$1"
		privateVarAssign "qatAction" "qatAct" "$2"
	fi

	qat_service $qatAct $qatDev 2>&1
}

qatTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local execPath busNum forceBgaNum qatDevCut cpaRes cpaTrace kmodExist qatRes forceQat qatDevUp
	privateVarAssign "qatTest" "execPath" "$1"
	privateVarAssign "qatTest" "busNum" "$2"
	forceBgaNum="$3"
	
	qatResStatus() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
		local execExitStatus cpaResInput
		cpaResInput="$1"
		execExitStatus=$(echo "$cpaResInput" |grep execRes |cut -d= -f2)
		test -z "$execExitStatus" && let stats+=1 || let stats+=$execExitStatus
		test "$execExitStatus" = "0" && echo -e "\e[0;32m OK\e[m" || echo -e "\e[0;31m FAIL\e[m"
	}
	
	export PATH=$PATH:$PWD:/etc/init.d
	which qat_service > /dev/null || {
		echo -e "\tQAT service is not installed, installing now."
		qatRes="$(qatConfig --install "$execPath" 2>&1)"
		#echo "DEBUG: $qatRes"
	}
	
	# qatDevs=$(ls -l /sys/bus/pci/devices/ |cut -d/ -f5- |grep :$busNum: |awk -F/ '{print $NF}' |cut -d: -f2,3 |uniq)
	allQatDevs="$(qatAction status)"
	#echo "$allQatDevs"
	for bus in $busNum; do
		qatDevs="$qatDevs $(echo "$allQatDevs"|grep "$bus" |cut -d ' ' -f2)"
		 
	done
		#warn "DEBUG: qatDevs=$qatDevs"
	
		export ICP_ROOT=$execPath

		shift
		CODE_PATH=$ICP_ROOT/quickassist/lookaside/access_layer/src/sample_code/build
		test -d "$CODE_PATH" || exitFail "qatTest exception, CODE_PATH not defined!"

		KMOD_PATH=$ICP_ROOT/quickassist/utilities/libusdm_drv
		test -d "$KMOD_PATH" || exitFail "qatTest exception, KMOD_PATH not defined!"
		KMOD_FILE=usdm_drv.ko
		KMOD_NAME=$(echo $KMOD_FILE |awk -F. '{print $1}')

		test -z "$forceBgaNum" || {
			forceQat="qat_dev$forceBgaNum"
			warn "\tForcing dev: $forceQat"
		}
		echo -e "\tInitializing QAT driver"
		kmodExist="$(lsmod | grep $KMOD_NAME)"
		test -z "$kmodExist" && {
			kmodIns="$(insmod $KMOD_PATH/$KMOD_FILE 2>&1 ; echo insRes=$?)"
			test -z "$(echo "$kmodIns" |grep insRes=0)" && {
				test -f "$KMOD_PATH/$KMOD_FILE" || exitFail "qatTest exception, KMOD_PATH/KMOD_FILE not defined!"
				echo -e "\033[;31m FAIL!!! Cannot load $KMOD_FILE!\033[0m"
				exit 1
			} || echo -e "\tKMOD driver inserted."
		}

		test -z "$qatDevs" && exitFail "qatTest exception, qatDevs not defined!"
		#warn "DEBUG: qatDevs=$qatDevs"
		for qatDev in $qatDevs; do
			qatDevCut=$(echo $qatDev|rev |cut -c1)
			dmsg inform "processing dev: qat_dev$qatDevCut"
			echo -e "\tStopping QAT device - qat_dev$qatDevCut"
			qatRes="$(qatAction qat_dev$qatDevCut Stop)"
			echo -e "\tRestarting QAT device - qat_dev$qatDevCut"
			test "$forceQat" = "qat_dev$qatDevCut" && qatRes="$(qatAction qat_dev$qatDevCut Restart 0x0)" || {
				test -z "$forceQat" && qatRes="$(qatAction qat_dev$qatDevCut Restart 0x0)" || warn "\tItercepted - QAT device qat_dev$qatDevCut is excluded."
			}
			qatRes="$(qatAction status)"
			qatDevUp=$(echo "$qatRes" |grep qat_dev$qatDevCut |awk -F 'state: ' '{print $2}')
			if [[ "$qatDevUp" = "up" ]]; then 
				echo -e "\tQAT dev - qat_dev$qatDevCut:\e[0;32m up\e[m" 
			else
				if [[ "$forceQat" = "qat_dev$qatDevCut" ]]; then
					exitFail "\tQAT dev - qat_dev$qatDevCut: DOWN (could not be initialized)" 
				else
					if [[ -z "$forceQat" ]]; then
						critWarn "\tQAT dev - qat_dev$qatDevCut: DOWN" 
					else
						warn "\tQAT dev - qat_dev$qatDevCut: DOWN (excluded)"
					fi
				fi
			fi
			dmsg inform "qatRes> $qatRes <qatRes"
			dmsg inform "forceQat=$forceQat"
			dmsg inform "qatDevUp=$qatDevUp"			
		done

		echo  -e "\n\tStarting acceleration test:"

		cd $CODE_PATH
		dmsg inform "CODE_PATH=$CODE_PATH"
		testFileExist "$CODE_PATH/cpa_sample_code"

		let stats=0

		echo -e -n "\t  Symmetric Test:"
		cpaRes="$($CODE_PATH/cpa_sample_code signOfLife=1 runTests=1 ; echo execRes=$?)"
		cpaTrace="$cpaRes\n$cpaTrace"
		qatResStatus "$cpaRes"

		echo -e -n "\t  RSA Test:"
		cpaRes="$($CODE_PATH/cpa_sample_code signOfLife=1 runTests=2 ; echo execRes=$?)"
		cpaTrace="$cpaRes\n$cpaTrace"
		qatResStatus "$cpaRes"

		echo -e -n "\t  DSA Test:"
		cpaRes="$($CODE_PATH/cpa_sample_code signOfLife=1 runTests=4 ; echo execRes=$?)"
		cpaTrace="$cpaRes\n$cpaTrace"
		qatResStatus "$cpaRes"

		echo -e -n "\t  ECDSA Test:"
		cpaRes="$($CODE_PATH/cpa_sample_code signOfLife=1 runTests=8 ; echo execRes=$?)"
		cpaTrace="$cpaRes\n$cpaTrace"
		qatResStatus "$cpaRes"

		echo -e -n "\t  Diffle-Hellman Test:"
		cpaRes="$($CODE_PATH/cpa_sample_code signOfLife=1 runTests=16 ; echo execRes=$?)"
		cpaTrace="$cpaRes\n$cpaTrace"
		qatResStatus "$cpaRes"

		echo -e -n "\t  Compression Test:"
		cpaRes="$($CODE_PATH/cpa_sample_code signOfLife=1 runTests=32 ; echo execRes=$?)"
		cpaTrace="$cpaRes\n$cpaTrace"
		qatResStatus "$cpaRes"

		for qatDev in $qatDevs; do
			qatDevCut=$(echo $qatDev|rev |cut -c1)
			echo -e "\tStopping QAT device - qat_dev$qatDevCut"
			qatRes="$(qatAction qat_dev$qatDevCut Stop)"
		done
		#echo "DEBUG: $cpaTrace"
		killAllScripts "cpa_sample_code"
		#echo "DEBUG stats=$stats"
		test -z "echo $stats |grep 0" && exitFail "QAT test failed!"
		exit $?
}

setMgntIp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ipReq cmdRes ethName actIp regEx
	echo -e "\n Setting management IP.."

	acquireVal "Management IP" ipReq ipReq
	regEx='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'; regEx+='0*(1?[0-9]{1,2}|2([‌​0-4][0-9]|5[0-5]))$'
	if [[ "$ipReq" =~ $regEx ]]; then
		echo "  IP Validated"
	else
		except "IP is not valid! Please check: $ipReq"
	fi
	echo "  Gathering ETH name"
	ethName=$(ifconfig -a |head -1 |awk '{print $1}'|tr --delete :)
	echo "  Stopping network manager service"
	cmdRes=$(systemctl stop NetworkManager.service 2>&1)
	echo "  Setting ethernet interface: $ethName"
	cmdRes=$(ifconfig $ethName $ipReq 2>&1)
	actIp=$(ifconfig $ethName |grep inet |head -n1 |awk '{print $2}')
	echo "  IP set to: $actIp"

	echo -e " Done.\n"
}

pingTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local actIp ethName regEx srvIp
	echo -e "\n Ping test.."
	
	echo "  Gathering ETH name"
	ethName=$(ifconfig -a |head -1 |awk '{print $1}'|tr --delete :)
	echo "  Gathering IP"
	actIp=$(ifconfig $ethName |grep inet |head -n1 |awk '{print $2}')
	echo "  IP: $actIp"
	regEx='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'; regEx+='0*(1?[0-9]{1,2}|2([‌​0-4][0-9]|5[0-5]))$'
	if [[ "$actIp" =~ $regEx ]]; then
		echo "  IP Validated"
	else
		warn "  IP setup required!"
		setMgntIp
		echo "  Gathering IP"
		actIp=$(ifconfig $ethName |grep inet |head -n1 |awk '{print $2}')
		if [[ "$actIp" =~ $regEx ]]; then
			echo "  IP: $actIp"
		else
			except "IP is not valid! Please check: $ipReq"
		fi
	fi
	srvIp="172.30.0.4"
	echo "  Server IP: $srvIp"
	for ((b=1;b<=10;b++)); do 
		echo -n "  Sending ping to $srvIp - "
		pingRes=$(echo -n $(ping -c 1 $srvIp 2>&1 ; echo exitCode=$?) |awk -F= '{print $NF}')
		if [[ "$pingRes" = "0" ]]; then 
			echo -e "\e[0;32mok\e[m"
		else 
			echo -e "\e[0;31mfailed\e[m"
			sleep 1 
		fi
	done

	echo -e " Done.\n"
}

reloadUSBPortByHandle() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubAddr pciHubAddr
	privateVarAssign "${FUNCNAME[0]}" "handleN" "$1"
	#	driverName could be also driver id or device id or any other in uevent
	privateNumAssign "reloadTimeout" "$2"
	hubAddr=$(grep $handleN /sys/bus/usb/devices/*/uevent |grep '\.0' |awk -F: '{print $1}' |awk -F/ '{print $(NF)}')
	if [ ! -z "$hubAddr" ]; then
		pciHubAddr=$(find /sys/bus/pci/devices/*/ -type d -name "$hubAddr")
		if [ ! -z "$pciHubAddr" ]; then
			echo 0 > $pciHubAddr/authorized
			sleep $reloadTimeout
			echo 1 > $pciHubAddr/authorized
		fi
	fi
}

getCordobaADC() {
	local voltage voltages nets multipliers netIdx
	let netIdx=0
	nets=( "V3P3A" "V3P3" "V1P5" "VNN" "V1P05" "VPP" "VDDQ" "VCCP" "VCCSRAM" )
	multipliers=( 1 1 1 1 1 1 1 1 1 )
	voltages=$(getADCVoltage 8 7 4 1 6 9 2 3 5)
	for voltage in $voltages; do
		dmsg echo " ${nets[$netIdx]}: $voltage"
		echo "${nets[$netIdx]}:$voltage:${multipliers[$netIdx]},"
		let netIdx++
	done
}

getATTxSADC() {
	local voltage voltages nets multipliers netIdx
	let netIdx=0
	nets=( "V1P05" "V5A_FPH" "VPP_CPU_DDR" "V3P3A_PIC" "VTT_CPU_DDR" "V1P5_MPCIE" "VDDQ_CPU_DDR" "V3P3_MPCIE" )
	multipliers=( 1 0.2 1 1 1 1 1 1 )
	voltages=$(getADCVoltage 5 4 6 3 7 2 8 1)
	for voltage in $voltages; do
		dmsg echo " ${nets[$netIdx]}: $voltage"
		echo "${nets[$netIdx]}:$voltage:${multipliers[$netIdx]},"
		let netIdx++
	done
}

getADCVoltages() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ADCCount ADCSerialDev
	ADCCount=$(dmesg |grep ch341 |grep attached |grep tty |cut -d] -f2- |uniq |wc -l)
	if [ $ADCCount -eq 1 ]; then
		ADCSerialDev=$(dmesg |grep ch341 |grep -m1 tty |cut -d] -f2- |uniq |awk '{print $NF}')
		getSerialADC $ADCSerialDev 115200 10
	else
		except "incorrect ADC count or not detected"
	fi
}

getADCVoltage() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ch reqCh ADCVoltRes voltage voltages
	privateVarAssign "${FUNCNAME[0]}" "reqCh" "$*"
	voltages=()
	ADCVoltRes="$(getADCVoltages)"
	for ch in $reqCh; do
		voltage=$(echo "$ADCVoltRes" | grep CH$ch | grep -m1 V |awk '{print $2}' |cut -dV -f1)
		if [ -z "$(grep ':\|CH' <<< $voltage)" ]; then 
			voltages+=( "$voltage" )
		else
			dmsg inform "incorrect format of ADC received, correcting.."
			voltage=$(echo "$ADCVoltRes" |grep CH$ch |tail -n1 |grep -m1 V |awk '{print $2}' |cut -dV -f1)
			if [ -z "$(grep ':\|CH' <<< $voltage)" ]; then 
				voltages+=( "$voltage" )
			else
				except "incorrect format: $voltage\nFull MSG:\n$ADCVoltRes \nCorrected to: $voltageNew"
			fi
		fi
	done
	if [ ${#voltages[*]} -gt 0 ]; then echo -n ${voltages[*]}; fi
}

function getATTQty() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local retRes cmdRes re ttyR cmdR resNum
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"
	let retRes=-1

	cmdRes="$(sendATT $ttyR "echo -en sendRes=;${cmdR}")"
	if [ ! -z "$cmdRes" ]; then
		resNum=$(grep "sendRes=" <<< "$cmdRes" |grep -v "sendRes=;" |cut -d= -f2 |sed 's/[^0-9]//g')
		re='^[0-9]+$'
		if [[ $resNum =~ $re ]] ; then
			let retRes=$resNum
			echo -n $resNum
		fi
	fi

	return $retRes
}

function getATTString() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes re ttyR cmdR resStr respTimeout newArgs

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) respTimeout=${VALUE} ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	cmdRes="$(sendATT --resp-timeout=$respTimeout $ttyR "echo -en sendRes=;${cmdR}")"
	if [ ! -z "$cmdRes" ]; then
		resStr=$(grep "sendRes=" <<< "$cmdRes" |grep -v "sendRes=;" |cut -d= -f2 |sed 's/\r$/ /')
		if [ ! -z "$resStr" ]; then echo $resStr; else echo "null"; fi
	fi
}

function getATTBlock() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes re ttyR cmdR resStr respTimeout newArgs timeoutArg bmcShellMode bmcCliMode

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) 
					respTimeout=${VALUE} 
					timeoutArg="--resp-timeout=$respTimeout"
				;;
				bmc-cli)	bmcCliMode=1;;
				bmc-shell)	bmcShellMode=1;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	if [ -z "$bmcMode" -a -z "$bmcCliMode" ]; then
		cmdRes="$(sendATT $ttyR "echo 'sendBlockStart-----';${cmdR};echo -e '\n-----sendBlockEnd';" $timeoutArg)"
		if [ ! -z "$cmdRes" ]; then
			resBlock=$(grep -v "\-';\|Start';" <<< "$cmdRes" |awk '/sendBlockStart-----/{f=1;next} /-----sendBlockEnd/{f=0} f')
			if [ ! -z "$resBlock" ]; then echo "$resBlock"; else echo "null"; fi
		fi
	else
		if [ -z "$bmcShellMode" ]; then
			nlChar=$(printf '\r\n')
			sendATTBMC $ttyR "'\"sendBlockStart-----\"'$nlChar${cmdR}${nlChar}echo -e '\n\"-----sendBlockEnd\"'"

		else
			sendATTBMC --shell $ttyR "echo 'sendBlockStart-----';${cmdR};echo -e '\n-----sendBlockEnd';"
		fi
	fi
}

function sendATT () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR respTimeout newArgs

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) respTimeout=${VALUE} ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getATTSerialState $ttyR $uutBaudRate $respTimeout)
	# serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars

	case "$serState" in
		bmc_shell) 	
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "HOST")
		;;&
		bmc_config) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "HOST")
		;;&
		bmc_enable) 	
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "HOST")
		;;&
		bmc_cli) 	
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "HOST")
		;;&
		bmc_login) 	
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "HOST")
		;;&
		bmc_shell|bmc_config|bmc_enable|bmc_cli|bmc_login) 	
			serState=$(getATTSerialState $ttyR $uutBaudRate $respTimeout)
			# serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g')
		;;
	esac

	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		bmc_shell|bmc_config|bmc_enable|bmc_cli|bmc_login) 	
			except "unexpected case state received! (state: $serState)"
		;;
		shell) 	
			sendSerialCmd --no-dollar $ttyR $uutBaudRate $respTimeout $cmdR
		;;
		login)
			loginATT $ttyR $uutBaudRate $respTimeout $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd --no-dollar $ttyR $uutBaudRate $respTimeout $cmdR
			else
				except "Unable to log in from $serState!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate $respTimeout nop)
			sleep 3
			loginATT $ttyR $uutBaudRate $respTimeout $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd --no-dollar $ttyR $uutBaudRate $respTimeout $cmdR
			else
				except "Unable to log in from $serState!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendATTBMC () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR respTimeout newArgs shellReq cmdSerialRes cmdRes

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) respTimeout=${VALUE} ;;
				shell) shellReq=1 ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getATTSerialState $ttyR $uutBaudRate $respTimeout)
	# serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars

	case "$serState" in
		login) 	
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "UBMC")
		;;&
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "UBMC")
		;;&
		shell) 
			cmdRes=$(switchATTMux $ttyR $uutBaudRate 5 "UBMC")
		;;&
		login|password|shell) 	
			serState=$(getATTSerialState $ttyR $uutBaudRate $respTimeout)
			# serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g')
		;;
	esac

	if [ ! -z "$shellReq" ]; then
		case "$serState" in
			null)	
				warn "Couldnt get status of the box, is the device connected and turned on?"
				except "null state received! (state: $serState)" 
			;;
			login|password|shell) 	
				except "unexpected case state received! (state: $serState)"
			;;
			bmc_shell) 	
				dmsg inform "bmc_shell sending shell command"
				cmdSerialRes="$(sendSerialCmdBMC --bmc-shell $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_config)
				dmsg inform "bmc_config sending shell command"
				loginATT $ttyR $uutBaudRate $respTimeout "$uutBMCShellUser" "$uutBMCShellPass"
				cmdSerialRes="$(sendSerialCmdBMC --bmc-shell $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_enable) 	
				dmsg inform "bmc_enable sending shell command"
				cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 configure)
				loginATT $ttyR $uutBaudRate $respTimeout "$uutBMCShellUser" "$uutBMCShellPass"
				cmdSerialRes="$(sendSerialCmdBMC --bmc-shell $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_cli)
				dmsg inform "bmc_cli sending shell command"
				cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 enable)
				cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 configure)
				loginATT $ttyR $uutBaudRate $respTimeout "$uutBMCShellUser" "$uutBMCShellPass"
				cmdSerialRes="$(sendSerialCmdBMC --bmc-shell $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_login) 	
				dmsg inform "bmc_login sending shell command"
				loginATT $ttyR $uutBaudRate $respTimeout $uutBMCUser $uutBMCPass
				if [ $? -eq 0 ]; then
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 enable)
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 configure)
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 "session expired-time 0")
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 "write memory")
					loginATT $ttyR $uutBaudRate $respTimeout "$uutBMCShellUser" "$uutBMCShellPass"
					cmdSerialRes="$(sendSerialCmdBMC --bmc-shell $ttyR $uutBaudRate $respTimeout $cmdR)"
				else
					except "Unable to log in from $serState! (2)"
				fi
			;;
			*) except "unexpected case state received! (state: $serState)"
		esac
	else
		case "$serState" in
			null)	
				warn "Couldnt get status of the box, is the device connected and turned on?"
				except "null state received! (state: $serState)" 
			;;
			login|password|shell) 	
				except "unexpected case state received! (state: $serState)"
			;;
			bmc_shell) 	
				cmdRes=$(sendSerialCmdBMC --bmc-shell $ttyR $uutBaudRate 5 exit)
				cmdSerialRes="$(sendSerialCmdBMC $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_config) 	
				cmdSerialRes="$(sendSerialCmdBMC $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_enable) 	
				cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 configure)
				cmdSerialRes="$(sendSerialCmdBMC $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_cli)
				cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 enable)
				cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 configure)
				cmdSerialRes="$(sendSerialCmdBMC $ttyR $uutBaudRate $respTimeout $cmdR)"
			;;
			bmc_login)
				loginATT $ttyR $uutBaudRate $respTimeout $uutBMCUser $uutBMCPass
				if [ $? -eq 0 ]; then
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 enable)
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 configure)
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 "session expired-time 0")
					cmdRes=$(sendSerialCmdBMC $ttyR $uutBaudRate 5 "write memory")
					cmdSerialRes="$(sendSerialCmdBMC $ttyR $uutBaudRate $respTimeout $cmdR)"
				else
					except "Unable to log in from $serState! (3)"
				fi
			;;
			*) except "unexpected case state received! (state: $serState)"
		esac
	fi
	echo "$cmdSerialRes"
}

function getNANOQty() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local retRes cmdRes re ttyR cmdR resNum respTimeout KEY VALUE newArgs timeoutArg

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) 
					respTimeout=${VALUE} 
					timeoutArg="--resp-timeout=$respTimeout"
				;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"
	let retRes=1

	cmdRes="$(sendNANO $ttyR "echo -en sendRes=;${cmdR}" $timeoutArg)"
	if [ ! -z "$cmdRes" ]; then
		resNum=$(grep "sendRes=" <<< "$cmdRes" |grep -v "sendRes=;" |cut -d= -f2 |sed 's/[^0-9]//g')
		re='^[0-9]+$'
		dmsg inform "resNum=$resNum\n"
		if [[ $resNum =~ $re ]] ; then
			dmsg inform "match ok"
			let retRes=0
			echo -n $resNum
		else
			dmsg inform "match ${rd}failed$yl"
			let retRes=99
		fi
	fi

	return $retRes
}

function getNANOString() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes re ttyR cmdR resStr respTimeout newArgs

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) respTimeout=${VALUE} ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	cmdRes="$(sendNANO --resp-timeout=$respTimeout $ttyR "echo -en sendRes=;${cmdR}")"
	if [ ! -z "$cmdRes" ]; then
		resStr=$(grep "sendRes=" <<< "$cmdRes" |grep -v "sendRes=;" |cut -d= -f2 |sed 's/\r$/ /')
		if [ ! -z "$resStr" ]; then echo $resStr; else echo "null"; fi
	fi
}

function getNANOBlock () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes re ttyR cmdR resStr respTimeout newArgs timeoutArg bmcShellMode bmcCliMode

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) 
					respTimeout=${VALUE} 
					timeoutArg="--resp-timeout=$respTimeout"
				;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	cmdRes="$(sendNANO --terminal=pico $ttyR "echo 'sendBlockStart-----';${cmdR};echo;echo -e '-----sendBlockEnd'" $timeoutArg)"
	if [ ! -z "$cmdRes" ]; then
		resBlock=$(grep -v "\-';\|Start';" <<< "$cmdRes" |awk '/sendBlockStart-----/{f=1;next} /-----sendBlockEnd/{f=0} f')
		if [ ! -z "$resBlock" ]; then echo "$resBlock"; else echo "null"; fi
	fi
}

function sendNANO () {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller): $(printCallstack)"
	local ttyR cmdR respTimeout newArgs envVar addArg powerOffReq

	for envVar in uutBaudRate uutBdsUser uutBdsPass; do
		checkDefined $envVar
	done

	respTimeout=5

	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				resp-timeout) respTimeout=${VALUE} ;;
				verbose) addArg+=" --verbose" ;;
				terminal) addArg+=" --terminal=${VALUE}" ;;
				power-off) powerOffReq=1 ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	if [ -z "$powerOffReq" ]; then
		privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"
	else
		cmdR='poweroff'
	fi

	serState=$(getNANOSerialState $ttyR $uutBaudRate $respTimeout)
	# serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	case "$serState" in
		null)	
			if [ -z "$powerOffReq" ]; then
				warn "Couldnt get status of the box, is the device connected and turned on?"
				except "null state received! (state: $serState)" 
			else
				echo " Box is in null state, poweroff is not necessary"
			fi
		;;
		linux_shell) 
			sendSerialCmdNANO $ttyR $uutBaudRate $respTimeout $cmdR$addArg
		;;
		login)
			dmsg inform "LOGIN_REQUEST> $ttyR@$uutBaudRate t/o:$respTimeout user:$uutBdsUser pass:$uutBdsPass"
			loginNANO $ttyR $uutBaudRate $respTimeout $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmdNANO $ttyR $uutBaudRate $respTimeout $cmdR$addArg
			else
				except "Unable to send cmd from $serState!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmdNANO $ttyR $uutBaudRate $respTimeout nop$addArg)
			sleep 3
			dmsg inform "LOGIN_REQUEST> $ttyR@$uutBaudRate t/o:$respTimeout user:$uutBdsUser pass:$uutBdsPass"
			loginNANO $ttyR $uutBaudRate $respTimeout $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmdNANO $ttyR $uutBaudRate $respTimeout $cmdR$addArg
			else
				except "Unable to send cmd from $serState!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
	dmsg inform "cmdRes=$cmdRes"
}

function sendIS40 () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIS40SerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		shell) 	
			cmdRes=$(sendRootIS40 $ttyR exit)
			sleep 3
			loginIS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in from $serState!"
			fi	
		;;
		gui) 
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		login)
			loginIS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in from $serState!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			sleep 3
			loginIS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in from $serState!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendRootIS40 () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR serState
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIS40SerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		shell) 		
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		gui) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 exit)
			sleep 3
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		login)
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			sleep 3
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendIS100 () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIS100SerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		shell) 	
			cmdRes=$(sendRootIS100 $ttyR exit)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in from $serState!"
			fi	
		;;
		gui) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 enable)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 configure)
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		guiEn)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 configure)
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		guiConf)
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		login)
			loginIS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in from $serState!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			sleep 3
			loginIS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in from $serState!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendRootIS100 () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR serState
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIS100SerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		shell) 		
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		gui) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 enable)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 configure)
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		guiEn) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 configure)
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		guiConf) 
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		login)
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutBdsUser" $uutBdsPass)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 enable)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 configure)
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			sleep 3
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutBdsUser" $uutBdsPass)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 enable)
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 configure)
			loginRes=$(loginIS $ttyR $uutBaudRate 5 "$uutRootUser" $uutRootPass)
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendIBS () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIBSSerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		shell) 	
			cmdRes=$(sendRootIBS $ttyR exit)
			loginIBS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi	
		;;
		gui) 
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		login)
			loginIBS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			sleep 3
			loginIBS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendRootIBS () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyR cmdR serState
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIBSSerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	
			warn "Couldnt get status of the box, is the device connected and turned on?"
			except "null state received! (state: $serState)" 
		;;
		shell) 		
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		gui) 
			cmdRes=$(sendIBS $ttyR exit)
			sleep 1
			loginIBS $ttyR $uutBaudRate 5 $uutRootUser $uutRootPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		login)
			loginIBS $ttyR $uutBaudRate 5 $uutRootUser $uutRootPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmd $ttyR $uutBaudRate 5 nop)
			sleep 3
			loginIBS $ttyR $uutBaudRate 5 $uutRootUser $uutRootPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "Unable to log in!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
}

function sendSSHCmdwPass () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local timeout cmd cmdR hostIP sshIp sshPass
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "hostIP" "$1";shift
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$1";shift
	privateVarAssign "${FUNCNAME[0]}" "sshPass" "$1";shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn ssh -oStrictHostKeyChecking=no $sshUser@$hostIP
	expect {
		*assword:* { 
			send_user \"\nSending password: \n\"
			send \"$sshPass\r\n\" 
			send_user \"\nPassword: $sshPass - Sent.\n\"
		}
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*]#* { send \"$cmdR\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*]#* { send \"exit\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout5\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	return $?
}

function sendBCMShellCmd () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local timeout cmd cmdR
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn /home/BCM_PHY/20220801_Quadra_1_8/Q28_1_8/quadra28_reference_app/bin/bcm82780_phy_init
	send \r\n
	expect {
	*Q28:)* { 
		send_user \"\nSending cmd: $cmdR\n\"
		send \"$cmdR\r\n\" 
		send_user \"\nCmd: $cmdR - Sent.\n\"
	}
	timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*Q28:)* { send \"$cmdR\r\n\" }
	timeout { send_user \"\nTimeout4\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	Disconnected { send_user Done\n }
	timeout { send_user \"\nTimeout5\n\"; exit 1 }
	eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	return $?
}

function sendBCMGetQSFPInfo () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local timeout cmd cmdR
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	srcDir=$(pwd)
	cd /home/BCM_PHY/20220801_Quadra_1_8/Q28_1_8/quadra28_reference_app/bin/
	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn /home/BCM_PHY/20220801_Quadra_1_8/Q28_1_8/quadra28_reference_app/bin/bcm82780_phy_init
	expect {
		*Q28:)* { 
			send_user \"\nSending cmd: get_all_sfp_info\n\"
			send \"get_all_sfp_info\r\" 
			send_user \"\nCmd: get_all_sfp_info - Sent.\n\"
		}

		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		exp_continue
	}
	sleep 1
	expect {
	*Q28:)* { 
		send_user \"\nExiting..\n\"
		send \"exit\r\n\" 
	}
	timeout { send_user \"\nTimeout4\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	" 
	cd $srcDir
	return $?
}

function switchATTMux () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout expRes

	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateVarAssign "${FUNCNAME[0]}" "baud" "$2"
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$3"
	privateVarAssign "${FUNCNAME[0]}" "targetMux" "$4"
	case $targetMux in
		"HOST") secMux="UBMC";;
		"UBMC") secMux="HOST";;
		*) except "illegal targetMux: $targetMux"
	esac


	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expRes="$(expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	expect {
		Connected { send_user \"\nSending Ctrl+x\n\"; send \x18 }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	expect {
		*Switching\ to\ $targetMux* { send_user \"\nSwithed to target mux: $targetMux\n\";send \x14q\r }
		*Switching\ to\ $secMux* {
			send_user \"\nSwithed to wrong mux ($secMux)..\n\"
			send_user \"\nSending second Ctrl+x\n\"
			send \x18
			expect {
				*Switching\ to\ $targetMux* { send_user \"\nSwithed to target mux: $targetMux\n\";send \x14q\r }
				timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
				eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
			}
		}
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 2>&1)"
	return $?
}

function loginIBS () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "login" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "pass" "$1"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	send \r
	expect {
	Connected { send \r }
	timeout { send_user \"\nTimeout1\n\"; exit 1 }
	eof { send_user \"\nEOF\n\"; exit 1 }
	}
	expect {
	*login:* { send \"$login\r\" }
	*:~#* { send \"$login\r\" }
	timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*Password:* { send \"$pass\r\" }
	*:~#* { send \"$pass\r\" }
	timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*\$* { send \x14q\r }
	*#* { send \x14q\r }
	timeout { send_user \"\nTimeout4\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	Disconnected { send_user Done\n }
	timeout { send_user \"\nTimeout5\n\"; exit 1 }
	eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	return $?
}

function loginIS () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "login" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "pass" "$1"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	send \r
	expect {
	Connected { send \r }
	timeout { send_user \"\nTimeout1\n\"; exit 1 }
	eof { send_user \"\nEOF\n\"; exit 1 }
	}
	expect {
	*g)#* { send \"$login\r\" }
	*RU\$* { send \"$login\r\" }
	*login:* { send \"$login\r\" }
	*:~#* { send \"$login\r\" }
	timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*Password:* { send \"$pass\r\" }
	*:~#* { send \"$pass\r\" }
	timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*\$* { send \x14q\r }
	*#* { send \x14q\r }
	*0>* { send \x14q\r }
	timeout { send_user \"\nTimeout4\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	Disconnected { send_user Done\n }
	timeout { send_user \"\nTimeout5\n\"; exit 1 }
	eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	return $?
}

function loginATT () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "login" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "pass" "$1"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	send \r
	expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	expect {
		*ubmc\ login:* { send_user \"\nSending UBMC login: $login\n\"; send \"$login\r\";send \"$login\r\";send \"$login\r\" }
		*ogin:* { send_user \"\nSending login: $login\n\"; send \"$login\r\" }
		*config)#* { send_user \"\nSending login: $login to cfg..\n\";send \"$login\r\" } 
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*word:* { send \"$pass\r\" }
		timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*#* { send \x14q\r }
		*\$\ * { send \x14q\r }
		*ubmc>* { send \x14q\r }
		timeout { send_user \"\nTimeout4\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout5\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	return $?
}

function loginNANO () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "login" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "pass" "$1"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	send \r
	expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	expect {
		*ogin:* { send_user \"\nSending login: $login\n\"; send \"$login\r\" }
		*]#* { send \x14q\r ; exit 1 }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*word:* { send_user \"\nSending password: $pass\n\";send \"$pass\r\" }
		timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*]#* { send \x14q\r }
		timeout { send_user \"\nTimeout4\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout5\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	" 
	exitStatus=$?
	dmsg inform "exitStatus=$exitStatus"
	return $exitStatus
}

function getSerialADC () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout

	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user 0
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	send \r
	expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	log_user 1
	expect {
		*CH0* { send \"\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*CH0* { send \"\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*CH9* { send \"\r\" ; exit 1}
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	log_user 0
	expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	"
	return $?
}

function sendSerialCmd () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd newArgs arg noDollar

	verb=0
	cmdDelay=0
	# extracting keys
	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				no-dollar) noDollar=1 ;;
				cmd-delay) cmdDelay=${VALUE} ;;
				verbose) verb=1 ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmd" "$*"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	if [ -z "$noDollar" ]; then
		expect -c "
		set timeout $timeout
		log_user $verb
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
			Connected { send \r }
			timeout { send_user \"\nTimeout1\n\"; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
			*\$* { send \"$cmd\r\" }
			*#* { send \"$cmd\r\" }
			*0>* { send \"$cmd\r\" }
			*ubmc>* { send \"$cmd\r\" }
			*config)#* { send \"$cmd\r\" }
			timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		sleep $cmdDelay
		log_user 1
		expect {
			*\$* { send \x14q\r }
			*#* { send \x14q\r }
			*0>* { send \x14q\r }
			*ubmc>* { send \x14q\r }
			*config)#* { send \x14q\r }
			*login:* { send \x14q\r }
			timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		log_user $verb
		expect {
			Disconnected { send_user Done\n }
			timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		"
	else
		expect -c "
		set timeout $timeout
		log_user $verb
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
			Connected { send \r }
			timeout { send_user \"\nTimeout1\n\"; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
			*#* { send \"$cmd\r\" }
			*0>* { send \"$cmd\r\" }
			*ubmc>* { send \"$cmd\r\" }
			*config)#* { send \"$cmd\r\" }
			timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		sleep $cmdDelay
		log_user 1
		expect {
			*#* { send \x14q\r }
			*0>* { send \x14q\r }
			*ubmc>* { send \x14q\r }
			*config)#* { send \x14q\r }
			*login:* { send \x14q\r }
			timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		log_user $verb
		expect {
			Disconnected { send_user Done\n }
			timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		"
	fi
	return $?
}

function sendSerialCmdNANO () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd newArgs arg noDollar verb ttyLock

	if [ -z "$debugMode" ]; then verb=0; else verb=1; fi

	# extracting keys
	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				verbose) verb=1 ;;
				terminal) termMode=${VALUE} ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmd" "$*"

	for ((retCnt=0;retCnt<=20;retCnt++)); do
		ttyLock=$(lsof |grep $ttyN)
		if [ -z "$ttyLock" ]; then
			break
		fi
		sleep 0.1
	done
	if [ ! -z "$ttyLock" ]; then critWarn "$ttyLock"; fi

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"
	if [ "$termMode" = "pico" ]; then
		which picocom > /dev/null || except "picocom not found by which!"
		termCmd="picocom -b $baud -f n -y n -p 1 --omap crlf /dev/$ttyN"
		termExitSeq='\x01\x18'
		conMsg='Terminal\ ready'
		discMsg='Thanks\ for\ using\ picocom'
	else
		termCmd="tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none"
		termExitSeq='\x14q\r'
		termDiscSeq=$termExitSeq
		conMsg='Connected'
		discMsg='Disconnected'
	fi

	expect -c "
	set timeout $timeout
	log_user $verb
	exp_internal $verb
	spawn $termCmd
	expect {
		$conMsg { send \n }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF1\n\"; exit 1 }
	}
	expect {
		*]#* { expect *; send \"$cmd\n\" }
		*ogin:* { send \"$cmd\n\" }
		*word:* { send \"$cmd\n\" }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF2\n\"; send \x14q\r ; exit 1 }
	}
	log_user 1
	sleep 0.3
	expect {
		*]#* { send $termExitSeq }
		*ogin:* { send $termExitSeq }
		*word:* { send $termExitSeq }
		timeout { send_user \"\nTimeout3\n\"; send \x03; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF3\n\"; send $termExitSeq ; exit 1 }
	}
	log_user $verb
	expect {
		$discMsg { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
		eof { send_user \"\nEOF4\n\"; exit 1 }
	}
	"
}

function initSerialNANO () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd newArgs arg noDollar verb exceptIdx

	verb=0
	# extracting keys
	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				verbose) verb=1 ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"

	
	ttyLock="$(lsof |grep "$ttyN")"
	if [ ! -z "$ttyLock" ]; then 
		warn "$ttyLock"
		killActiveSerialWriters $ttyN
	fi

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	expect -c "
	set timeout $timeout
	log_user $verb
	exp_internal 0
	spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
	expect {
		Connected { 
			send_user \" TIO pausing output transmission\n\"
			send \x11\r
			send_user \" TIO clearing buffer\n\"
			send \x18\r
			send_user \" TIO clearing screen\n\"
			send \x0C\r
			send_user \" TIO changind baud to $baud\n\"
			send \x0A\"$baud\"\r
			send_user \" TIO resuming output transmission\n\"
			send \x11\r
			send \r 
			send \x14q\r
			exit 1
		}
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF1\n\"; exit 1 }
	}
	log_user $verb
	expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
		eof { send_user \"\nEOF4\n\"; exit 1 }
	}
	"
}

function sendSerialCmdBMC () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd newArgs arg bmcShellMode


	# extracting keys
	for arg in "$@"
	do
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				bmc-shell) bmcShellMode=1 ;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmd" "$*"
	dmsg inform "Sending $cmd > $ttyN@$baud /w t/o: $timeout"

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"
	bmcRes="$(
		if [ -z "$bmcShellMode" ]; then
			expect -c "
			set timeout $timeout
			log_user 0
			exp_internal 0
			spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
			send \r
			expect {
				Connected { send \r }
				timeout { send_user \"\nTimeout1\n\"; exit 1 }
				eof { send_user \"\nEOF\n\"; exit 1 }
			}
			expect {
				*ubmc>* { send \"$cmd\r\" }
				*ubmc#* { send \"$cmd\r\" }
				*config)#* { send \"$cmd\r\" }
				timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
				eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
			}
			log_user 1
			expect {
				*\$\ * { 
					send \"export PS1='BMC_SHELL>>>'\r\"
					expect {
						*BMC_SHELL>>>* { send \x14q\r }
						timeout { send_user \"\nTimeout3\n\"\; send \x03; send \x14q\r ; exit 1 }
						eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
					}
				}
				*ubmc>* { send \x14q\r }
				*ubmc#* { send \x14q\r }
				*config)#* { send \x14q\r }
				timeout { send_user \"\nTimeout4\n\"; send \x03; send \x14q\r ; exit 1 }
				eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
			}
			log_user 0
			expect {
				Disconnected { send_user Done\n }
				timeout { send_user \"\nTimeout5\n\"; send \x03; exit 1 }
				eof { send_user \"\nEOF\n\"; exit 1 }
			}
			"
		else
			expect -c "
			set timeout $timeout
			log_user 0
			exp_internal 0
			spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
			send \r
			expect {
				Connected { send \r }
				timeout { send_user \"\nTimeout1\n\"; exit 1 }
				eof { send_user \"\nEOF\n\"; exit 1 }
			}
			expect {
				*\$\ * { 
					send \"export PS1='BMC_SHELL>>>'\r\"
					expect {
						*BMC_SHELL>>>* { send \"$cmd\recho '>''SERIAL_CMD_OK'\r\" }
						timeout { send_user \"\nTimeout2\n\"\; send \x03; send \x14q\r ; exit 1 }
						eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
					}
				}
				*BMC_SHELL>>>* { send \"$cmd\recho '>''SERIAL_CMD_OK'\r\" }
				timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
				eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
			}
			log_user 1
			expect {
				*>SERIAL_CMD_OK* { send \x14q\r }
				*config)#* { send \x14q\r }
				timeout { send_user \"\nTimeout4\n\"; send \x03; send \x14q\r ; exit 1 }
				eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
			}
			log_user 0
			expect {
				Disconnected { send_user Done\n }
				timeout { send_user \"\nTimeout5\n\"; send \x03; exit 1 }
				eof { send_user \"\nEOF\n\"; exit 1 }
			}
			"
		fi
	)"
	echo -n "$bmcRes"
	dmsg inform "bmcRes=$(od -c <<<$bmcRes)"
	return $?
}

function NANObootMonitor () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN logPath stateList lastPrintedState writerPids retStatus newStates bootingActive lastState loginState
	local retCnt portClosed bootMode shortBoot
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateVarAssign "${FUNCNAME[0]}" "bootMode" "$2"
	testFileExist "/dev/$ttyN"

	case $bootMode in
		"fullBoot") 
			loginPrompt="LINUX_LOGIN_PROMPT"	
			loginMsg="Login state reached!"	
		;;
		"shortBoot") 
			loginPrompt="BOOT_MGR_MSG"
			loginMsg="Boot state reached!"
			shortBoot=1
		;;
		*) except "illegal bootMode: $bootMode"
	esac

	let retStatus=0
	let loopLimit=960
	let linesPrinted=0
	let bootingActive=1
	logPath="/tmp/${ttyN}_serial_log.txt"
	killActiveSerialWriters $ttyN
	rm -f "$logPath"
	#set +m
	serialWriterNANO $ttyN $logPath
	echo "  Boot monitor running ($bootMode):"
	lastPrintedState=""
	lastBootState=""
	while [ $bootingActive -gt 0 ]; do
		if [ -e "$logPath" ]; then
			stateList="$(sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-\!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' <<<"$(cat $logPath)" |grep --binary-files=text 'State:' |awk '{print $2}' |tr -d '\r')"
			#stateList="$(cat $logPath |sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' |grep --binary-files=text 'State:' |awk '{print $2}')"
			let lineCount=$(wc -l <<<"$stateList")
			let linesRequired=$(($lineCount-$linesPrinted))
			if [ $linesRequired -gt 0 ]; then
				lastState=$(tail -n1 <<<"$stateList")
				loginState=$(grep --binary-files=text "$loginPrompt" <<<"$stateList")
				newStates="$(tail -n$linesRequired<<<"$stateList" |sed -z 's/\n/\n   /g')"
				if [ ! -z "$newStates" ]; then 
					if [ $linesPrinted -eq 0 ]; then
						echo -ne "   $newStates"
					else
						echo -ne "$newStates"
					fi
					lastPrintedState="$stateList"
					lastBootState="$lastState"
					let linesPrinted=$lineCount
				fi
			fi
			if [ ! -z "$loginState" ]; then let bootingActive=0; echo -e "   ${gr}$loginMsg$ec"; fi
		fi
		if [ $loopLimit -eq 0 ]; then
			echo -e "\t${rd}BOOT FAILED!$ec\n\tLast state: $yl$lastState$ec"
			echo -e "$rd\n\n\nFULL LOG START --- \n$yl"
			cat $logPath.console_out |sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-\!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g'
			echo -e "$rd\nFULL LOG END --- \n\n\n$ec"
			let retStatus++
			let bootingActive=0
		fi
		sleep 0.24
		let loopLimit--
	done
	echo "  Done."
	killActiveSerialWriters $ttyN
	let portClosed=0
	for ((retCnt=0;retCnt<=12;retCnt++)); do
		srvAct=$(lsof |grep $uutSerDev)
		if [ -z "$srvAct" ]; then
			let portClosed=1
			echo -e " Port$gr closed.$ec"
			break
		else
			if [ retCnt > 0 ]; then printf '\e[A\e[K'; fi
			countDownDelay 3 " Waiting port closure.."
		fi
	done
	if [ $portClosed -eq 0 ]; then
		echo -e "  Port was not closed, ${yl}killing.$ec"
		killActiveSerialWriters $ttyN
		#set -m
	fi
	echo  "  Port activity: $(lsof |grep $uutSerDev)"
	return $retStatus
}

startSerialMonitor() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local uutSerDev
	selectSerial "  Select UUT serial device"
	publicVarAssign silent uutSerDev ttyUSB$?
	testFileExist "/dev/$uutSerDev"
	echo " Setting traps on $ttyN"
	trap "killSerialMonitor $uutSerDev" SIGINT
	trap "killSerialMonitor $uutSerDev" SIGQUIT
	serialMonitor $uutSerDev
}

killSerialMonitor() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	killSerialWriters $ttyN
	#fuser -k /dev/$ttyN
}

serialMonitor() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local logFilePath lsofPids pid 
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	#fuser -k /dev/$ttyN
	echo " Starting monitor on $ttyN"
	stty -F /dev/$ttyN 115200
	cat -v < /dev/$ttyN
}

serialWriterNANO() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local logFilePath lsofPids pid nohupCmd conOutPath serialLogPid pid
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "logFilePath" "$1"
	conOutPath="$logFilePath.console_out"
	echo -e "\nSetting up serial configs."
	fuser -k /dev/$ttyN
	rm -f $logFilePath
	#stty -F /dev/$ttyN 115200 raw -echo -echok -echoctl -echoke
	stty -F /dev/$ttyN 115200 raw -echo -noflsh
	setserial /dev/$ttyN baud_base 115200 close_delay 100 closing_wait 9000 callout_nohup low_latency
	sleep 0.2
	echo " Starting reader on /dev/$ttyN"
	nohup sh -c "cat /dev/$ttyN > $conOutPath" &
	pid=$!; serialLogPids+=("$pid")
	echo -e "Logger started. PID: $pid\n"
	sleep 0.2
	#echo -e "\nSetting up serial configs."
	# stty -F /dev/$ttyN 115200 raw -echo -echok -echoctl -echoke
	echo " Starting boot watcher on $ttyN"
	nohup sh -c "source /root/multiCard/arturLib.sh; getNANOBootMsgFromLog "$conOutPath" > $logFilePath" >/dev/null 2>&1 & >/dev/null 2>&1
	pid=$!; serialLogPids+=("$pid")
	echo -e "Watcher started. PID: $pid\n"
}

function killSerialWriters () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local logFilePath lsofPids pid 
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	echo " Killing ALL serial writers on $ttyN"
	if [ -e /dev/$ttyN ];	then
		echo -e " Device checked, exists: /dev/$ttyN\n Checking activity on serial device"
		lsofPids=$(lsof |grep $ttyN |awk '{print $2}')

		if [ ! -z "$lsofPids" ]; then
			echo " Killing all processes on serial device"
			for pid in $lsofPids; do kill -9 $pid; echo "  Killing PID $pid"; done
		fi
		echo " Done."
	fi
}
function killActiveSerialWriters () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local logFilePath lsofPids pid 
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	echo " Killing active writers on $ttyN"
	if [ -e /dev/$ttyN ];	then
		echo -e " Device checked, exists: /dev/$ttyN\n Checking activity on serial device"
		lsofPids=$(getACMttyWriters $ttyN)

		if [ ! -z "$lsofPids" ]; then
			echo " Killing active writers on $ttyN"
			for pid in $lsofPids; do kill -9 $pid; echo "  Killing PID $pid"; done
		fi
		echo " Done."
	fi
}

function killLogWriters () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local logFilePath lsofPids pid 
	privateVarAssign "${FUNCNAME[0]}" "logFilePath" "$1"; shift
	echo " Killing log writers on $logFilePath"
	if [ -e $logFilePath ];	then
		echo " Checking activity on log file."
		lsofPids=$(lsof $logFilePath |awk '{print $2}' |grep -v PID)

		if [ ! -z "$lsofPids" ]; then
			echo " Killing active writers on log file"
			for pid in $lsofPids; do kill -9 $pid; echo "  Killing PID $pid"; done
		fi
		echo " Done."
	fi
}

function USBBPsyclePort () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN timeout sendRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateNumAssign "timeout" "$2"
 
	if [ -e /dev/$ttyN ]; then
		echo  " Unplugging USB.."
		sendRes="$(sendSerialCmd $ttyN 9600 5 "set_bypass off")"
		sleep $timeout
		echo  " Replugging USB.."
		sendRes="$(sendSerialCmd $ttyN 9600 5 "set_bypass on")"
	else
		except "Port /dev/$ttyN does not exist"
	fi
	echo  " Done cycling USB.."
}

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

function getIBSSerialState () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 1
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
		*#* { send_user \"State: shell\r\" }
		*\$* { send_user \"State: gui\r\" }
		*ogin:* { send_user \"State: login\r\" }
		*word:* { send_user \"State: password\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		** { send \x14q\r }
		timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'State:' |awk -F 'State:' '{print $2}' |cut -d ' ' -f2)
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	echo -n "$serStateRes"
}

function getATTSerialState () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes serialCmdNlRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 0
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r\n
		expect {
			Connected { send_user \"\nConnected to /dev/$ttyN\n\";send \r\n }
			timeout { send_user \"\nTimeout1\n\"; send \x03; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		log_user 1
		expect {
			*:~#* { send_user \"\n State: shell\n\" }
			*uefi\ login:* { send_user \"\n State: login\n\" }
			*word:* { send_user \"\n State: password\n\" }
			*\$\ * { send_user \"\n State: bmc_shell\n\" }
			*BMC_SHELL>>>* { send_user \"\n State: bmc_shell\n\" }
			*config)#\ * { send_user \"\n State: bmc_config\n\" }
			*ubmc#\ * { send_user \"\n State: bmc_enable\n\" }
			*ubmc>\ * { send_user \"\n State: bmc_cli\n\" }
			*ubmc\ login:* { send_user \"\n State: bmc_login\n\" }
			timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		log_user 0
		expect {
			** { send_user \"\nEnd of transmission\n\"; send \x03; send \x14q\r }
			timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
			Disconnected { send_user Done\n }
			timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	dmsg echo "$serialCmdNlRes"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'State:' |awk -F 'State:' '{print $2}' |cut -d ' ' -f2)
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	#echo -n "$serStateRes" | tr -dc '[:print:]'
	echo -n "$serStateRes"
}

function getNANOSerialState () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes serialCmdNlRes verbal ttyLock
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	if [ -z "$1" ]; then verbal=0; else verbal=$1; fi

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	for ((retCnt=0;retCnt<=20;retCnt++)); do
		ttyLock=$(lsof |grep $ttyN)
		if [ -z "$ttyLock" ]; then
			break
		fi
		sleep 0.1
	done
	if [ ! -z "$ttyLock" ]; then critWarn "$ttyLock"; fi

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user $verbal
		exp_internal $verbal
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		expect {
			Connected { send_user \"\nConnected to /dev/$ttyN\n\";send \n }
			timeout { send_user \"\nTimeout1\n\"; send \x03; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		log_user 1
		expect {
			*]#* { send_user \"\n State: linux_shell\n\" }
			*ogin:* { send_user \"\n State: login\n\" }
			*word:* { send_user \"\n State: password\n\" }
			timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		log_user $verbal
		expect {
			** { send_user \"\nEnd of transmission\n\"; send \x14q\r }
			timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
			eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
			Disconnected { send_user Done\n }
			timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
			eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	if [ "$verbal" = "0" ]; then
		dmsg echo "$serialCmdNlRes"
		serStateRes=$(echo "$serialCmdNlRes" |grep -w 'State:' |awk -F 'State:' '{print $2}' |cut -d ' ' -f2)
		if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
		#echo -n "$serStateRes" | tr -dc '[:print:]'
		echo -n "$serStateRes"
	else
		echo "serialCmdNlRes=$serialCmdNlRes"
		echo "serialCmdNlRes_wGrep=$(echo "$serialCmdNlRes" |grep -w 'State:')"
	fi
}

replugUSBMsg() {
	local title btitle conRows conCols
	title="USB Reconnect"
	btitle="  arturd@silicom.co.il"	
	whiptail --nocancel --notags --title "$title" --backtitle "$btitle" --msgbox "Reconnect USB cable to the UUT" 8 35 3>&2 2>&1 1>&3
}

getACMttyWriters(){
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"

	ioFilter='ModemMana\|gmain\|pool\|gdbus'
	lsof |grep $ttyN |grep -v $ioFilter |awk '{print $2}'
}

getACMttyServices(){
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	systemctl stop ModemManager.service &>/dev/null
	ioFilter='ModemMana\|gmain\|pool\|gdbus'
	lsof |grep $ttyN |grep $ioFilter |awk '{print $2}'
}

function bootNANOgrubShell () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes termCmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1" ;shift

	which expect > /dev/null || except "expect not found by which!"

	which picocom > /dev/null || except "picocom not found by which!"
	termCmd="picocom -b $baud -f n -y n -p 1 -r --omap crlf /dev/$ttyN"
	termExitSeq='\x01\x18'
	termDiscSeq='\x01\x11'
	conMsg='Terminal\ ready'
	discMsg='Thanks\ for\ using\ picocom'

	expect -c "
	set timeout $timeout
	log_user 1
	exp_internal 0
	spawn $termCmd

	expect {
		$conMsg { 
			send_user \"\r\n\r\nState: WAIT_FOR_SERIAL_INIT\r\n\r\n\";send \r 
			send \r 
		}
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF1\n\"; exit 1 }
	}
	expect {
		*isSecurebootEnabled* { send_user \"\r\n\r\nState: SECURE_BOOT_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout2\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF2\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Loading\ Usb\ Lens* { send_user \"\r\n\r\nState: USB_LOAD_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout3\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF3\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Installing\ Usb\ Lens* { send_user \"\r\n\r\nState: USB_INSTALL_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout4\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF4\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Mapping\ table* { send_user \"\r\n\r\nState: MAPPING_TABLE_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout5\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF5\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Pci(0x1C* { send_user \"\r\n\r\nState: EFI_MMC_DETECT\r\n\r\n\"; exp_continue }
		*USB(0x6* { send_user \"\r\n\r\nState: EFI_USB_DETECT\r\n\r\n\"; exp_continue }
		*Locking\ SPI* { send_user \"\r\n\r\nState: EFI_DEVS_END\r\n\r\n\" }
		timeout { send_user \"\nTimeout6\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Lock\ flash* { send_user \"\r\n\r\nState: SPI_LOCK\r\n\r\n\" }
		timeout { send_user \"\nTimeout9\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF6\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Boot\ Manager\ Menu* { send_user \"\r\n\r\nState: BOOT_MGR_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout11\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF7\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Mapping\ table* { send_user \"\r\n\r\nState: MAPPING_TABLE_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout5\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF5\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Pci(0x1C,0x0)/Msg(29,00)/Ctrl(0x0)/HD(1C* { 
			send_user \"\r\n\r\nState: EFI_FS_MMC_DETECT\r\n\r\n\"
			exp_continue 
		}
		*USB(0x6,0x0)/HD(1* { 
			send_user \"\r\n\r\nState: EFI_FS_USB_DETECT\r\n\r\n\"
			exp_continue 
		}
		*Shell>* { }
		timeout { send_user \"\nTimeout6\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*BootOrder0000* { 
			send_user \"\r\n\r\nState: BOOT_ORDER_DUMP\r\n\r\n\" 
			send_user \"\r\n\r\nState: BOOT_OPT_0_DETECT\r\n\r\n\" 
		}
		*BootOrder0001* { 
			send_user \"\r\n\r\nState: BOOT_ORDER_DUMP\r\n\r\n\" 
			send_user \"\r\n\r\nState: BOOT_OPT_0_DETECT\r\n\r\n\" 
		}
		*bcfg\ boot\ dump* { 
			send_user \"\r\n\r\nState: BOOT_ORDER_DUMP\r\n\r\n\" 
			set timeout 5
			expect {
				*Option:\ 00* { 
					send_user \"\r\n\r\nState: BOOT_OPT_0_DETECT\r\n\r\n\" 
					expect {
						*not\ recognized* { send_user \"\r\n\r\nState: BOOT_OPT_0_ND\r\n\r\n\" }
						*Pci(0x1C* { send_user \"\r\n\r\nState: BOOT_OPT_0_MMC\r\n\r\n\" }
						*USB(0x6* { send_user \"\r\n\r\nState: BOOT_OPT_0_USB\r\n\r\n\" }
						timeout { send_user \"\nTimeout6.1\n\" }
					}
				}
				timeout { send_user \"\r\n\r\nState: BOOT_OPT_NOT_DETECTED\r\n\r\n\" }
				eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
			}
			set timeout $timeout
		}
		timeout { send_user \"\nTimeout8\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Shell\\>\ \\%Boot* { send_user \"\r\n\r\nState: BOOT_OPTION_LOAD\r\n\r\n\" }
		*echo\ \\%BootOrder* { send_user \"\r\n\r\nState: BOOT_OPTION_LOAD\r\n\r\n\" }
		*0000\\]* { send_user \"\r\n\r\nState: NO_GRUB_LINUX_LOAD\r\n\r\n\" }
		timeout { send_user \"\nTimeout12\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*will\ be\ started\ automatically* { send_user \"\r\n\r\nState: GRUB_MENU\r\n\r\n\" }
		*0000\]* { send_user \"\r\n\r\nState: NO_GRUB_LINUX_LOAD\r\n\r\n\" }
		timeout { send_user \"\nTimeout13\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*SMBIOS* { send_user \"\r\n\r\nState: LINUX_BOOT_SCREEN\r\n\r\n\" }
		*ACPI:* { send_user \"\r\n\r\nState: LINUX_BOOT_SCREEN\r\n\r\n\" }
		*ogin:* { 
			send_user \"\r\n\r\nState: LINUX_LOGIN_PROMPT_NOLOAD\r\n\r\nPROMPT_OK1\"
			sleep 5
			send $termExitSeq
			expect {
				$discMsg { send_user \"\r\n\r\n\r\nDisconnected, ok\r\n\r\n\r\n\" ; exit 1 }
				timeout { send_user \"\nTimeout4\n\"; send $termExitSeq; exit 1 }
				eof { send_user \"\nEOF\n\";send $termExitSeq; exit 1 }
			}
		}
		timeout { send_user \"\nTimeout14\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*pci_bus\ 0000:00* { send_user \"\r\n\r\nState: LINUX_BOOT_PCI_INIT\r\n\r\n\" }
		timeout { send_user \"\nTimeout15\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*mmc0* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_INIT\r\n\r\n\"  }
		*Started\ OpenSSH* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_NOT_FOUND\r\n\r\n\"  }
		*Stopped\ Plymouth* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_NOT_FOUND\r\n\r\n\"  }
		*Starting\ Hostname* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_NOT_FOUND\r\n\r\n\"  }
		timeout { send_user \"\nTimeout16\n\"; send $termExitSeq ; exit 1 }
		eof { 
			send_user \"\r\n\r\nEOF, reloading TIO\r\n\r\n\"
			spawn $termCmd
			send \r
			send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_INIT_1\r\n\r\n\"
		}
	}
	set x 0
	expect {
		*login:* { send_user \"\r\n\r\nState: LINUX_LOGIN_PROMPT\r\n\r\nPROMPT_OK1\"; sleep 5; send $termExitSeq }
		timeout { send_user \"\nTimeout2\n\"; send $termExitSeq ; exit 1 }
		eof { 
			while {$x <= 10} {
				incr x
				spawn $termCmd
				expect {
					$conMsg {
						send_user \"\r\n\r\nState: WAIT_FOR_LINUX_LOGIN_PROMPT1.$attempt\r\n\r\n\";send \r
						send \r
						expect {
							timeout {
								send_user \"\r\n\r\nTimeout on reload after connection\r\n\r\n\"
								send $termExitSeq
								exit 1
								break
							}
							*login:* {
								send_user \"\r\n\r\nState: LINUX_LOGIN_PROMPT\r\n\r\nPROMPT_OK2.$attempt; sleep 5\"
								send $termExitSeq
								break
							}
							*isSecurebootEnabled* {
								send_user \"\r\n\r\nState: UNEXPECTED_RESET\r\n\r\n\"
								send $termExitSeq
								exit 1
								break
							}
						}
					}
					timeout {
						send_user \"\r\n\r\nTimeout on reload\r\n\r\n\"
						send $termExitSeq
						exit 1
						break
					}
					eof {
						send_user \"\r\n\r\nEOF8.$attempt, reloading TIO\r\n\r\n\"
						continue
					}
				}
			}
		}
	}
	expect {
		$discMsg { send_user \"\r\n\r\n\r\nDisconnected, ok\r\n\r\n\r\n\" ; exit 1 }
		timeout { send_user \"\nTimeout4\n\"; send $termExitSeq; exit 1 }
		eof { send_user \"\nEOF\n\";send $termExitSeq; exit 1 }
	}
	" 2>&1
}

function getNANOBootMsgFromLog () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes termCmd fileName
	privateVarAssign "${FUNCNAME[0]}" "fileName" "$1"; shift

	which expect > /dev/null || except "expect not found by which!"
	termExitSeq='\x03'

	expect -c "
	set timeout 360
	log_user 1
	exp_internal 0
	spawn tail -f $fileName

	send_user \"\r\n\r\nState: WAIT_FOR_SERIAL_INIT\r\n\r\n\"

	expect {
		*isSecurebootEnabled* { send_user \"\r\n\r\nState: SECURE_BOOT_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout2\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF2\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Loading\ Usb\ Lens* { send_user \"\r\n\r\nState: USB_LOAD_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout3\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF3\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Installing\ Usb\ Lens* { send_user \"\r\n\r\nState: USB_INSTALL_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout4\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF4\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Mapping\ table* { send_user \"\r\n\r\nState: MAPPING_TABLE_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout5\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF5\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Pci(0x1C* { send_user \"\r\n\r\nState: EFI_MMC_DETECT\r\n\r\n\"; exp_continue }
		*USB(0x6* { send_user \"\r\n\r\nState: EFI_USB_DETECT\r\n\r\n\"; exp_continue }
		*Locking\ SPI* { send_user \"\r\n\r\nState: EFI_DEVS_END\r\n\r\n\" }
		timeout { send_user \"\nTimeout6\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Lock\ flash* { send_user \"\r\n\r\nState: SPI_LOCK\r\n\r\n\" }
		timeout { send_user \"\nTimeout9\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF6\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Boot\ Manager\ Menu* { send_user \"\r\n\r\nState: BOOT_MGR_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout11\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF7\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Mapping\ table* { send_user \"\r\n\r\nState: MAPPING_TABLE_MSG\r\n\r\n\" }
		timeout { send_user \"\nTimeout5\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF5\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Pci(0x1C,0x0)/Msg(29,00)/Ctrl(0x0)/HD(1C* { 
			send_user \"\r\n\r\nState: EFI_FS_MMC_DETECT\r\n\r\n\"
			exp_continue 
		}
		*USB(0x6,0x0)/HD(1* { 
			send_user \"\r\n\r\nState: EFI_FS_USB_DETECT\r\n\r\n\"
			exp_continue 
		}
		*Shell>* { }
		timeout { send_user \"\nTimeout6\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*BootOrder0000* { 
			send_user \"\r\n\r\nState: BOOT_ORDER_DUMP\r\n\r\n\" 
			send_user \"\r\n\r\nState: BOOT_OPT_0_DETECT\r\n\r\n\" 
		}
		*BootOrder0001* { 
			send_user \"\r\n\r\nState: BOOT_ORDER_DUMP\r\n\r\n\" 
			send_user \"\r\n\r\nState: BOOT_OPT_0_DETECT\r\n\r\n\" 
		}
		*bcfg\ boot\ dump* { 
			send_user \"\r\n\r\nState: BOOT_ORDER_DUMP\r\n\r\n\" 
			set timeout 5
			expect {
				*Option:\ 00* { 
					send_user \"\r\n\r\nState: BOOT_OPT_0_DETECT\r\n\r\n\" 
					expect {
						*not\ recognized* { send_user \"\r\n\r\nState: BOOT_OPT_0_ND\r\n\r\n\" }
						*Pci(0x1C* { send_user \"\r\n\r\nState: BOOT_OPT_0_MMC\r\n\r\n\" }
						*USB(0x6* { send_user \"\r\n\r\nState: BOOT_OPT_0_USB\r\n\r\n\" }
						timeout { send_user \"\nTimeout6.1\n\" }
					}
				}
				timeout { send_user \"\r\n\r\nState: BOOT_OPT_NOT_DETECTED\r\n\r\n\" }
				eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
			}
			set timeout $timeout
		}
		timeout { send_user \"\nTimeout8\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Shell\\>\ \\%Boot* { send_user \"\r\n\r\nState: BOOT_OPTION_LOAD\r\n\r\n\" }
		*echo\ \\%BootOrder* { send_user \"\r\n\r\nState: BOOT_OPTION_LOAD\r\n\r\n\" }
		*0000\\]* { send_user \"\r\n\r\nState: NO_GRUB_LINUX_LOAD\r\n\r\n\" }
		timeout { send_user \"\nTimeout12\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*will\ be\ started\ automatically* { send_user \"\r\n\r\nState: GRUB_MENU\r\n\r\n\" }
		*0000\]* { send_user \"\r\n\r\nState: NO_GRUB_LINUX_LOAD\r\n\r\n\" }
		timeout { send_user \"\nTimeout13\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*SMBIOS* { send_user \"\r\n\r\nState: LINUX_BOOT_SCREEN\r\n\r\n\" }
		*ACPI:* { send_user \"\r\n\r\nState: LINUX_BOOT_SCREEN\r\n\r\n\" }
		*ogin:* { 
			send_user \"\r\n\r\nState: LINUX_LOGIN_PROMPT_NOLOAD\r\n\r\nPROMPT_OK1\"
			sleep 5
			send $termExitSeq
			expect {
				$discMsg { send_user \"\r\n\r\n\r\nDisconnected, ok\r\n\r\n\r\n\" ; exit 1 }
				timeout { send_user \"\nTimeout4\n\"; send $termExitSeq; exit 1 }
				eof { send_user \"\nEOF\n\";send $termExitSeq; exit 1 }
			}
		}
		timeout { send_user \"\nTimeout14\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*pci_bus\ 0000:00* { send_user \"\r\n\r\nState: LINUX_BOOT_PCI_INIT\r\n\r\n\" }
		timeout { send_user \"\nTimeout15\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*mmc0* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_INIT\r\n\r\n\"  }
		*Started\ OpenSSH* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_NOT_FOUND\r\n\r\n\"  }
		*Stopped\ Plymouth* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_NOT_FOUND\r\n\r\n\"  }
		*Starting\ Hostname* { send_user \"\r\n\r\nState: LINUX_BOOT_EMMC_NOT_FOUND\r\n\r\n\"  }
		timeout { send_user \"\nTimeout16\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*login:* { send_user \"\r\n\r\nState: LINUX_LOGIN_PROMPT\r\n\r\nPROMPT_OK1\" }
		timeout { send_user \"\nTimeout2\n\"; send $termExitSeq ; exit 1 }
		eof { 
				send_user \"\r\n\r\nEOF on reload\r\n\r\n\"
				send $termExitSeq
				exit 1
				break
			}
	}
	expect {
		** { send_user \"\r\n\r\n\r\nClosed, ok\r\n\r\n\r\n\" ; exit 1 }
		timeout { send_user \"\nTimeout4\n\"; send $termExitSeq; exit 1 }
		eof { send_user \"\nEOF\n\";send $termExitSeq; exit 1 }
	}
	" 2>&1
}

function getIS40SerialState () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 1
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
		*:~#* { send_user \"State: shell\r\" }
		*RU\$* { send_user \"State: gui\r\" }
		*)\$* { send_user \"State: gui\r\" }
		*ogin:* { send_user \"State: login\r\" }
		*word:* { send_user \"State: password\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		** { send \x14q\r }
		timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'State:' |awk -F 'State:' '{print $2}' |cut -d ' ' -f2)
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	echo -n "$serStateRes"
}

function getIS100SerialState () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 1
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
		*\$* { send_user \"State: shell\r\" }
		*0>* { send_user \"State: gui\r\" }
		*0#* { send_user \"State: guiEn\r\" }
		*g)#* { send_user \"State: guiConf\r\" }
		*ogin:* { send_user \"State: login\r\" }
		*word:* { send_user \"State: password\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		** { send \x14q\r }
		timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'State:' |awk -F 'State:' '{print $2}' |cut -d ' ' -f2)
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	echo -n "$serStateRes"
}

function getISBootMsg () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 1
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
		*BOOT_OK* { send_user \"State: BOOT_OK_CNF\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		** { send \x14q\r }
		timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'BOOT_OK_CNF')
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	echo -n "$serStateRes"
}

function getISCPUMsg () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 1
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
		*CPU0:* { send_user \"State: CPU0_MSG\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		** { send \x14q\r }
		timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'CPU0_MSG')
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	echo -n "$serStateRes"
}

function getISRstMsg () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd serStateRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "expect not found by which!"
	which tio > /dev/null || except "tio not found by which!"

	serialCmdNlRes="$(
		expect -c "
		set timeout $timeout
		log_user 1
		exp_internal 0
		spawn tio /dev/$ttyN -b $baud -d 8 -p none -s 1 -f none
		send \r
		expect {
		Connected { send \r }
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		expect {
		*RST_SEND* { send_user \"State: RST_SEND_CNF\r\" }
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		** { send \x14q\r }
		timeout { send_user \"\nTimeout3\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
		}
		expect {
		Disconnected { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
		}
		" 2>&1
	)"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'RST_SEND_CNF')
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	echo -n "$serStateRes"
}

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

setUsbNICip() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local nicCount nicEth cmdRes
	let nicCount=$(ls -l /sys/class/net |grep usb |wc -l)
	if [ $nicCount -eq 1 ]; then
		nicEth=$(ls -l /sys/class/net |grep -m1 usb |awk '{print $9}')
		echo "NIC found: $nicEth" 
	else
		except "incorrect NIC count: $nicCount"
	fi
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

ipmiCheckChassis() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes cutRes
	privateVarAssign "${FUNCNAME[0]}" "ipmiIP" "$1"
	verifyIp "${FUNCNAME[0]}" $ipmiIP
	privateVarAssign "${FUNCNAME[0]}" "ipmiUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "ipmiPass" "$3"
	cmdRes="$(ipmitool -H $ipmiIP -U $ipmiUser -P $ipmiPass chassis status)"
	dmsg inform "cmdRes=$cmdRes"
	cutRes=$(echo "$cmdRes" |grep 'Chassis Power\|System Power' |cut -d: -f2)
	dmsg inform "cutRes=$cutRes"
	if [ ! -z "$cutRes" ]; then
		echo -e "  Chassis status on $ipmiIP:$yl$cutRes$ec"
	else
		addSQLLogRecord $syncSrvIp $ipmiIP --ipmi-connection-failed
		except "Unable to connect to $ipmiUser@$ipmiIP"
	fi
}

ipmiPowerUP() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes cutRes
	privateVarAssign "${FUNCNAME[0]}" "ipmiIP" "$1"
	verifyIp "${FUNCNAME[0]}" $ipmiIP
	privateVarAssign "${FUNCNAME[0]}" "ipmiUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "ipmiPass" "$3"
	cmdRes="$(ipmitool -H $ipmiIP -U $ipmiUser -P $ipmiPass power on)"
	dmsg inform "cmdRes=$cmdRes"
	cutRes=$(echo "$cmdRes" |grep 'Chassis Power' |cut -d: -f2)
	dmsg inform "cutRes=$cutRes"
	if [ ! -z "$cutRes" ]; then
		echo "  Sent power ON command to $ipmiIP"
	else
		addSQLLogRecord $syncSrvIp $ipmiIP --ipmi-connection-failed
		addSQLLogRecord $syncSrvIp $ipmiIP --ipmi-power-up-failed
		except "Unable to connect to $ipmiUser@$ipmiIP"
	fi
}

ipmiPowerDOWN() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes cutRes
	privateVarAssign "${FUNCNAME[0]}" "ipmiIP" "$1"
	verifyIp "${FUNCNAME[0]}" $ipmiIP
	privateVarAssign "${FUNCNAME[0]}" "ipmiUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "ipmiPass" "$3"
	cmdRes="$(ipmitool -H $ipmiIP -U $ipmiUser -P $ipmiPass power off)"
	dmsg inform "cmdRes=$cmdRes"
	cutRes=$(echo "$cmdRes" |grep 'Chassis Power' |cut -d: -f2)
	dmsg inform "cutRes=$cutRes"
	if [ ! -z "$cutRes" ]; then
		echo "  Sent power OFF command to $ipmiIP"
	else
		addSQLLogRecord $syncSrvIp $ipmiIP --ipmi-connection-failed
		addSQLLogRecord $syncSrvIp $ipmiIP --ipmi-power-down-failed
		except "Unable to connect to $ipmiUser@$ipmiIP"
	fi
}

printTPLinkHub() {
	local hubIdx
	privateNumAssign "hubIdx" "$1"
	printUsbDevsOnHub $hubIdx bda:411 bda:5411 | { head -1; sort; }
}

getUsbHubs() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubDevId hubKeyw hubList hubDevsList hubDev hubOk hubArr hubHWPath
	hubDevId="005a"
	hubKeyw="0x0024"
	hubList="$(lsusb -d :$hubDevId 2>/dev/null)"
	if [ ! -z "$hubList" ]; then
		hubDevsList=$(awk '{print $4}'<<<"$hubList" |cut -d: -f1)
		for hubDev in $hubDevsList; do
			hubOk=$(timeout 2s lsusb -vs :$hubDev 2>/dev/null |grep "$hubKeyw")
			if [ ! -z "$hubOk" ]; then
				hubBus=$(lsusb -s :$hubDev 2>/dev/null |awk '{print $2}' |cut -d: -f1)
				hubHWPath=$(udevadm info --query=all -n /dev/bus/usb/$hubBus/$hubDev 2>&1 |grep DEVPATH |awk -F/ '{print $NF}')
				if [ ! -z "$hubHWPath" ]; then hubArr+=("$hubHWPath"); fi
			fi
		done
	fi
	if [ ! -z "$hubArr" ]; then echo -n "${hubArr[*]}"; fi
}

getUsbHubsByID() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubDevId hubKeyw hubList hubDevsList hubDev hubOk hubPathArr hubBusArr hubDevsArr hub hubArrIdx hubHWPath
	privateVarAssign "${FUNCNAME[0]}" "hubDevQuery" "$1"
	hubKeyw="Compound device"
	hubList="$(lsusb -d $hubDevQuery 2>/dev/null)"
	if [ ! -z "$hubList" ]; then
		while read hub; 
		do 		
			if isDefined hub; then
				dmsg inform "processing hub: $hub"
				hubBusArr+=("$(awk '{print $2}'<<<"$hub" |cut -d: -f1)")
				hubDevsArr+=("$(awk '{print $4}'<<<"$hub" |cut -d: -f1)")
			fi
		done <<< "$hubList"	
		for ((hubArrIdx=0;hubArrIdx<${#hubDevsArr[@]};hubArrIdx++)); do
			unset hubDevPathOk
			dmsg inform "processing dev: ${hubDevsArr[$hubArrIdx]}"
			hubDevPathOk=$(udevadm info --query=all -n /dev/bus/usb/${hubBusArr[$hubArrIdx]}/${hubDevsArr[$hubArrIdx]} 2>/dev/null |grep DEVPATH)
			if isDefined hubDevPathOk; then
				dmsg inform "hubDevPathOk: $hubDevPathOk"
				hubOk=$(timeout 2s lsusb -vs ${hubBusArr[$hubArrIdx]}:${hubDevsArr[$hubArrIdx]} 2>/dev/null | grep "$hubKeyw")
				if isDefined hubOk; then
					dmsg inform "hubOk: $hubOk"
					hubHWPath=$(udevadm info --query=all -n /dev/bus/usb/${hubBusArr[$hubArrIdx]}/${hubDevsArr[$hubArrIdx]} 2>&1 |grep DEVPATH |awk -F/ '{print $NF}')
					dmsg inform "getting hubHWPath: $hubHWPath"
					if [ ! -z "$hubHWPath" ]; then hubPathArr+=("$hubHWPath"); fi
				fi
			fi
		done
	fi
	if [ ! -z "$hubPathArr" ]; then echo -n "${hubPathArr[*]}"; fi
}

getUsbDevsOnHub() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubList hubNum hubIdx hubHWAddr hub devBus hubDevIDList hubDevId hubsInList
	local devName devParentPath devPath devUevent devInfo devId devSubId devBusnum devDevnum devVerbName
	local busSpeed busGen devIsSecondary hubHWAddrArr
	local devPort usbDir usbDirsOnParent maxChld maxChildren devRemovable portIdx portEval
	local ARG KEY VALUE minimalMode delimSym

	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			hub-number) privateNumAssign "hubNum" "${VALUE}" ;;
			hub-dev-id) 
				if isDefined VALUE; then
					hubDevIDList+="${VALUE} "
				else
					except "--hub-dev-id should be provided with Device ID!"
				fi
			;;
			delim) 
				if isDefined VALUE; then
					delimSym=${VALUE:0:1}
				else
					except "--delim should be provided with delimeter symbol"
				fi
			;;
			minimal) minimalMode=1 ;;
			margs)
				if isDefined VALUE; then
					margsList="${VALUE}"
					local chrIdx
					for (( chrIdx=0; chrIdx<${#margsList}; chrIdx++ )); do
						chrArg=${margsList:$chrIdx:1}
						case "$chrArg" in
							d) local noDevId=1;;
							g) local noUsbGen=1;;
							b) local noBusAdr=1;;
							c) local noSerCrc=1;;
							*) except "illegal minimal mode argument: $chrArg";;
						esac
					done
				else
					except "--margs should be provided with minimal mode arguments!"
				fi
			;;
			*) dmsg inform "Unknown arg: $ARG"
		esac
	done

	if ! isDefined delimSym; then delimSym=';'; fi
	let maxChildren=0
	
	for hubDevId in $hubDevIDList; do
		let hubIdx=0
		dmsg inform "processing: $hubDevId"
		hubList="$(getUsbHubsByID $hubDevId)"
		for hub in $hubList; do
			let hubIdx++
			if [ $hubNum -eq $hubIdx ]; then 
				hubHWAddrArr+=($hub)
				dmsg inform "hub arr: ${hubHWAddrArr[*]}"
				break
			fi
		done
	done

	if ! isDefined minimalMode; then
		printf "$blb%*s %*s %*s %*s %*s %*s %*s$ec\n" 5 "Port" 6 "Speed" 8 "Bus:Dev" 10 "ID:SubID" 21 "Name" 21 "Serial CRC"
	fi
	
	for hubHWAddr in ${hubHWAddrArr[*]}; do
		devBus=$(cut -d '-' -f1 <<<"$hubHWAddr")
		hubDevPath="/sys/bus/usb/devices/usb$devBus/$hubHWAddr"
		#devsOnHub="$(ls -l /sys/bus/usb/devices/ |grep "$hubHWAddr\..*:1\..$\|$hubHWAddr\.1\..*:1\..$" |grep -v "$hubHWAddr\.1:1\.0" |awk -F/ '{print $NF}')"
		
		devsOnHub="$(find `find $hubDevPath/* -name authorized |rev |cut -d/ -f2- |rev` -maxdepth 1 -name bInterfaceClass |rev |cut -d/ -f2- |rev)"
		hubsInList=$(grep DRIVER=hub $(sed -e 's|$|/uevent|' <<<"$devsOnHub") |rev |cut -d/ -f2- |rev)
		devsOnHub="$(grep -vF "$hubsInList" <<<"$devsOnHub" |awk -F/ '{print $NF}')" #removing hubs from list

		dmsg inform "devsOnHub: $devsOnHub"

		if [ -e "/sys/bus/usb/devices/usb$devBus/" ]; then
			dmsg inform "Device exist> /sys/bus/usb/devices/usb$devBus/"
			busSpeed=$(cat /sys/bus/usb/devices/usb$devBus/speed 2>/dev/null)

			if isNumber busSpeed; then
				if ! isDefined minimalMode; then
					if [ $busSpeed -gt 3000 ]; then busGen=" ${gr}USB3$ec"; else busGen=" ${org}USB2$ec"; fi
				else
					if [ $busSpeed -gt 3000 ]; then busGen="USB3"; else busGen="USB2"; fi
				fi
			else
				busGen=" ${rd} N/A$ec"
			fi
			
			for dev in $devsOnHub; do
				dmsg inform "Processing dev> $dev"
				devName=$(cut -d: -f1 <<<$dev)
				devPort=$(awk -F'.' '{print $NF}' <<<$devName)
				devPath="$(find "/sys/bus/usb/devices/usb$devBus/" -name dev |grep -m1 "$devName/dev" |rev |cut -d/ -f2- |rev)"
				devParentPath="$(find "/sys/bus/usb/devices/usb$devBus/" -name dev |grep -m1 "$devName/dev" |rev |cut -d/ -f3- |rev)"
				if [ "$hubDevPath" = "$devParentPath" ]; then devIsSecondary=1; else unset devIsSecondary; fi
				devsOnParent="$(find `ls -l -d $devParentPath/*/ |awk '{print $NF}'` -maxdepth 1 -name dev |awk -F/ '{print $(NF-1)}')"
				usbDirsOnParent="$(find `ls -l -d $devParentPath/*/ |awk '{print $NF}'` -maxdepth 1 -name dev |rev |cut -d/ -f2- |rev)"
				parentMaxChildren=$(cat $devParentPath/maxchild 2>/dev/null)
				if ! isNumber parentMaxChildren; then
					except "Parent cant have children, aborting"
				fi

				# dmsg inform "devPath: $devPath"
				dmsg inform "devsOnParent: $devsOnParent"
				dmsg inform "usbDirsOnParent: $usbDirsOnParent"

				let usbDevIdx=0
				let portIdx=0
				let fixedIdx=0
				for usbDir in $usbDirsOnParent; do 
					if [ -e "$usbDir/removable" ]; then 
						let usbDevIdx++
						devRemovable=$(grep "removable" $usbDir/removable 2>/dev/null)
						if isDefined devRemovable; then
							let portIdx++
						else
							if [ -e "$usbDir/maxchild" ]; then 
								dmsg inform "Checking maxchild of $usbDir: "$(cat $usbDir/maxchild)
								maxChld=$(cat $usbDir/maxchild 2>/dev/null)
								if isNumber maxChld; then
									if [ $maxChld -eq 0 ]; then
										let portIdx++
									else
										let fixedIdx++
										unset devRemovable
									fi
								else
									unset devRemovable
								fi
							else
								let fixedIdx++
							fi
						fi
					else
						unset devRemovable
					fi
					dmsg inform " $usbDir > PORTIdx: $portIdx devRemovable: $devRemovable"
					if [ "$devName" = "$usbDir" ]; then
						dmsg inform " port found, breaking loop.."
						break
					else
						dmsg inform "$devName is not equial to $usbDir"
					fi
				done
				if isDefined devIsSecondary; then
					let devPort+=$parentMaxChildren
				fi
				devUevent="$(cat $devPath/uevent)"
				devBusnum=$(grep 'BUSNUM=' <<<"$devUevent" |cut -d= -f2-)
				devDevnum=$(grep 'DEVNUM=' <<<"$devUevent" |cut -d= -f2-)
				devInfo=$(udevadm info -q property -n /dev/bus/usb/$devBusnum/$devDevnum)
				devId=$(grep -oE 'PRODUCT=([0-9a-zA-Z]+)/' <<<"$devInfo" | cut -d'=' -f2 | cut -d'/' -f1 |printf "%04X" "$((16#$(cat)))")
				devSubId=$(grep -oE 'PRODUCT=([0-9a-zA-Z]+)/([0-9a-zA-Z]+)/' <<<"$devInfo" | cut -d'=' -f2 | cut -d'/' -f2 |printf "%04X" "$((16#$(cat)))")
				devVerbName=$(grep 'ID_MODEL=' <<<"$devInfo" | cut -d'=' -f2 |sed "s/_/ /")
				devSerCrc=$(grep 'ID_SERIAL_SHORT=' <<<"$devInfo"| cut -d'=' -f2 | cksum | awk '{print $1}'| printf "%08X\n" "$(cat)" | tr '[:lower:]' '[:upper:]')
				dmsg inform "devPort=$devPort  usbDevIdx=$usbDevIdx  fixedIdx=$fixedIdx"
				portEval=$(($devPort-$fixedIdx))
				dmsg inform "  PORTIdx: $portIdx evalCnt: $portEval"
				if isDefined minimalMode; then
					if ! isDefined noDevId; then local devIdMsg=$devId:$devSubId$delimSym; fi
					if ! isDefined noUsbGen; then local busGenMsg=$busGen$delimSym; fi
					if ! isDefined noBusAdr; then local devBusMsg=$devBusnum:$devDevnum$delimSym; fi
					if ! isDefined noSerCrc; then local devSerCrcMsg=$devSerCrc; fi
					echo "$portEval$delimSym$busGenMsg$devBusMsg$devIdMsg${devVerbName:0:30}$delimSym$devSerCrcMsg"
				else
					printf "%-5s %b $blp%*s$ec $blp%-11s$ec $cyg%-30s$ec  $pr%-8s$ec\n" "  $portEval" "$busGen" 10 "[$devBusnum:$devDevnum]" "[$devId:$devSubId]" "${devVerbName:0:30}" "$devSerCrc"
				fi
			done
		fi
	done
}

getUsbTTYOnHub() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubPortNumReq hubList hubNum hubIdx hubHWAddr hub devBus
	privateNumAssign "hubNum" "$1"
	privateNumAssign "hubPortNumReq" "$2"

	let hubIdx=0
	hubList="$(getUsbHubs)"
	for hub in $hubList; do
		let hubIdx++
		if [ $hubNum -eq $hubIdx ]; then hubHWAddr=$hub; fi
	done

	devBus=$(cut -d '-' -f1 <<<"$hubHWAddr")
	devsOnHub="$(ls -l /sys/bus/usb/devices/ |grep "$hubHWAddr\..*:1\..$\|$hubHWAddr\.4\..*:1\..$" |grep -v "$hubHWAddr\.4:1\.0" |awk -F/ '{print $NF}')"
	#devsOnHub="$(ls -l /sys/bus/usb/devices/ |grep "$hubHWAddr\..:1\|$hubHWAddr\.4\..:1\.0" |grep -v "$hubHWAddr\.4:1\.0" |awk -F/ '{print $NF}')"
	if [ -e "/sys/bus/usb/devices/usb$devBus/" ]; then
		dmsg inform "Device exist> /sys/bus/usb/devices/usb$devBus/"
		for dev in $devsOnHub; do
			dmsg inform "Processing dev> $dev"
			ttyOnDev=$(find /sys/bus/usb/devices/usb$devBus/ -name dev |grep "$dev" |grep -m1 tty |awk -F/ '{print $(NF-1)}')
			if [ ! -z "$ttyOnDev" ]; then
				dmsg inform "TTY exist> $ttyOnDev"
				privateNumAssign "hubPortNum" "$(cut -d. -f2 <<<"$dev" |cut -d: -f1)"
				if [ $hubPortNum -gt 3 ]; then #second part of hub, address have to be adjusted
					privateNumAssign "hubPortNum" "$(cut -d. -f3 <<<"$dev" |cut -d: -f1)"
					let hubPortNum=$(($hubPortNum+3))
				fi
				dmsg inform "  Found dev on port $hubPortNum: $ttyOnDev"
				if [ $hubPortNumReq -eq $hubPortNum ]; then
					echo -n "$ttyOnDev"
				fi
			fi
		done
	fi
}

sshCheckPing() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local retryCount targIp
	privateNumAssign "retryCount" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targIp" "$2"
	verifyIp "${FUNCNAME[0]}" $targIp
	echo "  Checking ping on $targIp"
	for ((b=1;b<=$retryCount;b++)); do 
		echo -n "   Ping $targIp - "
		pingRes=$(echo -n $(ping -c 1 $targIp 2>&1 ; echo exitCode=$?) |awk -F= '{print $NF}')
		if [[ "$pingRes" = "0" ]]; then 
			echo -e "\e[0;32mok\e[m"
			sleep 0.2
		else 
			echo -e "\e[0;31mfailed\e[m"
			sleep 1 
		fi
	done
}

sshWaitForPing() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local secondsPassed totalDelay targIp status startTime successPing successReq
	privateNumAssign "totalDelay" "$1"
	let secondsPassed=0
	privateVarAssign "${FUNCNAME[0]}" "targIp" "$2"
	successReq=$3
	if [ -z "$successReq" ]; then let successReq=5; fi
	verifyIp "${FUNCNAME[0]}" $targIp
	tput civis
	# echo "  Waiting for ping on $targIp"
	startTime="$(date -u +%s)"
	while [ $secondsPassed -lt $totalDelay ]; do
		echo -n "  Ping $targIp ($(( $totalDelay - $secondsPassed )) seconds left) - "
		sleep 0.25
		pingRes=$(echo -n $(ping -c 1 $targIp 2>&1 ; echo exitCode=$?) |awk -F= '{print $NF}')
		if [[ "$pingRes" = "0" ]]; then 
			echo -ne "\e[0;32mUP\e[m"
			sleep 1
			let successPing++
			let status=0
		else 
			echo -ne "\e[0;31mDOWN\e[m"
			sleep 0.5
			let successPing=0
			let status=1
		fi
		echo -en "\033[2K\r"
		currTime="$(date -u +%s)"
		if [ $successPing -eq $successReq ]; then
			let secondsPassed=$totalDelay
		else
			let secondsPassed=$(bc <<<"$currTime-$startTime")
		fi
	done
	if [ $status -eq 0 ]; then
		echo -e "  Ping $targIp - \e[0;32mUP\e[m"
	else
		echo -e "  Ping $targIp - \e[0;31mDOWN\e[m"
	fi
	tput cnorm
	return $status
}

waitForLog() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local secondsPassed totalDelay status startTime retryDelay searchRes
	privateVarAssign "${FUNCNAME[0]}" "logPath" "$1"
	privateNumAssign "totalDelay" "$2"
	privateNumAssign "retryDelay" "$3"
	let secondsPassed=0
	privateVarAssign "${FUNCNAME[0]}" "expKeyw" "$4"
	
	if [ ! -s "$logPath" ]; then except "logPath does not exist: $logPath"; fi
	tput civis
	startTime="$(date -u +%s)"
	while [ $secondsPassed -lt $totalDelay ]; do
		echo -n "  Checking log $logPath, serching for $expKeyw ($(( $totalDelay - $secondsPassed )) seconds left) - "
		searchRes="$(cat "$logPath" |grep "$expKeyw")"
		if [[ ! -z "$searchRes" ]]; then 
			echo -ne "\e[0;32mFOUND\e[m"
			let status=0
		else 
			echo -ne "\e[0;31mNOT FOUND\e[m"
			let status=1
			sleep $retryDelay
		fi
		echo -en "\033[2K\r"
		currTime="$(date -u +%s)"
		if [ $status -eq 0 ]; then
			let secondsPassed=$totalDelay
		else
			let secondsPassed=$(bc <<<"$currTime-$startTime")
		fi
	done
	if [ $status -eq 0 ]; then
		echo -e "  Checking log $logPath - Found \e[0;32m$expKeyw\e[m"
	else
		echo -e "  Checking log $logPath - Not found \e[0;31m$expKeyw\e[m"
	fi
	tput cnorm
	return $status
}


startServer() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local servIp
	privateVarAssign "${FUNCNAME[0]}" "servIp" "$1"
	verifyIp "${FUNCNAME[0]}" $servIp
	echo -e "  Starting server: $servIp"
	sshWaitForPing 3 $servIp
	if [ $? -eq 1 ]; then
		echo "  Powering up IPPower"
		ipPowerSetPowerUP
		countDownDelay 90 "  Waiting for the server go UP:"
		sshWaitForPing 80 $servIp
		if [ $? -eq 0 ]; then
			echo -e "  Host $servIp is \e[0;32mUP\e[m"
		else
			echo -e "  Failed to UP the server, host $servIp is \e[0;31mDOWN\e[m"
		fi
	else
		echo -e "  Server $servIp is \e[0;32mUP\e[m"
	fi
}

stopServer() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local servIp
	privateVarAssign "${FUNCNAME[0]}" "servIp" "$1"
	verifyIp "${FUNCNAME[0]}" $servIp
	echo -e "  Stopping server: $servIp"
	sshWaitForPing 3 $servIp
	if [ $? -eq 0 ]; then
		sshSendCmdSilent $servIp root poweroff
		countDownDelay 5 "  Waiting for the server go DOWN:"
		sshWaitForPing 10 $servIp
		if [ $? -eq 1 ]; then
			echo "  Powering down IPPower"
			ipPowerSetPowerDOWN
		else
			echo -e "  Failed to shutdown the server, host $servIp is \e[0;31mUP\e[m"
		fi
	else
		echo -e "  Server $servIp is \e[0;31mDOWN\e[m"
	fi
}

setupInternet() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	if [ -z "$internetAcq" ]; then 
		warn "internetAcq status was not set, setting to 0"
		let internetAcq=0
	fi
	if [ $internetAcq -eq 0 ]; then
		echo "  Setting up routing GW"
		route add default gw 172.30.0.9 &> /dev/null
		echo -n "  Checking resolver: "
		if [ -z "$(cat /etc/resolv.conf |grep nameserver |grep '1.1\|8.8')" ]; then
			echo "not set, appending /etc/resolv.conf"
			echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf &> /dev/null
		else
			echo "checked, is set."
		fi
		sleep 1
		if ! ping -c 1 google.com &> /dev/null; then
			warn "  Internet setup failed, routing setup failed"
		else
			let internetAcq=1
			echo "  Internet setup was succesfull, ping ok"
		fi
	else
		if ! ping -c 1 google.com &> /dev/null; then
			warn "  Internet setup failed, unexpected state"
		else
			echo "  Skipped internet setup, not in down state"
		fi
	fi
}

bindSlotToBridge() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slotList maxSlots brSlot brSlots dmiSlotBusList brSlotBusList brDev brDevs brSlotBus brName brIp brNets
	privateVarAssign "${FUNCNAME[0]}" "slotList" "$*"
	privateVarAssign "${FUNCNAME[0]}" "dmiSlotBusList" "$(getDmiSlotBuses)"
	privateNumAssign "maxSlots" "$(getMaxSlots)"

	for slotNum in $slotList; do
		if isNumber slotNum; then
			if [ $slotNum -ge 1 ] && [ $slotNum -le $maxSlots ]; then 
				brSlots+="$slotNum "
			else
				except "illegal slot number: $slotNum, not in slot range 1 - $maxSlots"
			fi
		else
			except "provided slot: $slotNum in slotList: $slotList is not a number"
		fi
	done

	echo -e "  Binding Ifaces on slots: $slotList"
	brName="Slot"$(sed 's/ /_/g'<<<$slotList)"_BR"
	brIp="192.168.$(sed 's/[^0-9]*//g'<<<$slotList |cut -c1-2).1"

	for brSlot in $brSlots; do
		brNets+=$(getIfacesOnSlot $brSlot)" "
	done
	brNets=$(awk '$1=$1'<<<$brNets)

	if isDefined brNets; then
		echo -e "    Net list: $brNets"
		
		ip link del dev Slot1_3_BR >/dev/null 2>&1
		echo -e "    Checking nets.."
		checkIfacesExist $brNets
		echo -e "    Setting UP"
		setIfaceLinks -up $brNets
		echo -e "    Setting channels setting"
		setIfaceChannels -target-qty=3 $brNets
		echo -e "    Setting IRQ"
		setIrq $brNets
		# echo -e "    Setting pause parameters"
		# setIfaceParams -flow -on $brNets
		echo -e "    Binding ifaces to bridge $yl$brName$ec with IP $org$brIp$ec"
		bindIfacesToBridge $brName $brIp $brNets
		printNetsStats --nets-req="$brNets"
		echo -e "  Done."
	else
		except "No nets could be gathered"
	fi
}

bindIfacesToBridge() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local bridgeName bridgeIP ethIface ethIfaceList
	privateVarAssign "${FUNCNAME[0]}" "bridgeName" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "bridgeIP" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "ethIfaceList" "$*"
	verifyIp "${FUNCNAME[0]}" $bridgeIP

	echo -e "  Binding interfaces: $yl$ethIfaceList$ec to bridge: $gr$bridgeName$ec"
	checkIfacesExist $ethIfaceList

	if [ ! -e "/sys/class/net/$bridgeName/" ]; then
		echo -e "  Creating bridge $gr$bridgeName$ec"
		ip link add name $bridgeName type bridge
		echo -e "  Setting bridge $yl$bridgeName$ec to ${gr}UP$ec"
		ip link set $bridgeName up
		echo -e "   Assign IP address to the bridge: $yl$bridgeName$ec"
		ip addr add $bridgeIP/8 dev $bridgeName
	fi

	for ethIface in $ethIfaceList; do
		echo -e "  Setting iface $yl$ethIface$ec to ${yl}DOWN$ec"
		ip link set $ethIface down
		echo -e "  Flushing iface $yl$ethIface$ec"
		ip a flush dev $ethIface
		echo -e "  Adding iface $yl$ethIface$ec to $yl$bridgeName$ec"
		ip link set $ethIface master $bridgeName
		echo -e "  Setting iface $yl$ethIface$ec to ${gr}UP$ec"
		ip link set $ethIface up
	done
	echo "  Bridge setup done."
}

createVirtualIfaces() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ethIface ethIfaceList curPortIdx ifaceIdx ifaceQty virtPortName virtIfaceList
	privateVarAssign "${FUNCNAME[0]}" "ethIfaceList" "$*"

	checkIfacesExist $ethIfaceList

	let ifaceIdx=0
	let ifaceQty=$(wc -w<<<"$ethIfaceList")-1
	echo "  Creating virtual interfaces for ifaces: ${gr}$ethIfaceList$ec"
	for ethIface in $ethIfaceList; do
		echo -e "  $yl$ethIface$ec> Processing.."
		for ((curPortIdx=0; curPortIdx<=$ifaceQty; ++curPortIdx)) ; do
			if [ $ifaceIdx -ne $curPortIdx ]; then
				virtPortName=${ethIface}P$curPortIdx
				echo -e "    Adding virtual interface $yl$virtPortName$ec on $org$ethIface$ec"
				ip link add $virtPortName link $ethIface type macvlan mode bridge
				echo -e "    Setting virtual interface $yl$virtPortName$ec ${gr}UP$ec"
				ip link set dev $virtPortName up
				virtIfaceList+=("$virtPortName")
			fi
		done
		let ifaceIdx++
	done
	echo "   Created ifaces: ${virtIfaceList[*]}"
	echo "  Virtual interface setup done."
}

sshSendCmd() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshIP sshUser sshPass sshCmd sshCmdRes pathAdd
	privateVarAssign "${FUNCNAME[0]}" "sshIP" "$1"; shift
	verifyIp "${FUNCNAME[0]}" $sshIP
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$1"; shift
	# privateVarAssign "${FUNCNAME[0]}" "sshPass" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "sshCmd" "$*"

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	dmsg echo -e "  $pr$sshUser$ec@$cy$sshIP$ec $yl>>>$ec $sshCmd" 1>&2
	sshCmdRes="$(ssh -oStrictHostKeyChecking=no $sshUser@$sshIP "$pathAdd; $sshCmd" 2>&1)"
	echo "$sshCmdRes"
}

sshSendCmdSilent() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshIP sshUser sshPass sshCmd sshCmdRes pathAdd
	privateVarAssign "${FUNCNAME[0]}" "sshIP" "$1"; shift
	verifyIp "${FUNCNAME[0]}" $sshIP
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$1"; shift
	# privateVarAssign "${FUNCNAME[0]}" "sshPass" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "sshCmd" "$*"

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	dmsg echo -e "  $pr$sshUser$ec@$cy$sshIP$ec $yl>>>$ec $sshCmd" 1>&2
	sshCmdRes="$(ssh -oStrictHostKeyChecking=no $sshUser@$sshIP "$pathAdd; $sshCmd" 2>&1)"
	# echo "$sshCmdRes"
}

sshSendCmdNohup() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshIP sshUser sshPass sshCmd sshCmdRes pathAdd
	privateVarAssign "${FUNCNAME[0]}" "sshIP" "$1"; shift
	verifyIp "${FUNCNAME[0]}" $sshIP
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$1"; shift
	# privateVarAssign "${FUNCNAME[0]}" "sshPass" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "sshCmd" "$*"

	sshCmd="/root/bin/nohangup.sh 99 ${sshCmd}"

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	dmsg echo -e "  $pr$sshUser$ec@$cy$sshIP$ec $yl>>>$ec $sshCmd" 1>&2
	sshCmdRes="$(ssh -oStrictHostKeyChecking=no $sshUser@$sshIP "$pathAdd; $sshCmd" 2>&1)"
	dmsg echo "$sshCmdRes"
}

sshSendCmdBlockNohup() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshIP sshUser sshPass sshCmd sshCmdRes pathAdd
	privateVarAssign "${FUNCNAME[0]}" "sshIP" "$1"; shift
	verifyIp "${FUNCNAME[0]}" $sshIP
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$1"; shift
	# privateVarAssign "${FUNCNAME[0]}" "sshPass" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "sshCmd" "$*"

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	dmsg echo -e "  $pr$sshUser$ec@$cy$sshIP$ec $yl>>>$ec $sshCmd" 1>&2
	sshCmdRes="$(ssh -oStrictHostKeyChecking=no $sshUser@$sshIP "$pathAdd; nohup sh -c \"$sshCmd\" >/dev/null 2>/dev/null &" 2>&1)"
	dmsg echo "$sshCmdRes"
}

sshCheckLink() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshIP sshUser sshCmd linkSta targEth linkReq linkReqV
	privateVarAssign "${FUNCNAME[0]}" "sshIP" "$1"
	verifyIp "${FUNCNAME[0]}" $sshIP
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "targEth" "$3"
	privateVarAssign "${FUNCNAME[0]}" "linkReq" "$4"
	if [[ "$linkReq" = "yes" ]]; then linkReqV=UP; else linkReqV=DOWN; fi
	
	echo -n "  Check that $targEth is $linkReqV: "
	sshCmd="ethtool $targEth |grep Link |cut -d: -f2 |cut -d ' ' -f2"
	linkSta=$(sshSendCmd $goldSrvIp root ${sshCmd})
	if [[ ! -z "$linkSta" ]]; then
		if [[ ! "$linkSta" = "$linkReq" ]]; then
			echo -e "\e[0;31mFAIL\e[m"
			return 1
		else
			echo -e "\e[0;32mOK\e[m"
			return 0
		fi
	else
		if [[ "$linkReq" = "yes" ]]; then
			echo -e "\e[0;31mFAIL\e[m (null response)" 
			return 1
		else
			echo -e "\e[0;32mOK\e[m (null response)"
			return 0
		fi
	fi
}

sshCheckContains() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshIP sshUser sshCmd keywReq sshCmdRes
	privateVarAssign "${FUNCNAME[0]}" "sshIP" "$1" ;shift
	verifyIp "${FUNCNAME[0]}" $sshIP
	privateVarAssign "${FUNCNAME[0]}" "sshUser" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "keywReq" "$1" ;shift
	# keywReq="'"$keywReq"'"
	privateVarAssign "${FUNCNAME[0]}" "sshCmd" "$*"
	

	sshCmdRes="$(sshSendCmd $sshIP $sshUser ${sshCmd})"
	dmsg inform "sshCmdRes=$sshCmdRes"
	dmsg inform "keywReq=$keywReq"
	dmsg inform "if grep = >$(echo "$sshCmdRes" |grep "$keywReq")<"
	
	if [[ -z "$(echo "$sshCmdRes" |grep "$keywReq")" ]]; then
		echo -e "\e[0;31mFAIL\e[m"
		return 1
	else
		echo -e "\e[0;32mOK\e[m"
		return 0
	fi
}

checkContains() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local keywReq cmdCheck
	privateVarAssign "${FUNCNAME[0]}" "keywReq" "$1" ;shift
	# keywReq="'"$keywReq"'"
	privateVarAssign "${FUNCNAME[0]}" "cmdCheck" "$*"

	dmsg inform "cmdCheck=$cmdCheck"
	dmsg inform "keywReq=$keywReq"
	dmsg inform "if grep = >$(echo "$cmdCheck" |grep "$keywReq")<"
	
	if [[ -z "$(echo "$cmdCheck" |grep "$keywReq")" ]]; then
		echo -e "\e[0;31mFAIL\e[m"
		return 1
	else
		echo -e "\e[0;32mOK\e[m"
		return 0
	fi
}

checkIfNumber() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local numInput re
	privateVarAssign "${FUNCNAME[0]}" "numInput" "$1"
	re='^[+-]?[0-9]+$'
	if ! [[ $numInput =~ $re ]] ; then
		except "provided: $numInput is not a number"
	fi
}

countDownDelay() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local delayTime msgPrompt totalSecs
	privateVarAssign "${FUNCNAME[0]}" "numInput" "$1"; shift
	msgPrompt=$*

	checkIfNumber $numInput
	let totalSecs=$numInput
	tput civis
	while [ $numInput -gt 0 ]; do
		echo -ne "\033[0K\r"
		animDelay 0.0975 $msgPrompt
		: $((numInput--))
		echo -ne " - $yl$numInput$ec seconds left.."
	done
	echo -en "\033[2K\r$msgPrompt$gr waited for $totalSecs seconds. $ec\n"
	tput cnorm
}

verifyMac() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ipInput callerFunc
	privateVarAssign "${FUNCNAME[0]}" "macInput" "$1"

	if [ -z "$(echo -n "$macInput" | tr -d "[:digit:]" | tr -d [ABCDEFabcdef])" ]; then
		dmsg echo -e " $bl MAC Validated$ec" 1>&2 # will mess up definition of bus addresses by ssh if sent by stdout
	else
		except "MAC address is not valid! Please check: $macInput"
	fi
}

verifyIp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ipInput callerFunc
	privateVarAssign "${FUNCNAME[0]}" "callerFunc" "$1"
	privateVarAssign "${FUNCNAME[0]}" "ipInput" "$2"
	regEx='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'; regEx+='0*(1?[0-9]{1,2}|2([‌​0-4][0-9]|5[0-5]))$'
	if [[ "$ipInput" =~ $regEx ]]; then
		dmsg echo -e " $bl IP Validated$ec" 1>&2 # will mess up definition of bus addresses by ssh if sent by stdout
	else
		except "$callerFunc> IP is not valid! Please check: $ipInput"
	fi
}

echoIfExists() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	test -z "$2" || {
		echo -n "$1 "
		shift
		echo "$*"
	}
}

checkUUTTransceivers() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	slcm_start &> /dev/null
	selectSlot "  Select UUT:"
	uutSlotNum=$?
	publicVarAssign warn uutBus $(getDmiSlotBuses |head -n $uutSlotNum |tail -n 1)
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign warn uutBuses $(filterDevsOnBus $(echo -n ":$uutBus:") $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-))
	for dev in $uutBuses; do
		devNet=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $dev |awk -F/ '{print $NF}')
		if [ ! -z "$devNet" ]; then
			uutNetArr+=($devNet)
		fi
	done
	publicVarAssign warn uutNets ${uutNetArr[*]}
	checkTransceivers $uutBuses
}

checkUUTTransVpd() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local dev uutNetArr devNet

	slcm_start &> /dev/null
	selectSlot "  Select UUT:"
	uutSlotNum=$?
	publicVarAssign warn uutBus $(getDmiSlotBuses |head -n $uutSlotNum |tail -n 1)
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign warn uutBuses $(filterDevsOnBus $(echo -n ":$uutBus:") $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-))
	for dev in $uutBuses; do
		devNet=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $dev |awk -F/ '{print $NF}')
		if [ ! -z "$devNet" ]; then
			uutNetArr+=($devNet)
		fi
	done
	publicVarAssign warn uutNets ${uutNetArr[*]}
	getSfpVPDInfo $uutNets
}

writeUUTTransceivers() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	privateVarAssign "${FUNCNAME[0]}" "eepromFileArg" "$1"
	testFileExist $eepromFileArg

	slcm_start &> /dev/null
	selectSlot "  Select UUT:"
	uutSlotNum=$?
	publicVarAssign warn uutBus $(getDmiSlotBuses |head -n $uutSlotNum |tail -n 1)
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign warn uutBuses $(filterDevsOnBus $(echo -n ":$uutBus:") $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-))
	for dev in $uutBuses; do
		devNet=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $dev |awk -F/ '{print $NF}')
		if [ ! -z "$devNet" ]; then
			uutNetArr+=($devNet)
		fi
	done
	publicVarAssign warn uutNets ${uutNetArr[*]}
	writeSfpEEPROMFromFile "$eepromFileArg" $uutBuses
}

readEEPROMMasterFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local line eepromFile pageAddr byteAddr byteVal curLine pageNum byteNum
	eepromFile=$1
	testFileExist $eepromFile
	while read line; 
	do 		
		if [[ ! -z "$line" ]]; then
			pageAddr="$(echo $line |awk '{print $1}')"
			if [[ "$pageAddr" = "0xa0" ]]; then pageNum=2; else pageNum=3; fi
			byteAddr=$(echo -n $line |awk '{print $2}' | tr -dc '[:print:]')
			byteVal=$(echo -n $line |awk '{print $3}' | tr -dc '[:print:]')
			transData[$byteAddr,$pageNum]=$byteVal
		fi
	done <<< "$(cat $eepromFile)"	
}

checkTransceivers() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busesAddrs bus
	privateVarAssign "${FUNCNAME[0]}" "busesAddrs" "$*"
	for bus in $busesAddrs; do
		checkTransceiver $bus
	done
}

checkTransceiver() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local transData busAddr byteNum totalStatus pageNum currPage byteAddr errMsg charCnt
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"

	let totalStatus=0
	declare -A transData
# 		transData arraingment		transData[byteAddr,pageAddr]
# 	-------------------------------------
#      	PAGE>>  0xa0		0xa2		0xa0_DMP		0xa2_DMP		checkRes
#			0  	0x0			0x0			0x0				0x0				0 or 1
# 			1	0x0			0x0			0x0				0x0				0 or 1
# 			2	0x0			0x0			0x0				0x0				0 or 1
# 			3	0x0			0x0			0x0				0x0				0 or 1
# 			4	0x0			0x0			0x0				0x0				0 or 1
# 			ETC..	ETC..	ETC..		ETC..			ETC..			ETC..
# 	-------------------------------------
	readTransceiver $busAddr
	readEEPROMMasterFile /root/PE310G4BPI71/PE310G4BPI71-SR_TRANS_EEPROM.txt
	# for ((byteNum=0;byteNum<=127;byteNum++))
	# do
	# 	echo "${transData[$byteNum,0]} ${transData[$byteNum,2]}  ${transData[$byteNum,1]} ${transData[$byteNum,3]}"
	# 	#echo "$busAddr: Byte $byteNum:  "${transData[$byteNum,0]} ${transData[$byteNum,2]}  ${transData[$byteNum,1]} ${transData[$byteNum,3]}
	# done
	for ((byteNum=0;byteNum<=127;byteNum++))
	do
		let transData[$byteNum,4]=0
		if [[ ! -z ${transData[$byteNum,2]} ]]; then 
			if [[ ! "${transData[$byteNum,0]}" = "${transData[$byteNum,2]}" ]]; then
				let charCnt=$(echo -n ${transData[$byteNum,0]} |wc -c)
				if [ $charCnt -eq 3 ]; then addEl=" "; else unset addEl; fi #added "No-Break Space" U+00A0, or Alt+0160
				transData[$byteNum,0]=$(echo -ne "\e[0;31m${transData[$byteNum,0]}$addEl\e[m")
				let transData[$byteNum,4]++
				errMsg+=" Value missmatch! Page: 0xa0, Addr: $byteNum, Expected value: ${transData[$byteNum,2]}, Actual value: ${transData[$byteNum,0]}\n"
			fi
		fi
		if [[ ! -z ${transData[$byteNum,3]} ]]; then 
			if [[ ! "${transData[$byteNum,1]}" = "${transData[$byteNum,3]}" ]]; then
				let charCnt=$(echo -n ${transData[$byteNum,1]} |wc -c)
				if [ $charCnt -eq 3 ]; then addEl=" "; else unset addEl; fi #added "No-Break Space" U+00A0, or Alt+0160
				transData[$byteNum,1]=$(echo -ne "\e[0;31m${transData[$byteNum,1]}$addEl\e[m")
				let transData[$byteNum,4]++
				errMsg+=" Value missmatch! Page: 0xa2, Addr: $byteNum, Expected value: ${transData[$byteNum,3]}, Actual value: ${transData[$byteNum,1]}\n"
			fi
		fi
		let totalStatus+=transData[$byteNum,4]
		# dmsg echo -e "$busAddr: Byte $byteNum:  CPGa0:${transData[$byteNum,0]} DPGa0:${transData[$byteNum,2]}  CPGa2:${transData[$byteNum,1]} DPGa2:${transData[$byteNum,3]}  status=${transData[$byteNum,4]}"
	done
	dmsg echo "  totalStatus=$totalStatus"

	echo -e "\n\n ╔═══════════════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╗\n ║ BUS: $busAddr  ║   0  ║   1  ║   2  ║   3  ║   4  ║   5  ║   6  ║   7  ║   8  ║   9  ║"
	for ((pageNum=0;pageNum<=1;pageNum++))
	do 
		if [ $pageNum -eq 0 ]; then currPage=0xa0; else currPage=0xa2; fi
		for byteNum in {0..127..10}
		do 
			for ((byteVarCnt=0;byteVarCnt<=9;byteVarCnt++))
			do
				let byteAddr=$byteNum+$byteVarCnt
				eval "vl$byteVarCnt"='${transData[$byteAddr,$pageNum]}'
			done
			printf " ╠═══════════════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╣\n ║ %-5s %6s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║ %-4s ║\n" "$currPage: " "$byteNum: " $vl0 $vl1 $vl2 $vl3 $vl4 $vl5 $vl6 $vl7 $vl8 $vl9 
		done
	done
	echo -e " ╚═══════════════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╝"

	if [[ ! -z "$errMsg" ]]; then
		echo -e "\n\n$errMsg"
	fi
}

getSfpVPDInfo() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slcmCmdRes sfpVen sfpVenPn sfpVenSn sfpVenManufDate sfpWL busAddr
	privateVarAssign "${FUNCNAME[0]}" "ethIfaceList" "$*"
	checkIfacesExist $ethIfaceList

	for ethName in $ethIfaceList; do
		slcmCmdRes="$(slcm_util $ethName get_sfp_info)"
		sfpVen=$(echo "$slcmCmdRes" |grep "vendor:" |cut -d ' ' -f2)
		sfpVenPn=$(echo "$slcmCmdRes" |grep "vendor PN:" |cut -d ' ' -f3)
		sfpVenSn=$(echo "$slcmCmdRes" |grep "vendor sn:" |cut -d ' ' -f3)
		sfpVenManufDate=$(echo "$slcmCmdRes" |grep "date" |cut -d ' ' -f5)
		sfpWL=$(echo "$slcmCmdRes" |grep "wavelength" |cut -d ' ' -f3)
		echo -e "\n\n ETH Iface: $bl$ethName$ec"
		echo -e "  Vendor: $yl$sfpVen$ec\n  PN: $yl$sfpVenPn$ec\n  SN: $cy$sfpVenSn$ec  \n  Manufacture date: $cy$sfpVenManufDate$ec\n  Wavelength: $cy$sfpWL$ec"
		speedInfo="$(ethtool $ethName |grep base |tr -d '\t' |awk '{print $NF}' |sort |uniq)"
		if [ ! -z "$speedInfo" ]; then
			echo -e "  Speed support:"
			for spd in $speedInfo; do
				echo -e "   $yl$spd$ec"
			done
		fi
		echo -e "\n"
	done
}


function dumpSfpRegsToFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddrList busAddr fileArg currVal
	privateVarAssign "${FUNCNAME[0]}" "fileName" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "busAddrList" "$*"

	lsmod |grep slcm &> /dev/null || slcm_start &> /dev/null

	if [ -d "$fileName" ]; then
		except "file name $fileName is actualy a direrctory, cant be used."
	else
		local haveDots=$(grep '.'<<<"$fileName")
		# if isDefined haveDots; then
		# 	except "illegal file name $fileName , cant have dots in name"
		# fi
	fi

	for busAddr in $busAddrList; do
		testFileExist "/sys/bus/pci/devices/0000:$busAddr/"
	done
	let dumpStat=0

	mkdir -p "./EEPROM_dumps/"
	for busAddr in $busAddrList; do
		busPort=$(cut -d. -f2<<<"$busAddr")
		dumpFullPath="./EEPROM_dumps/${fileName}_p$busPort.EEPDMP"
		crcFullPath="./EEPROM_dumps/${fileName}_p$busPort.EEPDMP.crc"
		rm -f $dumpFullPath >/dev/null 2>&1
		rm -f $crcFullPath >/dev/null 2>&1

		tput civis
		echo -e "\n\n\n\tDumping bus: ${blw}$busAddr$ec\n"
		echo -e "\t${cy}Reading page 0xa0 on $busAddr..$ec"
		pageAddr="0xa0"
		for ((byteNum=0;byteNum<=127;byteNum++)); do  #excluding SN zone, and date code
			echo -e -n "\t  Reg:$byteNum : "
			currVal=$(readSfpAddr $busAddr $pageAddr $byteNum; exit $?)
			if [ $? -eq 0 ]; then
				echo -e "${gr}$currVal$ec"
				echo "$pageAddr $byteNum $currVal">>$dumpFullPath
				echo -ne '\e[A'
			else
				echo "$pageAddr $byteNum 0xEE">>$dumpFullPath
				echo -e "${rd}Dump failed.$ec"
				let dumpStat+=1
				echo -ne '\e[A'
			fi
		done	

		echo -e "\n\n\t${cy}Reading page 0xa2 on $busAddr..$ec"
		pageAddr="0xa2"
		for ((byteNum=0;byteNum<=127;byteNum++)); do   #excluding sensors and status bits
			echo -e -n "\t  Reg:$byteNum : "
			if (( $byteNum <= 95 || $byteNum >= 120)); then	
				currVal=$(readSfpAddr $busAddr $pageAddr $byteNum; exit $?)
				if [ $? -eq 0 ]; then
					echo -e "${gr}$currVal$ec"
					echo "$pageAddr $byteNum $currVal">>$dumpFullPath
				else
					echo "$pageAddr $byteNum 0xEE">>$dumpFullPath
					echo -e "${rd}Dump failed.$ec"
					let dumpStat+=1
				fi
				echo -ne '\e[A'
			else
				if (( $byteNum >= 96 && $byteNum <= 109)); then	
					echo -e "${pr}A/D Values region, skipping$ec"; sleep 0.05
				else
					echo -e "${bl}Status Bits and Flags region, skipping$ec"; sleep 0.05
				fi
				echo -ne '\e[A\e[K\e[0;30m\n\e[m\e[A\e[K'
			fi
		done
		echo -e "\n\t${yl}Creating CRC file for the dump..$ec"
		makeFileCrc "$dumpFullPath"
		echo -e "\t${gr}Done.$ec"
		if [ ! -e "$crcFullPath" ]; then except "CRC file could not be created for the dump file: $dumpFullPath"; fi
		tput cnorm
	done

	return $dumpStat
}

writeSfpEEPROMFromFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local masterByteDumpVal busAddr fileArg
	privateVarAssign "${FUNCNAME[0]}" "fileArg" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "busAddrList" "$*"
	
	testFileExist $fileArg
	for busAddr in $busAddrList; do
		testFileExist "/sys/bus/pci/devices/0000:$busAddr/"
	done
# 		transData arraingment		transData[byteAddr,pageAddr]
# 	-------------------------------------
#      	PAGE>>  0xa0		0xa2		0xa0_DMP		0xa2_DMP		checkRes
#			0  	0x0			0x0			0x0				0x0				0 or 1
# 			1	0x0			0x0			0x0				0x0				0 or 1
# 			2	0x0			0x0			0x0				0x0				0 or 1
# 			3	0x0			0x0			0x0				0x0				0 or 1
# 			4	0x0			0x0			0x0				0x0				0 or 1
# 			ETC..	ETC..	ETC..		ETC..			ETC..			ETC..
# 	-------------------------------------

	declare -A transData
	echo -e "\tReading transceiver EEPROM master file.."
	readEEPROMMasterFile $fileArg

	for busAddr in $busAddrList; do
		echo -e "\n\n\n\tChecking bus: ${blw}$busAddr$ec\n"
		echo -e "\t${cy}Writing page 0xa0..$ec"
		for ((byteNum=0;byteNum<=127;byteNum++)); do  #excluding SN zone, and date code
			echo -e -n "\nReg:$byteNum : "
			if (( $byteNum < 68 || $byteNum > 91)); then	
				masterByteDumpVal=${transData[$byteNum,2]}
				if [[ ! -z "$masterByteDumpVal" ]]; then 
					checkSfpReg $busAddr 0xa0 $byteNum $masterByteDumpVal
				fi	
			else
				if (( $byteNum >= 68 && $byteNum <= 83)); then	
					echo -e -n "${pr}Vendor SN region, skipping$ec"
				else
					echo -e -n "${bl}Date code region, skipping$ec"
				fi
			fi
		done	

		echo -e "\n\n\t${cy}Writing page 0xa2..$ec"
		for ((byteNum=0;byteNum<=127;byteNum++)); do   #excluding sensors and status bits
			echo -e -n "\nReg:$byteNum : "
			if (( $byteNum <= 95 || $byteNum >= 120)); then	
				masterByteDumpVal=${transData[$byteNum,3]}
				if [[ ! -z "$masterByteDumpVal" ]]; then 
					checkSfpReg $busAddr 0xa2 $byteNum $masterByteDumpVal
				fi	
			else
				if (( $byteNum >= 96 && $byteNum <= 109)); then	
					echo -e -n "${pr}A/D Values region, skipping$ec"
				else
					echo -e -n "${bl}Status Bits and Flags region, skipping$ec"
				fi
			fi
		done
	done

	echo -e "\n\n\t${cy}Done.$ec"
}


checkSfpReg() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"

	local retCnt busAddr pageAddr offset newVal curValBin newValBin cmdRetStat currVal writeVerify
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"
	privateVarAssign "${FUNCNAME[0]}" "pageAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "offset" "$3"
	privateVarAssign "${FUNCNAME[0]}" "newVal" "$4"
	
	currVal=$(readSfpAddr $busAddr $pageAddr $offset; exit $?)
	cmdRetStat=$?
	if [ -z "$cmdRetStat" ]; then dmsg inform "cmdRetStat is empty"; let cmdRetStat=99; fi
	if [ $cmdRetStat -eq 0 ]; then
		curValBin=$(echo "obase=2; ibase=16; $(echo $currVal |cut -dx -f2- |tr '[:lower:]' '[:upper:]')" | bc )
		newValBin=$(echo "obase=2; ibase=16; $(echo $newVal |cut -dx -f2- |tr '[:lower:]' '[:upper:]')" | bc )
		#echo -n " curVal: $curValBin  new val: $newValBin "
		if [ "$newValBin" = "$curValBin" ]; then
			echo -e -n "\e[0;33mvalues are same ($currVal), skipping\e[m"
		else
			writeVerify=$(writeSfpAddr $busAddr $pageAddr $offset $newVal; exit $?)
			case $? in
				0) echo -ne "$writeVerify";;
				1|2|3|4|99) 
					echo -ne "$writeVerify"
					echo -e "\n\n\t\e[0;31mUnable to proceed.\e[m"
					exit
				;;
				*) except "unexpected exit status of readSfpAddr"
			esac
		fi
	else
		except "unable to get currVal: $currVal"
	fi
}

function writeSfpAddr () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr offset slcmRes slcmWC resErr lastNonErrVal
	local currVal newVal retRes writeRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"
	privateVarAssign "${FUNCNAME[0]}" "pageAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "offset" "$3"
	privateVarAssign "${FUNCNAME[0]}" "newVal" "$4"
	let retCnt=5
	let writeOK=0
	let retRes=99

	while [ $writeOK -eq 0 -a $retCnt -gt 0 ]; do
		let resErr=0
		currVal=$(readSfpAddr $busAddr $pageAddr $offset; exit $?)
		if [ $? -eq 0 ]; then
			echo -e -n "\e[0;31moverwriting old value $currVal with $newVal \e[m"	
			writeRes=$(slcm_util $busAddr write_sfp $offset $pageAddr $newVal)	 2>&1 > /dev/null	
			writeResOK="$(grep "Ok" <<<"$writeRes")"
			if [ -z "$writeResOK" ]; then
				writeRes="\e[0;31mvaule NOT updated!\e[m"
				let retRes=2
			else
				writeRes="\e[0;32mvaule updated!\e[m"
				writeVerify=$(readSfpAddr $busAddr $pageAddr $offset; exit $?)
				case $? in
					0) 
						if [ "$writeVerify" = "$newVal" ]; then
							writeRes="\e[0;32m Verify: OK\e[m"
							let writeOK=1
							let retRes=0
							break
						else
							writeRes="\e[0;31m Verify: FAIL! wrV:$writeVerify nW:$newVal\e[m"
							let retRes=4
						fi
					;;
					1|2|99) 
						let retRes=3
						writeRes="$writeVerify"
					;;
					*) except "unexpected exit status of readSfpAddr"
				esac
			fi
		else
			let retRes=1
			echo -e -n "\e[0;33mread error, retrying ($retCnt left) \e[m"
		fi
		let retCnt--
	done
	echo -e "$writeRes"
	return $retRes
}

function readSfpAddr () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr offset slcmRes slcmWC resErr lastNonErrVal retRes readOK readRes isOkValue
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"
	privateVarAssign "${FUNCNAME[0]}" "pageAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "offset" "$3"

	let retCnt=5
	let readOK=0
	let retRes=99
	lastNonErrVal=""
	while [ $readOK -eq 0 -a $retCnt -gt 0 ]; do
		let retCnt--
		let resErr=0
		slcmRes=$(slcm_util $busAddr read_sfp $offset $pageAddr)
		slcmWC=$(echo $slcmRes |wc -w)
		if [ -z "$slcmWC" ]; then slcmWC="-1"; fi
		if [ "$slcmWC" = "1" ]; then
			printf "%d\n" $slcmRes &>/dev/null
			if [ $? -eq 0 ]; then 
				readRes="$slcmRes"
			else
				readRes="\e[0;47;31m0xEE\e[m"
				let resErr=1
			fi
		else
			readRes="\e[0;47;31m0xEE\e[m"
			let resErr=1
		fi
		if [ $resErr -eq 0 ]; then
			isOkValue="$(echo $readRes |grep "x")"
			if [ ! -z "$isOkValue" ]; then
				if [ "$readRes" = "$lastNonErrVal" ]; then
					let retRes=0
					let readOK=1
					break
				else
					lastNonErrVal=$readRes
				fi
			else
				let retRes=1
				readRes="\e[0;33minvalid value received, retrying ($retCnt left) \e[m"
			fi
		else
			let retRes=2
			readRes="\e[0;33merror received, retrying ($retCnt left) \e[m"
		fi
	done
	echo -ne "$readRes"
	return $retRes
}

readTransceiver() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr byteAddr acqRes pageNum byteNum currPage slcmWC slcmRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"

	for ((pageNum=0;pageNum<=1;pageNum++))
	do 
		if [ $pageNum -eq 0 ]; then currPage=0xa0; else currPage=0xa2; fi
		for ((byteNum=0;byteNum<=127 ;byteNum++))
		do
			slcmRes=$(slcm_util $busAddr read_sfp $byteNum $currPage)
			slcmWC=$(echo $slcmRes |wc -w)
			if [ "$slcmWC" = "1" ]; then
				printf "%d\n" $slcmRes &>/dev/null
				if [ $? -eq 0 ]; then 
					transData[$byteNum,$pageNum]=$slcmRes
				else
					transData[$byteNum,$pageNum]=$(echo -ne "\e[0;47;31m0xEE\e[m")
				fi
			else
				transData[$byteNum,$pageNum]=$(echo -ne "\e[0;47;31m0xEE\e[m")
			fi
		done
	done
}

compareEEPROM() {
	local busAddr line eepromFile addr byteAddr byteVal curVal totalLines curLine
	busAddr=$1
	eepromFile=$2
	rm -f /tmp/eepromErrTmpLog.log
	let lineEmpty=1
	let curLine=0
	let totalLines=$(cat ./$eepromFile | wc -l)
	while read line; 
	do 		
		test -z "$line" || {
			addr="$(echo $line |awk '{print $1}')"
			byteAddr="$(echo $line |awk '{print $2}')"
			byteVal="$(echo $line |awk '{print $3}' |cut -dx -f2- |tr '[:lower:]' '[:upper:]')"
			curVal="$(read_sfp_addr "$busAddr" "$addr" "$byteAddr")"
			let execPerc=$(echo $curLine |awk '{print int($1/'$totalLines'*100)}')
			test "$lineEmpty" = "0" && {
				clearLine "noOverwrite"
			}
			test "$curVal" = "$byteVal" && {
				echo -e $(echo -e 'Verifying '"$busAddr"':'"$addr"':'"$byteAddr: OK  $execPerc%") > /dev/null 2>&1
			} || {
				echo -e $(echo -e 'Verifying '"$busAddr"':'"$addr"':'"$byteAddr: ERROR! CURVAL: $curVal  MASTDMP: $byteVal" |& tee -a /tmp/eepromErrTmpLog.log) > /dev/null 2>&1
				warn "Vaules missmatch! Vaule: $curVal received! " "nnl" "sil"
				#sleep 0.3
				warn "Repetitive read $busAddr"':'"$addr"':'"$byteAddr: $(read_sfp_addr "$busAddr" "$addr" "$byteAddr")," "nnl" "sil"
				#sleep 0.3
				warn "$(read_sfp_addr "$busAddr" "$addr" "$byteAddr")," "nnl" "sil"
				#sleep 0.3
				warn "$(read_sfp_addr "$busAddr" "$addr" "$byteAddr")" "" "sil"
			}
			echo -e 'Verifying '"$busAddr"':'"$addr"':'"$byteAddr. $execPerc% done." 
			let lineEmpty=0
		}
		let curLine=$curLine+1
	done <<< "$(cat ./$eepromFile)"
	if [ -e /tmp/eepromErrTmpLog.log ] 
	then
		let passedCount=$totalLines-$(cat /tmp/eepromErrTmpLog.log | wc -l) > /dev/null 2>&1
		clearLine
		critWarn "EEPROM verification failed! Register total, failed: $(cat /tmp/eepromErrTmpLog.log | wc -l) passed: $passedCount"
		test "$showFailRegs" = "1" && cat /tmp/eepromErrTmpLog.log 			
	else
		clearLine
		passMsg "EEPROM verification passed! Register total: $totalLines"
	fi
}


printTransArr() {
	for bus in 81:00.0 81:00.1 81:00.2 81:00.3
	do
		echo -e "\n\n ╔═══════════════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╦══════╗\n ║ BUS: $bus  ║   0  ║   1  ║   2  ║   3  ║   4  ║   5  ║   6  ║   7  ║   8  ║   9  ║"
		for page in 0xa0 0xa2
		do 
			for ((i=0;i<=26;i++))
			do
				printf " ╠═══════════════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╬══════╣\n ║ %5s %6s ║ %4s ║ %4s ║ %4s ║ %4s ║ %4s ║ %4s ║ %4s ║ %4s ║ %4s ║ %4s ║\n" "$page: " "$(($i*10)): " $(slcm_util $bus read_sfp $i\0 $page) $(slcm_util $bus read_sfp $i\1 $page) $(slcm_util $bus read_sfp $i\2 $page) $(slcm_util $bus read_sfp $i\3 $page) $(slcm_util $bus read_sfp $i\4 $page) $(slcm_util $bus read_sfp $i\5 $page) $(slcm_util $bus read_sfp $i\6 $page) $(slcm_util $bus read_sfp $i\7 $page) $(slcm_util $bus read_sfp $i\8 $page) $(slcm_util $bus read_sfp $i\9 $page)
			done
		done
		echo -e " ╚═══════════════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╩══════╝"
	done
}

slcm_read() {
	#dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr byteAddr acqRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"
	privateVarAssign "${FUNCNAME[0]}" "pageAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "byteAddr" "$3"

	result='nullRead'
	#echo "READ_SFP_ADDR   DEBUG: "'('"$busAddr"':'"$pageAddr"':'"$byteAddr"')'
	acqRes=$(slcm_util $busAddr read_sfp $byteAddr $pageAddr |cut -dx -f2- |tr '[:lower:]' '[:upper:]')
	for ((i=0;i<=$sfpReadCount;i++)); do   #try few times because sometimes the first acquiring fails returning "ERROR!"
		test -z "$acqRes" || {
			test -z "$(echo "$acqRes" |grep ERROR)" && {
				echo "$acqRes"
				break
			} || {
				acqRes=$(slcm_util $busAddr read_sfp $byteAddr $pageAddr |cut -dx -f2- |tr '[:lower:]' '[:upper:]')
			}
		} && {
			acqRes=$(slcm_util $busAddr read_sfp $byteAddr $pageAddr |cut -dx -f2- |tr '[:lower:]' '[:upper:]')
			# first acquring after system reboot always is incorrect, so running read again 
		}
	done
	test -z "$(echo "$acqRes" |grep ERROR)" || echo "$acqRes"	
}

stsTransData() {
	# if [ -z "$bcmCmdRes" ]; then
	# 	export bcmCmdRes="$(sendBCMGetQSFPInfo 250 2>&1)"
	# fi
	for phyId in 8 9 10 11 12; do 
		echo "$bcmCmdRes" |grep -A10 "PHY id $phyId" |grep PNP |cut -d: -f2 |awk '{print $1=$1}'
	done
}

diskWriteTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local diskDev skipBlockSizeMB writeBlockSizeMB testStatus
	privateVarAssign "${FUNCNAME[0]}" "diskDev" "$1"
	skipBlockSizeMB=$2
	writeBlockSizeMB=$3

	if [ -z "$skipBlockSizeMB" -o -z "$writeBlockSizeMB" ]; then
		let skipBlockSizeMB=128
		let writeBlockSizeMB=16
	else
		privateNumAssign "skipBlockSizeMB" "$2"
		privateNumAssign "writeBlockSizeMB" "$3"
	fi

	let testStatus=0
	testFile="/tmp/random_data_file.bin"
	mountedDev="$(mount |grep "$diskDev")"

	echo -ne "\tDevice path: $yl$diskDev$ec "
	if [ ! -e "$diskDev" ]; then 
		echo -e "${rd}FAIL$ec"
	else
		echo -e "${gr}OK$ec"
		if [ -z "$mountedDev" ]; then 
			privateNumAssign "totalSpaceMB" $(($(blockdev --getsize64 $diskDev)/1024/1024))
			let totalSpaceMB=$(($totalSpaceMB-$writeBlockSizeMB)) #for safety

			if [ $totalSpaceMB -lt 145 ]; then
				except "Device $diskDev size is $totalSpaceMB and is less than 161MB so cannot be used"
			fi

			echo -e "\tTotal device size: $gr$(($totalSpaceMB+$writeBlockSizeMB))MB$ec"
			echo -e "\tSeek block size: $yl${skipBlockSizeMB}MB$ec"
			echo -e "\tWrite block size: $yl${writeBlockSizeMB}MB$ec"
			echo -e "\tTotal test write count: $yl$(($totalSpaceMB/$skipBlockSizeMB))$ec\n\n"

			createRandomFile "$testFile" $writeBlockSizeMB
			sourceChecksum=$(calculateChecksum "$testFile")

			for ((startAddr = $skipBlockSizeMB; startAddr < totalSpaceMB; startAddr += $skipBlockSizeMB)); do
				endAddr=$((startAddr + $writeBlockSizeMB))

				backupFilePath="/tmp/backup_${startAddr}-${endAddr}MB.bin"
				backupBlock "$diskDev" "$startAddr" "$endAddr" "$backupFilePath" $writeBlockSizeMB
				writeZeros "$diskDev" "$startAddr" "$endAddr" $writeBlockSizeMB
				verifyZeros "$diskDev" "$startAddr" "$endAddr" $writeBlockSizeMB
				writeRandomData "$diskDev" "$startAddr" "$endAddr" "$testFile" $writeBlockSizeMB
				exec 3>&1
				dumpedChecksum=$(dumpAndCalculateChecksum "$diskDev" "$startAddr" "$endAddr" $writeBlockSizeMB 4>&1)
				exec 3>&-

				# The prompts are displayed using file descriptor 3 (>&3), 
				# and the actual results of the calculation are redirected to file descriptor 4 (>&4). 
				# By using >&3- in the subshell command grouping, 
				# we close file descriptor 3 for the calculation output, ensuring that 
				# only the prompts are displayed there. The resultsOfCalc variable captures 
				# only the contents of file descriptor 4, which contains the calculation results.

				printf '\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K'
				echo -ne "\tWrite test on ${startAddr}-${endAddr}MB "
				if [ "$sourceChecksum" = "$dumpedChecksum" ]; then
					echo -e "\t${gr}OK$ec"
				else
					echo -e "\t${rd}FAIL$ec"
					let testStatus++
				fi

				restoreBlock "$diskDev" "$startAddr" "$endAddr" "$backupFilePath" $writeBlockSizeMB
				printf '\e[A\e[K'
				
			done
			if [ $testStatus -eq 0 ]; then
				echo -e "\e[A\e[K\tResult: Write test PASSED\t\t\t\t\t\t\t\t"
			else
				echo -e "\e[A\e[K\tResult: Write test FAILED\t\t\t\t\t\t\t\t"
			fi
			rm -f "$testFile"
		else
			echo -e "\t${rd}Mount list:$yl\n$mountedDev$ec\n"
			except "Device $diskDev is in use and cannot be tested, unmount it first"
		fi
	fi
}

calculateChecksum() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local file
	privateVarAssign "${FUNCNAME[0]}" "file" "$1"
	checkPkgExist md5sum
	if [ -e "$file" ]; then
		md5sum "$file" |awk '{print $1}'
	else
		except "File $filePath does not exist"
	fi
}

function execWithTimeout() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local timeout exitStatus cmdLine
	timeout=$1; shift
	if isNumber timeout; then
		if [ $timeout -lt 1 ]; then
			except "Timeout: $timeout cant be less than 1 second or decimal"
		fi
	else
		except "provided: $timeout is not a number, should be whole number more than 1"
	fi
	cmdLine="$*"
	if isDefined cmdLine; then
		eval timeout -k5 -s9 $timeout "${cmdLine}"
		let exitStatus=$?
	else
		except "Undefined command"
	fi
	if isDefined exitStatus; then
		let exitCode=$exitStatus
		case $exitStatus in
			124) except "Command: ${cmdLine} has timed out." ;;
			125) except "Timeout command has failed." ;;
			126) except "Command: ${cmdLine} is found but cannot be invoked." ;;
			127) except "Command: ${cmdLine} is not found." ;;
			137) except "Command: ${cmdLine} (or timeout itself) is sent the KILL (9) signal." ;;
			0|1) ;;
			*) except "Command: ${cmdLine} produced unexpected exit code: $exitStatus"
		esac
	else
		except "Exit code is undefined"
	fi
	return $exitCode
}

createRandomFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath mbCount timeoutN cmdL
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	privateNumAssign "mbCount" "$2"

	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi
	cmdL='dd if=/dev/urandom of="'"$filePath"'" bs=1M count='"$mbCount"' status=none'
	execWithTimeout $timeoutN "$cmdL"
	if [ $? -ne 0 ]; then except "Failed to create random file"; fi
	if [ ! -e "$filePath" ]; then
		except "Random file $filePath does not exist"
	fi
}

backupBlock() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount timeoutN cmdL
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateVarAssign "${FUNCNAME[0]}" "backupFile" "$4"
	privateNumAssign "mbCount" "$5"

	if [ -e "$devPath" ]; then
		rm -f "$backupFile" &>/dev/null
		if [ ! -e "$backupFile" ]; then
			echo -ne "\tBacking up block from region ${startAddr}-${endAddr}MB.."
			if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi
			cmdL='dd if="'"$devPath"'" skip="'"$startAddr"'" bs=1M count='"$mbCount"' of="'"$backupFile"'" status=none'
			isDefined ddVerbose && echo -n "dumping->"
			execWithTimeout $timeoutN "$cmdL"
			if [ $? -ne 0 ]; then except "Backing up of the block failed"; fi
			isDefined ddVerbose && echo "dumped." || echo
		else
			except "Backup file: $backupFile was not removed"
		fi
	else
		except "Device $devPath does not exist"
	fi
}

writeZeros() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount timeoutN
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateNumAssign "mbCount" "$4"

	if [ -e "$devPath" ]; then
		echo -ne "\tWriting zeros to block from region ${startAddr}-${endAddr}MB.."
		if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi
		cmdL='dd if=/dev/zero of="'"$devPath"'" seek="'"$startAddr"'" bs=1M count='"$mbCount"' conv=notrunc status=none'
		isDefined ddVerbose && echo -n "writing->"
		execWithTimeout $timeoutN "$cmdL"
		if [ $? -ne 0 ]; then except "Zero write to the region failed"; fi
		isDefined ddVerbose && echo "written." || echo
	else
		except "Device $devPath does not exist"
	fi
}

verifyZeros() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount byteCount cmdL timeoutN compareFilePath dumpByteSize cmpRes
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateNumAssign "mbCount" "$4"
	privateNumAssign "byteCount" "$(($mbCount*1048576))"
	compareFilePath="/tmp/$(xxd -u -l 4 -p /dev/urandom).dump"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" ]; then
		echo -ne "\tVerifying zeros in block from region ${startAddr}-${endAddr}MB.."
		if [ ! -e "$compareFilePath" ]; then
			cmdL='dd if="'"$devPath"'" of="'"$compareFilePath"'" skip="'"$startAddr"'" bs=1M count='"$mbCount"' status=none'
			isDefined ddVerbose && echo -n "dumping->"
			execWithTimeout $timeoutN "$cmdL"
			if [ $? -ne 0 ]; then except "Dump of the region failed"; fi
			isDefined ddVerbose && echo -n "dumped.."
			if [ -e "$compareFilePath" ]; then
				privateNumAssign dumpByteSize $(du -b "$compareFilePath" |cut -d/ -f1 |tr -cd '[:digit:]')
				if [ $dumpByteSize -eq $byteCount ]; then
					cmdL='cmp -n '"$byteCount"' /dev/zero "'"$compareFilePath"'" &>/dev/null'
					isDefined ddVerbose && echo -n "comparing->"
					execWithTimeout $timeoutN "$cmdL"; cmpRes=$?
					isDefined ddVerbose && echo "compared." || echo
					if [ $cmpRes -eq 0 ]; then
						echo -e "\t${gr}Block verified as zeros$ec"
					else
						except "Block verification failed"
					fi
					
				else
					except "Dump size does not match, dump: $dumpByteSize, target count: $byteCount"
				fi
			else
				except "Dump failed"
			fi
		else
			except "Temporary compare file already exist"
		fi
	else
		except "Device $devPath does not exist"
	fi

	rm -f "$compareFilePath" &>/dev/null
}

writeRandomData() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount byteCount timeoutN cmdL
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateVarAssign "${FUNCNAME[0]}" "inputFile" "$4"
	privateNumAssign "mbCount" "$5"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" -a -e "$inputFile" ]; then
		echo -ne "\tWriting random data to block from region ${startAddr}-${endAddr}MB.."
		cmdL='dd if="'"$inputFile"'" of="'"$devPath"'" seek='"$startAddr"' bs=1M count='"$mbCount"' conv=notrunc status=none'
		isDefined ddVerbose && echo -n "writing->"
		execWithTimeout $timeoutN "$cmdL"
		if [ $? -ne 0 ]; then except "Writing to the region failed"; fi
		isDefined ddVerbose && echo "written." || echo
	else
		except "Device $devPath or file path $inputFile does not exist"
	fi
}

function dumpAndCalculateChecksum () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount resRet checksum timeoutN cmdL dumpByteSize byteCount dumpPath
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateNumAssign "mbCount" "$4"
	# The prompts are displayed using file descriptor 3 (>&3), 
	# and the actual results of the calculation are redirected to file descriptor 4 (>&4). 
	# By using >&3- in the subshell command grouping, 
	# we close file descriptor 3 for the calculation output, ensuring that 
	# only the prompts are displayed there. The resultsOfCalc variable captures 
	# only the contents of file descriptor 4, which contains the calculation results.
	let resRet=1
	privateNumAssign "byteCount" "$(($mbCount*1048576))"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" ]; then
		dumpPath="/tmp/dump_${startAddr}-${endAddr}MB.bin"; rm -f "$dumpPath" &>/dev/null
		echo -ne "\tDumping block from region ${startAddr}-${endAddr}MB.." >&3
		if [ ! -e "$dumpPath" ]; then
			cmdL='dd if="'"$devPath"'" of="'"$dumpPath"'" skip='"$startAddr"' bs=1M count='"$mbCount"' status=none'
			isDefined ddVerbose && echo -n "dumping->" >&3
			execWithTimeout $timeoutN "$cmdL"
			if [ $? -ne 0 ]; then except "Dump of the region failed"; fi
			isDefined ddVerbose && echo -n "dumped.." >&3
			if [ -e "$dumpPath" ]; then
				privateNumAssign dumpByteSize $(du -b "$dumpPath" |cut -d/ -f1 |tr -cd '[:digit:]')
				if [ $dumpByteSize -eq $byteCount ]; then
					isDefined ddVerbose && echo -n "chksum->" >&3
					local checksum=$(calculateChecksum "$dumpPath")
					isDefined ddVerbose && echo "done." >&3 || echo >&3
					if [ ! -z "$checksum" ]; then
						echo -e "\tChecksum of dumped block: ${checksum}" >&3
						echo -n "${checksum}" >&4
						let resRet=0
					else
						except "Checksum of dumped block is empty!"
					fi
					rm -f "$dumpPath" &>/dev/null
				else
					except "Dump size does not match, dump: $dumpByteSize, target count: $byteCount"
				fi
			else
				except "Dump failed"
			fi
		else
			except "Dump file: $dumpPath already exist"
		fi
	else
		except "Device $devPath does not exist"
	fi
	return $resRet
}

restoreBlock() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount timeoutN
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateVarAssign "${FUNCNAME[0]}" "backupFile" "$4"
	privateNumAssign "mbCount" "$5"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" -a -e "$backupFile" ]; then
		echo -ne "\tRestoring backed up block to region ${startAddr}-${endAddr}MB from file.."
		cmdL='dd if="'"$backupFile"'" of="'"$devPath"'" seek='"$startAddr"' bs=1M count='"$mbCount"' conv=notrunc status=none'
		isDefined ddVerbose && echo -n "writing->"
		execWithTimeout $timeoutN "$cmdL"
		if [ $? -ne 0 ]; then except "Writing to the region failed"; fi
		isDefined ddVerbose && echo "written." || echo
		echo -ne "\tRemoving backup file.."
		isDefined ddVerbose && echo -n "removing->"
		rm -f "$backupFile"
		if [ -e "$backupFile" ]; then 
			except "Backup file $backupFile cant be removed"
		else
			isDefined ddVerbose && echo "removed." || echo
		fi
	else
		except "Device $devPath or backup file path $backupFile does not exist"
	fi
}

libs() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\nSourcing graphics.."
	source /root/multiCard/graphicsLib.sh
	echo -e "\nSourcing ACC.."
	source /root/multiCard/acc_diag_lib.sh
	echo -e "\nSourcing SFP.."
	source /root/multiCard/sfpLinkTest.sh
	echo -e "\nSourcing TS.."
	source /root/multiCard/tsTest.sh
	echo -e "\nSourcing IS.."
	source /root/multiCard/isTest.sh
	echo -e "\n"
}

checkPathVar(){
	if [ -z "$(echo -n "$PATH"|grep 'multiCard')" ]; then
		export PATH="$PATH:/root/multiCard"
		echo " Updating PATH.."
	fi
}

makeLibSymlinks() {
	local lib fileName
	local LIB_PATH="/root/multiCard"
	local libsList=( "arturLib.sh" "graphicsLib.sh" "sqlLib.sh" "trafficLib.sh" )
	for lib in ${libsList[*]}; do
		if [ -e "${LIB_PATH}/$lib" ]; then
			fileName=$(echo -n $lib|cut -d. -f1)
			which $fileName &> /dev/null || {
				echo "  Creating symlink for $lib"
				ln -s "${LIB_PATH}/$lib" "/usr/bin/$fileName" &> /dev/null
				chmod +777 "/usr/bin/$fileName" &> /dev/null
			}
		else
			echo "  $lib is not found in $LIB_PATH"
		fi
	done
}

setDefaultGlobals() {
	if [ -z "${dmsgStackArr[*]}" ]; then
		declare -ga dmsgStackArr=($(seq 0 1 30))
		let dmsgStackArr[99]=-1
	fi
}

libInit() {
	if [ -z $1 ]; then checkPathVar; fi
	makeLibSymlinks
	setDefaultGlobals
}

unsetDebug() {
	unset debugMode
	unset globalMute
	unset debugBrackets
	unset debugShowAssignations
	unset noExit
}

setDebug() {
	export debugMode=1
	export globalMute=1
	export let debugBrackets=0
	export let debugShowAssignations=0
	export noExit=1
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tLib for testing (support: arturd@silicom.co.il)'
	libInit "$@"
	rm -f /tmp/exitMsgExec
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi