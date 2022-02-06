#!/bin/bash

declareVars() {
	ver="v0.02"
	toolName='Universal Acceleration Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	declare -a pciArgs=("null" "null")
}

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			uut-slot-num) uutSlotArg=${VALUE} ;;	
			uut-pn) pnArg=${VALUE} ;;
			silent) silentMode=1 ;;
			skip-init) skipInit=1;;
			debug) debugMode=1 ;;
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
	echo -e "\tPN of UUT\n"
	echo -e " --silent"
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --skip-init"	
	echo -e "\tDoes not initializes the card\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"		
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	echo -e " Setting defaults.."
	
	publicVarAssign warn pciSpeedReq 8
	publicVarAssign warn pciWidthReq 8
	syncExecuted=0
	
	echo -e " Done.\n"
}

initQAT() {
	local qatVer
	test -z "$1" && qatVer="$1"
	if [[ ! -e "/etc/init.d/qat_service" ]]; then 
		echo "  Installing QAT$qatVer service"
		drvInstallRes="$(/root/Scripts/qat_update.sh a /root/QAT$qatVer)"
		test -z "$(echo $drvInstallRes |grep 'Acceleration Installation Complete')" && exitFail "Unable to install QAT$qatVer service!" $PROC
	fi
	
	test "$(lsmod |grep "intel_qat" |awk '{print $1}' | grep -c '^')" = "3" && {
		echo "  Restarting QAT$qatVer"
		echo "   Shutting down QAT$qatVer service"
		/etc/init.d/qat_service shutdown
		sleep 3
		echo "   Starting QAT$qatVer service"
		/etc/init.d/qat_service start
		echo "   Checking QAT$qatVer Status"
		#/root/QAT17/quickassist/utilities/adf_ctl/adf_ctl status
	} || {
		echo "  Shutting down QAT$qatVer service"
		test -z "$(/etc/init.d/qat_service shutdown)" || exitFail "Unable to shutdown QAT$qatVer module!" $PROC
		
		sleep 2
		echo "  Starting QAT$qatVer service"
		test -z "$(echo $(/etc/init.d/qat_service start) |grep 'Restarting all devices')" && exitFail "Unable to start QAT$qatVer service!" $PROC
	} 
}

PE3IS2CO3-INIT() {
	initQAT 17
	#  execScript "/root/PE310G4DBIR/rdif_config1vf4_mod.sh" "2 2 $uutSlotNum $uutSlotNum $uutSlotNum" "Rdif Config Passed" "Paired_Device=0" "Unable to configure RDIF"
}
PE2ISCO3-CX-INIT() {
	initQAT 17
}
PE3ISLBEL-FN-INIT() {
	initQAT 17
}
PE3ISLBTL-FU-INIT() {
	initQAT 17
}
PE3ISLBTL-FN-INIT() {
	initQAT 17
}
PE3ISLBLL-INIT() {
	initQAT 17
}
PE316IS2LBTLB-CX-INIT() {
	initQAT 17
}

startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	test -z "$skipInit" && {
		case "$baseModel" in
			PE3IS2CO3LS) PE3IS2CO3-INIT;;
			PE2ISCO3-CX) PE2ISCO3-CX-INIT;;
			PE3ISLBEL-FN) PE3ISLBEL-FN-INIT;;
			PE3ISLBTL-FU) PE3ISLBTL-FU-INIT;;
			PE3ISLBTL-FN) PE3ISLBTL-FN-INIT;;
			PE3ISLBLL) PE3ISLBLL-INIT;;
			PE316IS2LBTLB-CX) PE316IS2LBTLB-CX-INIT;;
			*) exitFail "Undefined startup init for baseModel: $baseModel" $PROC
		esac
	} || inform "  Skipped init"
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		"/root/multiCard/arturLib.sh"
		"/root/QAT17"
		"/root/Scripts"
		"/root/Scripts/qat_update.sh"
	)
	
	case "$baseModel" in
		PE3IS2CO3LS) 
			echo "  File list: PE3IS2CO3LS"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3IS2CO3LS"
				"/root/PE3IS2CO3LS/qat_update.sh"
			)
		;;
		PE2ISCO3-CX) 
			echo "  File list: PE2ISCO3-CX"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE2ISCO3-CX"
				"/root/PE2ISCO3-CX/qat_update.sh"
			)
		;;
		PE3ISLBTL) 
			echo "  File list: PE3ISLBTL"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3ISLBTL"
			)
		;;
		PE3ISLBLL) 
			echo "  File list: PE3ISLBLL"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3ISLBLL"
			)
		;;
		PE316IS2LBTLB-CX) 
			echo "  File list: PE316IS2LBTLB-CX"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE316IS2LBTLB-CX"
			)
		;;
		PE3ISLBEL-FN) 
			echo "  File list: PE3ISLBEL-FN"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3ISLBEL-FN"
				"/root/PE3ISLBEL-FN/qat_update.sh"
			)
		;;
		PE3ISLBTL-FN) 
			echo "  File list: PE3ISLBTL-FN"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3ISLBTL-FN"
				"/root/PE3ISLBTL-FN/qat_update.sh"
			)
		;;
		PE3ISLBTL-FU) 
			echo "  File list: PE3ISLBTL-FU"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3ISLBTL-FU"
				"/root/PE3ISLBTL-FU/qat_update.sh"
			)
		;;
		*) exitFail "Undefined file list for baseModel: $baseModel" $PROC
	esac
	
	test ! -z "$(echo ${filesArr[@]})" && {
		for filePath in "${filesArr[@]}";
		do
			testFileExist "$filePath" "true"
			test "$?" = "1" && {
				echo -e "  \e[0;31mfail.\e[m"
				echo -e "  \e[0;33mPath: $filePath does not exist! Starting sync.\e[m"
				test "$filePath" = "/root/Scripts" && syncFilesFromServ "Scripts" "Scripts" || syncFilesFromServ "$uutPn" "$baseModel"
			} || echo -e "  \e[0;32mok.\e[m"
		done
	}
	echo -e " Done."
    
}

listDevsQty() {
	local blankDevs
	blankDevs=$(lspci -n -d:154b |grep -ciw 154b)
	
	test "$blankDevs" = "0" && echo -e "\tBlank devices: $blankDevs $(qtyComp 0 $blankDevs warn)" || warn "Blank devices found! $(qtyComp 0 $blankDevs warn) $(lspci -n -d:154b)"
	
	testArrQty "UUT eth buses" "$uutEthBuses" "$uutDevQty" "No ethernet buses found on UUT"	
	testArrQty "UUT BP buses" "$uutBpBuses" "$uutBpDevQty" "No BP buses found on UUT"
	testArrQty "UUT Nets" "$uutNets" "$uutNetQty" "UUT has no nets"
}

defineRequirments() {
	echo -e "\n Defining requirements.."
	test -z "$uutPn" && exitFail "Requirements cant be defined, empty uutPn" $PROC
	test ! -z $(echo -n $uutPn |grep -w 'PE3IS2CO3LS\|PE3IS2CO3LS-CX\|PE2ISCO3-CX\|PE3ISLBTL-FU\|PE3ISLBTL-FN\|PE3ISLBLL\|PE3ISLBTL\|P3IMB-M-P1\|PE3ISLBEL-FN\|PE316IS2LBTLB-CX') && {
		test ! -z $(echo -n $uutPn |grep "PE3IS2CO3LS" |grep -v '-';echo -n $uutPn |grep "PE3IS2CO3LS-CX") && {
			assignBuses plx acc
			accKern="qat_dh895xcc"
			plxKern="pcieport"
			let accDevQty=2
			let plxDevQty=1
			let plxDevSubQty=2
			let plxDevEmptyQty=1
			baseModel="PE3IS2CO3LS"
			accDevId="0435"
			plxDevId="8724"
			let accDevSpeed=5
			let accDevWidth=8
			let plxDevSpeed=8
			let plxDevWidth=8
			let plxDevSubSpeed=5
			let plxDevSubWidth=8
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=0
			
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--acc-dev-id=$accDevId"
				"--acc-buses=$accBuses"
				"--plx-dev-id=$plxDevId"
				"--plx-buses=$plxBuses"
				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-empty-qty=$plxDevEmptyQty"
				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--plx-dev-empty-speed=$plxDevEmptySpeed"
				"--plx-dev-empty-width=$plxDevEmptyWidth"
				"--plx-keyw=Physical Slot:"
				"--plx-virt-keyw=ABWMgmt+"
			)
		}
		test ! -z $(echo -n $uutPn |grep "PE2ISCO3-CX") && {
			assignBuses acc
			accKern="qat_dh895xcc"
			let accDevQty=1
			baseModel="PE2ISCO3-CX"
			accDevId="0435"
			let accDevSpeed=5
			let accDevWidth=8
			
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--acc-dev-id=$accDevId"
				"--acc-buses=$accBuses"
				"--acc-kernel=$accKern"
				"--acc-dev-qty=$accDevQty"
			)
		} 
		test ! -z $(echo -n $uutPn |grep "PE3ISLBTL-FU") && {
			assignBuses plx acc
			accKern="qat_c62x"
			plxKern="pcieport"
			
			let accDevQty=3
			let plxDevQty=1
			let plxDevSubQty=3

			baseModel="PE3ISLBTL-FU"
			accDevId="37c8"
			plxDevId="37d1"
			let accDevSpeed=5
			let accDevWidth=16
			let plxDevSpeed=8
			let plxDevWidth=8
			plxDevSubSpeed="2.5"
			let plxDevSubWidth=1
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--acc-buses=$accBuses"
				"--plx-buses=$plxBuses"
				"--acc-dev-id=$accDevId"
				"--plx-dev-id=$plxDevId"
				"--acc-kernel=$accKern"
				"--plx-kernel=$plxKern"
				"--acc-dev-qty=$accDevQty"
				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--plx-keyw=Physical Slot"
				"--plx-virt-keyw=UpstreamFwd+"
			)
		}
		test ! -z $(echo -n $uutPn |grep "PE3ISLBLL" |grep -v '-') && {
			critWarn "NOT FULLY IMPLEMENTED"
			assignBuses plx acc eth
			accKern="qat_c62x"
			plxKern="pcieport"
			ethKern="i40e"
			
			let accDevQty=3
			let plxDevQty=1
			let plxDevSubQty=6
			let ethDevQty=2

			baseModel="PE3ISLBLL"
			accDevId="37c8"
			plxDevId="37c0"
			ethDevId="37d1"
			let accDevSpeed=5
			let accDevWidth=16
			let plxDevSpeed=8
			let plxDevWidth=8
			plxDevSubSpeed="2.5"
			let plxDevSubWidth=1
			ethDevSpeed="2.5"
			let ethDevWidth=1
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--acc-buses=$accBuses"
				"--plx-buses=$plxBuses"
				"--eth-buses=$ethBuses"
				
				"--acc-dev-id=$accDevId"
				"--plx-dev-id=$plxDevId"
				"--eth-dev-id=$ethDevId"
				
				"--acc-kernel=$accKern"
				"--plx-kernel=$plxKern"
				"--eth-kernel=$ethKern"
				
				"--acc-dev-qty=$accDevQty"
				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--eth-dev-qty=$ethDevQty"
				
				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--eth-dev-speed=$ethDevSpeed"
				"--eth-dev-width=$ethDevWidth"
				
				"--plx-keyw=Physical Slot"
				"--plx-virt-keyw=UpstreamFwd+"
			)
		}
		test ! -z $(echo -n $uutPn |grep -v '-' |grep "PE3ISLBTL" ) && {
			warn "REQUIRMENTS CAN DIFFER!!! NOT DEFINED FULLY!!!"
			exitFail "UNSUPPORTED" $PROC
			assignBuses spc eth plx acc
			accKern="qat_dh895xcc"
			let accDevQty=2
			baseModel="PE3ISLBTL"
			accDevId="0435"
			let accDevSpeed=5
			let accDevWidth=8
		}
		test ! -z $(echo -n $uutPn |grep "P3IMB-M-P1") && {
			warn "REQUIRMENTS CAN DIFFER!!! NOT DEFINED FULLY!!!"
			exitFail "UNSUPPORTED" $PROC
			assignBuses spc eth plx acc
			uutKern="NOT_DEFINED"
			let uutDevQty=-1
			baseModel="P3IMB-M-P1"
			pciDevId="NOT_DEFINED"
		}
		test ! -z $(echo -n $uutPn |grep "PE3ISLBEL-FN") && {
			assignBuses spc eth plx acc
			accKern="qat_c62x"
			ethKern="i40e"
			spcKern=""
			
			let accDevQty=1
			let ethDevQty=2
			let spcDevQty=1

			baseModel="PE3ISLBEL-FN"
			accDevId="37c8"
			ethDevId="37d1"
			spcDevId="37b1"
			let accDevSpeed=5
			let accDevWidth=16
			let spcDevSpeed=5
			let spcDevWidth=16
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--acc-buses=$accBuses"
				"--spc-buses=$spcBuses"
				"--eth-buses=$ethBuses"
				"--acc-dev-id=$accDevId"
				"--spc-dev-id=$spcDevId"
				"--eth-dev-id=$ethDevId"
				"--acc-kernel=$accKern"
				"--spc-kernel=$spcKern"
				"--eth-kernel=$ethKern"
				"--acc-dev-qty=$accDevQty"
				"--spc-dev-qty=$spcDevQty"
				"--eth-dev-qty=$ethDevQty"
			)
		}
		test ! -z $(echo -n $uutPn |grep "PE316IS2LBTLB-CX") && {
			assignBuses spc plx acc
			accKern="qat_c62x"
			plxKern="pcieport"
			spcKern=""
			
			let accDevQty=6
			let plxDevQty=2
			let plxDevSubQty=10
			let spcDevQty=2

			baseModel="PE316IS2LBTLB-CX"
			accDevId="37c8"
			plxDevId="37c0"
			spcDevId="37b1"
			
			let accDevSpeed=5
			let accDevWidth=16
			let plxDevSpeed=8
			let plxDevWidth=8
			plxDevSubSpeed="2.5"
			let plxDevSubWidth=1
			spcDevSpeed="2.5"
			let spcDevWidth=1
			
			let rootBusSpeedCap=8
			let rootBusWidthCap=8
			
			pciArgs=(
				"--target-bus=$uutBus"
				"--acc-buses=$accBuses"
				"--plx-buses=$plxBuses"
				"--spc-buses=$spcBuses"

				"--acc-dev-id=$accDevId"
				"--spc-dev-id=$spcDevId"
				"--plx-dev-id=$plxDevId"
				
				"--acc-kernel=$accKern"
				"--spc-kernel=$spcKern"
				"--plx-kernel=$plxKern"
				
				"--acc-dev-qty=$accDevQty"
				"--spc-dev-qty=$spcDevQty"
				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				
				"--acc-dev-speed=$accDevSpeed"
				"--acc-dev-width=$accDevWidth"
				"--spc-dev-speed=$spcDevSpeed"
				"--spc-dev-width=$spcDevWidth"
				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--root-bus-speed=$rootBusSpeedCap"
				"--root-bus-width=$rootBusWidthCap"
				
				"--plx-keyw=Physical Slot"
				"--plx-virt-keyw=UpstreamFwd+"
			)
			# exitFail "UNSUPPORTED" $PROC
		}
		test ! -z $(echo -n $uutPn |grep "PE3ISLBTL-FN") && {
			assignBuses spc eth plx acc
			accKern="qat_c62x"
			ethKern="i40e"
			spcKern=""
			
			accDevQty=3
			ethDevQty=2
			spcDevQty=1

			baseModel="PE3ISLBTL-FN"
			accDevId="37c8"
			ethDevId="37d1"
			spcDevId="37b1"
			ethDevSpeed="2.5"
			let ethDevWidth=1
			let accDevSpeed=5
			let accDevWidth=16
			spcDevSpeed="2.5"
			let spcDevWidth=1
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--acc-buses=$accBuses"
				"--spc-buses=$spcBuses"
				"--eth-buses=$ethBuses"
				"--acc-dev-id=$accDevId"
				"--spc-dev-id=$spcDevId"
				"--eth-dev-id=$ethDevId"
				"--acc-kernel=$accKern"
				"--spc-kernel=$spcKern"
				"--eth-kernel=$ethKern"
				"--acc-dev-qty=$accDevQty"
				"--spc-dev-qty=$spcDevQty"
				"--eth-dev-qty=$ethDevQty"
				
				"--eth-dev-speed=$ethDevSpeed"
				"--eth-dev-width=$ethDevWidth"
				"--acc-dev-speed=$accDevSpeed"
				"--acc-dev-width=$accDevWidth"
				"--spc-dev-speed=$spcDevSpeed"
				"--spc-dev-width=$spcDevWidth"
			)
		}
		
		
		
		
		echoIfExists "  Port count:" "$uutDevQty"
		echoIfExists "  UUT Kern:" "$uutKern"
		echoIfExists "  ACC Kern:" "$accKern"
		echoIfExists "  PLX Kern:" "$plxKern"
		echoIfExists "  SPC Kern:" "$spcKern"
		echoIfExists "  ETH Kern:" "$ethKern"
		echoIfExists "  Base model:" "$baseModel"
		echoIfExists "  Device ID:" "$pciDevId"
		echoIfExists "  ACC device ID:" "$accDevId"
		echoIfExists "  ACC device count:" "$accDevQty"
		echoIfExists "  ACC device speed:" "$accDevSpeed"
		echoIfExists "  ACC device width:" "$accDevWidth"
		
		echoIfExists "  PLX device ID:" "$plxDevId"
		echoIfExists "  PLX device count:" "$plxDevQty"
		echoIfExists "  PLX device count (with subordinate):" "$plxDevSubQty"
		echoIfExists "  PLX device count (empty):" "$plxDevEmptyQty"
		echoIfExists "  PLX device speed:" "$plxDevSpeed"
		echoIfExists "  PLX device width:" "$plxDevWidth"
		echoIfExists "  PLX device (with subordinate) speed:" "$plxDevSubSpeed"
		echoIfExists "  PLX device (with subordinate) width:" "$plxDevSubWidth"
		echoIfExists "  PLX device (empty) speed:" "$plxDevEmptySpeed"
		echoIfExists "  PLX device (empty) width:" "$plxDevEmptyWidth"

		echoIfExists "  SPC device ID:" "$spcDevId"
		echoIfExists "  SPC device count:" "$spcDevQty"
		echoIfExists "  SPC device speed:" "$spcDevSpeed"
		echoIfExists "  SPC device width:" "$spcDevWidth"
		echoIfExists "  Root bus device speed:" "$rootBusSpeedCap"
		echoIfExists "  Root bus device width:" "$rootBusWidthCap"
	} || {
		exitFail "  PN: $uutPn cannot be processed, requirements not defined for this specific model!" $PROC
	}	
	echo -e " Done.\n"
}

checkIfFailed() {
	local curStep severity
	curStep="$1"
	severity="$2"
	test ! -z "$(cat /tmp/statusChk.log | tr '[:lower:]' '[:upper:]' |grep FAIL)" && {
		test "$severity" = "warn" && warn "$curStep" ||	exitFail "$curStep" $PROC
	}
}

pciInfoTest() {
	echoSection "PCI Info"
		warn "\tUUT bus:"
		listDevsPciLib "${pciArgs[@]}" |& tee /tmp/statusChk.log
		#listDevsPci $uutSlotBus |& tee /tmp/statusChk.log
	checkIfFailed "PCI Info failed!"
}

qatTestStart() {
	local devNumForce options
	test -z "$accDevQty" && exitFail "qatTestStart exception, accDevQty undefined!" || {
		test "$accDevQty" = "1" || {
			echo -e "\n  Select device to test:"
			options=("All")
			for ((d=0;d<$accDevQty;d++)); do options=("${options[@]}" "Dev-$d"); done
			case `select_opt "${options[@]}"` in
				0) devNumForce="";;
				*) devNumForce=$(echo ${options[$?]} |cut -c5-);;
			esac
		}
		
		echoSection "Acceleration Test"
			qatTest "/root/QAT17" "$accBuses" $devNumForce|& tee /tmp/statusChk.log
		checkIfFailed "Acceleration Test failed!"
	}
}

mainTest() {
	local options
	echo -e "\n  Select test mode:"
	options=("PCI Info" "QAT Test" "Full test")
	dmsg inform "options=${options[@]}"
	case `select_opt "${options[@]}"` in
		0) pciInfoTest;;
		1) qatTestStart;;
		2) pciInfoTest; qatTestStart;;
		*) exitFail "Unknown option selected" $PROC;;
	esac
}

initialSetup(){
	acquireVal "UUT slot" uutSlotArg uutSlotNum
	acquireVal "Part Number" pnArg uutPn
	test ! -z "echo $uutPn |grep '#'" && uutPn=$(echo $uutPn |cut -d '#' -f2-)
	
	publicVarAssign fatal uutBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $uutSlotNum |tail -n 1)
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	
	
	test "$uutBus" = "ff" && exitFail "Card not detected, uutBus=ff"
	
	defineRequirments
	checkRequiredFiles
}

assignBuses() {
	for ARG in "$@"
	do
		case "$ARG" in
			spc) publicVarAssign critical spcBuses $(grep '1180' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;	
			eth) publicVarAssign critical ethBuses $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			plx) publicVarAssign critical plxBuses $(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			acc) publicVarAssign critical accBuses $(grep '0b40' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			*) echo "Unknown bus: $ARG"
		esac
	done
}

main() {
	echo -e "\n Prep done, main part execution."
		
	test ! -z "$(echo -n $uutBus|grep ff)" && exitFail "UUT or Master invalid slot or not detected! uutBus: $uutBus" $PROC || {
		mainTest
		passMsg "\n\tDone!\n"
	}
}

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
trap "exit 1" 10
PROC="$$"
declareVars
source /root/multiCard/arturLib.sh
echoHeader "$toolName" "$ver"
echoSection "Startup.."
parseArgs "$@"
setEmptyDefaults
initialSetup
startupInit
main
echo -e "See $(inform "--help" "nnl" "sil") for available parameters\n"
