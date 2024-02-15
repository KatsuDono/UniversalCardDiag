#!/bin/bash

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

printBridgeCaps() {
	lspci -nnd 8086: |grep -w '\[0604\]' |grep -w "\[8086:2f..\]" |awk '{print $1}' |xargs -n 1 lspci -vvvnns |grep '0604\|LnkCap:'
}

printNetPaths() {
	grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2- |xargs -n 1 -I {} sh -c "echo -n \"Net: \"; ls /sys/bus/pci/devices/0000\:{}/net/ |tr -d '\n'; echo -n \"  Dev: {} \" ; ls -l /sys/bus/pci/devices |grep {} |cut -d ' ' -f9-" |sed 's#->.*/pci0000:..#PCI Path -> #g'
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
						#devsOnBus=$(getDevsOnPciRootBus $slotBus) #removed after the major getDevsOnPciRootBus rewrite
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
	local mbType pciRootBusAddrList devsOnRootBus pciRootBus devIdList irqList devId extendedNotEqual irqN isException extendedDevsList exceptDev
	privateVarAssign critical "mbType" "$(dmidecode -t baseboard | grep Name: |cut -d: -f2 |cut -d' ' -f2)"
	privateVarAssign critical "pciRootBus" "$1"
	case "$mbType" in
		X10DRi) 
			# pciRootBus=$(echo -n $pciRootBus |cut -d. -f1)
			dmsg inform "rebuilding pciRootBus=$pciRootBus (greping '/$pciRootBus')"
			devsOnRootBus="$(ls -l /sys/bus/pci/devices/ |grep /$pciRootBus |cut -d/ -f7- |awk -F/ '{print $(NF)}' | awk '$1=$1')"
			#dmsg inform "devsOnRootBus: $devsOnRootBus"
			extendedDevsList="$(ls -l /sys/bus/pci/devices/ |grep /$(echo -n $pciRootBus |cut -d. -f1). |cut -d/ -f7- |awk -F/ '{print $(NF)}' | awk '$1=$1')"
			#dmsg inform "extendedDevsList: $extendedDevsList"
			for dev in $extendedDevsList; do
				isException=$(cat /sys/bus/pci/devices/$dev/subsystem_vendor |tr '[:lower:]' '[:upper:]' |cut -dX -f2- |grep -x '^15D9$')
				if isDefined isException; then 
					dmsg inform "Exception device found: $dev"
					exceptDev=$(cut -d. -f1 <<<"$dev")
					continue
				fi
				devIdList+=($(cat /sys/bus/pci/devices/$dev/uevent |grep PCI_ID |cut -d= -f2))
				irqList+=($(cat /sys/bus/pci/devices/$dev/irq))
				#dmsg inform "added dev: $dev ID:${devIdList[$((${#devIdList[*]}-1))]} IRQ: ${irqList[$((${#irqList[*]}-1))]}"
			done
			#dmsg inform "devIdList=${devIdList[*]}"
			#dmsg inform "irqList=${irqList[*]}"

			for devId in "${devIdList[@]}"; do
				if [[ "${devIdList[0]}" != "$devId" ]]; then
					extendedNotEqual=true
					break
				fi
			done
			for irqN in "${irqList[@]}"; do
				if [[ "${irqList[0]}" != "$irqN" ]]; then
					extendedNotEqual=true
					break
				fi
			done

			if [ $(echo ${irqList[*]} | tr ' ' '\n' | sort | uniq -c | awk '{if($1>1) {print 0; exit}}') ]; then
				unset extendedNotEqual
				dmsg echo "got at least one number repeat at least once."
			else
				dmsg echo "Not even one number repeats at least once."
			fi

			if isDefined exceptDev; then
				dmsg inform "Rebuilding lists, removing $exceptDev."
				dmsg inform "extendedDevsList=$extendedDevsList"
				dmsg inform "devsOnRootBus=$devsOnRootBus"
				extendedDevsList="$(tr '\n' ' '<<<"$extendedDevsList" |sed "s/$exceptDev\.. //g" |tr ' ' '\n')"
				devsOnRootBus="$(tr '\n' ' '<<<"$devsOnRootBus" |sed "s/$exceptDev\.. //g" |tr ' ' '\n')"
				
			fi

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
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slotBus bus slotNum
	privateNumAssign slotNum $1
	bus=$(getDmiSlotBuses |head -n $slotNum |tail -n 1)
	if ! [ "$bus" = "ff" -o -z "$bus" ]; then
		privateVarAssign fatal slotBus $(getPciSlotRootBus $bus)
		getIfacesOnSlotBus $slotBus
	fi
}

getIfacesOnSlotBus() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local netDevs devsOnBus pciRootBus netOnDev dev netDevsArr
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
			if [ -z "$(grep -w "$netOnDev"<<<$netDevsArr)" ]; then
				if [ ! -z "$netOnDev" ]; then echo "$netOnDev"|awk -F/ '{print $NF}'; fi
				netDevsArr+="$netOnDev "
			fi
		done
	fi
}

unbindIfaces() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ifaceList ifaceAddr iface
	privateVarAssign critical "ifaceList" "$*"
	for iface in $ifaceList; do
		ifaceAddr=$(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep -v "virtual\|total" |cut -d/ -f5- |grep -m1 -x '.*/'$iface'$' |awk -F/ '{print $(NF-2)}')
		if isDefined ifaceAddr; then
			echo -e " Unbinding $yl$iface$ec.."
			unbindPciDev $ifaceAddr
		fi
	done
}

bindDevsOnSlot() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local modName slotNum busAddr isEth devsOnBus devCnt dev
	privateVarAssign critical "modName" "$1"
	privateNumAssign "slotNum" "$2"
	let devCnt=0
	busAddr=$(getDmiSlotBuses |head -n $slotNum |tail -n 1)
	if ! [ "$busAddr" = "ff" -o -z "$busAddr" ]; then
		privateVarAssign fatal devsOnBus $(getDevsOnPciRootBus $(getPciSlotRootBus $busAddr))
		for dev in $devsOnBus; do
			let devCnt++
			isEth=$(grep '0200' /sys/bus/pci/devices/$dev/class)
			if isDefined isEth; then
				echo -e " Binding $yl$dev$ec (device: $devCnt on slot $slotNum) to $gr$modN$ec module"
				bindPciDev $dev $modName
			fi
		done
	fi
}

unbindPciDev() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local pciAddr modList fullPciAddr
	privateVarAssign critical "pciAddr" "$1"
	modList=$(find /sys/bus/pci/drivers/ |grep "$pciAddr" |cut -d/ -f6)
	if isDefined modList; then
		fullPciAddr=$(find /sys/bus/pci/drivers/ |grep -m1 "$pciAddr" |cut -d/ -f7)
		if isDefined fullPciAddr; then
			for modN in $modList; do
				if [ -e "/sys/bus/pci/drivers/$modN/unbind" ]; then
					echo -e "  Unbinding $yl$fullPciAddr$ec from $gr$modN$ec module"
					echo $fullPciAddr > /sys/bus/pci/drivers/$modN/unbind
				fi
			done
		fi
	fi
}

bindPciDev() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local pciAddr modName fullPciAddr 
	privateVarAssign critical "pciAddr" "$1"
	privateVarAssign critical "modName" "$2"
	fullPciAddr=$(find /sys/bus/pci/devices/ |grep -m1 "$pciAddr" |cut -d/ -f6)
	if isDefined fullPciAddr; then
		if [ -e "/sys/bus/pci/drivers/$modN/bind" ]; then
			echo -e "  Binding $yl$fullPciAddr$ec to $gr$modN$ec module"
			echo $fullPciAddr > /sys/bus/pci/drivers/$modN/bind
		fi
	fi
}

getPciBridgeMemParams() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
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
	privateVarAssign "${FUNCNAME[0]}" "sqlSrvIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "hexID" "$2"
	privateVarAssign "${FUNCNAME[0]}" "recordValue" "$3"
	dmsg echo "Adding SQL record: $recordValue on $hexID"
	sshCmd='source /root/multiCard/sqlLib.sh;'"sqlAddRecord \"$hexID\" $recordValue"
	sshSendCmdBlockNohup $sqlSrvIp root "${sshCmd}"
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

createPrintJob() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath syncSrvIp msg remotePath re couterList el targetPath sshCmd jobHexID
	privateVarAssign "${FUNCNAME[0]}" "syncSrvIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "jobHexID" "$2"
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$3"
	verifyIp "${FUNCNAME[0]}" $syncSrvIp
	sshWaitForPing 30 $syncSrvIp 1 >/dev/null
	if [ $? -ne 0 ]; then except "Log sync server $syncSrvIp is down!"; fi
	if ! isDefined syncSrvUser; then echo "syncSrvUser undefined, fallback to root"; syncSrvUser="root"; fi

	echo -e "   Creating print job from SQL.."
	echo "    Output file: $filePath"
	echo "  Running SQL request on sync server: $syncSrvIp"
	sshCmd='source /root/multiCard/sqlLib.sh &>/dev/null; '"sqlGetPrintDataCSV \"$jobHexID\""
	sshSendCmd $syncSrvIp $syncSrvUser "${sshCmd}" |grep -v 'ECDSA' |& tee $filePath
}

printCSVFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath 
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	testFileExist "$filePath"
}

