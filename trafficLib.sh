#!/bin/bash

getIfaceMaxBuff() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local args arg iface ifaceList txReq keyw buffSize buffSizes
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c2-)
		if isDefined key; then
			case "$key" in
				tx) let txReq=1;;
				rx) unset txReq;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done

	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		if isDefined txReq; then keyw="TX"; else keyw="RX"; fi
		for iface in $ifaceList; do
			buffSize=$(ethtool -g $iface 2>/dev/null |grep -A4 -m1 'maximums:' |grep -x "^$keyw:.*" |awk '{print $2}')
			if isDefined buffSize; then
				buffSizes+=("$buffSize")
			else
				except "Unable to get $keyw buffer size on ethernet interface: $iface"
			fi
		done
		echo -n "${buffSizes[*]}"
	else
		except "Ethernet interface list is empty"
	fi
}

function getIfaceLink() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key arg args iface ifaceList txBuffMax ipLinkState
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	let ipLinkState=99
	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c2-)
		if isDefined key; then
			case "$key" in
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done
	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		dmsg echo -e "  Getting links on ifaces: $org"$ifaceList"$ec"
		for iface in $ifaceList; do
			dmsg echo -e "   $org$iface$ec - processing.."
			linkCmdRes=$(ethtool $iface 2>/dev/null |grep -x ".*ink.*detected:.*")
			if ! isDefined linkCmdRes; then except "Unable to get link state on $iface"; fi
			linkUp=$(grep -x ".*yes$"<<<"$linkCmdRes")
			if isDefined linkUp; then
				let ipLinkState=0
			else
				let ipLinkState=1
			fi
			sleep 0.2 #to not exceed request rate
		done
		dmsg echo -e "  Done."
	else
		except "Ethernet interface list is empty"
	fi
	return $ipLinkState
}

function setIfaceLinks() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key arg args iface ifaceList txBuffMax targStateOn targState totalState setOk
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c2-)
		if isDefined key; then
			case "$key" in
				down) 
					unset targStateOn
					targState="down"
				;;
				up) 
					let targStateOn=1
					targState="up"
				;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done
	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		if isDefined targState; then
			echo -e "  Setting links on ifaces: $org"$ifaceList"$ec to $gr$targState$ec"
			for iface in $ifaceList; do
				echo -e "   $org$iface$ec - processing.."
				isDefined targStateOn; totalState="$?"
				getIfaceLink $iface; totalState+="$?"
				setOk=$(grep -x "^00$\|^11$"<<<"$totalState")
				if isDefined setOk; then
					echo -e "    $org$iface$ec> ${gr}Was set ok$ec."
				else
					echo -e "    $org$iface$ec> Setting link to ${yl}$targState$ec.."
					ip link set $targState $iface &>/dev/null
					if [ $? -eq 0 ]; then
						echo -e "    $org$iface$ec> ${gr}Is set ok$ec."
					else
						echo -e "    $org$iface$ec> ${rd}Was NOT set ok$ec."
					fi
					sleep 0.1 #to not exceed request rate
				fi
			done
			echo -e "  Done."
		else
			except "Target state is not defined"
		fi
	else
		except "Ethernet interface list is empty"
	fi
}

function setIfaceParams() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key arg args iface ifaceList txBuffMax targStateOn targState
	local ringRxBuffMax ringTxBuffMax pauseParamsCmdRes pauseRxStateOn pauseTxStateOn pauseAutoNegStateOn
	local ethtoolCmdFail globAutoNegParamsCmdRes globAutoNegStateOn totalState setOk runRes retLeft changesPending
	local retryMultiedDelay setOnly
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c2-)
		if isDefined key; then
			case "$key" in
				off) 
					unset targStateOn
					targState="off"
				;;
				on) 
					let targStateOn=1
					targState="on"
				;;
				flow) modeArg="g"; smode="flow";;
				pause) modeArg="a"; smode="pause";;
				global) modeArg="s"; smode="global";;
				set-only-no-wait) let setOnly=1; let retLeft=1;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done
	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		if isDefined smode; then
			echo -e "  Setting $smode on ifaces: $org"$ifaceList"$ec to $gr$targState$ec"
			for iface in $ifaceList; do
				echo -e "   $org$iface$ec - processing.."
				privateVarAssign "${FUNCNAME[0]}" "pauseParamsCmdRes" "$(ethtool -a $iface)"; sleep 0.5 #to not exceed request rate
				pauseRxStateOn=$(grep -x "^RX.*on" <<<"$pauseParamsCmdRes")
				pauseTxStateOn=$(grep -x "^TX.*on" <<<"$pauseParamsCmdRes")
				pauseAutoNegStateOn=$(grep -x "^Autoneg.*on" <<<"$pauseParamsCmdRes")
				privateVarAssign "${FUNCNAME[0]}" "globAutoNegParamsCmdRes" "$(ethtool $iface 2>/dev/null |grep -x ".*Auto.*negotiation:.*")"; sleep 0.5 #to not exceed request rate
				globAutoNegStateOn=$(grep -x "^.*: on$" <<<"$globAutoNegParamsCmdRes")
				let runRes=99
				if ! isDefined setOnly; then let retLeft=30; fi
				let goodRuns=0
				while [ $retLeft -gt 0 -a $goodRuns -lt 2 ]; do
					let runRes=0
					let changesPending=0
					unset ethtoolCmdFail
					case "$smode" in
						flow) 
							if isDefined globAutoNegStateOn; then 
								echo -e "    $org$iface$ec> Setting global auto-negotiation to ${yl}OFF$ec.."
								ethtoolCmdFail+="$(ethtool -s $iface autoneg off &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
							else
								dmsg echo -e "    $org$iface$ec> Global auto-negotiation no changes required, already ${gr}OFF$ec."
							fi
							if isDefined pauseAutoNegStateOn; then 
								echo -e "    $org$iface$ec> Setting pause auto-negotiation to ${yl}OFF$ec.."
								ethtoolCmdFail+="$(ethtool -A $iface autoneg off &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
							else
								dmsg echo -e "    $org$iface$ec> Pause auto-negotiation no changes required, already ${gr}OFF$ec."
							fi


							isDefined pauseRxStateOn targStateOn &>/dev/null; local rxState=$?
							if [ $rxState -eq 1 ]; then
								echo -e "    $org$iface$ec> Setting RX to ${yl}$targState$ec.."
								ip link set down $iface &>/dev/null; sleep 1
								ethtool -r $iface &>/dev/null; sleep 0.5
								ethtoolCmdFail+="$(ethtool -A $iface rx $targState tx $targState &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
								ip link set up $iface &>/dev/null
							else
								dmsg echo -e "    $org$iface$ec> RX no changes required, already ${gr}$targState$ec."
							fi

							isDefined pauseTxStateOn targStateOn &>/dev/null; local txState=$?
							if [ $txState -eq 1 ]; then
								if [ $rxState -eq 1 ]; then
									echo -e "    $org$iface$ec> TX was previously been set by RX querry to ${yl}$targState$ec.."
								else
									echo -e "    $org$iface$ec> Setting TX to ${yl}$targState$ec.."
									ip link set down $iface &>/dev/null; sleep 1
									ethtool -r $iface &>/dev/null; sleep 0.5
									ethtoolCmdFail+="$(ethtool -A $iface rx $targState tx $targState &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
									ip link set up $iface &>/dev/null
								fi
							else
								dmsg echo -e "    $org$iface$ec> TX no changes required, already ${gr}$targState$ec."
							fi

							if ! isDefined setOnly; then 
								if [ $changesPending -gt 0 ]; then 
									# privateNumAssign "retryMultipliedDelay" "$(((11-$retLeft)*5))"
									let retryMultipliedDelay=10
									echo -e "    $org$iface$ec> Waiting for changes to apply.. ${yl}$retryMultipliedDelay$ec sec, retries left: $retLeft.."
									sleep $retryMultipliedDelay
									#checking results 
									privateVarAssign "${FUNCNAME[0]}" "pauseParamsCmdRes" "$(ethtool -a $iface)"; sleep 0.5 #to not exceed request rate
									pauseRxStateOn=$(grep -x "^RX.*on" <<<"$pauseParamsCmdRes")
									pauseTxStateOn=$(grep -x "^TX.*on" <<<"$pauseParamsCmdRes")
									pauseAutoNegStateOn=$(grep -x "^Autoneg.*on" <<<"$pauseParamsCmdRes")
									privateVarAssign "${FUNCNAME[0]}" "globAutoNegParamsCmdRes" "$(ethtool $iface 2>/dev/null |grep -x ".*Auto.*negotiation:.*")"; sleep 0.5 #to not exceed request rate
									globAutoNegStateOn=$(grep -x "^.*: on$" <<<"$globAutoNegParamsCmdRes")

									isDefined pauseRxStateOn targStateOn &>/dev/null; totalState="$?"
									isDefined pauseTxStateOn targStateOn &>/dev/null; totalState+="$?"
									isDefined globAutoNegStateOn pauseAutoNegStateOn &>/dev/null; totalState+="$?"
									setOk=$(grep -x "^222$\|^002$"<<<"$totalState")
								else
									setOk="noChanges"
								fi

								if isDefined setOk; then
									let goodRuns++
									if [ $changesPending -gt 0 ]; then
										echo -e "    $org$iface$ec> ${gr}Is set ok$ec."
									else
										echo -e "    $org$iface$ec> ${gr}Was set ok$ec."
									fi
									if [ $goodRuns -lt 2 ]; then 
										echo -e "    $org$iface$ec> ${yl}Rechecking...$ec"
										sleep 0.5
									else
										ip link set up $iface
									fi
								else
									echo -e "    $org$iface$ec> ${rd}Was NOT set ok$ec. (errC:$totalState)"
									if [ $retLeft -gt 1 ]; then echo -e "    $org$iface$ec> ${rd}Retrying...$ec"; fi
									let runRes++
								fi
							else
								echo -e "    $org$iface$ec> Set only flag active, not checking for a result"
							fi
						;;
						pause) 
							except "Undefined mode"
						;;
						global) 

							isDefined globAutoNegStateOn targStateOn &>/dev/null
							if [ $? -eq 1 ]; then
								echo -e "    $org$iface$ec> Setting global auto-negotiation to ${yl}$targState$ec.."
								ethtoolCmdFail+="$(ethtool -s $iface autoneg $targState &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
							else
								dmsg echo -e "    $org$iface$ec> Global auto-negotiation no changes required, already ${gr}$targState$ec."
							fi

							isDefined pauseAutoNegStateOn targStateOn &>/dev/null
							if [ $? -eq 1 ]; then
								echo -e "    $org$iface$ec> Setting pause auto-negotiation to ${yl}$targState$ec.."
								ethtoolCmdFail+="$(ethtool -A $iface autoneg $targState &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
							else
								dmsg echo -e "    $org$iface$ec> Pause auto-negotiation no changes required, already ${gr}$targState$ec."
							fi

							isDefined pauseRxStateOn targStateOn &>/dev/null
							if [ $? -eq 1 ]; then
								echo -e "    $org$iface$ec> Setting RX to ${yl}$targState$ec.."
								ethtoolCmdFail+="$(ethtool -A $iface rx $targState tx $targState &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
							else
								dmsg echo -e "    $org$iface$ec> RX no changes required, already ${gr}$targState$ec."
							fi

							isDefined pauseTxStateOn targStateOn &>/dev/null
							if [ $? -eq 1 ]; then
								echo -e "    $org$iface$ec> Setting TX to ${yl}$targState$ec.."
								ethtoolCmdFail+="$(ethtool -A $iface rx $targState tx $targState &>/dev/null; echo -n $?|grep -vx "^0$\|^78$")"; let changesPending++; sleep 0.5 #to not exceed request rate
							else
								dmsg echo -e "    $org$iface$ec> TX no changes required, already ${gr}$targState$ec."
							fi

							if ! isDefined setOnly; then 
								if [ $changesPending -gt 0 ]; then 
									# privateNumAssign "retryMultipliedDelay" "$(((11-$retLeft)*5))"
									let retryMultipliedDelay=10
									echo -e "    $org$iface$ec> Waiting for changes to apply.. ${yl}$retryMultipliedDelay$ec sec, retries left: $retLeft.."
									sleep $retryMultiedDelay
									#checking results 
									privateVarAssign "${FUNCNAME[0]}" "pauseParamsCmdRes" "$(ethtool -a $iface)"; sleep 0.5 #to not exceed request rate
									pauseRxStateOn=$(grep -x "^RX.*on" <<<"$pauseParamsCmdRes")
									pauseTxStateOn=$(grep -x "^TX.*on" <<<"$pauseParamsCmdRes")
									pauseAutoNegStateOn=$(grep -x "^Autoneg.*on" <<<"$pauseParamsCmdRes")
									privateVarAssign "${FUNCNAME[0]}" "globAutoNegParamsCmdRes" "$(ethtool $iface 2>/dev/null |grep -x ".*Auto.*negotiation:.*")"; sleep 0.5 #to not exceed request rate
									globAutoNegStateOn=$(grep -x "^.*: on$" <<<"$globAutoNegParamsCmdRes")

									isDefined pauseRxStateOn targStateOn &>/dev/null; totalState="$?"
									isDefined pauseTxStateOn targStateOn &>/dev/null; totalState+="$?"
									isDefined globAutoNegStateOn targStateOn &>/dev/null; totalState+="$?"
									isDefined pauseAutoNegStateOn targStateOn &>/dev/null; totalState+="$?"
									setOk=$(grep -x "^2222$\|^0000$"<<<"$totalState")
								else
									setOk="noChanges"
								fi

								if isDefined setOk; then
									let goodRuns++
									if [ $changesPending -gt 0 ]; then
										echo -e "    $org$iface$ec> ${gr}Is set ok$ec."
									else
										echo -e "    $org$iface$ec> ${gr}Was set ok$ec."
									fi
									if [ $goodRuns -lt 2 ]; then 
										echo -e "    $org$iface$ec> ${yl}Rechecking...$ec"
										sleep 0.5
									fi
								else
									echo -e "    $org$iface$ec> ${rd}Was NOT set ok$ec. (errC:$totalState)"
									if [ $retLeft -gt 1 ]; then echo -e "    $org$iface$ec> ${rd}Retrying...$ec"; fi
									let runRes++
								fi
							else
								echo -e "    $org$iface$ec> Set only flag active, not checking for a result"
							fi
						;;
						*) except "Illegal set mode: $smode"
					esac
					let retLeft--
				done
				if isDefined ethtoolCmdFail && ! isDefined setOnly ; then
					except "ethtool failed to set $smode on $iface to $targState (exit code: $ethtoolCmdFail)"
				fi
				sleep 0.2 #to not exceed request rate
			done
			echo -e "  Done."
		else
			except "Set mode is not defined"
		fi
	else
		except "Ethernet interface list is empty"
	fi
}

function setIfaceChannels() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key arg args value iface ifaceList targQty
	local chanParamsCmdRes targQtyCap changesPending targRXQtyCap targTXQtyCap
	local ethtoolCmdFail ethtoolCmdExitCode
	local threadCount threadPerCore
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	let changesPending=0
	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c2- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		if isDefined key; then
			case "$key" in
				target-qty) privateNumAssign "targQty" "$value";;
				max-qty)
					privateNumAssign "threadCount" "$(nproc 2>/dev/null)"
					privateNumAssign "threadPerCore" "$(lscpu 2>/dev/null |grep -m1 -x "^Thread.*core.*$" |sed 's/[^0-9]*//g')"
					if [ $threadPerCore -gt 1 ]; then
						except "Thread count per core is greter than 1, turn off multi-threading"
					else
						privateNumAssign "targQty" "$threadCount"
					fi
				;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done

	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		if isDefined targQty; then
			echo -e "  Setting channel on ifaces: $org"$ifaceList"$ec to $gr$targQty$ec"
			for iface in $ifaceList; do
				echo -e "   $org$iface$ec - processing.."
				let targQtyCap=-1
				privateVarAssign "${FUNCNAME[0]}" "chanParamsCmdRes" "$(ethtool -l $iface)";  #to not exceed request rate
				privateVarAssign "${FUNCNAME[0]}" "chanMaxInfo" "$(grep -A4 -x "^.*maximums:.*$" <<<"$chanParamsCmdRes")"
				privateVarAssign "${FUNCNAME[0]}" "chanCurrInfo" "$(grep -A4 -x "^Current hardware settings:$" <<<"$chanParamsCmdRes")"
				privateNumAssign chanMaxRXqty $(grep -x "^RX:.*$" <<<"$chanMaxInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
				privateNumAssign chanMaxTXqty $(grep -x "^TX:.*$" <<<"$chanMaxInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
				privateNumAssign chanMaxCombQty $(grep -x "^Combined:.*$" <<<"$chanMaxInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
				privateNumAssign chanCurRXqty $(grep -x "^RX:.*$" <<<"$chanCurrInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
				privateNumAssign chanCurTXqty $(grep -x "^TX:.*$" <<<"$chanCurrInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
				privateNumAssign chanCurCombQty $(grep -x "^Combined:.*$" <<<"$chanCurrInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')

				if [ $chanMaxCombQty -gt 0 ]; then
					if [ $targQty -ne $chanCurCombQty ]; then
						let changesPending++
						if [ $targQty -gt $chanMaxCombQty ]; then
							privateNumAssign "targQtyCap" "$chanMaxCombQty"
							inform "    $org$iface$yl> ${rd}Target channel combined QTY is greater than maximum, capping to $yl$targQtyCap."
						else
							privateNumAssign "targQtyCap" "$targQty"
						fi
						echo -ne "    $org$iface$ec> Setting combined QTY to $gr$targQty$ec.. "
						ethtoolCmdExitCode="$(ethtool -L $iface combined $targQtyCap &>/dev/null; echo -n $?|grep -vx "^0$")"
						if isDefined ethtoolCmdExitCode; then
							ethtoolCmdFail+=$ethtoolCmdExitCode
							echo -e "${rd}FAIL$ec"
						else
							echo -e "${gr}ok$ec"
						fi
						let changesPending++
					else
						privateNumAssign "targQtyCap" "$targQty"
						echo -e "    $org$iface$ec> Combined QTY is already at $gr$targQty$ec."
					fi
				else
					echo -e "    $org$iface$ec> Combined QTY cap is ${yl}$chanMaxCombQty$ec, skipping."
				fi

				if [ $changesPending -gt 0 ]; then 
					echo -e "    $org$iface$ec> Waiting for combined channel changes processing..."
					sleep 2
					let changesPending=0
					privateVarAssign "${FUNCNAME[0]}" "chanParamsCmdRes" "$(ethtool -l $iface)";  #to not exceed request rate
					privateVarAssign "${FUNCNAME[0]}" "chanMaxInfo" "$(grep -A4 -x "^.*maximums:.*$" <<<"$chanParamsCmdRes")"
					privateVarAssign "${FUNCNAME[0]}" "chanCurrInfo" "$(grep -A4 -x "^Current hardware settings:$" <<<"$chanParamsCmdRes")"
					privateNumAssign chanMaxCombQty $(grep -x "^Combined:.*$" <<<"$chanMaxInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
					privateNumAssign chanCurCombQty $(grep -x "^Combined:.*$" <<<"$chanCurrInfo" |awk '{print $2}' |sed 's/[^0-9]*//g')
				fi

				if [ $chanMaxCombQty -gt 0 ]; then
					if [ $targQty -gt $chanMaxCombQty ]; then
						privateNumAssign "targQtyCap" "$chanMaxCombQty"
						inform "    $org$iface$yl> ${rd}Target channel combined QTY is greater than maximum, capping to $yl$targQtyCap."
					else
						privateNumAssign "targQtyCap" "$targQty"
					fi
					if [ $targQtyCap -eq $chanCurCombQty ]; then
						if [ $targQty -ne $chanMaxRXqty ]; then
							if [ $chanMaxRXqty -gt 0 ]; then
								if [ $targQty -gt $chanMaxRXqty ]; then
									privateNumAssign "targRXQtyCap" "$chanMaxRXqty"
									inform "    $org$iface$yl> ${rd}Target channel RX QTY is greater than maximum, capping to $yl$targRXQtyCap."
								else
									privateNumAssign "targRXQtyCap" "$targQty"
								fi
								echo -ne "    $org$iface$ec> Setting RX QTY to $gr$targRXQtyCap$ec.. "
								ethtoolCmdExitCode="$(ethtool -L $iface rx $targRXQtyCap &>/dev/null; echo -n $?|grep -vx "^0$")"
								if isDefined ethtoolCmdExitCode; then
									ethtoolCmdFail+=$ethtoolCmdExitCode
									echo -e "${rd}FAIL$ec"
								else
									echo -e "${gr}ok$ec"
								fi
								let changesPending++
							else
								echo -e "    $org$iface$ec> Max RX QTY is ${yl}$chanMaxRXqty$ec, skipping."
							fi
						else
							echo -e "    $org$iface$ec> RX QTY is already at $gr$targQty$ec."
						fi
						if [ $changesPending -gt 0 ]; then sleep 0.5; let changesPending=0; fi
						if [ $targQty -ne $chanMaxTXqty ]; then
							if [ $chanMaxTXqty -gt 0 ]; then
								if [ $targQty -gt $chanMaxTXqty ]; then
									privateNumAssign "targTXQtyCap" "$chanMaxTXqty"
									inform "    $org$iface$yl> ${rd}Target channel TX QTY is greater than maximum, capping to $yl$targTXQtyCap."
								else
									privateNumAssign "targTXQtyCap" "$targQty"
								fi
								echo -ne "    $org$iface$ec> Setting TX QTY to $gr$targTXQtyCap$ec.. "
								ethtoolCmdExitCode="$(ethtool -L $iface tx $targTXQtyCap &>/dev/null; echo -n $?|grep -vx "^0$")"
								if isDefined ethtoolCmdExitCode; then
									ethtoolCmdFail+=$ethtoolCmdExitCode
									echo -e "${rd}FAIL$ec"
								else
									echo -e "${gr}ok$ec"
								fi
								let changesPending++
							else
								echo -e "    $org$iface$ec> Max TX QTY is ${yl}$chanMaxTXqty$ec, skipping."
							fi
						else
							echo -e "    $org$iface$ec> TX QTY is already at $gr$targQty$ec."
						fi
						if [ $changesPending -gt 0 ]; then sleep 0.5; let changesPending=0; fi
					else
						echo -e "    $org$iface$ec> Combined QTY is at $yl$chanMaxCombQty$ec,not at $gr$targQty$ec, skipping"
					fi
				else
					echo -e "    $org$iface$ec> Combined QTY cap is ${yl}$chanMaxCombQty$ec, skipping."
				fi
			done
			if isDefined ethtoolCmdFail; then
				except "ethtool failed to set channel on ifaces: $org"$ifaceList"$ec to $gr$targQty$ec (exit code: $ethtoolCmdFail)"
			fi
		else
			except "Target channel qty is undefined"
		fi
	else
		except "Ethernet interface list is empty"
	fi
}

killIrqBalance() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local irqRunning
	irqRunning=$(ps -A 2>/dev/null |grep -x '^.*irqbalance$')
	if isDefined irqRunning; then
		killProcess irqbalance
		if [ $? -ne 0 ]; then
			except "Unable to kill irqbalance"
		fi
	fi
}

function setIrq() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local args arg iface ifaceList
	local threadCount threadPerCore
	local irqList devMsiList allTxRxIrqs validIrq irqN divider coreMask
	local curIrqMask curIrqMaskHex retryIdx
	privateNumAssign "threadCount" "$(nproc 2>/dev/null)"
	privateNumAssign "threadPerCore" "$(lscpu 2>/dev/null |grep -m1 -x "^Thread.*core.*$" |sed 's/[^0-9]*//g')"
	let divider=0

	
	if [ $threadCount -gt 1 ]; then
		privateVarAssign "${FUNCNAME[0]}" "args" "$*"
		for arg in ${args}
		do
			key=$(grep "^-.*" <<<"$arg" |cut -c2-)
			if isDefined key; then
				case "$key" in
					*) except "Unknown key: $key"
				esac
			else
				if ifaceExist "$arg"; then
					ifaceList+="$arg "
				else
					except "Non existent ethernet interface: $arg"
				fi
			fi
		done

		echo "  Setting IRQ balance for: $ifaceList Cores available: $threadCount"
		if [ $threadPerCore -gt 1 ]; then
			except "Thread count per core is greter than 1, turn off multi-threading"
		else
			if isDefined ifaceList; then
				checkIfacesExist $ifaceList
				echo "  Killing IRQ balance.."
				killIrqBalance
				for iface in $ifaceList; do
					echo -ne "   Getting IRQ list on $yl$iface$ec: "
					irqList=$(cat /proc/interrupts |grep -x ".*$iface-TxRx.*$" | cut -f1 -d:)
					if ! isDefined irqList; then
						irqList=$(cat /proc/interrupts |grep -w "$iface" | cut -f1 -d:)
					fi
					if ! isDefined irqList; then
						devMsiList=$(ls -Ux /sys/class/net/$iface/device/msi_irqs)
						if isDefined devMsiList; then
							allTxRxIrqs="$(cat /proc/interrupts |grep -x "^.*[[:digit:]]:.*TxRx.*$" |grep -v fdir |cut -d: -f1 |sed 's/[^0-9]*//g')"
							if isDefined allTxRxIrqs; then
								for devMsiIrq in $devMsiList; do
									validIrq=$(grep -wx "^$devMsiIrq$"<<<"$allTxRxIrqs")
									if isDefined validIrq; then
										irqList+="$validIrq "
									fi
								done
							else
								except "Unable to get Tx/Rx IRQ list from /proc/interrupts"
							fi
						else
							except "Unable to get device MSI IRQ list"
						fi
					fi
					if isDefined irqList; then
						echo -e $cy$irqList$ec
						let dividerBackup=$divider
						for irqN in $irqList; do
							let targetCore=$divider%$threadCount
							if [ $targetCore -ge 0 ]; then
								coreMask=$(printf %x $[2 ** $targetCore])
								if isDefined coreMask; then
									let curIrqMask=0x$(cat /proc/irq/$irqN/smp_affinity |awk -F, '{print $NF}')
									curIrqMaskHex=$(printf '%x' $curIrqMask)
									irqName=$(cat /proc/interrupts |grep -m1 -x "^.*$irqN: .*$" |awk '{print $NF}')
									if [ "$curIrqMaskHex" == "$coreMask" ]; then
										echo -e "    Checked, $org$iface$ec IRQ $cy$irqN$ec is already on CPU core $cyg$targetCore$ec ($irqName), ${gr}skipping IRQ set$ec"
									else
										echo "$coreMask" > /proc/irq/$irqN/smp_affinity
										echo -ne "    Setting $org$iface$ec IRQ $cy$irqN$ec to CPU core $cyg$targetCore$ec ($irqName)"
										for ((retryIdx=4; retryIdx>0; --retryIdx)) ; do
											sleep 0.08
											echo -ne " Checking: "
											let curIrqMask=0x$(cat /proc/irq/$irqN/smp_affinity |awk -F, '{print $NF}')
											curIrqMaskHex=$(printf '%x' $curIrqMask)
											if [ "$curIrqMaskHex" == "$coreMask" ]; then
												echo -ne "${gr}set.$ec"
												break
											else
												echo -ne "${rd}NOT set, setting$ec"
												echo "$coreMask" > /proc/irq/$irqN/smp_affinity
											fi
										done
										echo ""
									fi
								fi
								let divider++
							else
								dmsg inform "skipping, lesser than zero"
							fi
						done
					else
						except "Unable to define $iface IRQ list"
					fi
				done
			else
				except "Ethernet interface list is empty"
			fi
		fi
	else
		critWarn "Thread count is not greter than 1, skipping IRQ"
	fi
}

function updateIfaceStats() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local varName key arg args iface ifaceList vendorID devID statsCmdRes statFileName sedRes statLastByte updateMode pciInfo
	local tx_pkt_cnt tx_pkt_err tx_pkt_drop tx_byte_cnt tx_byte_err tx_byte_drop
	local rx_pkt_cnt rx_pkt_err rx_pkt_drop rx_byte_cnt rx_byte_err rx_byte_drop
	local allTrfVars="tx_pkt_cnt tx_pkt_err tx_pkt_drop tx_byte_cnt tx_byte_err tx_byte_drop rx_pkt_cnt rx_pkt_err rx_pkt_drop rx_byte_cnt rx_byte_err rx_byte_drop"
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	initTmp "/root/tmpTrfStats"
	for arg in ${args}; do
		key=$(grep "^-.*" <<<"$arg" |cut -c2-)
		if isDefined key; then
			case "$key" in
				update) let updateMode=1;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done
	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		for iface in $ifaceList; do
			ifaceBusAddr=$(cat /sys/class/net/$iface/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
			pciInfo=$(lspci -nms:$ifaceBusAddr)
			vendorID=$(cut -d'"' -f4 <<<$pciInfo)
			devID=$(cut -d'"' -f6 <<<$pciInfo)
			statsCmdRes="$(ethtool -S $iface)"
			statFileName="/root/tmpTrfStats/$iface.stats"
			if [ ! -s "$statFileName" ]; then
				local header="iface;vendorID;devID;ifaceBusAddr;"
				header+="tx_pkt_cnt;tx_pkt_err;tx_pkt_drop;tx_byte_cnt;tx_byte_err;tx_byte_drop;"
				header+="rx_pkt_cnt;rx_pkt_err;rx_pkt_drop;rx_byte_cnt;rx_byte_err;rx_byte_drop;"
				echo "$header">>"$statFileName"
			else
				if isDefined updateMode; then 
					if [ $(wc -l < "$statFileName") -gt 2 ]; then sed -i '$d' "$statFileName"; fi
				fi
			fi
			statLastByte=$(cat $statFileName 2>/dev/null |tail -c1 |od |awk '{print $2}' |grep -x '^000012$') #last byte need to be equal of \n
			if ! isDefined statLastByte; then echo >>"$statFileName"; fi #moving to newline if no newline char was present at end of the line
			case "$vendorID" in
				"14e4")
					tx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_ucast_frames: .*$' |awk '$1=$1 {print $2}')
					tx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_err: .*$' |awk '$1=$1 {print $2}')
					tx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_total_discard_pkts: .*$' |awk '$1=$1 {print $2}')
					#tx_chan_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_total_discard_pkts: .*$' |awk '$1=$1 {print $2}')
					tx_byte_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_bytes: .*$' |awk '$1=$1 {print $2}')
					tx_byte_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_stat_error: .*$' |awk '$1=$1 {print $2}')
					tx_byte_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_stat_discard: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_ucast_frames: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_fcs_err_frames: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_total_discard_pkts: .*$' |awk '$1=$1 {print $2}')
					#rx_chan_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_total_discard_pkts: .*$' |awk '$1=$1 {print $2}')
					rx_byte_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_bytes: .*$' |awk '$1=$1 {print $2}')
					rx_byte_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_stat_err: .*$' |awk '$1=$1 {print $2}')
					rx_byte_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_stat_discard: .*$' |awk '$1=$1 {print $2}')
				;;
				"15b3")
					tx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_packets: .*$' |awk '$1=$1 {print $2}')
					tx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_errors: .*$' |awk '$1=$1 {print $2}')
					tx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_dropped: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_packets: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_error_packets: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_dropped: .*$' |awk '$1=$1 {print $2}')
				;;
				"8086")
					case "$devID" in
						"1592"|"1593")
							tx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_unicast: .*$' |awk '$1=$1 {print $2}')
							tx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_errors: .*$' |awk '$1=$1 {print $2}')
							tx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_dropped: .*$' |awk '$1=$1 {print $2}')
							rx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_unicast: .*$' |awk '$1=$1 {print $2}')
							rx_pkt_err=$(($(tr ' ' '+'<<<$(grep rx <<<"$statsCmdRes" |grep errors |cut -d: -f2 |cut -d' ' -f2))))
							rx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_dropped: .*$' |awk '$1=$1 {print $2}')
						;;
						*)
							tx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_packets: .*$' |awk '$1=$1 {print $2}')
							tx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_errors: .*$' |awk '$1=$1 {print $2}')
							tx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_dropped: .*$' |awk '$1=$1 {print $2}')
							rx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_packets: .*$' |awk '$1=$1 {print $2}')
							rx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_errors: .*$' |awk '$1=$1 {print $2}')
							rx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_dropped: .*$' |awk '$1=$1 {print $2}')
					esac
				;;
				*) 
					tx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_packets: .*$' |awk '$1=$1 {print $2}')
					tx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_errors: .*$' |awk '$1=$1 {print $2}')
					tx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* tx_dropped: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_cnt=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_packets: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_err=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_errors: .*$' |awk '$1=$1 {print $2}')
					rx_pkt_drop=$(grep -v '\[' <<<"$statsCmdRes" |grep -x '^.* rx_dropped: .*$' |awk '$1=$1 {print $2}')
					#except "Illegal Vendor ID: $vendorID of iface: $iface."
			esac

			for varName in $allTrfVars; do
				if ! isDefined $varName; then
					dmsg inform "$varName is undefined, setting to 0"
					eval let $varName=0
				fi
				dmsg echo -e "  $yl$iface$ec> $varName=$yl${!varName}$ec"
			done
			lineAdd="$iface;$vendorID;$devID;$ifaceBusAddr;"
			lineAdd+="$tx_pkt_cnt;$tx_pkt_err;$tx_pkt_drop;$tx_byte_cnt;$tx_byte_err;$tx_byte_drop;"
			lineAdd+="$rx_pkt_cnt;$rx_pkt_err;$rx_pkt_drop;$rx_byte_cnt;$rx_byte_err;$rx_byte_drop;"
			echo "$lineAdd">>"$statFileName"
		done
	fi
	return $?
}

function compareIfaceStats() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local varName key arg args iface ifaceList vendorID devID statsCmdRes statFileName
	local tx_pkt_cnt tx_pkt_err tx_pkt_drop tx_byte_cnt tx_byte_err tx_byte_drop
	local rx_pkt_cnt rx_pkt_err rx_pkt_drop rx_byte_cnt rx_byte_err rx_byte_drop
	local lastLineNum secLastLineNum lastLine secLastLine preStatArr postStatArr vNum statPrintVar
	local allTrfVars="tx_pkt_cnt tx_pkt_err tx_pkt_drop tx_byte_cnt tx_byte_err tx_byte_drop rx_pkt_cnt rx_pkt_err rx_pkt_drop rx_byte_cnt rx_byte_err rx_byte_drop"
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"
	initTmp "/root/tmpTrfStats"
	for arg in ${args}; do
		key=$(grep "^-.*" <<<"$arg" |cut -c2-)
		if isDefined key; then
			case "$key" in
				parsable) local parseMode=1;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done
	if isDefined ifaceList; then
		checkIfacesExist $ifaceList
		for iface in $ifaceList; do
			statPrintVar+="$iface "
			ifaceBusAddr=$(cat /sys/class/net/$iface/device/uevent |grep PCI_SLOT_NAME= |cut -d: -f2-)
			vendorID=$(lspci -nms:$ifaceBusAddr |cut -d'"' -f4)
			devID=$(lspci -nms:$ifaceBusAddr |cut -d'"' -f6)
			statFileName="/root/tmpTrfStats/$iface.stats"
			privateNumAssign lastLineNum $(cat $statFileName 2>/dev/null |wc -l)
			let secLastLineNum=$(($lastLineNum-1))

			if [ $lastLineNum -gt 2 ]; then 
				lastLine=$(sed "${lastLineNum}q;d" $statFileName |grep -x "^$iface.*" |tr ';' ' ')
				secLastLine=$(sed "${secLastLineNum}q;d" $statFileName |grep -x "^$iface.*" |tr ';' ' ')
				dmsg inform "lastLine: $lastLine"
				dmsg inform "secLastLine: $secLastLine"
				if isDefined lastLine secLastLine; then
					read -ra preStatArr <<< "$secLastLine"
					read -ra postStatArr <<< "$lastLine" 
					preStatArr=("${preStatArr[@]:4}") #shifing non stat values
					postStatArr=("${postStatArr[@]:4}")
					dmsg inform "preStatArr: ${preStatArr[*]}"
					dmsg inform "postStatArr: ${postStatArr[*]}"
					case "$vendorID" in
						"14e4"|"15b3"|"8086"|*) 
							if isDefined parseMode; then
								for varName in $allTrfVars; do
									preVal=${preStatArr[0]}
									postVal=${postStatArr[0]}
									if isNumber preVal postVal; then
										compVal=$(($postVal-$preVal))
										preStatArr=("${preStatArr[@]:1}")
										postStatArr=("${postStatArr[@]:1}")
										if isDefined parseMode; then
											echo "$iface;$varName;$preVal;$postVal;$compVal"
										# else
										# 	echo -e "  $yl$iface$ec> $varName> Difference: $yl$compVal$ec"
										fi
									else
										except "  $yl$iface$ec> $varName> Illegal values :$rd$preVal, $postVal$ec "
									fi
								done
							else
								for vNum in 0 1 2 6 7 8; do
									preVal=${preStatArr[$vNum]}
									postVal=${postStatArr[$vNum]}
									if isNumber preVal postVal; then
										compVal=$(($postVal-$preVal))
										statPrintVar+="$compVal "
									fi
								done
								preStatArr=("${preStatArr[@]:11}")
								postStatArr=("${postStatArr[@]:11}")
							fi
						;;
						*) except "Illegal Vendor ID: $vendorID of iface: $iface."
					esac
				else
					except "Illegal Vendor ID: $vendorID of iface: $iface."
				fi
			else
				except "Not enough data for stat comparison in file: $statFileName"
			fi
		done
		if ! isDefined parseMode; then printIfaceStats $statPrintVar;fi
	fi
}

function printIfaceStats() {
	local clV iface rxCnt rxDrop rxErr txCnt txDrop txErr netCnt netIdx valIdx valArr sumErrDrop netData
	declare -A trfData
	shopt -s lastpipe
	let netCnt=0
	until [ -z "$1" ]; do
		privateVarAssign "${FUNCNAME[0]}" iface "$1"; shift
		privateNumAssign rxCnt "$1"; shift
		privateNumAssign rxDrop "$1"; shift
		privateNumAssign rxErr "$1"; shift
		privateNumAssign txCnt "$1"; shift
		privateNumAssign txDrop "$1"; shift
		privateNumAssign txErr "$1"; shift
		valArr=( $iface $rxCnt $rxDrop $rxErr $txCnt $txDrop $txErr )
		for ((valIdx=0; valIdx<=6; valIdx++)); do
			trfData[$netCnt,$valIdx]=${valArr[$valIdx]}
		done
		let netCnt++
	done

	echo -e "\n ╔═══════════════╦══════════════╦══════════════╦══════════════╦══════════════╦══════════════╦══════════════╗\n ║  Interface    ║    TX Qty    ║  TX Dropped  ║   TX Error   ║    RX Qty    ║  RX Dropped  ║   RX Error   ║"
	for ((netIdx=0; netIdx<$netCnt; netIdx++)); do
		netData=""
		for ((valIdx=0; valIdx<=6; valIdx++)); do
			netData+="${trfData[$netIdx,$valIdx]} "
		done
		let sumErrDrop=${trfData[$netIdx,2]}+${trfData[$netIdx,3]}+${trfData[$netIdx,5]}+${trfData[$netIdx,6]}
		if [ $sumErrDrop -eq 0 ]; then clV=$gr; else clV=$rd; fi
		printf " ╠═══════════════╬══════════════╬══════════════╬══════════════╬══════════════╬══════════════╬══════════════╣\n ║  $bl%-9s$ec    ║ $gr%12s$ec ║ $clV%12s$ec ║ $clV%12s$ec ║ $gr%12s$ec ║ $clV%12s$ec ║ $clV%12s$ec ║\n" $netData
	done
	echo -e " ╚═══════════════╩══════════════╩══════════════╩══════════════╩══════════════╩══════════════╩══════════════╝\n"
}

