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
	echo -e "\n\e[0;32m     ██████╗░░█████╗░░██████╗░██████╗"
	echo "     ██╔══██╗██╔══██╗██╔════╝██╔════╝"
	echo "     ██████╔╝███████║╚█████╗░╚█████╗░"
	echo "     ██╔═══╝░██╔══██║░╚═══██╗░╚═══██╗"
	echo "     ██║░░░░░██║░░██║██████╔╝██████╔╝"
	echo -e "     ╚═╝░░░░░╚═╝░░╚═╝╚═════╝░╚═════╝░\e[m\n\n"
}

echoFail() {
	echo -e "\n\e[0;31m     ███████╗░█████╗░██╗██╗░░░░░"
	echo "     ██╔════╝██╔══██╗██║██║░░░░░"
	echo "     █████╗░░███████║██║██║░░░░░"
	echo "     ██╔══╝░░██╔══██║██║██║░░░░░"
	echo "     ██║░░░░░██║░░██║██║███████╗"
	echo -e "     ╚═╝░░░░░╚═╝░░╚═╝╚═╝╚══════╝\e[m\n\n"
}
echoSection() {		
	local addEl
	for ((e=0;e<=${#1};e++)); do addEl="$addEl="; done		
	echo -e "\n  =====$addEl====="
	echo -e "  ░░   $1    ░░"
	echo -e "  =====$addEl=====\n"
}

killAllScripts() {
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
	local procId
	dmsg inform "exitFail executed, exitExec=$exitExec procId=$procId"
	test -z "$2" && procId=$PROC || procId=$2
	test -z "$procId" && echo -e "\t\e[1;41;33mexitFail exception, procId not specified\e[m"
	test -z "$guiMode" && echo -e "\t\e[1;41;33m$1\e[m\n" || msgBox "$1"
	echo -e "\n"
	sleep 1
	test "$exitExec" = "3" && {
		critWarn "\t Exit loop detected, exiting forced."
		kill -9 $procId
		killAllScripts
	}
	if [[ -e "/tmp/exitMsgExec" ]]; then 
		echoFail
		beepSpk fatal 3
	fi
	echo 1>/tmp/exitMsgExec
	if [[ -z "$debugNoExit" ]]; then exit 1; fi
}

critWarn() {	#nnl = no new line
	test -z "$2" && echo -e "\e[0;47;31m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\e[0;47;31m$1\e[m" || echo -e "\e[0;47;31m$1\e[m"
	}
	test -z "$(echo "$*" |grep "\-\-sil")" && beepSpk crit
}

warn() {	#nnl = no new line  #sil = silent mode
	test -z "$2" && echo -e "\e[0;33m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\e[0;33m$1\e[m" || echo -e "\e[0;33m$1\e[m"
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

	echo -e -n "\e[0;33m$msgNoKeys\e[m"

	if [ -z "$nnlEn" ]; then
		echo -n -e "\n"
	fi
	if [ -z "$silEn" ]; then
		beepSpk info
	fi
}

passMsg() {	#nnl = no new line  #sil = silent mode
	test -z "$2" && echo -e "\t\e[0;32m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\t\e[0;32m$1\e[m" || echo -e "\t\e[0;32m$1\e[m"
	}
	echo -e "\n"
	echoPass
	beepSpk pass
}

dmsg() {
	if [[ ! -z "$@" ]]; then
		if [ "$debugMode" == "1" ]; then
			if [ "$debugBrackets" == "0" ]; then
				echo -e -n "dbg> "; "$@"
			else
				inform "DEBUG> " --nnl
				"$@"
				inform "< DEBUG END"
			fi
		fi
	else
		inform "dmsg exception, input parameters undefined!"
	fi
}

function createLog () {
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
	local beepCount ttyName
	privateVarAssign "beepNoExec" "beepCount" "$1"
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
			fatal) test "$beepInstalled" = "0" && beepNoExec 3 || {
				beep -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6
				sleep 0.1
				beep -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6
				sleep 0.1
				beep -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6 -n -f 783 -l 6 -n -f 830 -l 6
			};;
			crit) test "$beepInstalled" = "0" && beepNoExec || beep -f 783 -l 20 -n -f 830 -l 20 -n -f 783 -l 20 -n -f 830 -l 20 -n -f 783 -l 20 -n -f 830 -l 20;;
			warn) test "$beepInstalled" = "0" && beepNoExec || beep -f 783 -l 20 -n -f 830 -l 20;;
			info) test "$beepInstalled" = "0" && beepNoExec || beep -f 783 -l 20;;
			pass) test "$beepInstalled" = "0" && beepNoExec || beep -f 523 -l 90 -n -f 659 -l 90 -n -f 783 -l 90 -n -f 1046 -l 90;;
			*) exitFail "beepSpk exception, unknown beepMode: $beepMode"
		esac
	fi
}