getTestCode() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local testName testCode
	privateVarAssign "${FUNCNAME[0]}" "testName" "$1"

	case "$testName" in
		"pciTest") 		testCode="POK";;
		"dumpTest") 	testCode="N/T";;
		"bpTest") 		testCode="LOK";;
		"trfTest") 		testCode="TOK";;
		"drateTest") 	testCode="DOK";;
		"undefMode") 	testCode="PLOK";;
		"undefMode2") 	testCode="PTOK";;
		"pciTrfTest") 	testCode="PDTOK";;
		*) except "Unknown testName: $testName"
	esac

	if isDefined testCode; then
		echo -n "$testCode"
	else
		except "undefined testCode"
	fi
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
	dmsg echo "    Log file: $filePath"
	dmsg echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l"	>/dev/null
	dmsg echo -e -n "    Creating log folder /mnt/LogStorage: "; echoRes "mkdir -p /mnt/LogStorage"	>/dev/null
	dmsg echo -e -n "    Mounting log folder to /mnt/LogStorage: "; echoRes "mount.cifs \\\\$srvIp\\LogStorage /mnt/LogStorage"' -o user=smbLogs,pass=smbLogs' >/dev/null
	remotePath="/mnt/LogStorage/$targetPath/$(basename $filePath)"
	dmsg echo "    Remote file path: $remotePath"
	createPathForFile $remotePath 1>/dev/null
	dmsg echo -e -n "    Copying $filePath to $remotePath: "; echoRes "cp -f "$filePath" "$remotePath"" >/dev/null
	dmsg echo -e -n "    Unmounting all mounts if any exists: "; echoRes "umount -a -t cifs -l" >/dev/null
	dmsg echo -e "   Done."
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
				dmsg inform "net:"$net"  act:"$act"  counter:"$counter"  actArgs:"$actArgs
				$act "$counter" $actArgs
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
	local secBus devsOnPciRootBus
	
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
	devsOnPciRootBus="$(getDevsOnPciRootBus $(getPciSlotRootBus $targBus))"

	test ! -z "$plxBuses" && {
		for bus in $plxBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(grep -w $bus <<<"$devsOnPciRootBus")
			if isDefined exist; then plxOnDevBus+="$bus "; fi
		done
		dmsg inform "plxOnDevBus=$plxOnDevBus"
	}
	test ! -z "$accBuses" && {
		for bus in $accBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(grep -w $bus <<<"$devsOnPciRootBus")
			if isDefined exist; then accOnDevBus+="$bus "; fi
		done
		dmsg inform "accOnDevBus=$accOnDevBus"
	}
	test ! -z "$spcBuses" && {
		for bus in $spcBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(grep -w $bus <<<"$devsOnPciRootBus")
			if isDefined exist; then spcOnDevBus+="$bus "; fi
		done
		dmsg inform "spcOnDevBus=$spcOnDevBus"
	}
	test ! -z "$ethBuses" && {
		for bus in $ethBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(grep -w $bus <<<"$devsOnPciRootBus")
			if isDefined exist; then ethOnDevBus+="$bus "; fi
		done
		dmsg inform "ethOnDevBus=$ethOnDevBus"
	}
	test ! -z "$bpBuses" && {
		for bus in $bpBuses ; do
			# exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			# [ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(grep -w $bus <<<"$devsOnPciRootBus")
			if isDefined exist; then bpOnDevBus+="$bus "; fi
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
			if isDefined plxDevQtyReq; then
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSpeed" "$plxDevSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevWidth" "$plxDevWidth"
			fi
			if isDefined plxDevSubQtyReq; then
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSubSpeed" "$plxDevSubSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSubWidth" "$plxDevSubWidth"
			fi
			if isDefined plxDevUpstQtyReq; then
				checkDefinedVal "${FUNCNAME[0]}" "plxDevUpstSpeed" "$plxDevUpstSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevUpstWidth" "$plxDevUpstWidth"
			fi			
			if isDefined plxDevEmptyQtyReq; then
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
				isDefined infoMode || isDefined plxDevQtyReq || except "plxDevQtyReq undefined, but devices found"
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
					isDefined infoMode || isDefined plxDevSubQtyReq || except "plxDevSubQtyReq undefined, but devices found"
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
							isDefined infoMode || isDefined plxDevUpstQtyReq || except "plxDevUpstQtyReq undefined, but devices found"
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
							isDefined infoMode || isDefined plxDevEmptyQtyReq || except "plxDevEmptyQtyReq undefined, but devices found"
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
						isDefined infoMode || isDefined plxDevEmptyQtyReq || except "plxDevEmptyQtyReq undefined, but devices found"
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
			isDefined plxDevQtyReq && [ $plxDevQtyReq -gt 0 ] && testArrQty "  Physical" "$plxDevArr" "$plxDevQtyReq" "No PLX physical devices found on UUT" "warn"
			isDefined plxDevSubQtyReq && [ $plxDevSubQtyReq -gt 0 ] && testArrQty "  Virtual" "$plxDevSubArr" "$plxDevSubQtyReq" "No PLX virtual devices found on UUT" "warn"
			isDefined plxDevUpstQtyReq && [ $plxDevUpstQtyReq -gt 0 ] && testArrQty "  Upstream" "$plxDevUpstArr" "$plxDevUpstQtyReq" "No PLX Upstream devices found on UUT" "warn"
			isDefined plxDevEmptyQtyReq && [ $plxDevEmptyQtyReq -gt 0 ] && testArrQty "  Virtual (empty)" "$plxDevEmptyArr" "$plxDevEmptyQtyReq" "No PLX virtual devices (empty) found on UUT" "warn"
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
		
		ip link del dev $brName >/dev/null 2>&1
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

function bindIfacesToBridge() {
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

function ifaceBelongsToBridge() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local bridgeName ethIfaceList ifaceFound exitCode
	let exitCode=-1
	privateVarAssign "${FUNCNAME[0]}" "bridgeName" "$1" ;shift
	privateVarAssign "${FUNCNAME[0]}" "ethIfaceList" "$*"
	checkIfacesExist $ethIfaceList

	if [ -e "/sys/class/net/$bridgeName/bridge/bridge_id" ]; then
		for iface in $ethIfaceList; do
			ifaceFound=$(ls -l /sys/class/net/$bridgeName/ |grep -x ".*/net/$iface\$")
			if isDefined ifaceFound; then
				let exitCode=0
			else
				let exitCode=0
				echo " $iface does not belong to a bridge $bridgeName"
				break
			fi
		done
		
	else
		let exitCode=2
		except "$bridgeName is not a bridge, aborting"
	fi
	return $exitCode
}

function bindIfacesToNAT() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ethIface srcIface trgIface srcIP1 srcIP2 trgIP1 trgIP2 srcMAC trgMAC id1 id2
	privateVarAssign "${FUNCNAME[0]}" "srcIface" "$1"
	privateVarAssign "${FUNCNAME[0]}" "trgIface" "$2"
	if [ ! -z "$3" ]; then except "function overloaded"; fi

	echo -e "  Binding interfaces: $yl$*$ec to ${gr}NAT$ec"
	checkIfacesExist $*
	for ethIface in $*; do
		echo -e "  Setting iface $yl$ethIface$ec to ${yl}DOWN$ec"
		ip link set $ethIface down
		echo -e "  Flushing iface $yl$ethIface$ec"
		ip a flush dev $ethIface
	done

	id1=$(echo $srcIface |cut -d. -f2 |tr -d [:alpha:])
	let id1=$(($id1 % 127 + 1))
	id2=$(echo $trgIface |cut -d. -f2 |tr -d [:alpha:])
	let id2=$(($id2 % 127 + 128))
	echo "  id1=$id1  id2=$id2"
	srcIP1="192.1$(cut -c1<<<"$j")0.$id1.$id1"
	srcIP2="192.1$(cut -c1<<<"$j")0.$id2.$id1"
	trgIP1="192.1$(cut -c1<<<"$j")0.$id2.$id2"
	trgIP2="192.1$(cut -c1<<<"$j")0.$id1.$id2"
	srcMAC=$(cat /sys/class/net/$srcIface/address)
	trgMAC=$(cat /sys/class/net/$trgIface/address)
	echo -e " srcIP1: $srcIP1\n srcIP2: $srcIP2\n trgIP1: $trgIP1\n trgIP2: $trgIP2\n "
	# lnk[$num]=$srcIface
	# src[$num]=$srcIP1
	# dst[$num]=$srcIP2
	# log[$num]=$srcIP2
	# let ++num
	# lnk[$num]=$trgIface
	# src[$num]=$trgIP1
	# dst[$num]=$trgIP2
	# log[$num]=$trgIP2
	# let ++num
	ip address add $srcIP1/24 brd + dev $srcIface 
	echo " Adding $srcIP1/24 on $srcIface"
	ip address add $trgIP1/24 brd + dev $trgIface 
	echo " Adding $trgIP1/24 on $trgIface"
	ip link set dev $srcIface up mtu 1500 promisc off
	ip link set dev $trgIface up mtu 1500 promisc off
	iptables -t nat -A POSTROUTING -s $srcIP1 -d $srcIP2 -j SNAT --to-source $trgIP2 
	echo " Setting NAT postroute SNAT Source:$srcIP1 to destination: $trgIP2"
	iptables -t nat -A PREROUTING -d $trgIP2 -j DNAT --to-destination $srcIP1 
	echo " Setting NAT preroute DNAT destination:$trgIP2 forward to destination: $srcIP1"
	iptables -t nat -A POSTROUTING -s $trgIP1 -d $trgIP2 -j SNAT --to-source $srcIP2 
	echo " Setting NAT postroute SNAT Source:$trgIP1 to destination: $srcIP2"
	iptables -t nat -A PREROUTING -d $srcIP2 -j DNAT --to-destination $trgIP1 
	echo " Setting NAT preroute DNAT destination:$srcIP2 forward to destination: $trgIP1"
	ip route add $srcIP2 dev $srcIface 
	echo " Adding route $srcIP2 on dev $srcIface"
	ip neigh add $srcIP2 lladdr $trgMAC dev $srcIface 
	echo " Adding neighbour lladdr $trgMAC for $srcIP2 on dev $srcIface"
	ip route add $trgIP2 dev $trgIface 
	echo " Adding route $trgIP2 on dev $trgIface"
	ip neigh add $trgIP2 lladdr $srcMAC dev $trgIface 
	echo " Adding neighbour lladdr $srcMAC for $trgIP2 on dev $trgIface"



	for ethIface in $*; do
		echo -e "  Setting iface $yl$ethIface$ec to ${gr}UP$ec"
		ip link set $ethIface up
	done
	echo "  NAT setup done."
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

getEthTransInfo() {
	local net nets transCmdRes
	nets="$@"
	if ! [ -z "$nets" ]; then
		for net in ${nets[*]]}; do
			echo -e "\n\tCheking net: [$gr$net$ec]"
			echo -ne "\t$yl Gathering info..$ec"
			transCmdRes="$(ethtool -m $net)"
			venName=$(echo "$transCmdRes" |grep "Vendor name" |cut -d: -f2 |cut -c2-)
			venPn=$(echo "$transCmdRes" |grep "Vendor PN" |cut -d: -f2 |cut -c2-)
			venRev=$(echo "$transCmdRes" |grep "Vendor rev" |cut -d: -f2 |cut -c2-)
			venSN=$(echo "$transCmdRes" |grep "Vendor SN" |cut -d: -f2 |cut -c2-)
			transType=$(echo "$transCmdRes" |grep -m1 "Transceiver type" |cut -d: -f3 |cut -c2-)
			transWL=$(echo "$transCmdRes" |grep "Laser wavelength" |cut -d: -f2 |cut -c2-)

			biasCurr=$(echo "$transCmdRes" |grep "Laser bias current" |grep -v 'alarm\|warning' |cut -d: -f2 |cut -c2-)
			txPW=$(echo "$transCmdRes" |grep "Laser output power" |grep -v 'alarm\|warning' |cut -d: -f2 |cut -c2- |cut -d/ -f1)
			rxPW=$(echo "$transCmdRes" |grep "Receiver signal average optical power" |cut -d: -f2 |cut -c2- |cut -d/ -f1)
			transVoltage=$(echo "$transCmdRes" |grep "Module voltage" |grep -v 'alarm\|warning' |cut -d: -f2 |cut -c2-)
			
			transWarn="$(echo "$transCmdRes" |grep 'warning' |grep ': On' |cut -d: -f1 | awk '$1=$1' |sed 's/warning//g')"
			transAlarm="$(echo "$transCmdRes" |grep 'alarm' |grep ': On' |cut -d: -f1 | awk '$1=$1' |sed 's/alarm//g')"

			if ! [ -z "$transAlarm" ]; then
				if ! [ -z "$transWarn" ]; then
					shopt -s lastpipe
					echo "$transAlarm" | while read almN ; do
						warnExist=$(echo "$transWarn" |grep "$almN")
						if ! [ -z "$warnExist" ]; then
							transWarn="$(echo "$transWarn" |sed "/$warnExist/d")"
						fi
					done
				fi
			fi

			printf "\r%s" ""
			echo -e "\t $transType ($transWL): $venName - $venPn (rev $venRev, SN: $venSN)"
			echo -e "\t  Input voltage: $transVoltage"
			echo -e "\t  Laser current: $biasCurr"
			echo -e "\t  Tx Power: $txPW"
			echo -e "\t  Rx Power: $rxPW"

			if ! [ -z "$transWarn" ]; then
				echo "$transWarn" | while read warnM ; do
					warnTrsh=$(echo "$transCmdRes" |grep "$warnM" |grep 'warning threshold' |cut -d: -f2 |cut -c2- |cut -d/ -f1)
					trshType=$(echo $warnM |awk '{print $NF}')
					if [ "$trshType" = "low" ]; then trshMsg="lower"; else trshMsg="higher"; fi
					echo -e "$yl\t  Warning: $warnM$ec (is $yl$trshMsg$ec than $warnTrsh)"
				done
			fi

			if ! [ -z "$transAlarm" ]; then
				echo "$transAlarm" | while read almM ; do
					almTrsh=$(echo "$transCmdRes" |grep "$almM" |grep 'alarm threshold' |cut -d: -f2 |cut -c2- |cut -d/ -f1)
					trshType=$(echo $almM |awk '{print $NF}')
					if [ "$trshType" = "low" ]; then trshMsg="lower"; else trshMsg="higher"; fi
					echo -e "$rd\t  Alarm: $almM$ec (is $rd$trshMsg$ec than $almTrsh)"
				done
			fi
		done
	else
		warn "${FUNCNAME[0]}, no nets found, skipped"
	fi
}

