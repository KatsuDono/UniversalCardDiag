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

exitFail() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local procId parentFunc
	dmsg "exitExec=$exitExec procId=$procId"
	test -z "$2" && procId=$PROC || procId=$2
	test -z "$procId" && echo -e "\t\e[1;41;33mexitFail exception, procId not specified\e[m"
	test -z "$guiMode" && echo -e "\t\e[1;41;33m$1\e[m\n" 1>&2 || msgBox "$1"
	if [ ! -z "$minorLaunch" ]; then echo -e "\n\tTotal Summary: \e[0;31mTESTS FAILED\e[m" 1>&2; fi
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
	if [[ -z "$noExit" ]]; then 
		exit 1
	fi
}

dbgWarn() {	#nnl = no new line
	test -z "$2" && echo -e "$blw$1$ec" || {
		test "$2"="nnl" && echo -e -n "$blw$1$ec" 1>&2 || echo -e "$blw$1$ec" 1>&2
	}
	test -z "$(echo "$*" |grep "\-\-sil")" && beepSpk crit
}

critWarn() {  #nnl = no new line
	test -z "$2" && echo -e "\e[0;47;31m$1\e[m" 1>&2 || {
		test "$2"="nnl" && echo -e -n "\e[0;47;31m$1\e[m" 1>&2 || echo -e "\e[0;47;31m$1\e[m" 1>&2
	}
	test -z "$(echo "$*" |grep "\-\-sil")" && beepSpk crit
}

warn() {	#nnl = no new line  #sil = silent mode
	test -z "$2" && echo -e "\e[0;33m$1\e[m" 1>&2 || {
		test "$2"="nnl" && echo -e -n "\e[0;33m$1\e[m" 1>&2 || echo -e "\e[0;33m$1\e[m" 1>&2
	}
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
	if [ -z "$silEn" ]; then
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
	beepSpk pass
}

dmsg() {
	local addArg callerFunc
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
	if [[ ! -z "$@" ]]; then
		if [ "$debugMode" == "1" ]; then
			if [ "$debugBrackets" == "0" ]; then
				echo -e -n "dbg>$callerFunc" 1>&2; $addArg"$@" 1>&2
			else
				inform "DEBUG>$callerFunc" --nnl 1>&2
				$addArg"$addArg$@" 1>&2
				inform "< DEBUG END" 1>&2
			fi
		fi
	else
		echo "dmsg exception, input parameters undefined!" 1>&2
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
	echo -e -n "\n\tEnter tracking: "
	read -r trackNum
	if [[ "${#trackNum}" = "13" ]]; then
		return 0
	else 
		return 1
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
			warn) test "$beepInstalled" = "0" && beepNoExec 2 || beep -f 783 -l 20 -n -f 830 -l 20;;
			info) test "$beepInstalled" = "0" && beepNoExec 1 || beep -f 783 -l 20;;
			pass) test "$beepInstalled" = "0" && beepNoExec 2 || beep -f 523 -l 90 -n -f 659 -l 90 -n -f 783 -l 90 -n -f 1046 -l 90;;
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
		traceSnip="$(echo "$cmdRes" |grep -B 10 -A 99 -w "$scriptTraceKeyw")"
		if [[ -z "$traceSnip" ]]; then 
			echo -e "$(echo "$cmdRes")"
		else
			echo -e "$(echo "$cmdRes" |grep -B 10 -A 99 -w "$scriptTraceKeyw")"
		fi
		echo -e "\n\t\e[0;31m --- TRACE END ---\e[m\n"
	fi
	unset cmdRes
	return $retStatus
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

	if [[ "$1" = "--minimalMode" ]]; then minimalMode=1; else unset minimalMode; fi

	echoSection "PCI Slots"
	slotBuses=$(dmidecode -t slot |grep Bus |cut -d: -f3)
	let slotNum=0
	let maxSlots=$(dmidecode -t slot |grep Handle |wc -l)
	declare -A slotArr
	assignBusesInfo spc eth plx acc bp 2>&1 > /dev/null	
	bpBusesTotal=$bpBuses
	if [[ ! -z "$bprdBuses" ]]; then
		test -z "$bpBusesTotal" && bpBusesTotal=$bprdBuses || bpBusesTotal="$bpBuses $bprdBuses"
	fi
	
	for slotBus in $slotBuses; do
		if [[ ! "$slotBus" = "ff" ]]; then 
			falseDetect=$(ls /sys/bus/pci/devices/ |grep -w "0000:$slotBus")
			if [[ -z "$falseDetect" ]]; then
				dmsg inform "populatedRootBuses false deteted slotbus $slotBus, skipping"
			else
				populatedRootBuses+=( "$(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' )" )
				dmsg inform "Added $(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' ) to populatedRootBuses"
			fi
		fi	
	done

	pciBridges=$( echo -n "${populatedRootBuses[@]}" |tr ' ' '\n' |sort |uniq)
	dmsg inform "pciBridges="$pciBridges
	for pciBr in $pciBridges; do
		pciBrInfo="$(lspci -vvvs $pciBr)"
		
		slotBrPhysNum=$(echo "$pciBrInfo" |grep SltCap -A1 |tail -n 1 |cut -d# -f2 |cut -c1)
		slotWidthCap=$(echo "$pciBrInfo" |grep -m1 LnkCap: |awk '{print $7}' |cut -d, -f1 |cut -c2-)

		slotArr[0,$slotBrPhysNum]=$slotWidthCap
	done

	dmiSlotInfo="$(dmidecode -t slot)"
	for ((i=1;i<=$maxSlots;i++)) do 
		slotArr[4,$i]=$(echo "$dmiSlotInfo" |grep Handle |head -n$i |tail -n1 |cut -d, -f1 |awk '{print $2}')
		slotArr[2,$i]=$(dmidecode -H ${slotArr[4,$i]} |grep Type |awk '{print $2}' |cut -c2-)
	done
	

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
	done
	echo -e "\n\n"
}

function selectSlot () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slotBuses slotBus busesOnSlots devsOnSlots populatedSlots slotSelRes totalDevList populatedBuses selDesc activeSlots busMode
	
	privateVarAssign "selectSlot" "selDesc" "$1"
	busMode=$2
	if [[ -z "$busMode" ]]; then echo -e "$selDesc";fi

	slotBuses=$(dmidecode -t slot |grep Bus |cut -d: -f3)
	let slotNum=1
	for slotBus in $slotBuses; do
		if [[ ! "$slotBus" = "ff" ]]; then
			busesOnSlots+=( "$slotBus" )
			devsOnSlots+=( "$(lspci -s $slotBus: |cut -c1-70 |head -n 1)" )
			populatedSlots+=( "$slotNum" )
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
	
	if [[ ! -z "${serialDevs[@]}" ]]; then
		slotSelRes=$(select_opt "${serialDevs[@]}")
		return $slotSelRes
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

echoRes() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdLn
	cmdLn="$@"
	cmdRes="$($cmdLn; echo "res:$?")"
	test -z "$(echo "$cmdRes" |grep -w 'res:1')" && echo -n -e "\e[0;32mOK\e[m\n" || echo -n -e "\e[0;31mFAIL"'!'"\e[m\n"
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
	local numInput varName numInput varNameDesc funcName

	funcName="${FUNCNAME[1]}"
	varName="$1"
	shift
	numInput=$1 ;shift
	if [[ ! -z "$*" ]]; then except "function overloaded"; fi
	checkIfNumber $numInput

	if [ ! "$funcName" == "beepSpk" ]; then
		if [[ "$debugShowAssignations" = "1" ]]; then
			dmsg echo "funcName=$funcName  varName=$varName  numInput=$numInput"
		fi
	fi
	
	test -z "$funcName" && exitFail "privateNumAssign preEval check exception, funcName undefined!"
	test -z "$varName" && exitFail "privateNumAssign preEval check exception, varName undefined!"
	test -z "$numInput" && exitFail "privateNumAssign preEval check exception, $funcName: $varName definition failed, new value is undefined!"
	
	eval "let $varName=\$numInput"
}

privateVarAssign() {
	local varName varVal varNameDesc funcName
	funcName="$1"
	shift
	varName="$1"
	shift
	varVal="$*"

	if [ ! "$funcName" == "beepSpk" ]; then
		if [[ "$debugShowAssignations" = "1" ]]; then
			dmsg echo "funcName=$funcName  varName=$varName  varVal=$varVal"
		fi
	fi
	
	# test -z "$funcName" && exitFail "privateVarAssign preEval check exception, caller: ${FUNCNAME[1]} > funcName undefined!"
	# test -z "$varName" && exitFail "privateVarAssign preEval check exception, caller: ${FUNCNAME[1]} > varName undefined!"
	# test -z "$varVal" && exitFail "privateVarAssign preEval check exception, caller: ${FUNCNAME[1]} > $funcName: $varName definition failed, new value is undefined!"
	
	test -z "$funcName" && except "preEval check, funcName undefined!"
	test -z "$varName" && except "preEval check, varName undefined!"
	test -z "$varVal" && except "preEval check, new value for $varName is undefined!"


	test -z "$(echo $varVal|grep 'noargs')" && eval $varName=\$varVal
}

publicVarAssign() {
	local varName varVal varNameDesc errMsg
	varSeverity="$1"
	shift
	varName="$1"
	shift
	varVal=$@
	varNameDesc="$varName"
	errMsg=""
	# inform "DEBUG> call stack> ${FUNCNAME[*]}"
	# test -z "$varName" && errMsg="  publicVarAssign preEval check exception, caller: ${FUNCNAME[1]} > varName undefined!"
	# test -z "$varSeverity" && errMsg="  publicVarAssign preEval check exception, caller: ${FUNCNAME[1]} > while proccesing assigning for $varName, varSeverity undefined!"
	# test -z "$varVal" && errMsg="  publicVarAssign preEval check exception, caller: ${FUNCNAME[1]} > while proccesing assigning for $varName, varVal undefined!"
	
	test -z "$varName" && errMsg="preEval check, varName undefined!"
	test -z "$varSeverity" && errMsg="preEval check, varSeverity for $varName undefined!"
	test -z "$varVal" && errMsg="preEval check, new value for $varName is undefined!"


	test -z "$errMsg" && {
		eval $varName=\$varVal
		echo -e "  $varNameDesc=${!varName}"
	} || {
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
	}
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
	echo -n "${FUNCNAME[1]} requested callstack: "
	for (( idx=${#FUNCNAME[*]:2}-1 ; idx>=1 ; idx-- )) ; do echo -n "${FUNCNAME[idx]}> "; done
	echo -ne "\n"
}

except() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local exceptDescr
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	exceptDescr="$*"
	echo -e "[multiCard]: Exception raised: $exceptDescr" |& tee /dev/kmsg &> /dev/null
	echo -e "[multiCard]: Exception callstack: $(caller): $(printCallstack)" |& tee /dev/kmsg &> /dev/null
	critWarn "\t$(caller): $(printCallstack)"
	exitFail "${FUNCNAME[1]} exception> $exceptDescr"
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

	# [[ -z "$funcArgs" ]] && except "funcArgs for callerFunc:$callerFunc are undefined!"

	# for ARG in "$@"; do
	# 	KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
	# 	VALUE=$(echo $ARG |cut -f2 -d=)
	# 	if [[ ! -z $(echo -n $KEY |grep -w "arg-max\|arg-min\|arg-exact") ]]; then 
	# 		compKey=$KEY
	# 		[[ ! -z "${VALUE}" ]] && let compValue=${VALUE} || except "VALUE undefined for key: $KEY!"
	# 	else 
	# 		[[ -z "$argsNoFlags" ]] && argsNoFlags=("$ARG") || argsNoFlags+=("$ARG")	
	# 	fi
	# done

	# case "$compKey" in
	# 	arg-max) if [[ ! ${#argsNoFlags[@]} -le $compValue ]]; then except "$callerFunc" "overloaded with parameters, ${#argsNoFlags[@]} received, but $compValue expected!"; fi ;;	
	# 	arg-min) if [[ ! ${#argsNoFlags[@]} -ge $compValue ]]; then except "$callerFunc" "insufficent parameters, ${#argsNoFlags[@]} received, but $compValue expected!"; fi ;;	
	# 	arg-exact) if [[ ! ${#argsNoFlags[@]} -eq $compValue ]]; then except "$callerFunc" "incorrect parameter count, ${#argsNoFlags[@]} received, but $compValue expected!"; fi ;;	
	# 	*) except "compKey received unexpected key: $compKey"
	# esac
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
				PE310G4I71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
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
				PE310G4I71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
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
		if [ -z "$rootBusSpeedCap" -o -z "$rootBusWidthCap" ]; then
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
				rootBusSpWdRes="$(speedWidthComp $rootBusSpeedCap $pciInfoDevCapSpeed $rootBusWidthCap $pciInfoDevCapWidth)"
				echo -e -n "\t "'|'" $rootBusSpWdRes\n"
			echo -e "\t -------------------------"
			test ! -z "$(echo "$rootBusSpWdRes" |grep FAIL)" && exitFail "Root bus speed is incorrect! Check PCIe BIOS settings."
		fi
	fi

	dmsg critWarn "check if next hex addr by bus existing and pciInfoDevPhysSlot corresponds to the slotNumLocal"

	test ! -z "$plxBuses" && {
		for bus in $plxBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			[ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || plxOnDevBus=$(echo $plxOnDevBus $bus)
		done
		dmsg inform "plxOnDevBus=$plxOnDevBus"
	}
	test ! -z "$accBuses" && {
		for bus in $accBuses ; do
			#exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			[ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || accOnDevBus=$(echo $accOnDevBus $bus)
		done
		dmsg inform "accOnDevBus=$accOnDevBus"
	}
	test ! -z "$spcBuses" && {
		for bus in $spcBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			[ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || spcOnDevBus=$(echo $spcOnDevBus $bus)
		done
		dmsg inform "spcOnDevBus=$spcOnDevBus"
	}
	test ! -z "$ethBuses" && {
		for bus in $ethBuses ; do
			#exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			[ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || ethOnDevBus=$(echo $ethOnDevBus $bus)
		done
		dmsg inform "ethOnDevBus=$ethOnDevBus"
	}
	test ! -z "$bpBuses" && {
		for bus in $bpBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			[ -z "$exist" ] && exist=$(ls -l /sys/bus/pci/devices/ |grep :$secBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || bpOnDevBus=$(echo $bpOnDevBus $bus)
		done
		dmsg inform "bpOnDevBus=$bpOnDevBus"
	}
	
	dmsg inform "WAITING FOR INPUT1"
	dmsg read foo
	
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
			gatherPciInfo $plxBus
			dmsg inform "Processing plxBus=$plxBus"
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

	
	if [[ ! -z "$reqVal" ]]; then
		echo -e -n "\t$compDesc: "
		if [[ ! -z "$(echo "$actVal" |grep -m 1 "$reqVal")" ]]; then 
			echo -e "$reqVal \e[0;32mOK\e[m"
		else 
			echo -e "\e[0;31mFAIL\e[m ('$reqVal' wasnt found"'!'")"
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

function sendSerialCmd () {
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
	timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*\$* { send \x14q\r }
	*#* { send \x14q\r }
	*0>* { send \x14q\r }
	*login:* { send \x14q\r }
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

function IPPowerCheckSerial () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local i ttyN outlet swRes
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"

	echo -n " Checking serial connections to IPPower, "
	swRes="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.1 read p6)"
	if [ ! -z "$(echo "$swRes" |grep "1=")" ]; then
		echo -e "\e[0;32mok.\e[m"
	else
		except "IPPower serial connection failure"
	fi
}

function IPPowerSwPowerAll () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local i
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"
	privateNumAssign "targState" "$2"

	for (( i=1; i<5; i++ )); do
		IPPowerSwPower ttyUSB0 $i $targState
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
		swRes="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.05 set p6$outlet $targState)"
		if [ "$targState" = "$(echo "$swRes" |grep "$outlet=" |cut -d= -f2)" ]; then
			echo -e "\e[0;32mok.\e[m"
		else
			echo -e "\e[0;31mfail.\e[m"
			echo -n " Retrying to switch $outlet outlet to $targState, "
			swRes="$(sendIPPowerSerialCmdDelayed $ttyN 19200 0.04 set p6$outlet $targState)"
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

	if ! [[ -e "/dev/$ttyN" ]]; then
		except "Serial dev does not exist"
	fi

	echo " Owning $ttyN"
	chmod o+rw /dev/$ttyN
	echo " Setting baud $baud"
	stty $baud < /dev/$ttyN
	stty $baud -F /dev/$ttyN

	killLogWriters $logFilePath
	rm -f $logFilePath
	
	echo " Started log file"
	cat -v < /dev/$ttyN |& tee $logFilePath >/dev/null &

	echo " Sending cmd: $cmd"
	echo -ne "\r" > /dev/$ttyN
	sleep $delay
	echo -ne "\r" > /dev/$ttyN
	sleep $delay
	for (( i=0; i<${#cmd}; i++ )); do echo -ne "${cmd:$i:1}" > /dev/$ttyN; sleep $delay; done
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	echo -e "\r" > /dev/$ttyN
	sleep $delay

	killLogWriters $logFilePath

	echo " Reading log file"
	outlStat="$(cat "$logFilePath" )"
	# echo " FULL LOG: $outlStat"

	outlStat="$(echo "$outlStat" |grep p6 |grep status |cut -d: -f2)"
	# echo -e " Cut log status:\n"$outlStat
	
	if [ ! -z "$outlStat" ]; then
		echo -e "\n\n Outlet status:"
		echo "  1=$(echo $outlStat |awk '{print $4}')"
		echo "  2=$(echo $outlStat |awk '{print $3}')"
		echo "  3=$(echo $outlStat |awk '{print $2}')"
		echo "  4=$(echo $outlStat |awk '{print $1}')"
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
			send \" a\n\r\"
			send \" a\n\r\"
			send \r\n 
		}
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF\n\"; exit 1 }
	}
	expect {
		*CMD:* { 
			send \"$cmd\r\"
			send \r\n
		}
		timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*\$* { send \x14q\r }
	*#* { send \x14q\r }
	*0>* { send \x14q\r }
	*login:* { send \x14q\r }
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

ipPowerSetPowerHttp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ipPowerIP ipPowerUser ipPowerPass targPort targState cmdRes
	privateVarAssign "${FUNCNAME[0]}" "ipPowerIP" "$1"
	verifyIp "${FUNCNAME[0]}" $ipPowerIP
	privateVarAssign "${FUNCNAME[0]}" "ipPowerUser" "$2"
	privateVarAssign "${FUNCNAME[0]}" "ipPowerPass" "$3"
	privateVarAssign "${FUNCNAME[0]}" "targPort" "$4"
	privateVarAssign "${FUNCNAME[0]}" "targState" "$5"
	cmdRes=$(wget "http://$ipPowerIP/set.cmd?user=$ipPowerUser+pass=$ipPowerPass+cmd=setpower+p6$targPort=$targState" 2>&1)
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
	local secondsPassed totalDelay targIp status startTime successPing
	privateNumAssign "totalDelay" "$1"
	let secondsPassed=0
	privateVarAssign "${FUNCNAME[0]}" "targIp" "$2"
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
		if [ $successPing -eq 5 ]; then
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
	if [ $internetAcq -eq 0 ]; then
		route add default gw 172.30.0.9 &> /dev/null
		sleep 1
		if ! ping -c 1 google.com &> /dev/null; then
			warn "  Internet setup failed, routing setup failed"
		else
			let internetAcq=1
			echo "  Internet setup was succesfull"
		fi
	else
		if ! ping -c 1 google.com &> /dev/null; then
			warn "  Internet setup failed, unexpected state"
		else
			echo "  Skipped internet setup, not in down state"
		fi
	fi
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
	re='^[0-9]+$'
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
	slcm_start &> /dev/null
	selectSlot "  Select UUT:"
	uutSlotNum=$?
	publicVarAssign warn uutBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $uutSlotNum |tail -n 1)
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign warn uutNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $uutSlotBus |awk -F/ '{print $NF}')
	publicVarAssign warn uutBuses $(filterDevsOnBus $(echo -n ":$uutBus:") $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-))
	checkTransceivers $uutBuses
}

readEEPROMMasterFile() {
	local line eepromFile pageAddr byteAddr byteVal curLine pageNum byteNum
	eepromFile=$1
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
	local busesAddrs bus
	privateVarAssign "${FUNCNAME[0]}" "busesAddrs" "$*"
	for bus in $busesAddrs; do
		checkTransceiver $bus
	done
}

checkTransceiver() {
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

readTransceiver() {
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
					#if [ "$slcmRes" = "0x0" ]; then 
					#	transData[$byteNum,$pageNum]=$(echo -ne "\e[0;47;31m0x0\e[m")
					#else
						transData[$byteNum,$pageNum]=$slcmRes
					#fi
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
			#sleep 0.02  <- was added in hope that will elliminate faulty read, did not work
		} && {
			acqRes=$(slcm_util $busAddr read_sfp $byteAddr $pageAddr |cut -dx -f2- |tr '[:lower:]' '[:upper:]')
			# first acquring after system reboot always is incorrect, so running read again 
		}
		#	Not used, because in case of an error re-read is done anyways
		#test -z "$(echo "$acqRes" |grep ERROR)" || {
		#	#acqRes='Error while reading ('"$busAddr"':'"$pageAddr"':'"$byteAddr"')'
		#	acqRes='ERROR!'
		#} 
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
	echo -e "\nSourcing ACC.."
	source /root/multiCard/acc_diag_lib.sh
	echo -e "\nSourcing SFP.."
	source /root/multiCard/sfpLinkTest.sh
	echo -e "\nSourcing TS.."
	source /root/multiCard/tsTest.sh
	echo -e "\n"
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tLib for testing (support: arturd@silicom.co.il)'
	rm -f /tmp/exitMsgExec
else	
	critWarn "This file is only a library and ment to be source'd instead"
fi