function startIfaceMonitor() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key value arg args iface iperfCfgArr servRunningPID ifaceArr pidsAlive pidArr pid stats
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			iface)
				if ifaceExist "$value"; then
					ifaceArr+=($value)
				else
					except "Illegal interface: $value"
				fi
			;;
			pid)
				if isDefined value; then
					pidArr+=($value)
				else
					except "null pid value"
				fi
			;;
			*) except "Unknown key: $key"
		esac
	done
	if ! isDefined {ifaceArr[*]}; then 
		except "Interface is undefined"
	else
		echo -ne "\n  Getting first stats update.."
		updateIfaceStats ${ifaceArr[*]} && echo -e "$gr done.$ec"
		echo -n "  Getting second stats update.."
		updateIfaceStats ${ifaceArr[*]} && echo -e "$gr done.$ec"
		printf '\e[A\e[K\e[A\e[K'
		let pidsAlive=-1
		echo -e "\n\n\n\n"
		for iface in ${ifaceArr[*]}; do echo -ne "\n\n"; done
		while true; do
			let pidsAlive=0
			for pid in ${pidArr[*]}; do
				if [ -d "/proc/$pid" ]; then let pidsAlive++; fi
			done
			if [[ $pidsAlive -eq 0 ]]; then break; fi
			local returnSym="$(printf '\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K')"
			for iface in ${ifaceArr[*]}; do returnSym+="$(printf '\e[A\e[K\e[A\e[K')"; done
			updateIfaceStats -update ${ifaceArr[*]}
			stats="$(compareIfaceStats ${ifaceArr[*]})"
			if ! [ "$controlSymbols" == "1" ]; then unset returnSym; fi
			echo -e "$returnSym$stats"
		done
	fi
}

function startIfaceDump() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key value arg args iface ifaceList srcIP packSize packQty ramdiskPath
	local pcapFile pcapPIDFile
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c2- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		if isDefined key; then
			case "$key" in
				src-IP)
					privateVarAssign "${FUNCNAME[0]}" "srcIP" "$value"
					verifyIp "${FUNCNAME[0]}" $srcIP
				;;
				pack-qty-per-port)
					privateNumAssign "packQty" "$value"
					if [ $packQty -le 0 ]; then
						except "Packet quantity should be greater than 0"
					fi
				;;
				pack-size)
					privateNumAssign "packSize" "$value"
					if [ $packSize -le 0 ]; then
						except "Packet size should be greater than 0"
					fi
				;;
				*) except "Unknown key: $key"
			esac
		else
			if ifaceExist "$arg"; then
				ifaceList+="$arg "
			else
				except "Non existent ethernet interface: $arg"
			fi
		fi
	done

	if isDefined ifaceList; then
		ramdiskPath="/root/tmpTrfStats/$(tr -d ' ' <<<"$ifaceList")"
		if ! isDefined packSize; then let packSize=1500; fi
		if ! isDefined packQty; then 
			let packQty=10000000
		else
			if [ $packQty -gt 0 ]; then
				let portCount=$(wc -w <<<$ifaceList)
				let byteReq=$(($packSize*$packQty))
				if [ $(($byteReq/1000000)) -lt 1 ]; then 
					let MBytesReq=1
				else
					let MBytesReq=$(($byteReq/1000000))
				fi
			else
				except "Packet quantity cant be lesser than 0"
			fi
		fi
		createRamdisk $MBytesReq "$ramdiskPath"

		checkIfacesExist $ifaceList
		dmsg echo -e "  Starting capture on ifaces: $org"$ifaceList"$ec"
		for iface in $ifaceList; do
			dmsg echo -e "   $org$iface$ec - processing.."
			pcapFile="/root/tmpTrfStats/${iface}_from_$srcIP.pcap"
			pcapPIDFile="/root/tmpTrfStats/${iface}_from_$srcIP.pid"
			if [ -e "$pcapPIDFile" ]; then
				except "PID file exists, cant start capture on it: $pcapPIDFile> PIDS: $(cat $pcapPIDFile)"
				break
			else
				tcpdump -i "$iface" "src $srcIP" -w "$pcapFile" &
				echo "$!" >> "$pcapPIDFile"
			fi
		done
		dmsg echo -e "  Done."
	else
		except "Ethernet interface list is empty"
	fi
	return 0
}

function initIperfSrvCfg() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local arg args key value srcIface trgIface srcIfacePort trgIfacePort i
	local srcSrvIP srcSrvBindIP srcSrvConnIP trgSrvIP trgSrvBindIP trgSrvConnIP srvArgs addArgs clientArgs
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			src-iface)
				if ifaceExist "$value"; then
					privateVarAssign "${FUNCNAME[0]}" "srcIface" "$value"
				else
					except "Illegal source interface: $value"
				fi
			;;
			trg-iface)
				if ifaceExist "$value"; then
					privateVarAssign "${FUNCNAME[0]}" "trgIface" "$value"
				else
					except "Illegal source interface: $value"
				fi
			;;
			run-once)
				addArgs+=("--one-off")
			;;
			log-path)
				createPathForFile "$value"
				addArgs+=("--logfile $value")
			;;
			*) except "Unknown key: $key"
		esac
	done
	if ! isDefined srcIface trgIface; then except "Source or target interface is undefined"; fi

	dmsg echo -e "  Initializing iperf3 server on interfaces: $yl$*$ec"
	bindIfacesToNAT $srcIface $trgIface
	echo -e "\n\n"
	privateNumAssign "srcIfacePort" "$(tr -d [:alpha:] <<<"$srcIface" |rev |cut -c1)$(printf "%d\n" 0x$(cut -d: -f5-6 <"/sys/class/net/$srcIface/address" |tr -d ':' |rev |cut -c1-3 |rev))"
	privateNumAssign "trgIfacePort" "$(tr -d [:alpha:] <<<"$trgIface" |rev |cut -c1)$(printf "%d\n" 0x$(cut -d: -f5-6 <"/sys/class/net/$trgIface/address" |tr -d ':' |rev |cut -c1-3 |rev))"
	privateVarAssign "${FUNCNAME[0]}" "srcSrvIP" "$(ifconfig $srcIface |grep -m1 '.*inet .*netmask .*' |awk '{print $2}')"
	privateVarAssign "${FUNCNAME[0]}" "srcSrvBindIP" "$(ip route list |grep -m1 "$trgIface"'.*src' |awk '{print $NF}')"
	privateVarAssign "${FUNCNAME[0]}" "srcSrvConnIP" "$(ip route list |grep -v 'src' |grep -m1 'dev '"$trgIface" |awk '{print $1}')"
	privateVarAssign "${FUNCNAME[0]}" "trgSrvIP" "$(ifconfig $trgIface |grep -m1 '.*inet .*netmask .*' |awk '{print $2}')"
	privateVarAssign "${FUNCNAME[0]}" "trgSrvBindIP" "$(ip route list |grep -m1 "$srcIface"'.*src' |awk '{print $NF}')"
	privateVarAssign "${FUNCNAME[0]}" "trgSrvConnIP" "$(ip route list |grep -v 'src' |grep -m1 'dev '"$srcIface" |awk '{print $1}')"


	if ! isFreePort $srcIfacePort; then
		echo -e "   Source interface $srcIface port is not free: $rd$srcIfacePort$ec.."
		if [ $srcIfacePort -lt 100 ]; then let srcIfacePort=$srcIfacePort+1000; fi
		if [ $srcIfacePort -gt 65000 ]; then let srcIfacePort=$srcIfacePort-1000; fi
		for (( i=1; i<=20; i++ )); do
			privateNumAssign "srcIfacePort" "${srcIfacePort%??}$(shuf -i 10-99 -n 1)"
			if ! [[ $srcIfacePort -ge 0 && $srcIfacePort -le 65535 ]]; then
				except "Invalid port number: $srcIfacePort"
			fi
			echo -e "   Trying different port: $yl$srcIfacePort$ec.."
			if isFreePort $srcIfacePort; then 
				echo -e "   Found open port: $gr$srcIfacePort$ec.."
				break
			else
				echo -e "   Port is in use: $rd$srcIfacePort$ec. Trying a different port..."
			fi
		done
		if ! isFreePort srcIfacePort; then
			except "Open port wasnt found for interface: $srcIface"
		fi
	fi

	if ! isFreePort $trgIfacePort; then
		echo -e "   Target interface $trgIface port is not free: $rd$trgIfacePort$ec.."
		if [ $trgIfacePort -lt 100 ]; then let trgIfacePort=$trgIfacePort+1000; fi
		if [ $trgIfacePort -gt 65000 ]; then let trgIfacePort=$trgIfacePort-1000; fi
		for (( i=1; i<=20; i++ )); do
			privateNumAssign "trgIfacePort" "${trgIfacePort%??}$(shuf -i 10-99 -n 1)"
			if ! [[ $trgIfacePort -ge 0 && $trgIfacePort -le 65535 ]]; then
				except "Invalid port number: $trgIfacePort"
			fi
			echo -e "   Trying different port: $yl$trgIfacePort$ec.."
			if isFreePort $trgIfacePort; then 
				echo -e "   Found open port: $gr$trgIfacePort$ec.."
				break
			else
				echo -e "   Port is in use: $rd$trgIfacePort$ec. Trying a different port..."
			fi
		done
		if ! isFreePort $trgIfacePort; then
			except "Open port wasnt found for interface: $trgIface"
		fi
	fi

	# echo -e "\n   Checking params...\n\n"
	# echo -e "  TX connection params ($yl$srcIface$ec -> $yl$trgIface$ec):"
	# echo -e "    Srv receiving iface bind ip    -> $gr$srcSrvIP$ec"
	# echo -e "    Cli transmitting iface bind ip -> $gr$srcSrvBindIP$ec"
	# echo -e "    Cli server iface connection ip -> $gr$srcSrvConnIP$ec"
	# echo -e "  RX connection params ($yl$trgIface$ec -> $yl$srcIface$ec):"
	# echo -e "    Srv receiving iface bind ip    -> $gr$trgSrvIP$ec"
	# echo -e "    Cli transmitting iface bind ip -> $gr$trgSrvBindIP$ec"
	# echo -e "    Cli server iface connection ip -> $gr$trgSrvConnIP$ec\n"
	
	echo -e "  Iperf3 server params on $yl$srcIface$ec"
	echo -e "    IP:   $gr$srcSrvIP$ec"
	echo -e "    Port: $gr$srcIfacePort$ec"
	echo -e "  Iperf3 client connection params on $yl$srcIface$ec"
	echo -e "    Bind IP: $gr$srcSrvBindIP$ec"
	echo -e "    Host IP: $gr$srcSrvConnIP$ec"
	echo -e "    Port:    $gr$srcIfacePort$ec\n"
	srvArgs=("-s" "-D" "-i 1" "-p $srcIfacePort" "-B $srcSrvIP")
	clientArgs=("-c $srcSrvConnIP" "-i 1" "-p $srcIfacePort" "-B $srcSrvBindIP")
	if isDefined addArgs; then srvArgs+=(${addArgs[@]}); fi
	sendToPipe "${srcIface}_iperf_cfg" "$srcSrvIP;$srcIfacePort;$srcSrvBindIP;$srcSrvConnIP;${srvArgs[@]};${clientArgs[@]}"
						# iperf_cfg    server IP; server port; client bind IP; client host IP; server IPerf args; client IPerf args
	echo -e "  Iperf3 server params on $yl$trgIface$ec"
	echo -e "    IP:   $gr$trgSrvIP$ec"
	echo -e "    Port: $gr$trgIfacePort$ec"
	echo -e "  Iperf3 client connection params on $yl$trgIface$ec"
	echo -e "    Bind IP: $gr$trgSrvBindIP$ec"
	echo -e "    Host IP: $gr$trgSrvConnIP$ec"
	echo -e "    Port:    $gr$trgIfacePort$ec"
	srvArgs=("-s" "-D" "-i 1" "-p $trgIfacePort" "-B $trgSrvIP")
	clientArgs=("-c $trgSrvConnIP" "-i 1" "-p $trgIfacePort" "-B $trgSrvBindIP")
	if isDefined addArgs; then srvArgs+=(${addArgs[@]}); fi
	sendToPipe "${trgIface}_iperf_cfg" "$trgSrvIP;$trgIfacePort;$trgSrvBindIP;$trgSrvConnIP;${srvArgs[@]};${clientArgs[@]}"
}		

function initIperfClientCfg() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local args key value clientArgs pktQty streamQty windowSize buffSize trgIface srcIface addArgs 
	local iperfCfgArr logPath
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			src-iface)
				if ifaceExist "$value"; then
					privateVarAssign "${FUNCNAME[0]}" "srcIface" "$value"
				else
					except "Illegal source interface: $value"
				fi
			;;
			trg-iface) 
				if ifaceExist "$value"; then
					privateVarAssign "${FUNCNAME[0]}" "trgIface" "$value"
				else
					except "Illegal source interface: $value"
				fi
			;;
			stream-qty)
				privateNumAssign "streamQty" "$value"
				if [ $streamQty -le 0 ]; then
					except "Stream quantity should be greater than 0"
				else
					addArgs+=("--parallel $streamQty")
				fi
			;;
			pkt-qty)
				privateNumAssign "pktQty" "$value"
				if [ $pktQty -le 0 ]; then
					except "Packet quantity should be greater than 0"
				else
					addArgs+=("-k $pktQty")
				fi
			;;
			window-size)
				privateNumAssign "windowSize" "$value"
				if [ $windowSize -le 0 ]; then
					except "Window size should be greater than 0"
				else
					addArgs+=("-w ${windowSize}K")
				fi
			;;
			buff-size)
				privateNumAssign "buffSize" "$value"
				if [ $buffSize -le 0 ]; then
					except "Buffer size should be greater than 0"
				else
					addArgs+=("-l ${buffSize}K")
				fi
			;;
			verbose)
				checkDefinedVal "${FUNCNAME[0]}" value
				addArgs+=("-V")
			;;
			*) except "Unknown key: $key"
		esac
	done
	if ! isDefined srcIface trgIface; then except "Source or target interface is undefined"; fi
	
	if ! isDefined streamQty; then privateNumAssign "streamQty" 1; addArgs+=("-P $streamQty"); fi
	if ! isDefined pktQty; then privateNumAssign "pktQty" 1000000; addArgs+=("-k $pktQty"); fi
	if ! isDefined windowSize; then privateNumAssign "windowSize" 64; addArgs+=("-w ${windowSize}K"); fi
	if ! isDefined buffSize; then privateNumAssign "buffSize" 128; addArgs+=("-l ${buffSize}K"); fi
	sendToPipe "${srcIface}_iperf_cli_log" "null"
	sendToPipe "${trgIface}_iperf_cli_log" "null"


	echo -e "\n  Iperf3 advanced client connection params on $yl$srcIface $trgIface$ec"
	echo -e "    Packet qty:  $gr$pktQty$ec"
	echo -e "    Stream qty:  $gr$streamQty$ec"
	echo -e "    Window size: $gr${windowSize}K$ec"
	echo -e "    Buffer size: $gr${buffSize}K$ec"
	# echo -e "    Log path:    $gr${srcIface}_iperf_cli_log$ec"
	# echo -e "    Log path:    $gr${trgIface}_iperf_cli_log$ec"

	IFS=';' read -ra iperfCfgArr <<<"$(cat ${srcIface}_iperf_cfg)"; unset IFS
	if [ -z "${iperfCfgArr[5]}" ]; then except "base cli cmd is empty in ${srcIface}_iperf_cfg"; fi
	IFS=' ' iperfCfgArr[5]="${iperfCfgArr[5]} ${addArgs[*]} --logfile ${srcIface}_iperf_cli_log"; unset IFS
	IFS=';'; sendToPipe "${srcIface}_iperf_cfg" "${iperfCfgArr[*]}"; unset IFS
	# iperf_cfg    server IP; server port; client bind IP; client host IP; server IPerf args; client IPerf args

	IFS=';' read -ra iperfCfgArr <<<"$(cat ${trgIface}_iperf_cfg)"; unset IFS
	if [ -z "${iperfCfgArr[5]}" ]; then except "base cli cmd is empty in ${trgIface}_iperf_cfg"; fi
	IFS=' ' iperfCfgArr[5]="${iperfCfgArr[5]} ${addArgs[*]} --logfile ${trgIface}_iperf_cli_log"; unset IFS
	IFS=';'; sendToPipe "${trgIface}_iperf_cfg" "${iperfCfgArr[*]}"; unset IFS
}

function startIperfSrv() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key value arg args iface iperfCfgArr servRunningPID ifaceArr
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			iface)
				if ifaceExist "$value"; then
					ifaceArr+=($value)
				else
					except "Illegal interface: $value"
				fi
			;;
			*) except "Unknown key: $key"
		esac
	done
	if ! isDefined {ifaceArr[*]}; then 
		except "Interface is undefined"
	else
		for iface in ${ifaceArr[*]}; do
			IFS=';' read -ra iperfCfgArr <<<"$(cat ${iface}_iperf_cfg)"; unset IFS
			if [ -z "${iperfCfgArr[5]}" ]; then except "base cli cmd is empty in ${iface}_iperf_cfg"; fi
			servRunningPID=$(top -bcn1 |grep -x ".* iperf3.*${iperfCfgArr[4]}.*" |grep -v grep |awk '{print $1}')
			if ! isDefined servRunningPID; then
				echo -e "\n  Starting IPerf3 server on $yl$iface$ec"
				dmsg echo -e "    Server run arguments: $bl${iperfCfgArr[4]}$ec"
				iperf3 ${iperfCfgArr[4]} #--pidfile ${iface}_iperf_srv_pid
				servRunningPID=$(top -bcn1 |grep -x ".* iperf3.*${iperfCfgArr[4]}.*" |grep -v grep |awk '{print $1}')
				if isDefined servRunningPID; then
					sendToPipe "${iface}_iperf_srv_pid" "$servRunningPID"
					echo -e "    Server PID: $yl$(cat ${iface}_iperf_srv_pid)$ec"
				else
					except "Failed to start iperf3 server"
				fi
			else
				echo -e "    Server aready running: PID-$yl$servRunningPID$ec"
			fi
		done
	fi
	return 0
}

function startIperfClient() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key value arg args iface iperfCfgArr clientRunningPID ifaceArr
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			iface)
				if ifaceExist "$value"; then
					ifaceArr+=($value)
				else
					except "Illegal interface: $value"
				fi
			;;
			*) except "Unknown key: $key"
		esac
	done
	if ! isDefined {ifaceArr[*]}; then 
		except "Interface is undefined"
	else
		for iface in ${ifaceArr[*]}; do
			IFS=';' read -ra iperfCfgArr <<<"$(cat ${iface}_iperf_cfg)"; unset IFS
			if [ -z "${iperfCfgArr[5]}" ]; then except "base cli cmd is empty in ${iface}_iperf_cfg"; fi
			echo -e "\n  Starting IPerf3 client on $yl$iface$ec"
			dmsg echo -e "    Client run arguments: $bl${iperfCfgArr[5]}$ec"
			dmsg echo -e "    Log file: $yl${iface}_iperf_cli_log$ec"
			echo >${iface}_iperf_cli_log
			nohup iperf3 ${iperfCfgArr[5]} > /dev/null 2>&1 & disown
			printf '\e[A\e[K'
			clientRunningPID=$(top -bcn1 |grep -x ".* iperf3.*${iperfCfgArr[5]}.*" |grep -v grep |awk '{print $1}')
			if isDefined clientRunningPID; then
				sendToPipe "${iface}_iperf_cli_pid" "$clientRunningPID"
				echo -e "    Client PID: $yl$(cat ${iface}_iperf_cli_pid)$ec"
			else
				echo -e "\t${rd}failed cmd: nohup iperf3 ${iperfCfgArr[5]}$ec"
				echo -e "\t${rd}clientRunningPID=$clientRunningPID$ec"
				echo -e "\t${rd}$(top -bcn1 |grep ".*iperf3.*")$ec"
				except "Failed to start iperf3 client"
			fi
		done
	fi
	return 0
}

function getIperfPidsByIface() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key value arg args iface ifaceArr pidArr pidN
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			iface)
				if ifaceExist "$value"; then
					ifaceArr+=($value)
				else
					except "Illegal interface: $value"
				fi
			;;
			*) except "Unknown key: $key"
		esac
	done

	for iface in ${ifaceArr[*]}; do
		for side in cli srv; do
			if [ -e "${iface}_iperf_${side}_pid" ]; then
				pidN=$(cat ${iface}_iperf_${side}_pid)
				if isDefined pidN; then
					pidArr+=($(cat ${iface}_iperf_${side}_pid))
				fi
			fi
		done
	done
	if isDefined pidArr; then echo -n "${pidArr[*]}"; fi
}

function testIperfTraffic() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local key value arg args iface ifaceArr ifacePairArr pidList pidArr ifaceArrKeys i streamQty pktQty
	privateVarAssign "${FUNCNAME[0]}" "args" "$*"

	for arg in ${args}
	do
		key=$(grep "^-.*" <<<"$arg" |cut -c3- |cut -f1 -d=)
		value=$(echo $arg |cut -f2 -d=)
		case "$key" in
			iface)
				if ifaceExist "$value"; then
					ifaceArr+=($value)
				else
					except "Illegal interface: $value"
				fi
			;;
			stream-qty)
				privateNumAssign "streamQty" "$value"
				if [ $streamQty -le 0 ]; then
					except "Stream quantity should be greater than 0"
				fi
			;;
			pkt-qty)
				privateNumAssign "pktQty" "$value"
				if [ $pktQty -le 0 ]; then
					except "Packet quantity should be greater than 0"
				fi
			;;
			*) except "Unknown key: $key"
		esac
	done


	if ! isDefined streamQty; then privateNumAssign "streamQty" 1; fi
	if ! isDefined pktQty; then privateNumAssign "pktQty" 500000; fi
	for ((i = 0; i < ${#ifaceArr[@]}; i += 2)); do
		if [ ! -z "${ifaceArr[i+1]}" ]; then 
			ifacePairArr+=( "--src-iface=${ifaceArr[i]} --trg-iface=${ifaceArr[i+1]}" )
		else
			except "No paired interface defined for ${ifaceArr[i]}"
		fi
	done

	#IFS='#' echo "ifacePairArr=${ifacePairArr[*]}  ifaceArr=${ifaceArr[*]}"
	for ((i = 0; i < ${#ifacePairArr[@]}; i += 1)); do
		echo -e "\n\n"
		dmsg echo -e "    Initializing pair: $yl${ifacePairArr[i]}$ec"
		initIperfSrvCfg ${ifacePairArr[i]} --run-once
		initIperfClientCfg ${ifacePairArr[i]} --pkt-qty=$pktQty --stream-qty=$streamQty
	done
	read -ra ifaceArrKeys <<<"$(printf -- "--iface=%s " "${ifaceArr[@]}")"
	#IFS='#' echo "ifaceArr=${ifaceArr[*]}"
	startIperfSrv ${ifaceArrKeys[*]}
	startIperfClient ${ifaceArrKeys[*]}
	local pidList=$(getIperfPidsByIface ${ifaceArrKeys[*]})
	read -ra pidArr <<<"$(printf -- "--pid=%s " $pidList )"
	#IFS='#' echo "pidArr=${pidArr[*]}"
	startIfaceMonitor ${ifaceArrKeys[*]} ${pidArr[*]}
	for iface in ${ifaceArr[@]}; do
		killPipeAndWriters $iface
	done
}

if (return 0 2>/dev/null) ; then
	let loadStatus=0
	echo -e '  Loaded module: \tTraffic generation lib for testing (support: arturd@silicom.co.il)'
	if ! [ "$(type -t makeLibSymlinks 2>&1)" == "function" ]; then 
		source /root/multiCard/arturLib.sh; let loadStatus+=$?
	fi
	if ! [ "$(type -t defineColors 2>&1)" == "function" ]; then 
		source /root/multiCard/graphicsLib.sh; let loadStatus+=$?
	fi
	if [[ ! "$loadStatus" = "0" ]]; then 
		echo -e "\t\e[0;31mLIBRARIES ARE NOT LOADED! UNABLE TO PROCEED\n\e[m"
		exit 1
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
fi