#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

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

sendCordoba() {
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
		cmdR="poweroff"
		addArg+=" --terminal=pico --exit-trigger-keyw=reboot:__SPACESYMB__Power__SPACESYMB__down"
	fi

	serState=$(getCordobaSerialState $ttyR $uutBaudRate $respTimeout)
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
			sendSerialCmdCordoba$addArg $ttyR $uutBaudRate $respTimeout $cmdR
		;;
		login)
			dmsg inform "LOGIN_REQUEST> $ttyR@$uutBaudRate t/o:$respTimeout user:$uutBdsUser pass:$uutBdsPass"
			loginCordoba $ttyR $uutBaudRate $respTimeout $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmdCordoba$addArg $ttyR $uutBaudRate $respTimeout $cmdR
			else
				except "Unable to send cmd from $serState!"
			fi
		;;
		password) 
			cmdRes=$(sendSerialCmdCordoba$addArg $ttyR $uutBaudRate $respTimeout nop)
			sleep 3
			dmsg inform "LOGIN_REQUEST> $ttyR@$uutBaudRate t/o:$respTimeout user:$uutBdsUser pass:$uutBdsPass"
			loginCordoba $ttyR $uutBaudRate $respTimeout $uutBdsUser $uutBdsPass
			if [ $? -eq 0 ]; then
				sendSerialCmdCordoba$addArg $ttyR $uutBaudRate $respTimeout $cmdR
			else
				except "Unable to send cmd from $serState!"
			fi
		;;
		*) except "unexpected case state received! (state: $serState)"
	esac
	dmsg inform "cmdRes=$cmdRes"
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

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tDevice utility lib for testing (support: arturd@silicom.co.il)'
	if ! [ "$(type -t sendToKmsg 2>&1)" == "function" ]; then 
		source /root/multiCard/arturLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mMAIN LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t privateVarAssign 2>&1)" == "function" ]; then 
		source /root/multiCard/utilLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mUTILITY LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
	if ! [ "$(type -t sendSerialCmd 2>&1)" == "function" ]; then 
		source /root/multiCard/serialLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mSERIAL LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi