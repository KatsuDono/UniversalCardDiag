#!/bin/bash

declareVars() {
	ver="v0.01"
	toolName='Prog utility'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	let exitExec=0
	let debugBrackets=1
}

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			uut-slot-num) uutSlotArg=${VALUE} ;;	
			uut-pn) pnArg=${VALUE} ;;
			uut-tn) tnArg=${VALUE} ;;
			uut-rev) revArg=${VALUE} ;;
			silent) 
				silentMode=1 
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			debug) 
				debugMode=1 
				inform "Launch key: Debug mode"
			;;
			help) showHelp ;;
			*) echo "Unknown arg: $ARG"; showHelp
		esac
	done
}

showHelp() {
	warn "\n=================================" "" "sil"
	echo -e "$toolName"
	echo -e " Arguments:"
	echo -e " --help"
	echo -e "\tShow help message\n"	
	echo -e " --uut-slot-num=NUMBER"
	echo -e "\tUse specific slot for UUT\n"
	echo -e " --uut-pn=NUMBER"	
	echo -e "\tProduct number of UUT\n"
	echo -e " --uut-tn=NUMBER"
	echo -e "\tTracking number of UUT\n"
	echo -e " --uut-rev=NUMBER"
	echo -e "\tDoes not initializes the card\n"	
	echo -e " --silent"
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	echo -e " Setting defaults.."
	
	echo -e " Done.\n"
}


startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	test "$skipInit" = "1" || {
		echo "  Searching $baseModel init sequence.."
		case "$baseModel" in
			*) inform "init skipped for now, not required"
		esac
	}
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		"/root/multiCard/arturLib.sh"
		"/root/multiCard/graphicsLib.sh"
	)
	
	case "$baseModel" in
		PE2G4I35) 
			echo "  File list: PE2G4I35"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE2G4I35/"	
			)				
		;;
		*) exitFail "checkRequiredFiles exception, unknown baseModel: $baseModel"
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

checkFwFile() {
	local fwFilePath
	privateVarAssign "checkFwFile" "fwFilePath" "$*"

	testFileExist "$fwFilePath" "true"
	test "$?" = "1" && {
		echo -e "  \e[0;31mfail.\e[m"
		exitFail "FW file not found!"
	} || echo -e "  \e[0;32mok.\e[m"
}

checkFWFiles() {
	local filePath filesArr
	echo -e " Checking required FW files.."
	

	
	declare -a filesArr=(
		${filesArr[@]}
		"$baseModelPath"
		"$baseModelPath/$fwFileName"
	)


	echo "  FW Path: $fwPath"
	echo "  FW File: $fwFileName"

	test ! -z "$(echo ${filesArr[@]})" && {
		for filePath in "${filesArr[@]}";
		do
			testFileExist "$filePath" "true"
			test "$?" = "1" && {
				echo -e "  \e[0;31mfail.\e[m"
				echo -e "  \e[0;33mPath: $filePath does not exist! Starting sync.\e[m"
				getFwFromServ "$baseModel" "$fwSyncPn"
			} || echo -e "  \e[0;32mok.\e[m"
		done
	}

	echo -e " Done."
}

patchFwFile() {
	local rev revOffset track trackOffset timePatch timeOffset patchedFwFile revEndAddr trackEndAddr status
	privateVarAssign "patchFwFile" "revOffset" "$1" 	;shift
	privateVarAssign "patchFwFile" "rev" "$1" 			;shift
	privateVarAssign "patchFwFile" "trackOffset" "$1" 	;shift
	privateVarAssign "patchFwFile" "track" "$1" 		;shift
	test -z "$fwFileName" && warn "patchFwFile exception, fwFileName is undefined"
	timePatch=$(date --rfc-3339=date |tr -d '-' |cut -c 3-8)

	patchedFwFile=$(echo -n "$baseModelPath/${fwFileName%.*}_patched.${fwFileName##*.}")
	cp "$baseModelPath/$fwFileName" "$patchedFwFile"

	echo -e "   Patching FW file.."
	echo -e "    Base FW file: $baseModelPath/$fwFileName"
	echo -e "    Patched FW file: $patchedFwFile"
	echo -e "    Tracking: $track"
	echo -e "    Revision: $rev"
	echo -e "    Date: $timePatch"
	
	if [[ -e "$patchedFwFile" ]]; then
		fwCurSize=$(stat -L -- "$patchedFwFile" |grep Size: |awk '{print $2}')
		revOffset=$((16#$(echo -n "$revOffset" | tr '[:lower:]' '[:upper:]' |rev |awk -F'X0' '{print $1}' |rev)))
		trackOffset=$((16#$(echo -n "$trackOffset" | tr '[:lower:]' '[:upper:]' |rev |awk -F'X0' '{print $1}' |rev)))
		let timeOffset=$revOffset+6
		revEndAddr=$(( $revOffset + $(echo -n $rev | wc -c) ))
		timeEndAddr=$(( $timeOffset + $(echo -n $timePatch | wc -c) ))
		trackEndAddr=$(( $trackOffset + $(echo -n $track | wc -c) ))
		
		dmsg inform "fwCurSize=$fwCurSize\nrevOffset=$revOffset\ntrackOffset=$trackOffset\nrevEndAddr=$revEndAddr\ntrackEndAddr=$trackEndAddr\ntimePatch=$timePatch\ntimeEndAddr=$timeEndAddr"

		if (( "$fwCurSize" >= "$revEndAddr" )); then
			echo -n "$rev" | dd bs=1 seek=$revOffset of="$patchedFwFile" conv=notrunc >/dev/null 2>&1
			if [[ "$?" -eq "0" ]]; then echo "    Revision patched."; else exitFail "  Failed to patch revision"'!'; let status+=$?; fi
		else
			exitFail "patchFwFile exception, revision length exceeds the FW size and cannot be patched onto it!"
		fi
		if (( "$fwCurSize" >= "$timeEndAddr" )); then
			echo -n "$timePatch" | dd bs=1 seek=$timeOffset of="$patchedFwFile" conv=notrunc >/dev/null 2>&1
			if [[ "$?" -eq "0" ]]; then echo "    Date patched."; else exitFail "  Failed to patch date"'!'; let status+=$?; fi
		else
			exitFail "patchFwFile exception, date length exceeds the FW size and cannot be patched onto it!"
		fi
		if (( "$fwCurSize" >= "$trackEndAddr" )); then
			echo -n "$track" | dd bs=1 seek=$trackOffset of="$patchedFwFile" conv=notrunc >/dev/null 2>&1
			if [[ "$?" -eq "0" ]]; then echo "    Tracking patched."; else exitFail "  Failed to patch tracking"'!'; let status+=$?; fi
		else
			exitFail "patchFwFile exception, track length exceeds the FW size and cannot be patched onto it!"
		fi


		if [[ "$status" -eq "0" ]]; then
			echo -e "   Patching done!"
		else
			exitFail "\tFW Patching failed!"
		fi
	else
		exitFail "patchFwFile exception, patchedFwFile is not found by path: $patchedFwFile"
	fi
}

burnCardFw() {
	privateVarAssign "burnCardFw" "slotNum" "$1"
	# $uutSlotBus
	acquireVal "UUT Tracking number" tnArg uutTn
	acquireVal "UUT Revision" revArg uutRev

	checkFWFiles
	patchFwFile $pnRevDumpOffset $uutRev $tnDumpOffset $uutTn
}

selectFwVer() {
	local fwVerLocal
	if [[ ! -z "$1" ]]; then 
		fwVerLocal=$1
		echo -e "\n  FW ver: $fwVerLocal"
	else
		echo -e "\n  FW ver:"
		uutFwVer=`select_opt "${uutFwVers[@]}"`	
		fwVerLocal=${uutFwVers[$uutFwVer]}
	fi

	case "$fwSyncPn" in
		PE2G4I35)
			echo "  FW Files list: PE310G4BPI71-SR"	
			case "$fwVerLocal" in
				1.00)	fwFileName="PE2G4i35.eep"	;;
				1.30)	fwFileName="PE2G4i35L-RB2.eep"	;;
				1.40)	fwFileName="PE2G4i35L.eep"	;;
				2.20)	fwFileName="PE2G4i35LE_2v00.eep"	;;
				erase)	fwFileName="i35blank.eep"	;;
				*) except "${FUNCNAME[0]}" "unknown ver selected: $fwVerLocal"
			esac
		;;
		*) except "${FUNCNAME[0]}" "unknown fwSyncPn: $fwSyncPn"
	esac

	fwPath="$baseModelPath/$fwFileName"
	dmsg echo "Path selected: $fwPath"

	if [[ ! -e "$fwPath" ]]; then
		getFwFromServ "$baseModel" "$fwSyncPn"
	fi

	# fwFolder=$(basename $fwPath)
}

defineRequirments() {
	local ethToRemove
	echo -e "\n Defining requirements.."
	test -z "$uutPn" && exitFail "Requirements cant be defined, empty uutPn"
	if [[ ! -z $(echo -n $uutPn |grep "PE2G4I35\|nullDev") ]]; then

		test ! -z $(echo -n $uutPn |grep "PE2G4I35") && {
			uutFwVers=("1.00" "1.30" "1.40" "2.20")
			uutEraseFwVer="erase"
			let verDumpLen=5
			pnDumpOffset="0x850"
			let pnDumpLen=28
			pnRevDumpOffset="0x86C"
			let pnRevDumpLen=4
			tnDumpOffset="0x880"
			let tnDumpLen=13
			tdDumpOffset="0x872"
			let tdDumpLen=6
			baseModel="PE2G4I35"
			syncPn="PE2G4I35"
			fwSyncPn="PE2G4I35"
			baseModelPath="/root/PE2G4I35"
			bpCtlMode="bpctl"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth plx spc acc
		} 

		echoIfExists "  Port count:" "$uutDevQty"
		echoIfExists "  Net count:" "$uutNetQty"
		echoIfExists "  BP count:" "$uutBpDevQty"
	else
		except "${FUNCNAME[0]}" "PN: $uutPn cannot be processed, requirements not defined"
	fi
	
	echo -e " Done.\n"
}


netInfoDump() {
	local pnDumpRes verDumpRes pnRevDumpRes tnDumpRes tnDumpResCut tdDumpRes tdDumpResDate net netDesc baseModelLocal
	local verDumpOffsetLocal verDumpLenLocal pnDumpOffsetLocal pnDumpLenLocal pnRevDumpOffsetLocal pnRevDumpLenLocal tnDumpOffsetLocal tnDumpLenLocal tdDumpOffsetLocal tdDumpLenLocal	
	
	privateVarAssign "netInfoDump" "net" "$1"
	privateVarAssign "netInfoDump" "netDesc" "$2"

	if [[ ! -z "$(echo -n $mastNets |grep $net)" ]]; then
		privateVarAssign "netInfoDump" "baseModelLocal" "$mastBaseModel"
		verDumpOffsetLocal=$verDumpOffset_mast
		verDumpLenLocal=$verDumpLen_mast
		pnDumpOffsetLocal=$pnDumpOffset_mast
		pnDumpLenLocal=$pnDumpLen_mast
		pnRevDumpOffsetLocal=$pnRevDumpOffset_mast
		pnRevDumpLenLocal=$pnRevDumpLen_mast
		tnDumpOffsetLocal=$tnDumpOffset_mast
		tnDumpLenLocal=$tnDumpLen_mast
		tdDumpOffsetLocal=$tdDumpOffset_mast
		tdDumpLenLocal=$tdDumpLen_mast
	else
		baseModelLocal="$baseModel" 
		test -z "$verDumpOffset" 	|| privateVarAssign "netInfoDump" "verDumpOffsetLocal" "$verDumpOffset"
		test -z "$verDumpLen" 		|| privateVarAssign "netInfoDump" "verDumpLenLocal" "$verDumpLen"
		test -z "$pnDumpOffset" 	|| privateVarAssign "netInfoDump" "pnDumpOffsetLocal" "$pnDumpOffset"
		test -z "$pnDumpLen" 		|| privateVarAssign "netInfoDump" "pnDumpLenLocal" "$pnDumpLen"
		test -z "$pnRevDumpOffset" 	|| privateVarAssign "netInfoDump" "pnRevDumpOffsetLocal" "$pnRevDumpOffset"
		test -z "$pnRevDumpLen" 	|| privateVarAssign "netInfoDump" "pnRevDumpLenLocal" "$pnRevDumpLen"
		test -z "$tnDumpOffset" 	|| privateVarAssign "netInfoDump" "tnDumpOffsetLocal" "$tnDumpOffset"
		test -z "$tnDumpLen" 		|| privateVarAssign "netInfoDump" "tnDumpLenLocal" "$tnDumpLen"
		test -z "$tdDumpOffset" 	|| privateVarAssign "netInfoDump" "tdDumpOffsetLocal" "$tdDumpOffset"
		test -z "$tdDumpLen" 		|| privateVarAssign "netInfoDump" "tdDumpLenLocal" "$tdDumpLen"
	fi
	
	dumpRegsPE310GxBPI71() {
		verDumpRes=$(ethtool -e $net offset $verDumpOffsetLocal length $verDumpLenLocal |grep : |cut -d: -f2 | xxd -r -p)
		pnDumpRes=$(ethtool -e $net offset $pnDumpOffsetLocal length $pnDumpLenLocal |grep : |cut -d: -f2 | xxd -r -p | tr '[:lower:]' '[:upper:]')
		pnRevDumpRes=$(ethtool -e $net offset $pnRevDumpOffsetLocal length $pnRevDumpLenLocal |grep : |cut -d: -f2 | xxd -r -p)
		tnDumpRes=$(ethtool -e $net offset $tnDumpOffsetLocal length $tnDumpLenLocal |grep : |cut -d: -f2 | xxd -r -p)
		tnDumpResCut=$(echo $tnDumpRes|cut -c2-)
		tdDumpRes=$(ethtool -e $net offset $tdDumpOffsetLocal length $tdDumpLenLocal |grep : |cut -d: -f2 | xxd -r -p)
		tdDumpResDate="$(echo -n $tdDumpRes|cut -c5-6)/$(echo -n $tdDumpRes|cut -c3-4)/20$(echo -n $tdDumpRes|cut -c1-2)"
	}
	
	printRegsPE310GxBPI71() {
		echo -e  "\t$netDesc dumps on $net"
		# echo -e -n "\t $netDesc     PN: $pnDumpRes  $(test -z "$(echo $pnDumpRes |grep $baseModelLocal)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		# echo -e -n "\t $netDesc FW_Ver: $verDumpRes   $(test -z "$(echo $verDumpRes |grep v)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		# echo -e -n "\t $netDesc    Rev: $pnRevDumpRes   $([ $(expr "x$pnRevDumpRes" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n"
		# echo -e -n "\t $netDesc     TN: $tnDumpRes   $([ $(expr "x$tnDumpResCut" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n"
		# echo -e -n "\t $netDesc     TD: $tdDumpResDate   $([ $(expr "x$tdDumpRes" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n"
		dmsg inform "pnDumpRes=$pnDumpRes   baseModelLocal=$baseModelLocal  grep=$(echo $pnDumpRes |grep $baseModelLocal)\n\tverDumpRes=$verDumpRes  pnRevDumpRes=$pnRevDumpRes  tnDumpRes=$tnDumpRes  tdDumpResDate=$tdDumpResDate"
		test ! -z "$(echo "$pnDumpRes" 2>&1 |xxd |grep 'ffff ffff')" && critWarn "\t $netDesc     PN: EMPTY" || {
			echo -e -n "\t $netDesc     PN: $pnDumpRes  $(test -z "$(echo $pnDumpRes |grep $baseModelLocal)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		}
		test ! -z "$(echo "$verDumpRes" 2>&1 |xxd |grep 'ffff ffff')" && critWarn "\t $netDesc FW_Ver: EMPTY" || {
			echo -e -n "\t $netDesc FW_Ver: $verDumpRes  $(test -z "$(echo $verDumpRes |grep v)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		}
		test ! -z "$(echo "$pnRevDumpRes" 2>&1 |xxd |grep 'ffff ffff')" && critWarn "\t $netDesc    Rev: EMPTY" || {
			echo -e -n "\t $netDesc    Rev: $pnRevDumpRes  $([ $(expr "x$pnRevDumpRes" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n"
		}
		test ! -z "$(echo "$tnDumpRes" 2>&1 |xxd |grep 'ffff ffff')" && critWarn "\t $netDesc     TN: EMPTY" || {
			echo -e -n "\t $netDesc     TN: $tnDumpRes  $([ $(expr "x$tnDumpResCut" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n"
		}
		test ! -z "$(echo "$tdDumpResDate" 2>&1 |xxd |grep 'ffff ffff')" && critWarn "\t $netDesc     TD: EMPTY" || {
			echo -e -n "\t $netDesc     TD: $tdDumpResDate  $([ $(expr "x$tdDumpRes" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n"
		}
		echo -e -n "\n"
	}
	
	printRegsPE210G2BPI9() {
		echo -e  "\t$netDesc dumps on $net"
		test ! -z "$(echo "$pnDumpRes" 2>&1 |xxd |grep 'ffff ffff')" && critWarn "\t $netDesc     PN: EMPTY" || {
			echo -e -n "\t $netDesc     PN: $pnDumpRes  $(test -z "$(echo $pnDumpRes |grep $baseModelLocal)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		}
		test -z "$(echo $pnRevDumpRes 2>&1 |xxd |grep 'ffff ffff')" && {
			echo -e -n "\t $netDesc    Rev: $pnRevDumpRes   $([ $(expr "x$pnRevDumpRes" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n" 
		} || critWarn "\t $netDesc    Rev: EMPTY"
		test -z "$(echo $tnDumpRes 2>&1 |xxd |grep 'ffff ffff')" && echo -e -n "\t $netDesc     TN: $tnDumpRes   $([ $(expr "x$tnDumpResCut" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n" || critWarn "\t $netDesc     TN: EMPTY"
		echo -e -n "\n"
	}
	
	dumpRegsPE310G4DBIR() {
		vpdPnDumpRes=$(rdifctl dev 0 get_reg $vpdPnDumpAddr |cut -d ' ' -f3)
		rrcDumpRes=$(rdifctl dev 0 get_reg $rrcChipDumpAddr |cut -d ' ' -f3)
	}
	
	printRegsPE310G4DBIR() {
		echo -e  "\t$netDesc dumps on dev 0"
		echo -e -n "\t $netDesc        VPD PN: $vpdPnDumpRes  $(test -z "$(echo $vpdPnDumpRes |grep $vpdPnDumpExp)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		echo -e -n "\t $netDesc  RRC CHIP VER: $rrcDumpRes   $(test -z "$(echo $rrcDumpRes |grep $rrcChipDumpExp)" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		echo -e -n "\n"
	}
	
	case "$baseModelLocal" in
		PE310G4BPI71) 
			dumpRegsPE310GxBPI71 
			printRegsPE310GxBPI71
		;;
		PE310G2BPI71) 
			dumpRegsPE310GxBPI71 
			printRegsPE310GxBPI71
		;;
		PE210G2BPI40) 
			warn "  dumps not implemented for $baseModelLocal"
		;;
		PE310G4BPI40) 
		warn "  dumps not implemented for $baseModelLocal"
		;;
		PE310G4I40) 
			warn "  dumps not implemented for $baseModelLocal"
		;;
		PE310G4DBIR) 
			dumpRegsPE310G4DBIR
			printRegsPE310G4DBIR
		;;
		PE340G2DBIR) 
			warn "  dumps not implemented for $baseModelLocal"
		;;		
		PE3100G2DBIR) 
			warn "  dumps not implemented for $baseModelLocal"
		;;		
		PE310G4BPI9) 
			warn "  dumps not implemented for $baseModelLocal"
		;;		
		PE210G2BPI9) 
			dumpRegsPE310GxBPI71 
			printRegsPE210G2BPI9
		;;
		PE210G2SPI9A) 
			dumpRegsPE310GxBPI71 
			printRegsPE210G2BPI9
		;;
		PE325G2I71) 
			# warn "  netInfoDump exception, dumps not implemented for PE325G2I71"
			dumpRegsPE310GxBPI71
			printRegsPE310GxBPI71
		;;
		PE31625G4I71L) 
			dumpRegsPE310GxBPI71 
			printRegsPE310GxBPI71
		;;
		M4E310G4I71)
			dumpRegsPE310GxBPI71 
			printRegsPE310GxBPI71
		;;
		*) exitFail "Unknown baseModelLocal: $baseModelLocal"
	esac
}

checkIfFailed() {
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

assignBuses() {
	for ARG in "$@"
	do	
		dmsg inform "ASSIGNING BUS: $ARG"
		case "$ARG" in
			spc) publicVarAssign silent spcBuses $(grep '1180' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;	
			eth) publicVarAssign critical ethBuses $(filterDevsOnBus $uutSlotBus $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)) ;;
			plx) publicVarAssign warn plxBuses $(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			acc) publicVarAssign silent accBuses $(grep '0b40' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			*) except "${FUNCNAME[0]}" "unknown bus type: $ARG"
		esac
	done
}

eraseUUT() {
	local somestuff
	echo "  Erasing UUT.."
	case "$baseModel" in
		PE2G4I35) 
			selectFwVer "erase"
			flashCard "$(echo $ethBuses |cut -d ' ' -f1 |cut -d: -f1)" "$fwPath"
		;;
		*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
	esac 
	echo "  Done."
}

mainTest() {
	local eraseOpt
	
	if [[ ! -z "$untestedPn" ]]; then untestedPnWarn; fi

	echo -e "\n  Select tests:"
	options=("Erase")
	case `select_opt "${options[@]}"` in
		0) eraseOpt=1;;
		*) except "${FUNCNAME[0]}" "unknown option";;
	esac

	dmsg inform "eraseOpt=$eraseOpt"


	if [ ! -z "$eraseOpt" ]; then
		echoSection "Erase"
			eraseUUT |& tee -a /tmp/statusChk.log
		test -z "$ignDumpFail" && checkIfFailed "Erase failed!" crit || checkIfFailed "Erase failed!" warn
	else
		inform "\tErase skipped"
	fi

}

assignNets() {
	publicVarAssign warn uutNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $uutSlotBus |awk -F/ '{print $NF}')
}

initialSetup(){
	if [[ -z "$uutSlotArg" ]]; then 
		selectSlot "  Select UUT:"
		uutSlotNum=$?
		dmsg inform "uutSlotNum=$uutSlotNum"
	else acquireVal "UUT slot" uutSlotArg uutSlotNum; fi
	

	acquireVal "Part Number" pnArg uutPn
	
	
	publicVarAssign warn uutBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $uutSlotNum |tail -n 1)
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign fatal devsOnUutSlotBus $(ls -l /sys/bus/pci/devices/ |grep $uutSlotBus |awk -F/ '{print $NF}')
	publicVarAssign fatal filteredEthDevs $(filterDevsOnBus $(echo -n ":$uutBus:") $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-))

	test "$uutBus" = "ff" && exitFail "Card not detected, uutBus=ff"

	defineRequirments
	checkRequiredFiles
}

main() {	
	test ! -z "$(echo -n $uutBus|grep ff)" && {
		except "${FUNCNAME[0]}" "UUT invalid slot or not detected! uutBus: $uutBus"
	} || {
		mainTest
		passMsg "\n\tDone!\n"
	}
}

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
(return 0 2>/dev/null) && echo -e "\tsfpLinkTest has been loaded as lib" || {
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
	main
	echo -e "See $(inform "--help" "--nnl" "--sil") for available parameters\n"
}
