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
	echoFail
	test -z "$2" && procId=$PROC || procId=$2
	test -z "$procId" && echo -e "\texitFail exception, procId not specified"
	beepSpk fatal 3
	test -z "$guiMode" && echo -e "\t\e[1;41;33m$1\e[m\n" || msgBox "$1"
	echo -e "\n"
	sleep 1
	kill -9 $procId
	test "$exitExec" = "1" && {
		critWarn "\t Exit loop detected, exiting forced."
		killAllScripts
	}
	let exitExec=1
	exit 1
}

critWarn() {	#nnl = no new line
	test -z "$2" && echo -e "\e[0;47;31m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\e[0;47;31m$1\e[m" || echo -e "\e[0;47;31m$1\e[m"
	}
	beepSpk crit
}

warn() {	#nnl = no new line  #sil = silent mode
	test -z "$2" && echo -e "\e[0;33m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\e[0;33m$1\e[m" || echo -e "\e[0;33m$1\e[m"
	}
	test "$3"="sil" || beepSpk warn
}

inform() {	#nnl = no new line  #sil = silent mode
	test -z "$2" && echo -e "\e[0;33m$1\e[m" || {
		test "$2"="nnl" && echo -e -n "\e[0;33m$1\e[m" || echo -e "\e[0;33m$1\e[m"
	}
	test "$3"="sil" || beepSpk info
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
	test -z "$debugMode" || {
		local commandExec="$@" lineCount

		# echo -e -n "\n"
		inform "DEBUG> " nnl
		$commandExec |& tee /tmp/dbgCmdRes.log
		lineCount=$(cat /tmp/dbgCmdRes.log | wc -l)
		test $lineCount -gt 1 && {
			inform "DEBUG END> "
			rm -f /tmp/dbgCmdRes.log
		}
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
	test -z "$debugMode" && {
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
	}
}

execScript() {
	local scriptPath scriptArgs scriptExpect scriptTraceKeyw scriptFailDesc
	scriptPath="$1"
	scriptArgs="$2"
	scriptExpect="$3"
	scriptTraceKeyw="$4"
	scriptFailDesc="$5"
	
	cmdRes="$($scriptPath $scriptArgs 2>&1)"
	test -z "$(echo "$cmdRes" |grep -w "$scriptExpect")" && {
		warn "  $scriptFailDesc"
		test -z "$debugMode" || {
			inform "pwd=$(pwd)"
			echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
			echo -e "$(echo "$cmdRes" |grep -A 99 -w "$scriptTraceKeyw")"
			echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
			
			echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
			echo -e "$cmdRes"
			echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
		}
		return 1
	} || {
		test -z "$debugMode" || {
			echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
			echo -e "$cmdRes"
			echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
		}
		return 0
	}
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

drawPciSlot() {		
	local addEl excessSymb cutText color slotWidthInfo
	slotNum=$1
	shift
	test ! -z "$(echo $* |grep '\-\- Empty \-\-')" || {
		widthInfo=$1
		shift
		slotWidthInfo="  Width Cap: $widthInfo"
	}
	cutText=$(echo $* |cut -c1-56)
	let excessSymb=56-${#cutText}
	for ((e=0;e<=excessSymb;e++)); do addEl="$addEl "; done
	test "$cutText" = "-- Empty --" && color='\e[0;31m' || color='\e[0;32m'
	  
	echo -e "\n\t-------------------------------------------------------------------------"
	echo -e "\t░ Slot: $slotNum  ░  $color$cutText$addEl\e[m ░$slotWidthInfo"
	echo -e -n "\t-------------------------------------------------------------------------"
}

showPciSlots() {
	local slotBuses slotNum slotBusRoot
	echoSection "PCI Slots"
	slotBuses=$(dmidecode -t slot |grep Bus |cut -d: -f3)
	let slotNum=0
	for slotBus in $slotBuses; do
		let slotNum=$slotNum+1
		test "$slotBus" = "ff" && drawPciSlot $slotNum "-- Empty --" || {
			slotBusRoot=$(ls -l /sys/bus/pci/devices/ |grep -m1 :$slotBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
			test -z "$slotBusRoot" && drawPciSlot $slotNum "-- Empty --" || {
				gatherPciInfo $slotBusRoot
				dmsg debugPciVars
				drawPciSlot $slotNum $pciInfoDevCapWidth $(lspci -s $slotBus:)
			}
		}
	done
	echo -e "\n\n"
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
		checkRequiredFiles
	} || exitFail "Repetative sync requested. Seems that declared files requirments cant be met. Call for help"
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
			*) exitFail "  publicVarAssign exception, varSeverity not in range: $varSeverity" $PROC
		esac
	}
}

speedWidthComp() {
	local reqSpeed actSpeed reqWidth actWidth testSeverity compRule varAssigner
	#echo "speedWidthComp debug:  $1  =   $2  =   $3  =   $4"
	test -z "$debugMode" && varAssigner="privateVarAssign" || varAssigner="publicVarAssign"
	$varAssigner "speedWidthComp" "reqSpeed" "$1"
	$varAssigner "speedWidthComp" "actSpeed" "$2"
	$varAssigner "speedWidthComp" "reqWidth" "$3"
	$varAssigner "speedWidthComp" "actWidth" "$4"
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

testLinks() {
	local netTarg linkReq uutModel netId retryCount linkAcqRes
	privateVarAssign "testLinks" "netTarg" "$1"
	privateVarAssign "testLinks" "linkReq" "$2"
	privateVarAssign "testLinks" "uutModel" "$3"
	test ! -z "$4" && privateVarAssign "testLinks" "retryCount" "$4" || privateVarAssign "testLinks" "retryCount" "$globLnkAcqRetr"

	for ((r=0;r<=$retryCount;r++)); do 
		dmsg inform "try:$r"
		if [ -z "$linkAcqRes" -a "$linkReq" = "yes" ]; then
			test $r -gt 0 && sleep $globLnkUpDel
			case "$uutModel" in
				PE310G4BPI71-SR) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |grep yes);;
				PE310G2BPI71-SR) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |grep yes);;
				PE310G4DBIR) 
					netId=$(net2bus "$netTarg" |cut -d. -f2)
					test "$netId" = "0" && linkReq="no"
					linkAcqRes=$(rdifctl dev 0 get_port_link $netId |grep UP)
				;;
				PE210G2BPI9) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |grep yes);;
				PE325G2I71) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |grep yes);;
				PE31625G4I71L) linkAcqRes=$(ethtool $netTarg |grep Link |cut -d: -f2 |grep yes);;
				*) exitFail "testLinks exception, Unknown uutModel: $uutModel"
			esac
			dmsg inform $linkAcqRes
		else
			dmsg inform "skipped because not empty"
		fi
	done
	
	test -z "$linkAcqRes" && {
		test "$linkReq" = "yes" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m"
	} || {
		test "$netId" = "0" && echo -e -n "\e[0;32m-\e[m" || {
			test "$linkReq" = "no" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m"
		}
	}
}

getEthRates() {
	local netTarg speedReq uutModel linkAcqRes netId
	privateVarAssign "getEthRates" "netTarg" "$1"
	privateVarAssign "getEthRates" "speedReq" "$2"
	privateVarAssign "getEthRates" "uutModel" "$3"
	test ! -z "$4" && privateVarAssign "getEthRates" "retryCount" "$4" || privateVarAssign "getEthRates" "retryCount" "$globRtAcqRetr"
	
	for ((r=0;r<=$retryCount;r++)); do 
		dmsg inform "try:$r"
		if [ -z "$linkAcqRes" -a "$speedReq" != "Fail" ] || [ "$speedReq" != "Fail" -a -z "$(echo $linkAcqRes |grep $speedReq)" ]; then
			test $r -gt 0 && sleep 1
			case "$uutModel" in
				PE310G4BPI71-SR) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G2BPI71-SR) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE310G4DBIR) 
					netId=$(net2bus "$netTarg" |cut -d. -f2)
					test "$netId" = "0" && speedReq="Fail"
					linkAcqRes="Speed: $(rdifctl dev 0 get_port_speed $netId)Mb/s"
				;;
				PE210G2BPI9) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE325G2I71) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				PE31625G4I71L) linkAcqRes=$(ethtool $netTarg |grep Speed:);;
				*) exitFail "getEthRates exception, Unknown uutModel: $uutModel"
			esac
			dmsg inform $linkAcqRes
		else
			dmsg inform "linkAcqRes=$linkAcqRes"
			dmsg inform "skipped because not empty"
		fi
	done
	
	test ! -z "$linkAcqRes" && {
		test -z "$(echo $linkAcqRes |grep $speedReq)" && {
			echo -e -n "\e[0;31m$(echo $linkAcqRes |cut -d: -f2-)\e[m" 
		} || {
			test "$speedReq" = "Fail" && echo -e -n "\e[0;32m-\e[m" || echo -e -n "\e[0;32m$(echo $linkAcqRes |cut -d: -f2-)\e[m"
		}
	} || {
		echo -e -n "\e[0;31mNO DATA\e[m" 
	}
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

allNetAct() {
	local nets act actDesc net
	privateVarAssign "allNetAct" "nets" "$1"
	shift
	privateVarAssign "allNetAct" "actDesc" "$1"
	shift
	privateVarAssign "allNetAct" "act" "$1"
	shift
	privateVarAssign "allNetAct" "actArgs" "$@"
	#echo "DEBUG: nets:"$nets"  actDesc:"$actDesc"   act:"$act"   actArgs:"$actArgs
	echo -e -n "\t$actDesc: \n\t\t"; for net in $nets; do echo -e -n "$net:";$act "$net" $actArgs;echo -e -n "   "; done; echo -e -n "\n\n"
}

net2bus() {
	local net bus
	privateVarAssign "net2bus" "net" "$1"
	bus=$(grep PCI_SLOT_NAME /sys/class/net/*/device/uevent |grep "$net" |cut -d ':' -f3-)
	test -z "$bus" && exitFail "net2bus exception, bus returned nothing!" $PROC || echo -e -n "$bus"
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
	 echo $pciInfoDevDesc
	 echo $pciInfoDevSubs
	 echo $pciInfoDevLnkCap
	 echo $pciInfoDevLnkSta
	 echo $pciInfoDevSpeed
	 echo $pciInfoDevWidth
	 echo $pciInfoDevCapSpeed
	 echo $pciInfoDevCapWidth
	 echo $pciInfoDevKernMod
	 echo $pciInfoDevKernUse
	 echo $pciInfoDevSubInfo
	 echo $pciInfoDevSubdev
	 echo $pciInfoDevSubord
}

gatherPciInfo() {
	local pciInfoDev
	pciInfoDev="$1"
	dmsg inform "pciInfoDev=$pciInfoDev"
	test -z "$pciInfoDev" && exitFail "gatherPciInfo exception, pciInfoDev in undefined" $PROC
	clearPciVars
	if [[ ! "$pciInfoDev" == *":"* ]]; then 
		pciInfoDev="$pciInfoDev:"
		dmsg inform "pciInfoDev appended, : wasnt found"
	fi
	fullPciInfo="$(lspci -nnvvvks $pciInfoDev 2>&1)"
	pciInfoDevDesc=$(lspci -nns $pciInfoDev |cut -d ':' -f3- |cut -d ' ' -f1-9)
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
	local listPciArg argsTotal
	
	argsTotal=$*
	
	test -z "$argsTotal" && exitFail "listDevsPciLib exception, args undefined"
	
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
		
	}
	
	#devId=$pciDevId

	#pciDevs=$(grep PCI_ID /sys/bus/pci/devices/*/uevent | tr '[:lower:]' '[:upper:]' |grep :$devId |cut -d '/' -f6 |cut -d ':' -f2- |grep $targBus:)
	#test -z "$pciDevs" && {
	#	critWarn "No :$devId devices found on bus $targBus!"
	#	exit 1
	#}
	test -z "$targBus" && exitFail "listDevsPciLib exception, targBus is undefined"
	# slotBus root is now defined earlier
	# privateVarAssign "listDevsPciLib" "slotBus" $(ls -l /sys/bus/pci/devices/ |grep -m1 :$targBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')

	slotBus=$targBus
	dmsg inform "slotBus=$slotBus"
	
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
	
	test ! -z "$plxBuses" && {
		for bus in $plxBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -v $slotBus |grep -w $bus)
			test -z "$exist" || plxOnDevBus=$(echo $plxOnDevBus $bus)
		done
	}
	test ! -z "$accBuses" && {
		for bus in $accBuses ; do
			#exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -v $slotBus |grep -w $bus)

			test -z "$exist" || accOnDevBus=$(echo $accOnDevBus $bus)
		done
	}
	test ! -z "$spcBuses" && {
		for bus in $spcBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || spcOnDevBus=$(echo $spcOnDevBus $bus)
		done
	}
	test ! -z "$ethBuses" && {
		for bus in $ethBuses ; do
			#exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -v $slotBus |grep -w $bus)
			test -z "$exist" || ethOnDevBus=$(echo $ethOnDevBus $bus)
		done
	}
	test ! -z "$bpBuses" && {
		for bus in $bpBuses ; do
			exist=$(ls -l /sys/bus/pci/devices/ |grep $slotBus |awk -F/ '{print $NF}' |grep -w $bus)
			test -z "$exist" || bpOnDevBus=$(echo $bpOnDevBus $bus)
		done
	}
	
	
	dmsg inform "plxOnDevBus=$plxOnDevBus"
	test -z "$plxOnDevBus" && {
		dmsg inform "plxOnDevBus is empty\ndbg3: >$plxDevQtyReq$plxDevSubQtyReq$plxDevEmptyQtyReq$plxKern$plxDevId<"
		test -z "$plxDevQtyReq$plxDevSubQtyReq$plxDevEmptyQtyReq$plxKern$plxDevId" || critWarn "  PLX bus empty! PCI info on PLX failed!"
	} || {
		dmsg inform "plxOnDevBus is not empty\nPLX is not empty! there is: >$plxOnDevBus<"
		test -z "$plxDevQtyReq$plxDevSubQtyReq$plxDevEmptyQtyReq" && exitFail "listDevsPciLib exception, no quantities are defined on PLX!"
		test -z "$plxKern" && exitFail "listDevsPciLib exception, plxKern undefined!"
		test -z "$plxDevQtyReq" && exitFail "listDevsPciLib exception, plxDevQtyReq undefined, but devices found" || {
			test -z "$plxDevSpeed" && exitFail "listDevsPciLib exception, plxDevSpeed undefined!"
			test -z "$plxDevWidth" && exitFail "listDevsPciLib exception, plxDevWidth undefined!"
		}
		test ! -z "$plxDevSubQtyReq" && {
			test -z "$plxDevSubSpeed" && exitFail "listDevsPciLib exception, plxDevSubSpeed undefined!"
			test -z "$plxDevSubWidth" && exitFail "listDevsPciLib exception, plxDevSubWidth undefined!"
		}
		test ! -z "$plxDevEmptyQtyReq" && {
			test -z "$plxDevEmptySpeed" && exitFail "listDevsPciLib exception, plxDevEmptySpeed undefined!"
			test -z "$plxDevEmptyWidth" && exitFail "listDevsPciLib exception, plxDevEmptyWidth undefined!"
		}
		plxDevArr=""
		plxDevSubArr=""
		plxDevEmptyArr=""
		subdevInfo=""
		echo -e "\n\tPLX Devices" 
		echo -e "\t -------------------------"
		for plxBus in $plxOnDevBus ; do
			gatherPciInfo $plxBus
			#debugPciVars
			test -z "$plxKeyw" && exitFail "listDevsPciLib exception, plxKeyw undefined!"
			#warn "debug keyw:$plxKeyw fullPciInfo: $(echo "$fullPciInfo" |grep -w "$plxKeyw")"
			#warn "full PCI: $fullPciInfo"
			test ! -z "$(echo "$fullPciInfo" |grep -w "$plxKeyw")" && {
				#echo "DEBUG: $plxBus is physical device"
				plxDevArr="$plxBus $plxDevArr"
				echo -e "\t "'|'" $plxBus: PLX Physical Device: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $plxDevSpeed $pciInfoDevSpeed $plxDevWidth $pciInfoDevWidth)"
			} || {
				test -z "$plxVirtKeyw" && exitFail "listDevsPciLib exception, plxVirtKeyw undefined!"
				test ! -z "$(echo "$fullPciInfo" |grep -w "$plxVirtKeyw")" && {
					plxDevSubArr="$plxBus $plxDevSubArr"
					echo -e "\t "'|'" $plxBus: PLX Virtual Device: $pciInfoDevDesc"
					echo -e -n "\t "'|'" $(speedWidthComp $plxDevSubSpeed $pciInfoDevSpeed $plxDevSubWidth $pciInfoDevWidth)"
					#echo "DEBUG: $plxBus have subordinate"
				} || {
					plxDevEmptyArr="$plxBus $plxDevEmptyArr"
					echo -e "\t "'|'" $plxBus: PLX Virtual Device \e[0;33m(empty)\e[m: $pciInfoDevDesc"
					echo -e -n "\t "'|'" $(speedWidthComp $plxDevEmptySpeed $pciInfoDevSpeed $plxDevEmptyWidth $pciInfoDevWidth)"
					#echo "DEBUG: $plxBus is empty"
				}
			}
			echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse|grep $plxKern)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
			#echo -e "\t--------------"
		done
		echo -e "\t -------------------------"
		echo -e "\n\n\tPLX Device count" 
		testArrQty "  Physical" "$plxDevArr" "$plxDevQtyReq" "No PLX physical devices found on UUT" "warn"
		testArrQty "  Virtual" "$plxDevSubArr" "$plxDevSubQtyReq" "No PLX virtual devices found on UUT" "warn"
		testArrQty "  Virtual (empty)" "$plxDevEmptyArr" "$plxDevEmptyQtyReq" "No PLX virtual devices (empty) found on UUT" "warn"
		echo -e "\n"
	}
	
	dmsg inform "accOnDevBus=$accOnDevBus"
	test -z "$accOnDevBus" && { 
		test -z "$accKern$accDevQtyReq$accDevSpeed$accDevWidth" || critWarn "  ACC bus empty! PCI info on ACC failed!"
	} || {
		test -z "$accKern" && exitFail "listDevsPciLib exception, accKern undefined!"
		test -z "$accDevQtyReq" && exitFail "listDevsPciLib exception, accDevQtyReq undefined, but devices found" || {
			test -z "$accDevSpeed" && exitFail "listDevsPciLib exception, accDevSpeed undefined!"
			test -z "$accDevWidth" && exitFail "listDevsPciLib exception, accDevWidth undefined!"
		}
		accDevArr=""  
		subdevInfo=""
		echo -e "\n\tACC Devices" 
		echo -e "\t -------------------------"
		for accBus in $accOnDevBus ; do
			gatherPciInfo $accBus
			accDevArr="$accBus $accDevArr"
			echo -e "\t "'|'" $accBus: ACC Device: $pciInfoDevDesc"
			echo -e -n "\t "'|'" $(speedWidthComp $accDevSpeed $pciInfoDevSpeed $accDevWidth $pciInfoDevWidth)"
			echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $accKern)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
		done
		echo -e "\t -------------------------"
		echo -e "\n\n\tACC Device count" 
		testArrQty "  ACC Devices" "$accDevArr" "$accDevQty" "No ACC devices found on UUT" "warn"
		echo -e "\n"
	}
	
	dmsg inform "ethOnDevBus=$ethOnDevBus"
	test -z "$ethOnDevBus" && {
		test -z "$ethDevQtyReq$ethVirtDevQtyReq$ethKernReq$ethDevId" || critWarn "  ETH bus empty! PCI info on ETH failed!"
	} || {
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

		ethDevArr=""
		ethVirtDevArr=""
		echo -e "\n\tETH Devices" 
		echo -e "\t -------------------------"
		for ethBus in $ethOnDevBus ; do
			gatherPciInfo $ethBus
			test ! -z "$(echo "$fullPciInfo" |grep 'Capabilities' |grep -w 'Power Management')" && {
				#echo "DEBUG: $ethBus is physical device"
				ethDevArr="$ethBus $ethDevArr"
				echo -e "\t "'|'" $ethBus: ETH Physical Device: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $ethDevSpeed $pciInfoDevSpeed $ethDevWidth $pciInfoDevWidth)"
			} || {
				ethVirtDevArr="$ethBus $ethVirtDevArr"
				echo -e "\t "'|'" $ethBus: ETH Virtual Device: $pciInfoDevDesc"
				echo -e -n "\t "'|'" $(speedWidthComp $ethVirtDevSpeed $pciInfoDevSpeed $ethVirtDevWidth $pciInfoDevWidth)"
				#echo "DEBUG: $ethBus have subordinate"
			}
			echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse|grep $ethKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
			#echo -e "\t--------------"
		done
		echo -e "\t -------------------------"
		echo -e "\n\n\tETH Device count" 
		testArrQty "  Physical" "$ethDevArr" "$ethDevQtyReq" "No ETH physical devices found on UUT" "warn"
		testArrQty "  Virtual" "$ethVirtDevArr" "$ethVirtDevQtyReq" "No ETH virtual devices found on UUT" "warn"
		echo -e "\n"
	}
	
	dmsg inform "bpOnDevBus=$bpOnDevBus"
	test ! -z "$bpOnDevBus" && {
		test -z "$bpDevQtyReq" && exitFail "listDevsPciLib exception, no quantities are defined on BP!"
		test -z "$bpKernReq" && exitFail "listDevsPciLib exception, bpKernReq undefined!"
		test -z "$bpDevQtyReq" && exitFail "listDevsPciLib exception, bpDevQtyReq undefined, but devices found" || {
			test -z "$bpDevSpeed" && exitFail "listDevsPciLib exception, bpDevSpeed undefined!"
			test -z "$bpDevWidth" && exitFail "listDevsPciLib exception, bpDevWidth undefined!"
		}
		
		bpDevArr=""  
		echo -e "\n\tBP Devices" 
		echo -e "\t -------------------------"
		for bpBus in $bpOnDevBus ; do
			gatherPciInfo $bpBus
			bpDevArr="$bpBus $bpDevArr"
			echo -e "\t "'|'" $bpBus: BP Device: $pciInfoDevDesc"
			echo -e -n "\t "'|'" $(speedWidthComp $bpDevSpeed $pciInfoDevSpeed $bpDevWidth $pciInfoDevWidth)"
			echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $bpKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
		done
		echo -e "\t -------------------------"
		echo -e "\n\n\tBP Device count" 
		testArrQty "  BP Devices" "$bpDevArr" "$bpDevQtyReq" "No BP devices found on UUT" "warn"
		echo -e "\n"
	} || {
		test -z "$bpDevQtyReq$bpKernReq$bpDevSpeed$bpDevWidth$bpDevId" || critWarn "  BP bus empty! PCI info on BP failed!"
	}
	
	dmsg inform "spcOnDevBus=$spcOnDevBus"
	test -z "$spcOnDevBus" && {
		test -z "$spcDevQtyReq$spcKernReq$spcDevSpeed$spcDevWidth$spcDevId" || critWarn "  SPC bus empty! PCI info on SPC failed!"
	} || {
		test -z "$spcDevQtyReq" && exitFail "listDevsPciLib exception, no quantities are defined on SPC!"
		#test -z "$spcKernReq" && exitFail "listDevsPciLib exception, spcKernReq undefined!"
		test -z "$spcDevQtyReq" && exitFail "listDevsPciLib exception, spcDevQtyReq undefined, but devices found" || {
			test -z "$spcDevSpeed" && exitFail "listDevsPciLib exception, spcDevSpeed undefined!"
			test -z "$spcDevWidth" && exitFail "listDevsPciLib exception, spcDevWidth undefined!"
		}
		
		spcDevArr=""  
		echo -e "\n\tSPC Devices" 
		echo -e "\t -------------------------"
		for spcBus in $spcOnDevBus ; do
			gatherPciInfo $spcBus
			spcDevArr="$spcBus $spcDevArr"
			echo -e "\t "'|'" $spcBus: SPC Device: $pciInfoDevDesc"
			echo -e -n "\t "'|'" $(speedWidthComp $spcDevSpeed $pciInfoDevSpeed $spcDevWidth $pciInfoDevWidth)\n\t "'|------'"\n"
			#echo -e -n "\t$(test ! -z "$(echo $pciInfoDevKernUse $pciInfoDevKernMod|grep $spcKernReq)" && echo -n "KERN: \e[0;32mOK\e[m " || echo -n "KERN: \e[0;31mFAIL!\e[m ")$pciInfoDevSubInfo\n\t "'|'"\n"
		done
		#echo -e "\t -------------------------"
		echo -e "\n\n\tSPC Device count" 
		testArrQty "  SPC Devices" "$spcDevArr" "$spcDevQtyReq" "No SPC devices found on UUT" "warn"
		echo -e "\n"
	}
}

qtyComp() {
	local reqQty actQty qtySeverity
	reqQty=$1
	actQty=$2
	qtySeverity=$3 #empty=exit with fail  warn=just warn
	test "$reqQty" = "$actQty" && {
		echo -e -n "\tQty: \e[0;32mOK\e[m"
	} || {
		test "$qtySeverity" = "warn" && warn "\tQty: FAIL (expected: $reqQty)" || exitFail "\tQty: FAIL (expected: $reqQty)" $PROC
	}
}

testArrQty() {
	local testDesc errDesc testArr exptQty testSeverity
	privateVarAssign "testArrQty" "testDesc" "$1"
	privateVarAssign "testArrQty" "testArr" "$2"
	privateVarAssign "testArrQty" "exptQty" "$3"
	privateVarAssign "testArrQty" "errDesc" "$4"
	testSeverity=$5 #empty=exit with fail  warn=just warn
	dmsg inform 'testArrQty: >testArr='"$testArr"'< >exptQty='"$exptQty<"
	test -z "$exptQty" || {
		test ! -z "$testArr" && {  
			echo -e "\t$testDesc: "$testArr" $(qtyComp $exptQty $(echo -e -n "$testArr"| tr " " "\n" | grep -c '^') $testSeverity)"
		} || exitFail "\t$errDesc!"	$PROC
	}
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
	test "$1" = "status" && {
		privateVarAssign "qatAction" "qatAct" "$1"
	} || {
		privateVarAssign "qatAction" "qatDev" "$1"
		privateVarAssign "qatAction" "qatAct" "$2"
	}

	
	
	qat_service $qatAct $qatDev
}

qatTest() {
	local execPath busNum forceBgaNum qatDevCut cpaRes cpaTrace kmodExist qatRes forceQat
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
	allQatDevs="$(qatAction status 2>&1)"
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
			#echo "debug: processing dev: qat_dev$qatDevCut"
			echo -e "\tStopping QAT device - qat_dev$qatDevCut"
			qatRes="$(qatAction qat_dev$qatDevCut Stop 2>&1)"
			echo -e "\tRestarting QAT device - qat_dev$qatDevCut"
			test "$forceQat" = "qat_dev$qatDevCut" && qatRes="$(qatAction qat_dev$qatDevCut Restart 0x0 2>&1)" || {
				test -z "$forceQat" && qatRes="$(qatAction qat_dev$qatDevCut Restart 0x0 2>&1)" || warn "\tItercepted - QAT device qat_dev$qatDevCut is excluded."
			}
			qatRes="$(qatAction status 2>&1)"
			test "$(echo "$qatRes" |grep qat_dev$qatDevCut |cut -d ' ' -f21)" = "up" && echo -e "\tQAT dev - qat_dev$qatDevCut:\e[0;32m up\e[m" || {
				test "$forceQat" = "qat_dev$qatDevCut" && exitFail "\tQAT dev - qat_dev$qatDevCut: DOWN (could not be initialized)" || {
					test -z "$forceQat" && critWarn "\tQAT dev - qat_dev$qatDevCut: DOWN" || warn "\tQAT dev - qat_dev$qatDevCut: DOWN (excluded)"
				}
			}
		done

		echo  -e "\n\tStarting acceleration test:"

		cd $CODE_PATH

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
			qatRes="$(qatAction qat_dev$qatDevCut Stop 2>&1)"
		done
		#echo "DEBUG: $cpaTrace"
		killAllScripts "cpa_sample_code"
		#echo "DEBUG stats=$stats"
		test -z "echo $stats |grep 0" && exitFail "QAT test failed!"
		exit $?
}

echoIfExists() {
	test -z "$2" || echo "$1 $2"
}

echo -e '  Loaded module: \tLib for testing (support: arturd@silicom.co.il)'