checkBcmDriver() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local bcmModQty loadStatus bnxtEnVer bnxtEnVerReq
	
	bnxtEnVerReq="1.10.0"

	let bcmModQty=$(lsmod |grep '^bnxt_re\|^bnxt_en' |wc -l |tr -dc '[:digit:]' 2>/dev/null)
	if [[ $bcmModQty -lt 2 ]]; then
		let loadStatus=0
		rmmod bnxt_re bnxt_en &>/dev/null; let loadStatus+=$?
		modprobe bnxt_en bnxt_re &>/dev/null; let loadStatus+=$?
		if [[ $loadStatus -ne 0 ]]; then
			except "Unable to load broadcom drivers!"
		fi
	fi
	privateVarAssign "${FUNCNAME[0]}" "bnxtEnVer" "$(modinfo bnxt_en |grep '^version:' |awk '{print $2}')"
	if ! versionCheck "$bnxtEnVer" "$bnxtEnVerReq"; then
		except "Invalid bnxt_en driver version: $bnxtEnVer"
	fi
}

checkBcmVPD() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local bcmDev bcmDevs bcmCmdRes bcmList detectedBcmDevsArr bcmDevsArr bcmDevsMatch ifaceVpdInfo
	privateVarAssign "${FUNCNAME[0]}" "bcmDevs" "$*"
	checkIfacesExist $bcmDevs
	checkBcmDriver

	bcmList=$(bnxtnvm listdev |tr '\n' ' ')
	if isDefined bcmList; then
		read -ra detectedBcmDevsArr <<<"$bcmList"
		read -ra bcmDevsArr <<<"$bcmDevs"

		bcmDevsMatch=()
		for bcmDev in "${bcmDevsArr[@]}"; do
			if [[ " ${detectedBcmDevsArr[*]} " =~ " $bcmDev " ]]; then
				bcmDevsMatch+=("$bcmDev")
			fi
		done
		if isDefined bcmDevsMatch; then
			for bcmDev in ${bcmDevsMatch[*]}; do
				echo -e "\n    VPD check on dev: $yl$bcmDev$ec"
				bcmCmdRes="$(bnxtnvm -dev=$bcmDev view 2>/dev/null)"
				if isDefined bcmCmdRes; then
					ifaceVpdInfo="$(grep -A99 '^VPD Resource Tag.*$' <<<"$bcmCmdRes" |grep '^    ..: ".*"$\|^VPD Resource Tag ID.*$')"
					if isDefined ifaceVpdInfo; then
						echo -e "\tTag Name: $bl$(grep -x '^VPD Resource Tag.*$' <<<"$ifaceVpdInfo" |cut -d'"' -f2)$ec"
						echo -e "\tPN: $(grep -x "^    PN:.*$" <<<"$ifaceVpdInfo" |cut -d'"' -f2)"
						echo -e "\tRevision: $(grep -x "^    EC:.*$" <<<"$ifaceVpdInfo" |cut -d'"' -f2)"
						echo -e "\tTN: $(grep -x "^    V8:.*$" <<<"$ifaceVpdInfo" |cut -d'"' -f2)"
						echo -e "\tSN: $(grep -x "^    SN:.*$" <<<"$ifaceVpdInfo" |cut -d'"' -f2)"
						echo -e "\tProdDate: $(grep -x "^    V7:.*$" <<<"$ifaceVpdInfo" |cut -d'"' -f2)\n\n"
					else
						except "Null VPD info output"
					fi
				else
					except "Null bnxtnvm output"
				fi
			done
		else
			except "No ifaces provided ($bcmDevs) matched to BCM devs list ($bcmList)"
		fi
	else
		except "No BCM devs is detected"
	fi
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
		except "unable to get currVal: $currVal, cmdRetStat=$cmdRetStat"
	fi
}

function writeSfpAddr () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr offset slcmRes slcmWC resErr lastNonErrVal errorString retCnt
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
				errorString+="\e[0;31mvaule NOT updated!\e[m\n"; sleep 0.3
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
							errorString+="\e[0;31m Verify: FAIL! wrV:$writeVerify nW:$newVal\e[m\n"; sleep 0.3
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
	if [ $writeOK -eq 1 ]; then 
		echo -ne "$writeRes"
	else 
		sendToKmsg "$errorString"
		echo -ne "$writeRes\nError log: \n$errorString"
	fi
	return $retRes
}

function writeQsfpAddrNoverify () {
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
			writeRes=$(slcmi_util $busAddr write_sfp $offset $pageAddr $newVal)	 2>&1 > /dev/null	
			writeResOK="$(grep "Ok" <<<"$writeRes")"
			sendToKmsg "    $writeRes  "
			if [ -z "$writeResOK" ]; then
				writeRes="\e[0;31mvaule NOT updated!\e[m"
				let retRes=2
			else
				writeRes="\e[0;32mvaule updated!\e[m"
				let writeOK=1
				let retRes=0
				break
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

printOctDecode() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local octVal
	octVal=$1
	if isDefined octVal; then 
		echo -n "OCT: $octVal   DEC: "
		printf "%d  " $octVal
		echo "  ASCII: $(xxd -r <<<"$octVal")" 
	else
		echo "err" 
	fi
}

avagoAuth() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr byteNum cmdRes addrOffset
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"
	if [ ! -z "$2" ]; then let addrOffset=$2; else let addrOffset=0; fi

	echo -e "\tStatus reg: Page0: 122"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 $((111+$addrOffset)) 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 

	echo -e "\t\tWriting auth status: Page0: 122"
	cmdRes=$(writeQsfpAddrNoverify $busAddr 0xa0 $((111+$addrOffset)) 0x00 |grep -v 'error'); sleep 0.15 

	echo -e "\tWriting auth: Page0: 123-126"
	echo -e "\t\tWriting auth: Page0: 123"
	cmdRes=$(writeQsfpAddrNoverify $busAddr 0xa0 $((112+$addrOffset)) 0x30 |grep -v 'error'); sleep 0.15 
	echo -e "\t\tWriting auth: Page0: 124"
	cmdRes=$(writeQsfpAddrNoverify $busAddr 0xa0 $((113+$addrOffset)) 0x14 |grep -v 'error'); sleep 0.15 
	echo -e "\t\tWriting auth: Page0: 125"
	cmdRes=$(writeQsfpAddrNoverify $busAddr 0xa0 $((114+$addrOffset)) 0x51 |grep -v 'error'); sleep 0.15 
	echo -e "\t\tWriting auth: Page0: 126"
	cmdRes=$(writeQsfpAddrNoverify $busAddr 0xa0 $((115+$addrOffset)) 0x96 |grep -v 'error'); sleep 0.20

	echo -e "\tStatus reg: Page0: 122"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 $((111+$addrOffset)) 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 

}

avagoSetPage() {
	null
}

readLowerPage() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr byteAddr acqRes pageNum byteNum currPage slcmWC slcmRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"

	pageNum=0
	for ((byteNum=0;byteNum<=127 ;byteNum++))
	do
		slcmRes=$(readQsfpAddr $busAddr 0xa0 $byteNum 20 |grep -v 'error'); printOctDecode $slcmRes; sleep 0.15 
		slcmWC=$(echo $slcmRes |wc -w)
		if [ "$slcmWC" = "1" ]; then
			printf "%d\n" $slcmRes &>/dev/null
			if [ $? -eq 0 ]; then 
				echo -ne "$yl$slcmRes$ec"
			else
				echo -ne "\e[0;47;31m0xEE\e[m"
			fi
		else
			echo -ne "\e[0;47;31m0xEE\e[m"
		fi
	done
}

readLowerPageHEX() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr byteAddr acqRes pageNum byteNum currPage slcmWC slcmRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"

	pageNum=0
	for ((byteNum=0;byteNum<=127 ;byteNum++))
	do
		slcmRes=$(readQsfpAddr $busAddr 0xa0 $byteNum 20 |grep -v 'error'); printOctDecode $slcmRes; sleep 0.15 
		slcmWC=$(echo $slcmRes |wc -w)
		if [ "$slcmWC" = "1" ]; then
			printf "%d\n" $slcmRes &>/dev/null
			if [ $? -eq 0 ]; then 
				echo -ne "$yl$slcmRes$ec"
			else
				echo -ne "\e[0;47;31m0xEE\e[m"
			fi
		else
			echo -ne "\e[0;47;31m0xEE\e[m"
		fi
	done
}

readUpperPage() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr byteAddr acqRes pageNum byteNum currPage slcmWC slcmRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"

	for ((pageNum=0;pageNum<=3;pageNum++))
	do 
		echo -e "  Writing page addr $pageNum to 127"
		cmdRes=$(writeQsfpAddrNoverify $busAddr 0xa0 127 0x$pageNum |grep -v 'error'); sleep 0.15 
		echo -e "\tReading page $pageNum"
		for ((byteNum=128;byteNum<=255 ;byteNum++))
		do
			echo -ne "\t  Addr $byteNum: "
			slcmRes=$(readQsfpAddr $busAddr 0xa0 $byteNum 20 |grep -v 'error')
			# printOctDecode $slcmRes
			# sleep 0.15 
			slcmWC=$(echo $slcmRes |wc -w)
			if [ "$slcmWC" = "1" ]; then
				printf "%d\n" $slcmRes &>/dev/null
				if [ $? -eq 0 ]; then 
					echo -e "$yl$slcmRes$ec"
				else
					echo -e "\e[0;47;31m0xEE\e[m"
				fi
			else
				echo -e "\e[0;47;31m0xEE\e[m"
			fi
		done
	done
}

avagoReadStats()  {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr byteNum cmdRes
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"

	
	echo -e "\tTRX_Temp: Page0: 22-23"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 22 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 23 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 

	echo -e "\tTRX_PW_3.3: Page0: 26-27"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 26 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 27 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 

	echo -e "\tTRX_Bias_CH1: Page0: 42-43"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 42 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 43 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTRX_Bias_CH2: Page0: 44-45"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 44 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 45 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTRX_Bias_CH3: Page0: 46-47"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 46 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 47 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTRX_Bias_CH4: Page0: 48-49"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 48 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 49 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tRX_PW_CH1: Page0: 34-35"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 34 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 35 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tRX_PW_CH2: Page0: 36-37"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 36 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 37 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tRX_PW_CH3: Page0: 38-39"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 38 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 39 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tRX_PW_CH4: Page0: 40-41"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 40 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 41 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTX_PW_CH1: Page0: 50-51"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 50 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 51 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTX_PW_CH2: Page0: 52-53"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 52 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 53 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTX_PW_CH3: Page0: 54-55"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 54 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 55 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	
	echo -e "\tTX_PW_CH4: Page0: 56-57"
	cmdRes=$(readQsfpAddr $busAddr 0xa0 56 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 
	cmdRes=$(readQsfpAddr $busAddr 0xa0 57 20 |grep -v 'error'); printOctDecode $cmdRes; sleep 0.15 

}

function readQsfpAddr () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr pageAddr offset slcmiRes slcmiWC resErr lastNonErrVal retRes readOK readRes isOkValue
	privateVarAssign "${FUNCNAME[0]}" "busAddr" "$1"
	privateVarAssign "${FUNCNAME[0]}" "pageAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "offset" "$3"
	retArg=$4
	if isDefined retArg; then let retCnt=$4; else let retCnt=5; fi
	
	let readOK=0
	let retRes=99
	lastNonErrVal=""
	while [ $readOK -eq 0 -a $retCnt -gt 0 ]; do
		let retCnt--
		let resErr=0
		slcmiRes=$(slcmi_util $busAddr read_sfp $offset $pageAddr)
		slcmiWC=$(echo $slcmiRes |wc -w)
		if [ -z "$slcmiWC" ]; then slcmiWC="-1"; fi
		if [ "$slcmiWC" = "1" ]; then
			printf "%d\n" $slcmiRes &>/dev/null
			if [ $? -eq 0 ]; then 
				readRes="$slcmiRes"
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

function readSfpAddr () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local retCnt busAddr pageAddr offset slcmRes slcmWC resErr lastNonErrVal retRes readOK readRes isOkValue errorString
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
				errorString+="\e[0;47;31m0xEE\e[m, slcmWC:$slcmWC\n"
				let resErr=1; sleep 0.3
			fi
		else
			readRes="\e[0;47;31m0xEE\e[m"
			errorString+="\e[0;47;31m0xEE\e[m, slcmWC:$slcmWC\n"
			let resErr=1; sleep 0.3
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
				errorString+="\e[0;33minvalid value received, retrying ($retCnt left) \e[m\n"; sleep 0.3
			fi
		else
			let retRes=2
			errorString+="\e[0;33merror received, retrying ($retCnt left) \e[m\n"
			readRes="\e[0;33merror received, retrying ($retCnt left) \e[m"; sleep 0.3
		fi
	done
	if [ $readOK -eq 1 ]; then 
		echo -ne "$readRes"
	else 
		sendToKmsg "$errorString"
		echo -ne "$readRes\nError log: \n$errorString"
	fi
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

libs() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\nSourcing graphics.."
	source /root/multiCard/graphicsLib.sh
	echo -e "\nSourcing traffic library.."
	source /root/multiCard/trafficLib.sh
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
	if ! [ "$(type -t privateVarAssign 2>&1)" == "function" ]; then 
		source /root/multiCard/utilLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mUTILITY LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t echoFail 2>&1)" == "function" ]; then 
		source /root/multiCard/textLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mTEXT LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t selectUSBBus 2>&1)" == "function" ]; then 
		source /root/multiCard/usbLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mUSB LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t sendKikusuiCmd 2>&1)" == "function" ]; then 
		source /root/multiCard/kikusuiLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mKIKUSUI LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t IPPowerSwPowerAll 2>&1)" == "function" ]; then 
		source /root/multiCard/ippowerLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mIPPOWER LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t createRandomFile 2>&1)" == "function" ]; then 
		source /root/multiCard/ioLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mI\O LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	libInit "$@"
	rm -f /tmp/exitMsgExec
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi