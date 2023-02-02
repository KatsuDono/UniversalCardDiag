#!/bin/bash

declareVars() {
	ver="v0.03"
	toolName='Universal Acceleration Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	declare -a pciArgs=("null" "null")
	declare exitExec=0
	let debugBrackets=0
	let debugShowAssignations=0
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
			test-sel) 
				inform "Launch key: Selected test: ${VALUE}"
				testSelArg=${VALUE}
			;;
			slDupSkp) 
				inform "Launch key: Ignoring slot duplicate (compatability)"
				ignoreSlotDuplicate=1
			;;
			noMasterMode) 
				inform "Launch key: No master mode (compatability)"
				noMasterMode=1
			;;
			minor-launch) 
				inform "Launch key: Minor priority launch mode (compatability)"
				minorLaunch=1
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
			no-dbg-brk) debugBrackets=0 ;;
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
	echo -e " --no-dbg-brk	"
	echo -e "\tNo debug brackets"	
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

installQat() {
	local drvInstallRes
	echo "  Installing QAT$qatVer service"
	drvInstallRes="$(/root/Scripts/qat_update.sh a /root/QAT$qatVer)"
	dmsg inform "$drvInstallRes"
	test -z "$(echo $drvInstallRes |grep 'Acceleration Installation Complete')" && exitFail "Unable to install QAT$qatVer service!" $PROC
}

startQat() {
	local qatStartRes
	echo "  Starting QAT$qatVer service"
	
	qatStartRes="$(/etc/init.d/qat_service start 2>&1)"
	dmsg inform "$qatStartRes"
	test ! -z "$(echo "$qatStartRes" |grep 'No such file')" && installQat
	if [[ ! -e "/dev/qat_adf_ctl" ]]; then
		qatStartRes="$(/etc/init.d/qat_service start 2>&1)"
		dmsg inform "$qatStartRes"
		test ! -z "$(echo "$(/etc/init.d/qat_service start)" |grep 'Failed to configure')" && exitFail "Unable to start QAT$qatVer service!" $PROC
	fi
}

stopQat() {
	local qatStopRes
	echo "  Shutting down QAT$qatVer service"
	qatStopRes="$(/etc/init.d/qat_service shutdown 2>&1)"
	dmsg inform "$qatStopRes"
	if [[ -e "/dev/qat_adf_ctl" ]]; then
		exitFail "Unable to shutdown QAT$qatVer module!" $PROC
	fi
}

initQAT() {
	test ! -z "$1" && {
		qatVer="$1"
		inform "  QAT Ver: $qatVer"
	}
	if [[ ! -e "/etc/init.d/qat_service" ]]; then 
		installQat $qatVer
	fi
	
	test "$(lsmod |grep "intel_qat" |awk '{print $1}' | grep -c '^')" = "3" && {
		echo "  Restarting QAT$qatVer"
		stopQat
		sleep 3
		startQat	
		echo "   Checking QAT$qatVer Status"
		/root/QAT17/quickassist/utilities/adf_ctl/adf_ctl status
	} || {
		sleep 2
		startQat
		echo "   Checking QAT$qatVer Status"
		/root/QAT17/quickassist/utilities/adf_ctl/adf_ctl status
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

P3IMB-M-P1-INIT() {
	warn "  Init is not required for model $baseModel"
	# initQAT 17
}

startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	if [ -z "$skipInit" ]; then
		case "$baseModel" in
			PE3IS2CO3LS) PE3IS2CO3-INIT;;
			PE2ISCO3-CX) PE2ISCO3-CX-INIT;;
			PE3ISLBEL-FN) PE3ISLBEL-FN-INIT;;
			PE3ISLBTL-FU) PE3ISLBTL-FU-INIT;;
			PE3ISLBTL-FN) PE3ISLBTL-FN-INIT;;
			PE316ISLBTL-CX) PE3ISLBTL-FN-INIT;;
			PE3ISLBLL) PE3ISLBLL-INIT;;
			PE316IS2LBTLB-CX) PE316IS2LBTLB-CX-INIT;;
			P3IMB-M-P1) P3IMB-M-P1-INIT;;
			*) exitFail "Undefined startup init for baseModel: $baseModel" $PROC
		esac
	else
		inform "  Skipped init"
	fi
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		"/root/multiCard/arturLib.sh"
		"/root/Scripts"
		"/root/Scripts/qat_update.sh"
	)
	
	case "$baseModel" in
		PE3IS2CO3LS) 
			echo "  File list: PE3IS2CO3LS"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
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
				"/root/QAT17"
				"/root/PE3ISLBTL"
			)
		;;
		PE3ISLBLL) 
			echo "  File list: PE3ISLBLL"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
				"/root/PE3ISLBLL"
			)
		;;
		PE316IS2LBTLB-CX) 
			echo "  File list: PE316IS2LBTLB-CX"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
				"/root/PE316IS2LBTLB-CX"
			)
		;;
		PE3ISLBEL-FN) 
			echo "  File list: PE3ISLBEL-FN"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
				"/root/PE3ISLBEL-FN"
				"/root/PE3ISLBEL-FN/qat_update.sh"
			)
		;;
		PE3ISLBTL-FN) 
			echo "  File list: PE3ISLBTL-FN"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
				"/root/PE3ISLBTL-FN"
				"/root/PE3ISLBTL-FN/qat_update.sh"
			)
		;;
		PE3ISLBTL-FU) 
			echo "  File list: PE3ISLBTL-FU"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
				"/root/PE3ISLBTL-FU"
				"/root/PE3ISLBTL-FU/qat_update.sh"
			)
		;;
		PE316ISLBTL-CX) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/QAT17"
				"/root/PE316ISLBTL-CX"
				"/root/PE316ISLBTL-CX/qat_update.sh"
			)
		;;
		P3IMB-M-P1) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/P3IMB-M-P1"
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
	test ! -z $(echo -n $uutPn |grep -w 'PE3IS2CO3LS\|PE3IS2CO3LS-CX\|PE2ISCO3-CX\|PE3ISLBTL-FU\|PE3ISLBTL-FN\|PE316ISLBTL-CX\|PE3ISLBLL\|PE3ISLBTL\|P3IMB-M-P1-VZ\|PE3ISLBEL-FN\|PE316IS2LBTLB-CX') && {
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
				"--target-bus=$uutBus"
				"--acc-buses=$accBuses"
				"--plx-buses=$plxBuses"

				"--acc-dev-id=$accDevId"
				"--plx-dev-id=$plxDevId"

				"--acc-kernel=$accKern"
				"--plx-kernel=$plxKern"

				"--acc-dev-qty=$accDevQty"
				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-empty-qty=$plxDevEmptyQty"

				"--acc-dev-speed=$accDevSpeed"
				"--acc-dev-width=$accDevWidth"
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
				"--target-bus=$uutBus"
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
				"--target-bus=$uutBus"
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
				"--target-bus=$uutBus"
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
		test ! -z $(echo -n $uutPn |grep "P3IMB-M-P1-VZ") && {
			warn "REQUIRMENTS CAN DIFFER!!! NOT DEFINED FULLY!!!"
			# exitFail "UNSUPPORTED" $PROC
			assignBuses acc
			accKern="qat_c62x"
			let accDevQty=1
			baseModel="P3IMB-M-P1"
			accDevId="0d5c"
			let accDevSpeed=8
			let accDevWidth=16

			pciArgs=(
				"--target-bus=$uutBus"
				"--acc-buses=$accBuses"
				"--acc-dev-id=$accDevId"
				"--acc-kernel=$accKern"
				"--acc-dev-qty=$accDevQty"
				"--acc-dev-speed=$accDevSpeed"
				"--acc-dev-width=$accDevWidth"
				"--no-kern"
			)
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
				"--target-bus=$uutBus"
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
				"--target-bus=$uutBus"
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
		test ! -z $(echo -n $uutPn |grep "PE316ISLBTL-CX") && {
			assignBuses eth plx acc
			accKern="qat_c62x"
			plxKern="pcieport"
			
			accDevQty=3
			ethDevQty=2
			let plxDevQty=1
			let plxDevEmptyQty=5
			
			let plxDevSubQty=0

			baseModel="PE316ISLBTL-CX"
			accDevId="37c8"
			plxDevId="37c0"
			let accDevSpeed=5
			let accDevWidth=16
			let plxDevSpeed=8
			let plxDevWidth=16
			plxDevSubSpeed="2.5"
			let plxDevSubWidth=1
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=1



			pciArgs=(
				"--target-bus=$uutBus"
				"--acc-buses=$accBuses"
				"--plx-buses=$plxBuses"


				"--acc-dev-id=$accDevId"
				"--plx-dev-id=$plxDevId"

				"--acc-kernel=$accKern"
				"--plx-kernel=$plxKern"

				"--acc-dev-qty=$accDevQty"
				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-empty-qty=$plxDevEmptyQty"
				
				"--acc-dev-speed=$accDevSpeed"
				"--acc-dev-width=$accDevWidth"
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
		
		
		
		echoIfExists "  UUT slot bus:" "$uutSlotBus"
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

checkBbdevPassed() {
	if [ ! -z "$(echo "$*"|grep 'Bbdev Test Passed')" ]; then 
		echo -e "\e[0;32mPASSED\e[m"
	else
		echo -e "\e[0;31mFAILED\e[m"
	fi
}

lisbonAccTest() {
	local targSlot allSlots
	targSlot=$1 ; shift
	allSlots=$*
	cd /root/P3IMB-M-P1
	echo -n "    Starting ldpc_dec_HARQ_1627_1.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_1627_1.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_1_0.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_1_0.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_1_1.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_1_1.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_1_2.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_1_2.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_1_3.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_1_3.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_26449_1.loopback_r test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_26449_1.loopback_r $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_26449_1.loopback_w test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_26449_1.loopback_w $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_2_1_llr_comp.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_2_1_llr_comp.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_HARQ_3_1_harq_comp.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_HARQ_3_1_harq_comp.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_qm2_k1944_e32400.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_qm2_k1944_e32400.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v11835.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v11835.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v14298.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v14298.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v2342_drop.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v2342_drop.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v6563.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v6563.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v7813.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v7813.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v8480.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v8480.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v8568.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v8568.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v8568_low.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v8568_low.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_v9503.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_v9503.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_dec_vcrc_fail.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_dec_vcrc_fail.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_c1_k1144_r0_e1380_rm.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_c1_k1144_r0_e1380_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_c1_k1144_r0_e1380_rm_crc24b.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_c1_k1144_r0_e1380_rm_crc24b.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_c1_k330_r0_e360_rm.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_c1_k330_r0_e360_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_c1_k720_r0_e832_rm.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_c1_k720_r0_e832_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_c1_k720_r0_e864_rm_crc24b.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_c1_k720_r0_e864_rm_crc24b.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_c1_k8148_r0_e9372_rm.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_c1_k8148_r0_e9372_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v11835.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v11835.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v2342.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v2342.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v2570_lbrm.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v2570_lbrm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v3964_rv1.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v3964_rv1.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v7813.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v7813.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v8568.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v8568.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting ldpc_enc_v9503.data test: "; cmdRes="$(./test_bbdev_once.sh ldpc_enc_v9503.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_dec_c1_k3136_r0_e4914_sbd_negllr.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_dec_c1_k3136_r0_e4914_sbd_negllr.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_dec_c1_k40_r0_e17280_sbd_negllr.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_dec_c1_k40_r0_e17280_sbd_negllr.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_dec_c1_k6144_r0_e10376_crc24b_sbd_negllr_high_snr.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_dec_c1_k6144_r0_e10376_crc24b_sbd_negllr_high_snr.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_dec_c1_k6144_r0_e10376_crc24b_sbd_negllr_high_snr_crc24bdrop.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_dec_c1_k6144_r0_e10376_crc24b_sbd_negllr_high_snr_crc24bdrop.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_dec_c1_k6144_r0_e10376_crc24b_sbd_negllr_low_snr.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_dec_c1_k6144_r0_e10376_crc24b_sbd_negllr_low_snr.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_dec_c1_k6144_r0_e34560_sbd_negllr.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_dec_c1_k6144_r0_e34560_sbd_negllr.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k40_r0_e1190_rm.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k40_r0_e1190_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k40_r0_e1194_rm.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k40_r0_e1194_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k40_r0_e1196_rm.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k40_r0_e1196_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k40_r0_e272_rm.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k40_r0_e272_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k456_r0_e1380_scatter.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k456_r0_e1380_scatter.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k6144_r0_e120_rm_rvidx.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k6144_r0_e120_rm_rvidx.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k6144_r0_e18444.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k6144_r0_e18444.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
	echo -n "    Starting turbo_enc_c1_k6144_r0_e32256_crc24b_rm.data test: "; cmdRes="$(./test_bbdev_once.sh turbo_enc_c1_k6144_r0_e32256_crc24b_rm.data $targSlot $allSlots 2>&1)"; checkBbdevPassed "$cmdRes"; cmdRes=""
}

lisbonAccTests() {
	echoSection "Lisbon Acceleration Test"
		lisbonAccTest $uutSlotNum $uutSlotNum |& tee /tmp/statusChk.log
	# checkIfFailed "Lisbon Acceleration Test failed!"
}

getThermalLisbon() {
	local slotTTY cmdRes targSlot localTemp
	targSlot=$1
	localTemp="null"
	eastTemp="null"
	westTemp="null"
	vddCoreTemp="null"
	unset thermalDataCsv; thermalDataCsv="null"

	if [ -z "$targSlot" ]; then 
		critWarn "target slot undefined"
	else
		cd /root/P3IMB-M-P1
		echo -n "  Gathering serial name: "
		cmdRes=$(./get_ttyusb.sh $targSlot 0 |grep -m1 '=ttyUSB')
		if [ -z "$cmdRes" ]; then
			critWarn "get_ttyusb result undefined"
		else
			slotTTY=$(echo $cmdRes |cut -d= -f2)
			echo "$slotTTY"
			localTemp=$(./usb_tio_lisbon.sh $slotTTY sensor 1 |grep Num |awk '{print $6}' 2>&1)
			eastTemp=$(./usb_tio_lisbon.sh $slotTTY sensor 2 |grep Num |awk '{print $6}' 2>&1)
			westTemp=$(./usb_tio_lisbon.sh $slotTTY sensor 3 |grep Num |awk '{print $6}' 2>&1)
			vddCoreTemp=$(./usb_tio_lisbon.sh $slotTTY sensor 20 |grep Num |awk '{print $5}' 2>&1)
			if [ -z "$localTemp" ]; then localTemp="ERR"; fi
			if [ -z "$eastTemp" ]; then eastTemp="ERR"; fi
			if [ -z "$westTemp" ]; then westTemp="ERR"; fi
			if [ -z "$vddCoreTemp" ]; then vddCoreTemp="ERR"; fi
			echo "  Thermal data: localTemp=$localTemp  eastTemp=$eastTemp  westTemp=$westTemp  vddCoreTemp=$vddCoreTemp"
			echo "  "thermalDataCsv="$localTemp;$eastTemp;$westTemp;$vddCoreTemp"
		fi
	fi
}

thermalInfo() {
	case "$baseModel" in
		PE3IS2CO3LS) critWarn "Undefined for $baseModel";;
		PE2ISCO3-CX) critWarn "Undefined for $baseModel";;
		PE3ISLBEL-FN) critWarn "Undefined for $baseModel";;
		PE3ISLBTL-FU) critWarn "Undefined for $baseModel";;
		PE3ISLBTL-FN) critWarn "Undefined for $baseModel";;
		PE316ISLBTL-CX) critWarn "Undefined for $baseModel";;
		PE3ISLBLL) critWarn "Undefined for $baseModel";;
		PE316IS2LBTLB-CX) critWarn "Undefined for $baseModel";;
		P3IMB-M-P1) getThermalLisbon "$@" ;;
		*) critWarn "Unable to gather thermal data for baseModel: $baseModel, undefined"
	esac
}

mainTest() {
	local options pciTest qatTest fullTest

	if [ -z "$testSelArg" ]; then
		echo -e "\n  Select test mode:"
		options=("PCI Info" "QAT Test" "Full test")
		dmsg inform "options=${options[@]}"
		case `select_opt "${options[@]}"` in
			0) pciInfoTest;;
			1) qatTestStart;;
			2) pciInfoTest; qatTestStart;;
			*) exitFail "Unknown option selected" $PROC;;
		esac
	else
		if [[ ! -z $(echo -n $testSelArg |grep "pciTest\|qatTest\|lisbonTest\|lisbonPciTest\|thermalData\|fullTest") ]]; then
			case "$testSelArg" in
				pciTest) 		pciInfoTest ;;
				qatTest) 		qatTestStart ;;
				lisbonTest)		lisbonAccTests ;;
				lisbonPciTest)	pciInfoTest; lisbonAccTests; pciInfoTest;;
				thermalData) 	thermalInfo $uutSlotNum ;;
				fullTest) 		pciInfoTest; qatTestStart ;;
				*) except "Unknown testSelArg: $testSelArg"
			esac
		else
			except "testSelArg is not in allowed test names region"
		fi
	fi
}

initialSetup(){
	# acquireVal "UUT slot" uutSlotArg uutSlotNum

	if [[ -z "$uutSlotArg" ]]; then 
		selectSlot "  Select UUT:"
		uutSlotNum=$?
		dmsg inform "uutSlotNum=$uutSlotNum"
	else acquireVal "UUT slot" uutSlotArg uutSlotNum; fi

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
			acc) publicVarAssign critical accBuses $(grep '0b40\|1200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			gen) publicVarAssign critical allBuses $(ls -l /sys/bus/pci/devices/ |grep $uutSlotBus |awk -F/ '{print $(NF)}' |grep -v $uutSlotBus |cut -d: -f2-)	;;
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

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tacc_diag_lib has been loaded as lib (support: arturd@silicom.co.il)'
else
	echo -e '\n# arturd@silicom.co.il\n\n'
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
	if [ -z "$minorLaunch" ]; then echo -n " See "; echo -n $(inform --nnl --sil "--help"); echo -e " for available parameters\n"; fi
fi
