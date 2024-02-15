#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

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

function sendSerialCmdCordoba () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ttyN baud timeout cmd newArgs arg args noDollar verb ttyLock exitTrig nonverbalCmd cmdVerb

	if [ -z "$debugMode" ]; then verb=0; else verb=1; fi

	# extracting keys
	#for arg in "$@"
	for arg in $@
	do
		dmsg "processing arg: $arg"
		if ! [ "$(echo -n "$arg" |cut -c1-2)" == "--" ]; then 
			newArgs+=("$arg")
		else
			KEY=$(echo $arg|cut -c3- |cut -f1 -d=)
			VALUE=$(echo $arg |cut -f2 -d=)
			case "$KEY" in
				verbose) verb=1 ;;
				terminal) termMode="${VALUE}";;
				exit-trigger-keyw) 
					exitTrig=$(sed 's/__SPACESYMB__/\\\ /g'<<<"${VALUE}")
					nonverbalCmd=1
					dmsg inform "exitTrig=$exitTrig"
				;;
				*) dmsg echo "Unknown arg: $arg"
			esac
		fi
	done
	set -- "${newArgs[@]}"

	dmsg inform "newArgs: $@"
	dmsg pause

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
	if ! isDefined exitTrig; then exitTrig="nullexittrig"; fi

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
	if isDefined nonverbalCmd; then cmdVerb=0; else cmdVerb=1; fi

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
		*:~#* { expect *; send \"$cmd\n\" }
		*ogin:* { send \"$cmd\n\" }
		*word:* { send \"$cmd\n\" }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF2\n\"; send \x14q\r ; exit 1 }
	}
	log_user $cmdVerb
	sleep 0.3
	expect {
		$exitTrig { 
			send_user \"\nEXIT_TRIG_POST, trig: $exitTrig\n\"
			send $termExitSeq 
		}
		*:~#* { send $termExitSeq }
		*ogin:* { send $termExitSeq }
		*word:* { send $termExitSeq }
		timeout { send_user \"\nTimeout3\n\"; send \x03; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF3\n\"; exit 1 }
	}
	log_user $verb
	expect {
		$discMsg { send_user Done\n }
		timeout { send_user \"\nTimeout4\n\"; send \x03; exit 1 }
		eof { send_user \"\nEOF4\n\"; exit 1 }
	}
	"
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

function loginCordoba () {
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
		*ogin:* { send_user \"\nSending login: $login\n\"; send \"$login\r\" }
		*:~#* { send \x14q\r ; exit 1 }
		timeout { send_user \"\nTimeout2\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*word:* { send_user \"\nSending password: $pass\n\";send \"$pass\r\" }
		timeout { send_user \"\nTimeout3\n\"; send \x03; send \x14q\r ; exit 1 }
		eof { send_user \"\nEOF\n\"; send \x14q\r ; exit 1 }
	}
	expect {
		*:~#* { send \x14q\r }
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

function getIBSSerialState () {
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
		" 2>&1 |sed "s/\r//"
	)"
	dmsg inform "$serialCmdNlRes"
	serStateRes=$(echo "$serialCmdNlRes" |grep -w 'State:' |awk -F 'State:' '{print $2}' |cut -d ' ' -f2)
	if [[ -z "$serStateRes" ]]; then serStateRes=null; fi
	dmsg inform '>'"serStateRes=$serStateRes"'<'
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

function getCordobaSerialState () {
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
			*:~#* { send_user \"\n State: linux_shell\n\" }
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

function getCordobaBootMsg () {
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

	log_user 0
	expect {
		$conMsg { 
			send_user \"\r\n\r\nState: WAIT_FOR_SERIAL_INIT\r\n\";send \r 
			send \r 
		}
		timeout { send_user \"\nTimeout1\n\"; exit 1 }
		eof { send_user \"\nEOF1\n\"; exit 1 }
	}
	expect {
		*isSecurebootEnabled* { send_user \"State: SECURE_BOOT_MSG\r\n\" }
		timeout { send_user \"\nTimeout2\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF2\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Loading\ Usb\ Lens* { send_user \"State: USB_LOAD_MSG\r\n\" }
		timeout { send_user \"\nTimeout3\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF3\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Installing\ Usb\ Lens* { send_user \"State: USB_INSTALL_MSG\r\n\" }
		timeout { send_user \"\nTimeout4\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF4\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Mapping\ table* { send_user \"State: MAPPING_TABLE_MSG\r\n\" }
		timeout { send_user \"\nTimeout5\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF5\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Pci(0x1C* { send_user \"State: EFI_MMC_DETECT\r\n\"; exp_continue }
		*USB(0x6* { send_user \"State: EFI_USB_DETECT\r\n\"; exp_continue }
		*Locking\ SPI* { send_user \"State: EFI_DEVS_END\r\n\" }
		timeout { send_user \"\nTimeout6\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Mapping\ table* { send_user \"State: MAPPING_TABLE_MSG\r\n\" }
		timeout { send_user \"\nTimeout5\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF5\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Pci(0x1C,0x0)/Msg(29,00)/Ctrl(0x0)/HD(1C* { 
			send_user \"State: EFI_FS_MMC_DETECT\r\n\"
			exp_continue 
		}
		*USB(0x6,0x0)/HD(1* { 
			send_user \"State: EFI_FS_USB_DETECT\r\n\"
			exp_continue 
		}
		*Shell>* { }
		timeout { send_user \"\nTimeout6\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*Shell\\>\ \\%Boot* { send_user \"State: BOOT_OPTION_LOAD\r\n\" }
		*echo\ \\%BootOrder* { send_user \"State: BOOT_OPTION_LOAD\r\n\" }
		*0000\\]* { send_user \"State: NO_GRUB_LINUX_LOAD\r\n\" }
		timeout { send_user \"\nTimeout12\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*will\ be\ started\ automatically* { send_user \"State: GRUB_MENU\r\n\" }
		*0000\]* { send_user \"State: NO_GRUB_LINUX_LOAD\r\n\" }
		timeout { send_user \"\nTimeout13\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*SMBIOS* { send_user \"State: LINUX_BOOT_SCREEN\r\n\" }
		*ACPI:* { send_user \"State: LINUX_BOOT_SCREEN\r\n\" }
		*ogin:* { 
			send_user \"State: LINUX_LOGIN_PROMPT_NOLOAD\r\nPROMPT_OK1\"
			sleep 5
			send $termExitSeq
			expect {
				$discMsg { send_user \"\r\nDisconnected, ok\" ; exit 1 }
				timeout { send_user \"\nTimeout4\n\"; send $termExitSeq; exit 1 }
				eof { send_user \"\nEOF\n\";send $termExitSeq; exit 1 }
			}
		}
		timeout { send_user \"\nTimeout14\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*pci_bus\ 0000:00* { send_user \"State: LINUX_BOOT_PCI_INIT\r\n\" }
		timeout { send_user \"\nTimeout15\n\"; send $termExitSeq ; exit 1 }
		eof { send_user \"\nEOF\n\"; send $termExitSeq ; exit 1 }
	}
	expect {
		*mmc0* { send_user \"State: LINUX_BOOT_EMMC_INIT\r\n\"  }
		*Started\ OpenSSH* { send_user \"State: LINUX_BOOT_EMMC_NOT_FOUND\r\n\"  }
		*Stopped\ Plymouth* { send_user \"State: LINUX_BOOT_EMMC_NOT_FOUND\r\n\"  }
		*Starting\ Hostname* { send_user \"State: LINUX_BOOT_EMMC_NOT_FOUND\r\n\"  }
		timeout { send_user \"\nTimeout16\n\"; send $termExitSeq ; exit 1 }
		eof { 
			send_user \"EOF, reloading TIO\r\n\"
			spawn $termCmd
			send \r
			send_user \"State: LINUX_BOOT_EMMC_INIT_1\r\n\"
		}
	}
	set x 0
	expect {
		*login:* { send_user \"State: LINUX_LOGIN_PROMPT\r\nPROMPT_OK1\"; sleep 5; send $termExitSeq }
		timeout { send_user \"\nTimeout2\n\"; send $termExitSeq ; exit 1 }
		eof { 
			while {$x <= 10} {
				incr x
				spawn $termCmd
				expect {
					$conMsg {
						send_user \"State: WAIT_FOR_LINUX_LOGIN_PROMPT1.$attempt\r\n\";send \r
						send \r
						expect {
							timeout {
								send_user \"Timeout on reload after connection\r\n\"
								send $termExitSeq
								exit 1
								break
							}
							*login:* {
								send_user \"State: LINUX_LOGIN_PROMPT\r\nPROMPT_OK2.$attempt; sleep 5\"
								send $termExitSeq
								break
							}
							*isSecurebootEnabled* {
								send_user \"State: UNEXPECTED_RESET\r\n\"
								send $termExitSeq
								exit 1
								break
							}
						}
					}
					timeout {
						send_user \"Timeout on reload\r\n\"
						send $termExitSeq
						exit 1
						break
					}
					eof {
						send_user \"EOF8.$attempt, reloading TIO\r\n\"
						continue
					}
				}
			}
		}
	}
	expect {
		$discMsg { send_user \"\r\nDisconnected, ok\r\n\r\n\r\n\" ; exit 1 }
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

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tSerial port lib for testing (support: arturd@silicom.co.il)'
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
	if ! [ "$(type -t loginATT 2>&1)" == "function" ]; then 
		source /root/multiCard/devUtilLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mDEVICE UTLITY LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi