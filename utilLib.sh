#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

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
		if [[ -v $varVal ]]; then 
			# check as a variable
			varValEval=$(eval echo -ne "\$$varVal" 2>/dev/nul) 
			if [ -z "$varValEval" ]; then
				let statusRes++
			else
				if ! [[ $varValEval =~ $re ]] ; then
					let statusRes++
				fi
			fi
		else
			# check as litteral number
			if ! [[ $varVal =~ $re ]] ; then
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

versionCheck() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
    local verCheck="$1"
    local verReq="$2"  #usage, provide two versions to comare, like 1.1.0.12 and 1.0.9

	local IFS='.'
    read -ra verCheckArr <<< "$verCheck"
    read -ra verReqArr <<< "$verReq"

    local max_len=$(( ${#verCheckArr[@]} > ${#verReqArr[@]} ? ${#verCheckArr[@]} : ${#verReqArr[@]} ))
    for ((i = ${#verCheckArr[@]}; i < max_len; i++)); do
        verCheckArr[i]=0
    done
    for ((i = ${#verReqArr[@]}; i < max_len; i++)); do
        verReqArr[i]=0
    done

    for ((i = 0; i < max_len; i++)); do
		if isNumber ${verCheckArr[i]} ${verReqArr[i]}; then
			if (( verCheckArr[i] > verReqArr[i] )); then
				return 0
			elif (( verCheckArr[i] < verReqArr[i] )); then
				return 1
			fi
		else
			except "one of the parameters provided is not a number (${verCheckArr[i]},${verReqArr[i]})"; return 1
		fi
    done

    return 0
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

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tUtility lib for testing (support: arturd@silicom.co.il)'
	if ! [ "$(type -t sendToKmsg 2>&1)" == "function" ]; then 
		source /root/multiCard/arturLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mMAIN LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi