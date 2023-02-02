#!/bin/bash

declareVars() {
	ver="v0.01"
	toolName='IS Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	let exitExec=0
	let debugBrackets=0
	let debugShowAssignations=0
	trafficGenIP=172.30.6.194
}

parseArgs() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			uut-pn) pnArg=${VALUE} ;;
			uut-tn) tnArg=${VALUE} ;;
			uut-rev) revArg=${VALUE} ;;
			test-sel) 
				inform "Launch key: Selected test: ${VALUE}"
				testSelArg=${VALUE}
			;;
			silent) 
				silentMode=1 
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			debug) 
				debugMode=1 
				inform "Launch key: Debug mode"
			;;
			debug-show-assign) 
				let debugShowAssignations=1
				debugMode=1 
				inform "Launch key: Debug mode, visible assignations"
			;;
			dbg-brk) 
				debugBrackets=1
				inform "Launch key: Debug mode arg: no debug brackets"
			;;
			help) showHelp ;;
			*) echo "Unknown arg: $ARG"; showHelp
		esac
	done
}

showHelp() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	warn "\n=================================" "" "sil"
	echo -e "$toolName"
	echo -e " Arguments:"
	echo -e "\tShow help message\n"	
	echo -e " --help"
	echo -e "\tProduct name of UUT\n"
	echo -e " --uut-pn=NUMBER"	
	echo -e "\tTracking number of UUT\n"
	echo -e " --uut-tn=NUMBER"	
	echo -e "\tRevision of UUT\n"
	echo -e " --uut-rev=NUMBER"	
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --silent"
	echo -e "\tDebug mode"	
	echo -e " --debug"
	echo -e "\tDebug brackets"	
	echo -e " --dbg-brk	"
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	echo -e " Setting defaults.."
	publicVarAssign warn globRtAcqRetr "7"
	echo -e " Done.\n"
}

sshCheckServer() {
	echo "  Checking server: $trafficGenIP"
	verifyIp "${FUNCNAME[0]}" $trafficGenIP 
	sshWaitForPing 3 $trafficGenIP
	if [ $? -eq 1 ]; then
		except "  Server check failed, host $trafficGenIP is \e[0;31mDOWN\e[m"
	fi
}

startupInit() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local drvInstallRes
	echo -e " StartupInit.."
	test "$skipInit" = "1" || {
		echo "  Searching $baseModel init sequence.."
		case "$baseModel" in
			IS100G-Q-RU) sshCheckServer;;
			IS401U-RU) sshCheckServer;;
			*) except "unknown baseModel: $baseModel"
		esac
	}
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		# "/root/PE310G4BPI71/library.sh"
		"/root/multiCard/arturLib.sh"
		"/root/multiCard/graphicsLib.sh"
	)
	
	case "$baseModel" in
		IS100G-Q-RU) 
			echo "  File list: PE310G4BPI71"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/multiCard/arturLib.sh"	
			)				
		;;
		IS401U-RU) 
			echo "  File list: PE310G4BPI71"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/multiCard/arturLib.sh"	
			)				
		;;
		*) except "unknown baseModel: $baseModel"
	esac

	test ! -z "$(echo ${filesArr[@]})" && {
		for filePath in "${filesArr[@]}";
		do
			testFileExist "$filePath" "true"
			test "$?" = "1" && {
				echo -e "  \e[0;31mfail.\e[m"
				echo -e "  \e[0;33mPath: $filePath does not exist! Starting sync.\e[m"
				syncFilesFromServ "$syncPn" "$baseModel"
			} || echo -e "  \e[0;32mok.\e[m"
		done
	}
	echo -e " Done."
}

defineRequirments() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local ethToRemove secBusAddr secBusArg
	echo -e "\n Defining requirements.."
	test -z "$uutPn" && except "requirements cant be defined, empty uutPn"
	if [[ ! -z $(echo -n $uutPn |grep "IS100G-Q-RU\|IS401U-RU") ]]; then
		dmsg inform "DEBUG1: ${pciArgs[@]}"

		test ! -z $(echo -n $uutPn |grep "IS100G-Q-RU") && {
			baseModel="IS100G-Q-RU"
			uutBdsUser="is_admin"
			uutBdsPass="Silicom2015"
			uutRootUser="debug shell"
			uutRootPass="She11#local"
			uutBaudRate=115200

			isUbootVer="IS100_UBOOT_1.0_2015_09_29"
			isSwVer="IS100_1.0.3.9_BUILD_8289"
			isFwVer="IS100G_FW_18.0"
			isDevType="IS100G"
		}

		test ! -z $(echo -n $uutPn |grep "IS401U-RU") && {
			baseModel="IS401U-RU"
			uutBdsUser="badas"
			uutBdsPass="vlg38Ag7"
			uutRootUser="root"
			uutRootPass="Prb71GP2"
			uutBaudRate=115200

			isUbootVer="2011.12-sl:00.01"
			isSwVer="0.2.2.0"
			isFwVer="22.2.0.40"
			isDevType="3.0.34-sl"
		}

		echoIfExists "  Base model:" "$baseModel"
	else
		except "$uutPn cannot be processed, requirements not defined"
	fi
	
	echo -e "  Done."
	
	echo -e " Done.\n"
}

40gSendTraffic() { 
	local jenaExecName packetAmnt portMask sshCommand testResVar
	privateVarAssign "${FUNCNAME[0]}" "packetAmnt" "$1"

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	sshCommand="cd /root/PE340G2BPI71;bpctl_start; bpctl_util all set_bypass off;./anagenohuptask1.sh 0x4 01 $packetAmnt 0x0 2 1 6"
	testResVar="$(ssh -oStrictHostKeyChecking=no root@$trafficGenIP "$pathAdd; $sshCommand" 2>&1)"
	if [[ -z "$(echo "$testResVar" |grep "configurecard failed")" ]]; then
		if [[ -z "$(echo "$testResVar" |grep lost |grep rx |awk '{print $3}' |grep -v -w 0)" ]]; then
			echo -e "\e[0;32mPassed: "$(echo "$testResVar" |grep packets |grep rx |awk '{print $3" "$4" "}')"  \e[0;32mLost: "$(echo "$testResVar" |grep lost  |grep rx |awk '{print $3" "$4" "}')"\e[m"
		else
			echo -e "\e[0;32mPassed: "$(echo "$testResVar" |grep packets |grep rx |awk '{print $3" "$4" "}')"  \e[0;31mLost: "$(echo "$testResVar" |grep lost  |grep rx |awk '{print $3" "$4" "}')" FAILED\e[m"
		fi
	else
		echo -e "\n\n\n\e[0;31m\tTRAFFIC GENERATOR FPGA CONFIGURATION FAILED!\e[m"
		echo -e "\e[0;31m\t\tUNABLE TO SEND TRAFFIC,\e[m"
		echo -e "\e[0;31m\t\tEXITING.\e[m\n\n\n"
		exit
	fi
}

is100sshSendTraffic() { 
	local jenaExecName packetAmnt portMask sshCommand testResVar
	privateVarAssign "${FUNCNAME[0]}" "jenaExecName" "$1"
	privateVarAssign "${FUNCNAME[0]}" "packetAmnt" "$2"
	privateVarAssign "${FUNCNAME[0]}" "portMask" "$3"

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	
	sshCommand="sw 100; stdbuf -oL -eL $jenaExecName $packetAmnt 60 $portMask 1500 silent dealloc"
	testResVar=$(ssh -oStrictHostKeyChecking=no root@$trafficGenIP "$pathAdd; $sshCommand" |& tail -n 1)
	test -z "$(echo $testResVar |grep "configurecard failed")" && {
		echo "$testResVar"
	} || {
		echo -e "\n\n\n\e[0;31m\tTRAFFIC GENERATOR FPGA CONFIGURATION FAILED!\e[m"
		echo -e "\e[0;31m\t\tUNABLE TO SEND TRAFFIC,\e[m"
		echo -e "\e[0;31m\t\tEXITING.\e[m\n\n\n"
		exit
	}
}


is100sshSendTrafficAndPoweroff() { 
	local jenaExecName packetAmnt portMask sshCommand testResVar fullResult

	pathAdd='export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/sbin:/root/bin'
	
	sshCommand="sw 100; cd IS100; ./jenagen1_1k 100000000"

	echo -e -n "\tSending delayed PAS BP command on both modules, switching to bypass: "
	delayedCmd='ash -c \"sleep 15 ; sudo is_cpld_ctrl segment_passive_mode_set seg_id=1.0 op_mode=2; sudo is_cpld_ctrl segment_passive_mode_set seg_id=0.0 op_mode=2\" &'
	cmdRes=$(sendRootIS100 $uutSerDev "$delayedCmd")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	echo -e -n "\tSending traffic and switching modules to Passive BP: "
	fullResult=$(ssh -oStrictHostKeyChecking=no root@$trafficGenIP "$pathAdd; $sshCommand" 2>&1)
	testResVar=$(echo "$fullResult" |& tail -n 1)
	test -z "$(echo $testResVar |grep "configurecard failed")" && {
		echo "$testResVar"
		if [[ ! -z "$(echo $testResVar |grep Failed)" ]]; then
			echo "$fullResult"
		fi
	} || {
		echo -e "\n\n\n\e[0;31m\tTRAFFIC GENERATOR FPGA CONFIGURATION FAILED!\e[m"
		echo -e "\e[0;31m\t\tUNABLE TO SEND TRAFFIC,\e[m"
		echo -e "\e[0;31m\t\tEXITING.\e[m\n\n\n"
		exit
	}
}

is40CheckLinkState() {
	local targMod targNet reqState cmdRes
	privateNumAssign "targMod" "$1"
	privateNumAssign "targNet" "$2"
	privateVarAssign "${FUNCNAME[0]}" "reqState" "$3"

	echo -e -n "\tChecking that link on Module $targMod Net $targNet is $reqState: "
	cmdRes=$(sendIS40 $uutSerDev "get_link NET$targNet")
	if [[ ! -z "$(echo "$cmdRes" |grep "link $reqState")" ]]; then echo -e "\e[0;32mOK, $reqState\e[m"; else echo -e "\e[0;31mFAILED, not $reqState\e[m"; fi
}

is40CheckAllLinkState() {
	local reqState
	privateVarAssign "${FUNCNAME[0]}" "reqState" "$1"
	is40CheckLinkState $modSelect 0 $reqState
	is40CheckLinkState $modSelect 1 $reqState
}

is100CheckLinkState() {
	local targMod targNet reqState actState cmdRes
	privateNumAssign "targMod" "$1"
	privateNumAssign "targNet" "$2"
	privateVarAssign "${FUNCNAME[0]}" "reqState" "$3"

	echo -e -n "\tChecking that link on Module $targMod Net $targNet is $reqState: "
	cmdRes=$(sendIS100 $uutSerDev "show bypass state")
	cmdRes=$(echo "$cmdRes" |grep -A38 "Module $targMod Status")
	actState=$(echo "$cmdRes" |grep "PortNet"$targNet"Link" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g')
	if [[ "$reqState" == "$actState" ]]; then echo -e "\e[0;32mOK\e[m ($actState)"; else echo -e "\e[0;31mFAILED\e[m ($actState)"; fi
}

is100CheckAllLinkState() {
	local reqState
	privateVarAssign "${FUNCNAME[0]}" "reqState" "$1"
	is100CheckLinkState 1 0 $reqState
	is100CheckLinkState 1 1 $reqState
	is100CheckLinkState 2 0 $reqState
	is100CheckLinkState 2 1 $reqState
}


is40printBPState(){
	local mod1Info mod2Info mod1ActSt mod1PasSt mod1HBSt cmdRes cmdRes2 cmdRes3 hbc vbc 
	cmdRes=$(sendIS40 $uutSerDev "get_bypass_mode" |grep -m1 "Active")
	cmdRes2=$(sendIS40 $uutSerDev "bssf get_state" |grep -m1 "Passive")
	cmdRes3=$(sendIS40 $uutSerDev "get_hb_act_mode" |grep -m1 "HB")
	mod1ActSt=$(echo "$cmdRes" |cut -d: -f2 |cut -d. -f1 |sed 's/[^a-zA-Z0-9]//g')
	mod1PasSt=$(echo "$cmdRes2" |cut -d: -f2 |cut -d. -f1 |sed 's/[^a-zA-Z0-9]//g')
	mod1HBSt=$(echo "$cmdRes3" |cut -d: -f2 |cut -d. -f1 |sed 's/[^a-zA-Z0-9]//g')
	if [[ "$mod1ActSt" == "inline" ]]; then vbc=2m; else vbc=3m; fi
	if [[ "$mod1PasSt" == "inline" ]]; then pbc=2m; else pbc=3m; fi
	if [[ "$mod1HBSt" == "on" ]]; then hbc=2m; else hbc=3m; fi

	echo -ne "\t==============================================\n"
	echo -ne "\t== Module $modSelect\n"
	echo -ne "\t==           HB: \e[0;3$hbc$mod1HBSt\e[m\n"
	echo -ne "\t==   Virtual BP: \e[0;3$vbc$mod1ActSt\e[m\n"
	echo -ne "\t==  Physical BP: \e[0;3$pbc$mod1PasSt\e[m\n"
	echo -ne "\t==============================================\n"
}

is100printBPState(){
	local mod1Info mod2Info mod1ActSt mod1PasSt mod2ActSt mod2PasSt
	mod1Info=$(sendIS100 $uutSerDev "show bypass state")
	mod1Info=$(echo "$mod1Info" |grep -A38 "Module 1 Status")
	mod1ActSt=$(echo "$mod1Info" |grep "ActiveState" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g')
	mod1PasSt=$(echo "$mod1Info" |grep "PassiveState" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g')

	mod2Info=$(sendIS100 $uutSerDev "show bypass state")
	mod2Info=$(echo "$mod2Info" |grep -A38 "Module 2 Status")
	mod2ActSt=$(echo "$mod2Info" |grep "ActiveState" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g')
	mod2PasSt=$(echo "$mod2Info" |grep "PassiveState" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g')

	echo -ne "\t==============================================\n"
	echo -ne "\t== Module 1\n"
	echo -ne "\t==  Virtual BP: $mod1ActSt    Physical BP: $mod1PasSt\n"
	echo -ne "\t==== \n"
	echo -ne "\t== Module 2\n"
	echo -ne "\t==  Virtual BP: $mod2ActSt    Physical BP: $mod2PasSt\n"
	echo -ne "\t==============================================\n"
}

is100HardReset() {
	local cmdArg
	echo -e -n "\tSending hard reset to the box: "
	cmdArg='sudo ash -c \"echo b > \/proc\/sysrq-trigger\"'
	cmdRes=$(sendRootIS100 $uutSerDev $cmdArg)
	if [ $? -eq 1 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
}

is40GetStat(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targSeg cmdRes

	echo -e -n "\tClearing statistics: "
	cmdRes=$(sendIS40 $uutSerDev "get_stat")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
}

is40ClearStat(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targSeg cmdRes

	echo -e -n "\tClearing statistics: "
	cmdRes=$(sendIS40 $uutSerDev "clear_stat")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
}


is40SetBP(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targSeg cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"
	privateVarAssign "${FUNCNAME[0]}" "targSeg" "$3"

	echo -e -n "\tSetting ACT BP mode on Module $targMod to $targBPState: "
	cmdRes=$(sendIS40 $uutSerDev "set_bypass_mode $targBPState")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	is40GetBP $targBPState $targMod
}

is100SetBP(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"

	echo -e -n "\tSetting ACT BP mode on Module $targMod to $targBPState: "
	cmdRes=$(sendIS100 $uutSerDev "bypass segment $targMod.1 active-op-mode $targBPState")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	is100GetBP $targBPState $targMod
}

is40GetBP(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"

	echo -e -n "\tChecking that BP mode on Module $targMod is $targBPState: "
	cmdRes=$(sendIS40 $uutSerDev "get_bypass_mode")
	if [[ ! -z "$(echo "$cmdRes" |grep "$targBPState")" ]]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
}

is100GetBP(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"

	echo -e -n "\tGetting BP mode on Module $targMod: "
	cmdRes=$(sendIS100 $uutSerDev "show bypass state")
	cmdRes=$(echo "$cmdRes" |grep -A38 "Module $targMod Status")
	echo $(echo ACT:$(echo "$cmdRes" |grep "ActiveState" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g') PAS:$(echo "$cmdRes" |grep "PassiveState" |cut -d: -f2| sed 's/[^a-zA-Z0-9]//g'))

}

is40SetPasBP() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targSeg cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"
	privateVarAssign "${FUNCNAME[0]}" "targSeg" "$3"

	if [ "$targBPState" == "bypass" ]; then targBPStateArg="on"; else targBPStateArg="off"; fi

	echo -e -n "\tSetting active module to $targMod: "
	cmdRes=$(sendIS40 $uutSerDev "set_seg $targMod $targSeg")
	cmdRes=$(sendIS40 $uutSerDev "get_seg")
	if [[ ! -z "$(echo "$cmdRes" |grep "$targMod:$targSeg.")" ]]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	echo -e -n "\tSetting PAS BP mode on Module $targMod to $targBPState: "
	cmdRes=$(sendIS40 $uutSerDev "set_pas_bypass $targBPStateArg")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	is40BSSFgetBP $targBPState $targMod $targSeg
}

is40BSSFsetBP() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targSeg cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"
	privateVarAssign "${FUNCNAME[0]}" "targSeg" "$3"

	if [ "$targBPState" == "bypass" ]; then targBPStateArg="set_bypass"; else targBPStateArg="set_normal"; fi

	echo -e -n "\tSetting active module to $targMod: "
	cmdRes=$(sendIS40 $uutSerDev "set_seg $targMod $targSeg")
	cmdRes=$(sendIS40 $uutSerDev "get_seg")
	if [[ ! -z "$(echo "$cmdRes" |grep "$targMod:$targSeg.")" ]]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	echo -e -n "\tSetting PAS BP (BSSF) mode on Module $targMod to $targBPState: "
	cmdRes=$(sendIS40 $uutSerDev "bssf $targBPStateArg")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	is40BSSFgetBP $targBPState $targMod $targSeg
}

is100CPLDsetBP() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targModArg cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"

	if [ "$targBPState" == "bypass" ]; then targBPStateArg="2"; else targBPStateArg="1"; fi
	if [ "$targMod" == "1" ]; then targModArg="0"; else targModArg="1"; fi

	echo -e -n "\tSetting PAS BP mode on Module $targMod to $targBPState: "
	cmdRes=$(sendRootIS100 $uutSerDev "sudo is_cpld_ctrl segment_passive_mode_set seg_id=$targModArg.0 op_mode=$targBPStateArg")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

	isCPLDgetBP $targBPState $targMod
	is100GetBP $targBPState $targMod
}

is40BSSFgetBP() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targSeg targModArg cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateNumAssign "targMod" "$2"
	privateNumAssign "targSeg" "$3"
	
	echo -e -n "\tChecking BP mode on Module $targMod is $targBPState: "
	cmdRes=$(sendIS40 $uutSerDev "bssf get_state")
	cmdRes=$(echo "$cmdRes" |grep $targBPState)
	if [ ! -z "$cmdRes" ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
}

isCPLDgetBP() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targBPState targBPStateArg targMod targModArg cmdRes
	privateVarAssign "${FUNCNAME[0]}" "targBPState" "$1"
	privateNumAssign "targMod" "$2"

	if [ "$targBPState" == "bypass" ]; then targBPStateArg="2"; else targBPStateArg="1"; fi
	let targModArg=$targMod-1

	echo -e -n "\tChecking BP mode on Module $targMod is $targBPState: "
	cmdRes=$(sendRootIS100 $uutSerDev "sudo is_cpld_ctrl segment_passive_mode_get seg_id=$targModArg.0")
	cmdRes=$(echo "$cmdRes" |grep 0x$targBPStateArg)
	if [ ! -z "$cmdRes" ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
}

is40SwitchHB() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targHBState targMod
	privateVarAssign "${FUNCNAME[0]}" "targHBState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"

	echo -e -n "\tSetting HB mode on Module $targMod, Segment $targSeg to $targHBState: "
	sendIS40 $uutSerDev "set_hb_act_mode $targHBState" 2>&1 > /dev/null
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

}

is100SwitchHB() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targHBState targHBStateCmd targMod
	privateVarAssign "${FUNCNAME[0]}" "targHBState" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targMod" "$2"

	echo -e -n "\tSetting HB mode on Module $targMod, Segment $targSeg to $targHBState: "
	if [ "$targHBState" == "off" ]; then targHBStateCmd="disable"; else targHBStateCmd="enable"; fi
	sendIS100 $uutSerDev "bypass segment $targMod.1 hb active-mode $targHBStateCmd" 2>&1 > /dev/null
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

}

is40GetStat() {
	local 
	echo -e -n "\tSetting default parameters: "
	cmdRes=$(sendIS40 $uutSerDev "get_stat")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

}

is40SetDefault() {
	local 
	echo -e -n "\tSetting default parameters: "
	cmdRes=$(sendIS40 $uutSerDev "set_default")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

}

is40GetCPLD() {
	local 
	echo -e -n "\tGet CPLD build: "
	cmdRes=$(sendIS40 $uutSerDev "get_cpld_build")
	if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	echo "$cmdRes" |grep 0x
}

is40SetSegment() {
	local targMod targSeg
	privateNumAssign "targMod" "$1"
	privateNumAssign "targSeg" "$2"

	echo -e -n "\tSetting active module to $targMod: "
	cmdRes=$(sendIS40 $uutSerDev "set_seg $targMod $targSeg")
	cmdRes=$(sendIS40 $uutSerDev "get_seg")
	if [[ ! -z "$(echo "$cmdRes" |grep "$targMod:$targSeg.")" ]]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi

}

is40SendTraffic() {
	echo -e -n "\tSending traffic: "
	40gSendTraffic 10000000
}

is40SendShortTraffic() {
	echo -e -n "\tSending short traffic: "
	40gSendTraffic 1000000
}

is100SendTraffic() {
	echo -e -n "\tSending traffic: "
	is100sshSendTraffic jenagenMod_v2 100000000 3
}

is100TrfAndPwOff() {
	echo -ne "\n"
	is100CPLDsetBP inline 1
	is100CPLDsetBP inline 2
	is100SetBP inline 1
	is100SetBP inline 2


	is100sshSendTrafficAndPoweroff
	is100CPLDsetBP inline 1
	is100CPLDsetBP inline 2
	is100SetBP inline 1
	is100SetBP inline 2
}

isPasBpTests() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"

	case $baseModel in
		"IS100G-Q-RU") except "not defined";;
		"IS401U-RU") 
			sleep 1
			is40SetSegment $modSelect 1
			is40BSSFsetBP inline $modSelect 1
			is40SetBP inline $modSelect 1
			is40SwitchHB off $modSelect
			is40CheckAllLinkState up

			echo -ne "\n"
			is40SetBP bypass $modSelect 1
			is40BSSFsetBP bypass $modSelect 1
			is40CheckAllLinkState down
			echo -ne "\n"
			is40printBPState
			for ((e=0;e<=5;e++)); do
				is40ClearStat
				is40SendShortTraffic
			done
			for ((e=0;e<=5;e++)); do
				echo -e "\n\tSetting switch to IL (BSSF)."
				is40ClearStat
				is40BSSFsetBP inline $modSelect 1  > /dev/null 2>&1
				is40SetBP inline $modSelect 1 > /dev/null 2>&1
				sleep 10
				is40SendShortTraffic
				echo -e "\n\tSetting switch to BP (BSSF)."
				is40SetBP bypass $modSelect 1 > /dev/null 2>&1
				is40BSSFsetBP bypass $modSelect 1 > /dev/null 2>&1
				is40SendShortTraffic
			done
			for ((e=0;e<=5;e++)); do
				echo -e "\n\tSetting switch to IL."
				is40ClearStat
				is40SetPasBP inline $modSelect 1 > /dev/null 2>&1
				is40SetBP inline $modSelect 1 > /dev/null 2>&1
				sleep 10
				is40SendShortTraffic
				echo -e "\n\tSetting switch to BP."
				is40SetBP bypass $modSelect 1 > /dev/null 2>&1
				is40SetPasBP bypass $modSelect 1 > /dev/null 2>&1
				is40SendShortTraffic
			done
			echo -ne "\n"
			is40BSSFsetBP inline $modSelect 1
			is40SetBP inline $modSelect 1


			# is100sshSendTrafficAndPoweroff
			# is40BSSFsetBP inline 1 1
			# is40SetBP inline 1
		;;
		*) except "unknown baseModel: $baseModel"
	esac
}

isBpTests() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"

	case $baseModel in
		"IS100G-Q-RU") 
			sleep 1
			is100CPLDsetBP inline 1
			is100CPLDsetBP inline 2
			is100SwitchHB off 1
			is100SwitchHB off 2
			is100SetBP inline 1
			is100SetBP inline 2
			is100SwitchHB on 1
			is100SwitchHB on 2
			is100CheckAllLinkState up
			echo -ne "\n"
			is100printBPState
			is100SendTraffic

			echo -ne "\n"
			is100SwitchHB off 1
			is100SwitchHB off 2
			is100SetBP bypass 1
			is100SetBP bypass 2
			is100CPLDsetBP inline 1
			is100CPLDsetBP inline 2
			is100CheckAllLinkState up
			echo -ne "\n"
			is100printBPState
			is100SendTraffic

			echo -ne "\n"
			is100SetBP bypass 1
			is100SetBP bypass 2
			is100CPLDsetBP bypass 1
			is100CPLDsetBP bypass 2
			is100CheckAllLinkState down
			echo -ne "\n"
			is100printBPState
			is100SendTraffic

			echo -ne "\n"
			is100CPLDsetBP inline 1
			is100CPLDsetBP inline 2
			is100SetBP inline 1
			is100SetBP inline 2


			is100sshSendTrafficAndPoweroff
			is100CPLDsetBP inline 1
			is100CPLDsetBP inline 2
			is100SetBP inline 1
			is100SetBP inline 2
		;;
		"IS401U-RU") 
			sleep 1
			is40SetSegment $modSelect 1
			is40BSSFsetBP inline $modSelect 1
			is40SwitchHB off $modSelect
			is40SetBP inline $modSelect 1
			is40CheckAllLinkState up
			echo -ne "\n"
			is40printBPState
			is40SendShortTraffic
			# is40SendTraffic

			echo -ne "\n"
			is40SwitchHB off $modSelect
			is40SetBP bypass $modSelect 1
			is40BSSFsetBP inline $modSelect 1
			is40CheckAllLinkState up
			echo -ne "\n"
			is40printBPState
			is40SendTraffic

			echo -ne "\n"
			is40SetBP bypass $modSelect 1
			is40BSSFsetBP bypass $modSelect 1
			is40CheckAllLinkState down
			echo -ne "\n"
			is40printBPState
			is40SendTraffic

			echo -ne "\n"
			is40BSSFsetBP inline $modSelect 1
			is40SetBP inline $modSelect 1


			# is100sshSendTrafficAndPoweroff
			# is40BSSFsetBP inline 1 1
			# is40SetBP inline 1
		;;
		*) except "unknown baseModel: $baseModel"
	esac
}

isFTTests() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"

	case $baseModel in
		"IS100G-Q-RU") except "not defined";;
		"IS401U-RU") 
			sleep 1
			is40SetDefault
			is40SetSegment $modSelect 1
			is40BSSFsetBP inline $modSelect 1
			is40SwitchHB off $modSelect
			is40SetBP inline $modSelect 1
			is40CheckAllLinkState up
			is40ClearStat
			is40GetCPLD

			echo -ne "\n"
			is40SwitchHB off $modSelect
			is40SetBP bypass $modSelect 1
			is40ClearStat
			is40printBPState
			is40SendShortTraffic
			is40SetBP tap $modSelect 1
			is40SetBP linkdrop $modSelect 1
			is40ClearStat
			is40GetStat
			is40SetBP tapi12 $modSelect 1
			is40SetBP tapa $modSelect 1
			is40SetBP tapai1 $modSelect 1
			is40SetBP tapai2 $modSelect 1
			is40SetBP tapai12 $modSelect 1
			is40SetBP inline $modSelect 1
			is40CheckAllLinkState up
			is40ClearStat
			is40printBPState
			is40SendShortTraffic
			is40GetStat
			is40SetPasBP bypass $modSelect 1 
			is40ClearStat
			is40printBPState
			is40SendShortTraffic
			is40GetStat
			is40SetPasBP inline $modSelect 1 
			is40SetDefault
			is40ClearStat
			is40printBPState
			is40SendTraffic
			is40SetBP bypass $modSelect 1
			is40BSSFsetBP bypass $modSelect 1
			is40printBPState
			is40SendTraffic
			is40BSSFsetBP inline $modSelect 1
			is40SetBP inline $modSelect 1
			is40printBPState
			is40SendShortTraffic
			is40SetBP bypass $modSelect 1
			is40SetPasBP bypass $modSelect 1
			is40printBPState
			is40SendShortTraffic
			is40BSSFsetBP inline $modSelect 1
			is40SetBP inline $modSelect 1
		;;
		*) except "unknown baseModel: $baseModel"
	esac
}

isInfoCheck() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local devInfoRes
	case $baseModel in
		"IS100G-Q-RU") devInfoRes="$(sendIS100 $uutSerDev show device)" ;;
		"IS401U-RU") devInfoRes="$(sendIS40 $uutSerDev get_ver)"
	esac

	checkIfContains "Checking U-Boot version" "--$isUbootVer" "$(echo "$devInfoRes" |grep -m 1 "$isUbootVer")"
	checkIfContains "Checking SW version" "--$isSwVer" "$(echo "$devInfoRes" |grep -m 1 "$isSwVer")"
	checkIfContains "Checking FW version" "--$isFwVer" "$(echo "$devInfoRes" |grep -m 1 "$isFwVer")"
	checkIfContains "Checking Device type" "--$isDevType" "$(echo "$devInfoRes" |grep -m 1 "$isDevType")"
}

checkIfFailed() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local curStep severity errMsg
	
	privateVarAssign "checkIfFailed" "curStep" "$1"
	privateVarAssign "checkIfFailed" "severity" "$2"
	curStep="$1"
	severity="$2"
	if [[ -e "/tmp/statusChk.log" ]]; then
		errMsg="$(cat /tmp/statusChk.log | tr '[:lower:]' '[:upper:]' |grep -e 'EXCEPTION\|FAIL')"
		dmsg inform "checkIfFailed debug:\n=========================================================="
		dmsg inform ">$errMsg<"
		dmsg inform "\n==========================================================\ncheckIfFailed debug END"
		if [[ ! -z "$errMsg" ]]; then
			if [[ "$severity" = "warn" ]]; then
				warn "$curStep" 
			else
				exitFail "$curStep"
			fi
		fi
	fi
}

mainTest() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local pciTest dumpTest bpTest drateTest trfTest isInfoTest
	
	if [[ ! -z "$untestedPn" ]]; then untestedPnWarn; fi

	checkDefined uutBdsUser
	checkDefined uutBdsPass
	checkDefined uutRootUser
	checkDefined uutRootPass

	echo -e "\n  Select tests:"
	options=("Full test" "Info test" "BP test" "Passive BP test" "FT test" "Hard reset" "Send traffic and power off")
	case `select_opt "${options[@]}"` in
		0) 
			isInfoTest=1
			bpTest=1
		;;
		1) isInfoTest=1;;
		2) bpTest=1;;
		3) pasBpTest=1;;
		4) FTTest=1;;
		5) hardReset=1;;
		6) trfPwOff=1;;
		*) except "unknown option";;
	esac

	if [ ! -z "$isInfoTest" ]; then
		echoSection "IS Info test"
			isInfoCheck |& tee /tmp/statusChk.log
		checkIfFailed "IS Info test failed!" warn
	else
		inform "\tIS Info test skipped"
	fi

	if [ ! -z "$bpTest" ]; then
		echoSection "IS BP test"
			isBpTests |& tee /tmp/statusChk.log
		checkIfFailed "IS BP test failed!" exit
	else
		inform "\tIS BP test skipped"
	fi

	if [ ! -z "$pasBpTest" ]; then
		echoSection "IS Passive BP test"
			isPasBpTests |& tee /tmp/statusChk.log
		checkIfFailed "IS Passive BP test failed!" exit
	else
		inform "\tIS BP test skipped"
	fi

	
	if [ ! -z "$FTTest" ]; then
		echoSection "IS FT test"
			isFTTests |& tee /tmp/statusChk.log
		checkIfFailed "IS FT test failed!" exit
	else
		inform "\tIS FT test skipped"
	fi

	if [ ! -z "$hardReset" ]; then
		echoSection "Hard reset"
		is100HardReset |& tee /tmp/statusChk.log
	fi

	if [ ! -z "$trfPwOff" ]; then
		echoSection "Send traffic and power off"
		is100TrfAndPwOff |& tee /tmp/statusChk.log
	fi
}


initialSetup(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"

	selectSerial "  Select UUT serial device"
	uutSerDev=ttyUSB$?
	testFileExist "/dev/$uutSerDev"

	acquireVal "Part Number" pnArg uutPn
	
	defineRequirments
	checkRequiredFiles
}


selectMod() {
	local modulues segments
	modulues=("Module 1" "Module 2" "Module 3")
	select_option "${modulues[@]}"
	case ${modulues[$?]} in 
		"Module 1") let modSelect=1;;
		"Module 2")	let modSelect=2;;
		"Module 3")	let modSelect=3;;
		*) 
			echo "Invalid option, try again"
			modSelect="-1"
		;;
	esac
}

main() {
	case $baseModel in
		"IS100G-Q-RU") ;;
		"IS401U-RU") selectMod
	esac
	
	mainTest
	if [ -z "$minorLaunch" ]; then passMsg "\n\tDone!\n"; else echo "  Returning to caller"; fi
}


if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tsfpLinkTest has been loaded as lib (support: arturd@silicom.co.il)'
else
	echo -e '\n# arturd@silicom.co.il\n\n'
	trap "exit 1" 10
	PROC="$$"
	declareVars
	source /root/multiCard/arturLib.sh; let status+=$?
	source /root/multiCard/graphicsLib.sh; let status+=$?
	if [[ ! "$status" = "0" ]]; then 
		echo -e "\t\e[0;31mLIBRARIES ARE NOT LOADED! UNABLE TO PROCEED\n\e[m"
		exit 1
	fi
	echoHeader "$toolName" "$ver"
	echoSection "Startup.."
	parseArgs "$@"
	setEmptyDefaults
	initialSetup
	startupInit
	source /root/PE310G4BPI71/library.sh &> /dev/null
	if ! [ $? -eq 0 ]; then 
		echo -e "\t\e[0;31mLIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
		exit 1
	fi
	main
	if [ -z "$minorLaunch" ]; then echo -e "See $(inform "--help" "--nnl" "--sil") for available parameters\n"; fi
fi