beep() {
	test -z "$1" && let beepCount=1 || let beepCount=$1
	if [ "$silentMode" = "1" ]; then
		ttyName=$(ls /dev/tty6* |uniq |tail -n 1)
		for ((b=1;b<=$beepCount;b++)); do 
			echo -ne "\a" > $ttyName
			sleep 0.13
		done
	fi
}

execScript() {
	local scriptPath scriptArgs scriptExpect scriptTraceKeyw scriptFailDesc retStatus
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
		esac
	done

	scriptPath="$1"
	scriptArgs="$2"
	scriptTraceKeyw="$3"
	scriptFailDesc="$4"
	dmsg inform "scriptExpect=$scriptExpect"
	dmsg inform "cmd=$scriptPath $scriptArgs"
	cmdRes="$($scriptPath $scriptArgs 2>&1)"
	for expKw in "${scriptExpect[@]}"; do
		dmsg inform "execScript loop> procerssing kw=>$expKw<"
		if [[ ! $(echo "$cmdRes" |tail -n 10) =~ $expKw ]]; then
			critWarn "\tTest: $expKw - NO"
			dmsg inform ">${expKw}< wasnt found in $(echo "$cmdRes" |tail -n 10)"
			test -z "$debugMode" || {
				inform "pwd=$(pwd)"
				echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
				echo -e "$cmdRes"
				echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
			}
			let retStatus++
		else
			inform "\tTest: $expKw - YES"
			test -z "$debugMode" || {
				echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
				echo -e "$cmdRes"
				echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
			}
		fi
	done
	if [[ ! "$retStatus" = "0" ]]; then
		echo -e "\n\t\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$cmdRes" |grep -B 10 -A 99 -w "$scriptTraceKeyw")"
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
			acc) publicVarAssign silent accBuses $(grep '0b40' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			bp) 
				publicVarAssign silent bpBuses $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1)
				publicVarAssign silent bprdBuses $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1)
			;;
			*) exitFail "assignBuses exception, unknown bus type: $ARG"
		esac
	done
}

drawPciSlot() {		
	local addEl addElDash addElSpace excessSymb cutText color slotWidthInfo pciInfoRes curLine curLineCut widthLocal cutAddExp addElDashSp
	if [[ ! -z "$globDrawWidthAdj" ]]; then let widthLocal=$globDrawWidthAdj; else let widthLocal=0; fi
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
	for ((e=0;e<$widthLocal;e++)); do addElDashSp="$addElDashSp "; done
	for ((e=0;e<$widthLocal;e++)); do addElSpace="$addElSpace "; done
	test ! -z "$(echo $cutText |grep '\-\- Empty ')" && color='\e[0;31m' || color='\e[0;32m'
	#test "$cutText" = "-- Empty --" && color='\e[0;31m' || color='\e[0;32m'

	echo -e "\n\t-------------------------------------------------------------------------$addElDash"
	echo -e "\t░ Slot: $slotNum  ░  $color$cutText$addEl\e[m ░  $slotWidthInfo"
	test -z "$pciArgs" || {
		echo -e "\t░      - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -    $addElDashSp ░"
		pciInfoRes="$(listDevsPciLib "${pciArgs[@]}")"
		unset pciArgs
		echo "${pciInfoRes[@]}" | while read curLine ; do	
			addEl=""
			let cutAddExp=$cutAdd+12+11
			curLineCut=$(echo $curLine |cut -c1-$cutAddExp)
			let excessSymb=$widthLocal+11+68-${#curLineCut}
			for ((e=0;e<=$excessSymb;e++)); do addEl="$addEl "; done
			echo -e "\t░ $curLineCut$addEl ░"
		done

	}
	echo -e -n "\t-------------------------------------------------------------------------$addElDash"
}

showPciSlots() {
	local slotBuses slotNum slotBusRoot bpBusesTotal 
	local pciBridges pciBr slotBrPhysNum pciBrInfo rootBus slotArr dmiSlotInfo minimalMode

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
			populatedRootBuses+=( "$(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' )" )
		fi	
	done

	pciBridges=$( echo -n "${populatedRootBuses[@]}" |tr ' ' '\n' |sort |uniq)
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

	dmsg inform critWarn "MAKE sure that in case that +1 by hex address is an actual device, \n
	check that parent bus does not have slot capabilities \n
	moreover, check if slot in theory can have more than 4x or 8x by its length"

	for slotBus in $slotBuses; do
		let slotNum=$slotNum+1
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
					gatherPciInfo $slotBus
					dmsg debugPciVars
					if [[ -z "$minimalMode" ]]; then
						declare -a pciArgs=(
							"--plx-keyw=Physical Slot:"
							"--plx-virt-keyw=ABWMgmt+"
							"--spc-buses=$spcBuses"
							"--eth-buses=$ethBuses"
							"--plx-buses=$plxBuses"
							"--acc-buses=$accBuses"
							"--bp-buses=$bpBuses"
							"--info-mode"
							"--target-bus=$slotBus"
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
	local selDesc serialDevs slotSelRes
	
	privateVarAssign "${FUNCNAME[0]}" "selDesc" "$1"
	echo -e "$selDesc"

	serialDevs+=( $(ls /dev |grep ttyUSB) )
	
	if [[ ! -z "${serialDevs[@]}" ]]; then
		slotSelRes=$(select_opt "${serialDevs[@]}")
		return $slotSelRes
	else
		except "${FUNCNAME[0]}" "no serial devs found!"
	fi
}

function ibsSelectMgntMasterPort () {
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
		except "${FUNCNAME[0]}" "unable to retrieve eth name!"
	fi
}

echoRes() {
	local cmdLn
	cmdLn="$@"
	cmdRes="$($cmdLn; echo "res:$?")"
	test -z "$(echo "$cmdRes" |grep -w 'res:1')" && echo -n -e "\e[0;32mOK\e[m\n" || echo -n -e "\e[0;31mFAIL"'!'"\e[m\n"
}

syncFilesFromServ() {
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
		
		echo -e -n "    Mounting $seqPn folder: "; echoRes "mount.cifs \\\\172.30.0.4\\e\\Seq_DB\\$syncPn /mnt/$syncPn"' -o user=LinuxCopy,pass=LnX5CpY'
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

privateVarAssign() {
	local varName varVal varNameDesc funcName
	funcName="$1"
	shift
	varName="$1"
	shift
	varVal="$*"

	if [ ! "$funcName" == "beepSpk" ]; then
		dmsg echo "privateVarAssign>  funcName=$funcName  varName=$varName  varVal=$varVal"
	fi
	
	test -z "$funcName" && exitFail "privateVarAssign exception, funcName undefined!"
	test -z "$varName" && exitFail "privateVarAssign exception, varName undefined!"
	test -z "$varVal" && exitFail "privateVarAssign exception, $funcName: $varName definition failed, new value is undefined!"
	
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
	
	test -z "$varName" && errMsg="  publicVarAssign exception, varName undefined!"
	test -z "$varSeverity" && errMsg="  publicVarAssign exception, while proccesing assigning for $varName, varSeverity undefined!"
	test -z "$varVal" && errMsg="  publicVarAssign exception, while proccesing assigning for $varName, varVal undefined!"
	
	test -z "$errMsg" && {
		eval $varName=\$varVal
		echo -e "  $varNameDesc=${!varName}"
	} || {
		case "$varSeverity" in
			fatal) exitFail "$errMsg" ;;
			critical) critWarn "$errMsg" ;;
			warn) warn "$errMsg" ;;
			silent) ;;
			*) except "${FUNCNAME[0]}" "varSeverity not in range: $varSeverity"
		esac
	}
}

function checkDefinedVal () {
	local funcName varVal
	dmsg inform "DEBUG> checkDefinedVal> args: $*"
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	funcName="$1" ;shift
	varName="$1" ;shift
	varVal="$1" ;shift
	dmsg inform "DEBUG> checkDefinedVal> funcName=$funcName varName=$varName varVal=$varVal"
	if [[ -z "$varVal" ]]; then
		except "${FUNCNAME[0]}" "in $funcName: varVal for $varName is undefined!"
	else
		return 0
	fi
}

checkDefined() {
	local funcName varName
	dmsg inform "DEBUG> checkDefined> args: $*"
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	funcName="$1" ;shift
	varName="$1" ;shift
	checkOverload "${FUNCNAME[0]}" "$*" --arg-min=1
	dmsg inform "DEBUG> checkDefined> funcName=$funcName varName=$varName"
	if [[ -z "${!varName}" ]]; then
		except "${FUNCNAME[0]}" "$varName is undefined!"
	fi
}

except() {
	local funcName exceptDescr
	# not using privateVarAssign because could cause loop in case of fail inside the assigner itself
	funcName=$1 ;shift
	exceptDescr="$*"
	exitFail "$(caller): $funcName exception, $exceptDescr"
}

removeArg() {
	local targArg
	privateVarAssign "removeArg" "targArg" "$1"; shift
	echo -n "$*" | sed 's/'" $targArg"'//g'
}

checkOverload() {
	local callerFunc funcArgs argsNoFlags optFlag compKey
	callerFunc=$1 ;shift
	funcArgs="$*"

	[[ -z "$callerFunc" ]] && except "${FUNCNAME[0]}" "callerFunc is undefined!"
	[[ -z "$funcArgs" ]] && except "${FUNCNAME[0]}" "funcArgs for callerFunc:$callerFunc are undefined!"

	for ARG in "$@"; do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		if [[ ! -z $(echo -n $KEY |grep -w "arg-max\|arg-min\|arg-exact") ]]; then 
			compKey=$KEY
			[[ ! -z "${VALUE}" ]] && let compValue=${VALUE} || except "checkOverload exception, VALUE undefined for key: $KEY!"
		else 
			[[ -z "$argsNoFlags" ]] && argsNoFlags=("$ARG") || argsNoFlags+=("$ARG")	
		fi
	done

	case "$compKey" in
		arg-max) if [[ ! ${#argsNoFlags[@]} -le $compValue ]]; then except "$callerFunc" "overloaded with parameters, ${#argsNoFlags[@]} received, but $compValue expected!"; fi ;;	
		arg-min) if [[ ! ${#argsNoFlags[@]} -ge $compValue ]]; then except "$callerFunc" "insufficent parameters, ${#argsNoFlags[@]} received, but $compValue expected!"; fi ;;	
		arg-exact) if [[ ! ${#argsNoFlags[@]} -eq $compValue ]]; then except "$callerFunc" "incorrect parameter count, ${#argsNoFlags[@]} received, but $compValue expected!"; fi ;;	
		*) except "${FUNCNAME[0]}" "compKey received unexpected key: $compKey"
	esac
}

speedWidthComp() {
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
	local netTarg linkReq uutModel netId retryCount linkAcqRes cmdRes devNumRDIF
	privateVarAssign "${FUNCNAME[0]}" "netTarg" "$1"
	privateVarAssign "${FUNCNAME[0]}" "linkReq" "$2"
	privateVarAssign "${FUNCNAME[0]}" "uutModel" "$3"
	case "$uutModel" in
		PE340G2DBIR|PE3100G2DBIR)
			privateVarAssign "${FUNCNAME[0]}" "devNumRDIF" "$4"
			privateVarAssign "${FUNCNAME[0]}" "retryCount" "$globLnkAcqRetr"
		;;
		*) 
			test ! -z "$4" && privateVarAssign "testLinks" "retryCount" "$4" || privateVarAssign "testLinks" "retryCount" "$globLnkAcqRetr"
		;;
	esac
	for ((r=0;r<=$retryCount;r++)); do 
		dmsg inform "try:$r"
		if [ ! "$linkReq" = "$linkAcqRes" ]; then
			if [ $r -gt 0 ]; then 
				inform --sil --nnl "."
				sleep $globLnkUpDel
			fi
			case "$uutModel" in
				PE310G4BPI71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G2BPI71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE210G2BPI40) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4BPI40) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4I40) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE310G4DBIR) 
					netId=$(net2bus "$netTarg" |cut -d. -f2)
					if [ "$netId" = "0" ]; then 
						linkReq="no"
						linkAcqRes="no"
					else
						linkAcqRes=$(rdifctl dev $devNumRDIF get_port_link $netId |grep UP)
						if [[ ! -z "$(echo $linkAcqRes |grep UP)" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
					fi
				;;
				PE340G2DBIR|PE3100G2DBIR) 
					linkAcqRes=$(rdifctl dev $devNumRDIF get_port_link $netTarg |grep UP)
					if [[ ! -z "$(echo $linkAcqRes |grep UP)" ]]; then linkAcqRes="yes"; else linkAcqRes="no"; fi
				;;
				PE310G4BPI9) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE210G2BPI9) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE210G2SPI9A) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE325G2I71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				PE31625G4I71L) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
				M4E310G4I71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |cut -d ' ' -f2);;
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
			dmsg inform $linkAcqRes
		else
			dmsg inform "skipped because not empty"
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
		dmsg inform "try:$r"
		if [ -z "$linkAcqRes" -a "$speedReq" != "Fail" ] || [ "$speedReq" != "Fail" -a -z "$(echo $linkAcqRes |grep $speedReq)" ]; then
			test $r -gt 0 && sleep 1
			case "$uutModel" in
				PE310G4BPI71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G2BPI71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE210G2BPI40) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4BPI40) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4I40) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4DBIR) 
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
				*) except "${FUNCNAME[0]}" "unknown uutModel: $uutModel"
			esac
			dmsg inform $linkAcqRes
		else
			dmsg echo "getEthRates> linkAcqRes=$linkAcqRes"
			dmsg echo "getEthRates> skipped because not empty"
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
	local nets act actDesc net status counter
	privateVarAssign "${FUNCNAME[0]}" "nets" "$1"
	shift
	privateVarAssign "${FUNCNAME[0]}" "actDesc" "$1"
	shift
	privateVarAssign "${FUNCNAME[0]}" "act" "$1"
	shift
	privateVarAssign "${FUNCNAME[0]}" "actArgs" "$@"
	dmsg inform "DEBUG: nets:"$nets"  actDesc:"$actDesc"   act:"$act"   actArgs:"$actArgs
	case "$uutModel" in
		PE340G2DBIR|PE3100G2DBIR)
			echo -e -n "\t$actDesc: \n\t\t"; 
			let counter=1
			for net in $nets; do 
				echo -e -n "$net:"
				$act "$counter" $actArgs
				dmsg inform "DEBUG: net:"$net"  act:"$act"  counter:"$counter"  actArgs:"$actArgs
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
	local net bus
	privateVarAssign "net2bus" "net" "$1"
	bus=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent |grep "$net" |cut -d ':' -f3-)
	test -z "$bus" && exitFail "net2bus exception, bus returned nothing!" $PROC || echo -e -n "$bus"
}

filterDevsOnBus() {
	local sourceBus filterDevs devsTotal
	if [[ -z "$debugMode" ]]; then  # it is messing up assignBuses because of debug messages
		privateVarAssign "devsOnBus" "sourceBus" "$1"	;shift
		privateVarAssign "devsOnBus" "filterDevs" "$*"
		privateVarAssign "devsOnBus" "devsOnSourceBus" $(ls -l /sys/bus/pci/devices/ |grep $sourceBus |awk -F/ '{print $NF}')
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
	if [[ ! -z "$devsTotal" ]]; then echo -n ${devsTotal[@]}; fi
}

clearPciVars() {
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
	local pciInfoDev nameLine
	pciInfoDev="$1"
	dmsg inform "pciInfoDev=$pciInfoDev"
	test -z "$pciInfoDev" && exitFail "gatherPciInfo exception, pciInfoDev in undefined" $PROC
	clearPciVars
	if [[ ! "$pciInfoDev" == *":"* ]]; then 
		pciInfoDev="$pciInfoDev:"
		dmsg inform "pciInfoDev appended, : wasnt found"
	fi
	fullPciInfo="$(lspci -nnvvvks $pciInfoDev 2>&1)"
	let nameLine=$(echo "$fullPciInfo" |grep -B9999 -m1 $pciInfoDev |wc -l)
	pciInfoDevDesc=$(echo "$fullPciInfo" |head -n$nameLine |tail -n1 |cut -d ':' -f3- |cut -d ' ' -f1-9)
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
	local listPciArg argsTotal infoMode
	local netRes slotWidthCap slotWidthMax slotNumLocal
	
	argsTotal=$*
	
	test -z "$argsTotal" && except "${FUNCNAME[0]}" "argsTotal undefined"
	
	for listPciArg in "$@"
	do
		KEY=$(echo $listPciArg|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $listPciArg |cut -f2 -d=)
		#echo -e "\tlistDevsPciLib debug: processing arg: $listPciArg   KEY:$KEY   VALUE:$VALUE"
		case "$KEY" in
			target-bus) 		targBus=${VALUE} ;;
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
			slot-width-cap)			slotWidthCap=${VALUE} ;;
			slot-width-max)			slotWidthMax=${VALUE} ;;
			slot-number)			slotNumLocal=${VALUE} ;;

			*) echo "listDevsPciLib exception, unknown arg: $listPciArg"; exit 1
		esac
	done
	
	test -z "$debugMode" || {
		dmsg inform "targBus=$targBus"
		dmsg inform "accBuses=$accBuses"
		dmsg inform "spcBuses=$spcBuses"
		dmsg inform "plxBuses=$plxBuses"
		dmsg inform "ethBuses=$ethBuses"
		dmsg inform "bpBuses=$bpBuses"
				
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
	}
	
	#devId=$pciDevId

	#pciDevs=$(grep PCI_ID /sys/bus/pci/devices/*/uevent | tr '[:lower:]' '[:upper:]' |grep :$devId |cut -d '/' -f6 |cut -d ':' -f2- |grep $targBus:)
	#test -z "$pciDevs" && {
	#	critWarn "No :$devId devices found on bus $targBus!"
	#	exit 1
	#}
	test -z "$targBus" && exitFail "listDevsPciLib exception, targBus is undefined"
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

	dmsg inform critWarn "check if next hex addr by bus existing and pciInfoDevPhysSlot corresponds to the slotNumLocal"

	test ! -z "$plxBuses" && {
		for bus in $plxBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || plxOnDevBus=$(echo $plxOnDevBus $bus)
		done
		dmsg inform "\t${FUNCNAME[0]}> plxOnDevBus=$plxOnDevBus"
	}
	test ! -z "$accBuses" && {
		for bus in $accBuses ; do
			#exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)

			test -z "$exist" || accOnDevBus=$(echo $accOnDevBus $bus)
		done
		dmsg inform "\t${FUNCNAME[0]}> accOnDevBus=$accOnDevBus"
	}
	test ! -z "$spcBuses" && {
		for bus in $spcBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || spcOnDevBus=$(echo $spcOnDevBus $bus)
		done
		dmsg inform "\t${FUNCNAME[0]}> spcOnDevBus=$spcOnDevBus"
	}
	test ! -z "$ethBuses" && {
		for bus in $ethBuses ; do
			#exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || ethOnDevBus=$(echo $ethOnDevBus $bus)
		done
		dmsg inform "\t${FUNCNAME[0]}> ethOnDevBus=$ethOnDevBus"
	}
	test ! -z "$bpBuses" && {
		for bus in $bpBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep :$targBus: |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || bpOnDevBus=$(echo $bpOnDevBus $bus)
		done
		dmsg inform "\t${FUNCNAME[0]}> bpOnDevBus=$bpOnDevBus"
	}
	
	dmsg inform "\t ${FUNCNAME[0]} WAITING FOR INPUT1"
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
			test -z "$plxDevQtyReq$plxDevSubQtyReq$plxDevEmptyQtyReq" && exitFail "listDevsPciLib exception, no quantities are defined on PLX!"
			checkDefinedVal "${FUNCNAME[0]}" "plxKernReq" "$plxKernReq"
			if [[ -z "$plxDevQtyReq" ]]; then 
				except "${FUNCNAME[0]}" "plxDevQtyReq undefined, but devices found"
			else
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSpeed" "$plxDevSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevWidth" "$plxDevWidth"
			fi

			if [[ -z "$plxDevSubQtyReq" ]]; then 
				except "${FUNCNAME[0]}" "plxDevSubQtyReq undefined, but devices found"
			else
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSubSpeed" "$plxDevSubSpeed"
				checkDefinedVal "${FUNCNAME[0]}" "plxDevSubWidth" "$plxDevSubWidth"
			fi
			if [[ -z "$plxDevEmptyQtyReq" ]]; then 
				except "${FUNCNAME[0]}" "plxDevEmptyQtyReq undefined, but devices found"
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
			test -z "$accKernReq" && exitFail "listDevsPciLib exception, accKernReq undefined!"
			test -z "$accDevQtyReq" && exitFail "listDevsPciLib exception, accDevQtyReq undefined, but devices found" || {
				test -z "$accDevSpeed" && exitFail "listDevsPciLib exception, accDevSpeed undefined!"
				test -z "$accDevWidth" && exitFail "listDevsPciLib exception, accDevWidth undefined!"
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
				echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $accKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
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
			test -z "$ethDevQtyReq$ethVirtDevQtyReq" && exitFail "listDevsPciLib exception, no quantities are defined on ETH!"
			test -z "$ethKernReq" && exitFail "listDevsPciLib exception, ethKernReq undefined!"
			test -z "$ethDevQtyReq" && exitFail "listDevsPciLib exception, ethDevQtyReq undefined, but devices found" || {
				test -z "$ethDevSpeed" && exitFail "listDevsPciLib exception, ethDevSpeed undefined!"
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
			test -z "$bpDevQtyReq" && except "${FUNCNAME[0]}" "no quantities are defined on BP!"
			test -z "$bpKernReq" && except "${FUNCNAME[0]}" "bpKernReq undefined!"
			test -z "$bpDevQtyReq" && except "${FUNCNAME[0]}" "bpDevQtyReq undefined, but devices found" || {
				test -z "$bpDevSpeed" && except "${FUNCNAME[0]}" "bpDevSpeed undefined!"
				test -z "$bpDevWidth" && except "${FUNCNAME[0]}" "bpDevWidth undefined!"
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
				echo -e "\t "'|'" $bpBus: $blw BP Device$ec: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $bpDevSpeed $pciInfoDevSpeed $bpDevWidth $pciInfoDevWidth)"
			else
				echo -e "$bpBus: $blw BP Dev$ec: $pciInfoDevDesc"
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
			testArrQty "  BP Devices" "$bpDevArr" "$bpDevQtyReq" "No BP devices found on UUT" "warn"
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
			#test -z "$spcKernReq" && exitFail "listDevsPciLib exception, spcKernReq undefined!"
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
	local testDesc errDesc testArr exptQty testSeverity
	dmsg inform "testArrQty> 1=$1 2=$2 3=$3 4=$4 5=$5 6=$6"
	privateVarAssign "testArrQty" "testDesc" "$1"
	testArr=$2
	exptQty=$3
	privateVarAssign "testArrQty" "errDesc" "$4"
	testSeverity=$5 #empty=exit with fail  warn=just warn
	dmsg inform 'testArrQty: >testArr='"$testArr"'< >exptQty='"$exptQty<"
	if [ -z "$exptQty" ]; then
		dmsg inform "testArrQty> $testDesc skipped, no qty defined"
	else
		if [ ! -z "$testArr" ]; then
			echo -e "\t$testDesc: "$testArr" $(qtyComp $exptQty $(echo -e -n "$testArr"| tr " " "\n" | grep -c '^') $testSeverity)"
		else
			exitFail "\tQty check failed! $errDesc!" $PROC
		fi
	fi
}

removePciDev() {
	local pciAddrs
	privateVarAssign "${FUNCNAME[0]}" "pciAddrs" "$*"
	for pciDev in $pciAddrs
	do
		warn "  Removing $pciDev"
		echo 1 > /sys/bus/pci/devices/0000:$pciDev/remove
	done
}

qatConfig() {
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
	local execPath busNum forceBgaNum qatDevCut cpaRes cpaTrace kmodExist qatRes forceQat qatDevUp
	privateVarAssign "qatTest" "execPath" "$1"
	privateVarAssign "qatTest" "busNum" "$2"
	forceBgaNum="$3"
	
	qatResStatus() {
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
	local ipReq cmdRes ethName actIp regEx
	echo -e "\n Setting management IP.."

	acquireVal "Management IP" ipReq ipReq
	regEx='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'; regEx+='0*(1?[0-9]{1,2}|2([‌​0-4][0-9]|5[0-5]))$'
	if [[ "$ipReq" =~ $regEx ]]; then
		echo "  IP Validated"
	else
		except "${FUNCNAME[0]}" "IP is not valid! Please check: $ipReq"
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
			except "${FUNCNAME[0]}" "IP is not valid! Please check: $ipReq"
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

function sendIBS () {
	local ttyR cmdR
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIBSSerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	except "${FUNCNAME[0]}" "null state received! (state: $serState)" ;;
		shell) 	
			cmdRes=$(sendRootIBS $ttyR exit)
			loginIBS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "${FUNCNAME[0]}" "Unable to log in!"
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
				except "${FUNCNAME[0]}" "Unable to log in!"
			fi
		;;
		password) 
			cmdRes=$(sendIBS $ttyR nop)
			sleep 3
			loginIBS $ttyR $uutBaudRate 5 $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "${FUNCNAME[0]}" "Unable to log in!"
			fi
		;;
		*) except "${FUNCNAME[0]}" "unexpected case state received! (state: $serState)"
	esac
}

function sendRootIBS () {
	local ttyR cmdR serState
	privateVarAssign "${FUNCNAME[0]}" "ttyR" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmdR" "$*"

	serState=$(getIBSSerialState $ttyR $uutBaudRate 5 2>&1)
	serState=$(echo "$serState" | sed 's/[^a-zA-Z0-9]//g') # cleanup of special chars
	
	case "$serState" in
		null)	except "${FUNCNAME[0]}" "null state received! (state: $serState)" ;;
		shell) 		
			sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
		;;
		gui) 
			cmdRes=$(sendIBS $ttyR exit)
			loginIBS $ttyR $uutBaudRate 5 $uutRootUser $uutRootPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "${FUNCNAME[0]}" "Unable to log in!"
			fi
		;;
		login)
			loginIBS $ttyR $uutBaudRate 5 $uutRootUser $uutRootPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "${FUNCNAME[0]}" "Unable to log in!"
			fi
		;;
		password) 
			cmdRes=$(sendIBS $ttyR nop)
			sleep 3
			loginIBS $ttyR $uutBaudRate 5 $uutRootUser $uutRootPass
			if [ $? -eq 0 ]; then
				sendSerialCmd $ttyR $uutBaudRate 5 $cmdR
			else
				except "${FUNCNAME[0]}" "Unable to log in!"
			fi
		;;
		*) except "${FUNCNAME[0]}" "unexpected case state received! (state: $serState)"
	esac
}

function loginIBS () {
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "login" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "pass" "$1"

	which expect > /dev/null || except "${FUNCNAME[0]}" "expect not found by which!"
	which tio > /dev/null || except "${FUNCNAME[0]}" "tio not found by which!"

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

function sendSerialCmd () {
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "cmd" "$*"

	which expect > /dev/null || except "${FUNCNAME[0]}" "expect not found by which!"
	which tio > /dev/null || except "${FUNCNAME[0]}" "tio not found by which!"

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
	timeout { send_user \"\nTimeout2\n\"; send \x14q\r ; exit 1 }
	eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
	*\$* { send \x14q\r }
	*#* { send \x14q\r }
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
	local ttyN baud timeout cmd
	privateVarAssign "${FUNCNAME[0]}" "ttyN" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "baud" "$1"; shift
	privateVarAssign "${FUNCNAME[0]}" "timeout" "$1"	

	which expect > /dev/null || except "${FUNCNAME[0]}" "expect not found by which!"
	which tio > /dev/null || except "${FUNCNAME[0]}" "tio not found by which!"

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

echoIfExists() {
	test -z "$2" || {
		echo -n "$1 "
		shift
		echo "$*"
	}
}

rm -f /tmp/exitMsgExec
echo -e '  Loaded module: \tLib for testing (support: arturd@silicom.co.il)'