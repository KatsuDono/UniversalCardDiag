#!/bin/bash

declareVars() {
	ver="v0.02"
	toolName='X710 BP Link Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	declare -a pciArgs=("null" "null")
	declare -a mastPciArgs=("null" "null")
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
			master-slot-num) masterSlotArg=${VALUE} ;;
			uut-pn) pnArg=${VALUE} ;;
			igonre-dumps-fail) ignDumpFail=1;;
			skip-init) skipInit=1;;
			silent) silentMode=1 ;;
			debug) debugMode=1 ;;
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
	echo -e " --master-slot-num=NUMBER"
	echo -e "\tPN of UUT\n"
	echo -e " --uut-pn=NUMBER"	
	echo -e "\tUse specific slot for traffic generation card\n"	
	echo -e " --skip-init"	
	echo -e "\tDoes not initializes the card\n"	
	echo -e " --silent"
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"		
	echo -e " --no-dbg-brk	"
	echo -e "\tNo debug brackets"	
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	echo -e " Setting defaults.."
	publicVarAssign warn globLnkUpDel "0.3"
	publicVarAssign warn globLnkAcqRetr "7"
	publicVarAssign warn globRtAcqRetr "7"
	echo -e " Done.\n"
}

preInitBpStartup() {
	echo "  Loading SLCM module"
	test -z "$(lsmod |grep slcmi_mod)" && slcm_start 2>&1 > /dev/null	
	echo "  Loading BPCtl module"
	test -z "$(lsmod |grep bpctl_mod)" && bpctl_start 2>&1 > /dev/null
	echo "  Loading BPRDCtl module"
	testFileExist "/dev/bprdctl0" "true" "silent"
	test "$?" = "0" && {
		test -z "$(lsmod |grep bprdctl_mod)" && bprdctl_start 2>&1 > /dev/null
	} || {
		inform "  BPRDCtl dev not found!"
	}
}

bpi71SrInit() {
	echo "  Loading i40e module"
	test -z "$(lsmod |grep i40e)" && ./loadmod.sh i40e 2>&1 > /dev/null
	echo "  Reseting all BP switches"
	bpctl_util all set_bp_manuf  2>&1 > /dev/null
	bpctl_util all set_bypass off 2>&1 > /dev/null
}

g4dbirInit() {
	echo "  Loading fm10k module"
	test -z "$(lsmod |grep $ethKern)" && {
		drvInstallRes="$(/root/PE310G4DBIR/iqvlinux.sh 2>&1)"
		test -z "$(echo $drvInstallRes |grep Passed)" && exitFail "Unable to install Intel driver!"
	}
	
	echo "  Compiling and installing fm10k module"
	if [[ ! -e "/root/PE310G4DBIR/fm10k-0.27.1.sl.3.12/src/fm10k.ko" ]]; then 
		drvInstallRes="$(/root/PE310G4DBIR/setup_ethernet.sh /root/PE310G4DBIR/fm10k-0.27.1.sl.3.12.tar.gz)"
		test -z "$(echo $drvInstallRes |grep 'Shell Script Complete Passed')" && exitFail "Unable to compile and install fm10k module!"
	fi
	
	echo "  Remounting fm10k module"
	drvInstallRes="$(rdif stop; rmmod $ethKern;insmod /root/PE310G4DBIR/fm10k.ko;echo status=$?)"
	#
	#drvInstallRes="$(rdif stop; rmmod $ethKern;insmod /root/PE310G4DBIR/fm10k-0.27.1.sl.3.12/src/fm10k.ko;echo status=$?)"
	test -z "$(echo $drvInstallRes |grep 'status=0')" && warn "Unable to Remounting fm10k module!"
	
	echo "  Compiling and installing bypass control module"
	test "$(which bprdctl_util)" = "/usr/bin/bprdctl_util" || {
		drvInstallRes="$(/root/PE310G4DBIR/setup_bypass.sh /root/PE310G4DBIR/bprd_ctl-1.0.17.tar.gz)"
		test -z "$(echo $drvInstallRes |grep 'Shell Script Complete Passed')" && exitFail "Unable to install bypass control module!"
	}
	
	echo "  Starting bypass control module"
	test -z "$(lsmod |grep -w bprdctl_mod)" && {
		test "$(bprdctl_start; echo -n $?)" = "0" || exitFail "Unable to start bypass control module!"
	}
	
	echo "  Reseting all BP switches to default configuration"
	test -z "$(bprdctl_util all set_bp_manuf |grep fail)" || exitFail "Unable to reset BP switches to default configuration!"
	
	echo "  Switching all BP switches to inline mode"
	test -z "$(bprdctl_util all set_bypass off |grep fail)" || exitFail "Unable to BP switches to inline mode!"	
		
	echo "  Setting up redirector control"
	test "$(which rdifctl)" = "/usr/bin/rdifctl" || {
		drvInstallRes="$(/root/PE310G4DBIR/setup_director.sh /root/PE310G4DBIR/rdif-6.0.10.7.33.6.3.tar.gz)"
		test -z "$(echo $drvInstallRes |grep 'Shell Script Complete Passed')" && exitFail "Unable to setup redirector control!"
	}
	
	echo "  Switching all BP switches to inline mode"
	test -z "$(bprdctl_util all set_bypass off |grep fail)" || exitFail "Unable to BP switches to inline mode!"	
	
	echo "  Starting RDIF"
	rdifStartRes="$(/root/PE310G4DBIR/rdif_bpstart.sh ./ $uutSlotNum)"
	test -z "$(echo "$rdifStartRes" |grep -w "RDIFD Passed")" && {
		warn "  Unable to starting RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	}
	
	echo "  Configuring RDIF"
	rdifStartRes="$(/root/PE310G4DBIR/rdif_config1vf4_mod.sh 2 2 $uutSlotNum $uutSlotNum $uutSlotNum)"
	test -z "$(echo "$rdifStartRes" |grep -w "Rdif Config Passed")" && {
		warn "  Unable to configure RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "Paired_Device=0")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	}
	
	echo "  Reassigning nets"
	assignNets
	
	echo "  Reassigning UUT buses"
	assignBuses eth bp
	
	echo "  Defining PCi args"
	dmsg inform "DEBUG1: ${pciArgs[@]}"
	pciArgs=(
		"--target-bus=$uutSlotBus"
		
		"--eth-buses=$ethBuses"
		"--bp-buses=$bpBuses"
		
		"--eth-dev-id=$physEthDevId"
		"--eth-virt-dev-id=$virtEthDevId"
		
		"--eth-dev-qty=$physEthDevQty"
		"--eth-virt-dev-qty=$virtEthDevQty"
		"--bp-dev-qty=$uutBpDevQty"
		
		"--eth-kernel=$ethKern"
		"--eth-virt-kernel=$ethVirtKern"
		"--bp-kernel=$ethKern"
		
		"--eth-dev-speed=$physEthDevSpeed"
		"--eth-dev-width=$physEthDevWidth"
		"--eth-virt-dev-speed=$virtEthDevSpeed"
		"--eth-virt-dev-width=$virtEthDevWidth"
		
		
		"--bp-dev-speed=$virtEthDevSpeed"
		"--bp-dev-width=$virtEthDevWidth"
	)
	dmsg inform "DEBUG2: ${pciArgs[@]}"
}

pe325g2i71Init() {
	echo "  Loading i40e module"
	test -z "$(lsmod |grep i40e)" && ./loadmod.sh i40e 2>&1 > /dev/null
	inform "  Forcing scripts update"
	syncFilesFromServ "$syncPn" "$baseModel" "forced"
}

pe31625gi71lInit() {
	inform "  Raising global link up delay to 5 seconds"
	#publicVarAssign warn globLnkUpDel "5"
}
m4E310g4i71Init() {
	echo "  Loading i40e module"
	test -z "$(lsmod |grep i40e)" && ./loadmod.sh i40e 2>&1 > /dev/null
}

startupInit() {
	local drvInstallRes
	echo -e " StartupInit.."
	test "$skipInit" = "1" || {
		echo "  Searching $baseModel init sequence.."
		case "$baseModel" in
			PE310G4BPI71-SR) bpi71SrInit;;
			PE310G2BPI71-SR) bpi71SrInit;;
			PE310G4DBIR) g4dbirInit;;
			PE210G2BPI9) bpi71SrInit;;
			PE325G2I71) pe325g2i71Init;;
			PE31625G4I71L)	pe31625gi71lInit;;
			M4E310G4I71)	m4E310g4i71Init;;
			*) exitFail "Unknown baseModel: $baseModel"
		esac
	}
	echo -e "  Initializing master"
	bpi71SrInit
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		"/root/PE310G4BPI71/library.sh"
		"/root/multiCard/arturLib.sh"
	)
	
	case "$baseModel" in
		PE310G4BPI71-SR) 
			echo "  File list: PE310G4BPI71-SR"						
		;;
		PE310G2BPI71-SR) 
			echo "  File list: PE310G2BPI71-SR"
		;;
		PE310G4DBIR) 
			echo "  File list: PE310G4DBIR"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE310G4DBIR"
				"/root/PE310G4DBIR/iqvlinux.sh" 
				"/root/PE310G4DBIR/setup_ethernet.sh"
				"/root/PE310G4DBIR/fm10k-0.27.1.sl.3.12.tar.gz"
				"/root/PE310G4DBIR/setup_bypass.sh"
				"/root/PE310G4DBIR/bprd_ctl-1.0.17.tar.gz"
				"/root/PE310G4DBIR/setup_director.sh"
				"/root/PE310G4DBIR/rdif-6.0.10.7.33.6.3.tar.gz"
				"/root/PE310G4DBIR/iplinkup.sh"
				"/root/PE310G4DBIR/rdif_config1vf4_mod.sh"
				"/root/PE310G4DBIR/fm10k.ko"
			)
		;;
		PE210G2BPI9) 
			echo "  File list: PE210G2BPI9"
		;;
		PE325G2I71) 
			echo "  File list: PE325G2I71"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE325G2I71"
				"/root/PE325G2I71/ispcitxgenoneg1.sh"
				"/root/PE325G2I71/library.sh"
			)
		;;
		PE31625G4I71L) 
			echo "  File list: PE31625G4I71L-XR-CX"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE31625G4I71L"
			)
		;;
		M4E310G4I71) 
			echo "  File list: M4E310G4I71"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/M4E310G4I71"
			)
		;;
		*) exitFail "Unknown baseModel: $baseModel"
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

setupLinks() {
	local allNets linkSetup baseModelLocal
	allNets=$1
	test -z "$allNets" && warn "No nets were detected! Is firmware flashed?" || {
		echo -e "  Initializing nets: "$allNets
		test ! -z "$(echo -n "$mastNets" |grep "$allNets")" && baseModelLocal="$mastBaseModel" || baseModelLocal="$baseModel"
		case "$baseModelLocal" in
			PE310G4BPI71-SR) linkSetup=$(link_setup $allNets);;
			PE310G2BPI71-SR) linkSetup=$(link_setup $allNets);;
			PE310G4DBIR) linkSetup="$(/root/PE310G4DBIR/iplinkup.sh $uutSlotNum)";;
			PE210G2BPI9) linkSetup=$(link_setup $allNets);;
			PE325G2I71) linkSetup=$(link_setup $allNets);;
			PE31625G4I71L) linkSetup=$(link_setup $allNets);;
			M4E310G4I71) linkSetup=$(link_setup $allNets);;
			*) exitFail "setupLinks exception, unknown baseModelLocal: $baseModelLocal"
		esac		
		test -z "$(echo $linkSetup |grep "Failed")" || echo -e "\e[0;31m   Link setup failed!\e[m" && echo -e "\e[0;32m   Link setup passed.\e[m"	
	}
}

trafficTest() {
	local pcktCnt dropAllowed slotNum pn portQty sendDelay queryCnt orderFile execFile sourceDir rootDir buffSize
	privateVarAssign "trafficTest" "slotNum" "$1"
	shift
	privateVarAssign "trafficTest" "pcktCnt" "$1"
	shift 
	privateVarAssign "trafficTest" "pn" "$1"
	
	echo -e "\tTraffic tests (profile $pn): \n"
	
	case "$pn" in
		PE310G4BPI71-SR) inform "Traffic test is not defined for $baseModel";;
		PE310G2BPI71-SR) inform "Traffic test is not defined for $baseModel";;
		PE310G4DBIR) inform "Traffic test is not defined for $baseModel";;
		PE210G2BPI9) inform "Traffic test is not defined for $baseModel";;
		PE325G2I71) 
			portQty=2
			sendDelay=0x0
			queryCnt=1
			rootDir="/root/PE325G2I71"
			orderFile="order"
			echo -n "1 2" >$rootDir/$orderFile
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"
			execFile="./ispcitxgenoneg1.sh"
			dmsg inform "$pcktCnt $sendDelay $queryCnt $portQty $orderFile $slotNum"
			execScript "$execFile" "$pcktCnt $sendDelay $queryCnt $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"
			#trfSendRes=$($execFile $pcktCnt $sendDelay $queryCnt $portQty $orderFile $slotNum 2>&1)
			#echo "$trfSendRes"
		;;
		PE31625G4I71L) inform "Traffic test is not defined for $baseModel";;
		M4E310G4I71) 
			portQty=4
			sendDelay=0x0
			buffSize=4096
			rootDir="/root/M4E310G4I71"
			orderFile="order"
			echo -n "1 2 3 4" >$rootDir/$orderFile
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"
			execFile="./pcitxgenohup1.sh"
			dmsg inform "$pcktCnt $sendDelay $buffSize $portQty $orderFile $slotNum" #Bus Error Test Failed
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"
			write_err
		;;
		*) warn "trafficTest exception, unknown pn: $pn"
	esac
	
	cd "$sourceDir"
	
	# 
}

defineRequirments() {
	echo -e "\n Defining requirements.."
	test -z "$uutPn" && exitFail "Requirements cant be defined, empty uutPn"
	if [[ ! -z $(echo -n $uutPn |grep "PE310G4BPI71-SR\|PE310G2BPI71-SR\|PE310G4DBIR\|PE210G2BPI9\|PE325G2I71\|PE31625G4I71L-XR-CX\|M4E310G4I71-XR-CP") ]]; then
		dmsg inform "DEBUG1: ${pciArgs[@]}"
		
		test ! -z $(echo -n $uutPn |grep "PE310G4BPI71-SR") && {
			ethKern="i40e"
			let physEthDevQty=4
			let bpDevQty=2
			verDumpOffset="0x817"
			let verDumpLen=5
			pnDumpOffset="0x850"
			let pnDumpLen=28
			pnRevDumpOffset="0x86C"
			let pnRevDumpLen=4
			tnDumpOffset="0x880"
			let tnDumpLen=13
			tdDumpOffset="0x872"
			let tdDumpLen=6
			baseModel="PE310G4BPI71-SR"
			syncPn="PE310G4BPI71-SR"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth bp
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--eth-buses=$ethBuses"
				"--eth-dev-id=$physEthDevId"
				"--eth-kernel=$ethKern"
				"--eth-dev-qty=$physEthDevQty"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
				"--bp-buses=$bpBuses"
				"--bp-kernel=$ethKern"
				"--bp-dev-qty=$bpDevQty"
				"--bp-dev-speed=$physEthDevSpeed"
				"--bp-dev-width=$physEthDevWidth"
			)
		} 

		test ! -z $(echo -n $uutPn |grep "PE310G2BPI71-SR") && { 
			ethKern="i40e"
			let uutDevQty=2
			let uutNetQty=2
			let uutBpDevQty=1
			verDumpOffset="0x817"
			let verDumpLen=5
			pnDumpOffset="0x850"
			let pnDumpLen=28
			pnRevDumpOffset="0x86C"
			let pnRevDumpLen=4	
			tnDumpOffset="0x880"
			let tnDumpLen=13
			tdDumpOffset="0x872"
			let tdDumpLen=6
			baseModel="PE310G2BPI71-SR"
			pciDevId="1572"
			bpCtlMode="bpctl"
		}
		
		test ! -z $(echo -n $uutPn |grep "PE310G4DBIR") && {
			
			ethKern="fm10k"
			ethVirtKern="fm10k"
			let uutDevQty=5
			let uutNetQty=5
			let uutBpDevQty=2
			let physEthDevQty=1
			let virtEthDevQty=4
			baseModel="PE310G4DBIR"
			syncPn="PE310G4DBIR"
			physEthDevId="15A4"
			virtEthDevId="15A5"
			let physEthDevSpeed=8
			let physEthDevWidth=8
			virtEthDevSpeed="unknown"
			let virtEthDevWidth=0
			vpdPnDumpAddr="0x304"
			rrcChipDumpAddr="0x452"
			vpdPnDumpExp="0xae21"
			rrcChipDumpExp="0x1"
			bpCtlMode="bprdctl"
		}
		
		# test ! -z $(echo -n $uutPn |grep "PE210G2BPI9-SR") && {
			# ethKern="ixgbe"
			# let physEthDevQty=2
			# let bpDevQty=1
			# baseModel="PE210G2BPI9-SR"
			# syncPn="PE210G2BPI9-SR"
			# physEthDevId="10fb"
			# let physEthDevSpeed=5
			# let physEthDevWidth=8
			# assignBuses eth bp
			# dmsg inform "DEBUG1: ${pciArgs[@]}"
			# pciArgs=(
				# "--target-bus=$uutSlotBus"
				# "--eth-buses=$ethBuses"
				# "--eth-dev-id=$physEthDevId"
				# "--eth-kernel=$ethKern"
				# "--eth-dev-qty=$physEthDevQty"
				# "--eth-dev-speed=$physEthDevSpeed"
				# "--eth-dev-width=$physEthDevWidth"
				# "--bp-buses=$ethBuses"
				# "--bp-kernel=$ethKern"
				# "--bp-dev-qty=$physEthDevQty"
				# "--bp-dev-speed=$physEthDevSpeed"
				# "--bp-dev-width=$physEthDevWidth"
			# )
			# dmsg inform "DEBUG2: ${pciArgs[@]}"
		# }
										  
		test ! -z $(echo -n $uutPn |grep "PE210G2BPI9") && {
			ethKern="ixgbe"
			let physEthDevQty=2
			let bpDevQty=1
			baseModel="PE210G2BPI9"
			syncPn="PE210G2BPI9"
			physEthDevId="10fb"
			
			let physEthDevSpeed=5
			let physEthDevWidth=8
			
			
			verDumpOffset="0x3F73"
			let verDumpLen=5
			pnDumpOffset="0x3FB0"
			let pnDumpLen=28
			pnRevDumpOffset="0x3FCC"
			let pnRevDumpLen=4	
			tnDumpOffset="0x3FE0"
			let tnDumpLen=13
			tdDumpOffset="0x3FD8"
			let tdDumpLen=6
			bpCtlMode="bpctl"
			
			assignBuses eth bp
			dmsg inform "DEBUG1: ${pciArgs[@]}"
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--eth-buses=$ethBuses"
				"--eth-dev-id=$physEthDevId"
				"--eth-kernel=$ethKern"
				"--eth-dev-qty=$physEthDevQty"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
				"--bp-buses=$ethBuses"
				"--bp-kernel=$ethKern"
				"--bp-dev-qty=$physEthDevQty"
				"--bp-dev-speed=$physEthDevSpeed"
				"--bp-dev-width=$physEthDevWidth"
			)
			dmsg inform "DEBUG2: ${pciArgs[@]}"
		}
		
		test ! -z $(echo -n $uutPn |grep "PE325G2I71") && {
			ethKern="i40e"
			let physEthDevQty=2
			baseModel="PE325G2I71"
			syncPn="PE325G2I71"
			physEthDevId="158b"
			
			verDumpOffset="0x817"
			let verDumpLen=5
			pnDumpOffset="0x850"
			let pnDumpLen=28
			pnRevDumpOffset="0x86C"
			let pnRevDumpLen=4
			tnDumpOffset="0x880"
			let tnDumpLen=13
			tdDumpOffset="0x872"
			let tdDumpLen=6
			bpCtlMode="bpctl"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth
			dmsg inform "DEBUG1: ${pciArgs[@]}"
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--eth-buses=$ethBuses"
				"--eth-dev-id=$physEthDevId"
				"--eth-kernel=$ethKern"
				"--eth-dev-qty=$physEthDevQty"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
			)
			dmsg inform "DEBUG2: ${pciArgs[@]}"
		}

		test ! -z $(echo -n $uutPn |grep "PE31625G4I71L-XR-CX") && {
			ethKern="i40e"
			let physEthDevQty=4
			verDumpOffset="0x817"
			let verDumpLen=5
			pnDumpOffset="0x850"
			let pnDumpLen=28
			pnRevDumpOffset="0x86C"
			let pnRevDumpLen=4
			tnDumpOffset="0x880"
			let tnDumpLen=13
			tdDumpOffset="0x872"
			let tdDumpLen=6
			baseModel="PE31625G4I71L"
			syncPn="PE31625G4I71L"
			physEthDevId="158b"
			bpCtlMode="bpctl"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth
			dmsg inform "DEBUG1: ${pciArgs[@]}"
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--eth-buses=$ethBuses"
				"--eth-dev-id=$physEthDevId"
				"--eth-kernel=$ethKern"
				"--eth-dev-qty=$physEthDevQty"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
			)
			dmsg inform "DEBUG2: ${pciArgs[@]}"
		}

		test ! -z $(echo -n $uutPn |grep "M4E310G4I71-XR-CP") && {
			ethKern="i40e"
			let physEthDevQty=4
			verDumpOffset="0x817"
			let verDumpLen=5
			pnDumpOffset="0x850"
			let pnDumpLen=28
			pnRevDumpOffset="0x86C"
			let pnRevDumpLen=4
			tnDumpOffset="0x880"
			let tnDumpLen=13
			tdDumpOffset="0x872"
			let tdDumpLen=6
			baseModel="M4E310G4I71"
			syncPn="M4E310G4I71"
			physEthDevId="1572"
			bpCtlMode="bpctl"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth
			dmsg inform "DEBUG1: ${pciArgs[@]}"
			pciArgs=(
				"--target-bus=$uutSlotBus"
				"--eth-buses=$ethBuses"
				"--eth-dev-id=$physEthDevId"
				"--eth-kernel=$ethKern"
				"--eth-dev-qty=$physEthDevQty"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
			)
			dmsg inform "DEBUG2: ${pciArgs[@]}"
		}
		
		
		echoIfExists "  Port count:" "$uutDevQty"
		echoIfExists "  Net count:" "$uutNetQty"
		echoIfExists "  BP count:" "$uutBpDevQty"
		echoIfExists "  Physical Ethernet device count:" "$physEthDevQty"
		echoIfExists "  Virtual Ethernet device count:" "$virtEthDevQty"
		echoIfExists "  UUT Physical Ethernet Kernel:" "$ethKern"
		echoIfExists "  UUT Virtual Ethernet Kernel:" "$ethVirtKern"
		echoIfExists "  Version dump offset:" "$verDumpOffset"
		echoIfExists "  Version dump length:" "$verDumpLen"
		echoIfExists "  PN dump offset:" "$pnDumpOffset"
		echoIfExists "  PN dump length:" "$pnDumpLen"
		echoIfExists "  PN Rev dump offset:" "$pnRevDumpOffset"
		echoIfExists "  PN Rev dump length:" "$pnRevDumpLen"
		echoIfExists "  TN dump offset:" "$tnDumpOffset"
		echoIfExists "  TN dump length:" "$tnDumpLen"	
		echoIfExists "  Chip version offset:" "$chipVerOffset"
		echoIfExists "  VPD PN dump address:" "$vpdPnDumpAddr"
		echoIfExists "  RRC Chip dump address:" "$rrcChipDumpAddr"
		echoIfExists "  VPD PN dump expected:" "$vpdPnDumpExp"
		echoIfExists "  RRC Chip dump expected:" "$rrcChipDumpExp"
		echoIfExists "  Test date dump offset:" "$tdDumpOffset"
		echoIfExists "  Test date dump length:" "$tdDumpLen"	
		echoIfExists "  Base model:" "$baseModel"
		echoIfExists "  Sync model:" "$syncPn"
		echoIfExists "  Device ID:" "$pciDevId"
		echoIfExists "  Virtual Device ID:" "$pciVirtDevId"
		echoIfExists "  Physical Ethernet device ID:" "$physEthDevId"
		echoIfExists "  Virtual Ethernet device ID:" "$virtEthDevId"
		echoIfExists "  Physical Ethernet device speed:" "$physEthDevSpeed"
		echoIfExists "  Physical Ethernet device width:" "$physEthDevWidth"
		echoIfExists "  Virtual Ethernet device speed:" "$virtEthDevSpeed"
		echoIfExists "  Virtual Ethernet device width:" "$virtEthDevWidth"
		dmsg inform "DEBUG2: ${pciArgs[@]}"
	else
		exitFail "  PN: $uutPn cannot be processed, requirements not defined"
	fi
	
	echo -e "  Defining requirements for the master"
	let mastPciSpeedReq=8
	let mastPciWidthReq=8
	let mastDevQty=4
	let mastBpDevQty=2
	let mastNetQty=4
	
	verDumpOffset_mast="0x817"
	let verDumpLen_mast=5
	pnDumpOffset_mast="0x850"
	let pnDumpLen_mast=28
	pnRevDumpOffset_mast="0x86C"
	let pnRevDumpLen_mast=4
	tnDumpOffset_mast="0x880"
	let tnDumpLen_mast=13
	tdDumpOffset_mast="0x872"
	let tdDumpLen_mast=6
	
	mastBaseModel="PE310G4BPI71-SR"
	mastDevId=1572
	mastKern="i40e"
	
	mastPciArgs=("--target-bus=$mastSlotBus"
			"--eth-buses=$mastEthBuses"
			"--eth-dev-id=$mastDevId"
			"--eth-kernel=$mastKern"
			"--eth-dev-qty=$mastDevQty"
			"--eth-dev-speed=$mastPciSpeedReq"
			"--eth-dev-width=$mastPciWidthReq"
			"--bp-buses=$mastBpBuses"
			"--bp-dev-id=$mastDevId"
			"--bp-dev-qty=$mastBpDevQty"
			"--bp-kernel=$mastKern"
			"--bp-dev-speed=$mastPciSpeedReq"
			"--bp-dev-width=$mastPciWidthReq")
	
	echo "   mastPciSpeedReq=$mastPciSpeedReq"
	echo "   mastPciWidthReq=$mastPciWidthReq"
	echo "   mastDevQty=$mastDevQty"
	echo "   mastBpDevQty=$mastBpDevQty"
	echo "   mastDevId=$mastDevId"
	echo "   mastNetQty=$mastNetQty"
	echo "   mastKern=$mastKern"
	echo "   mastBaseModel=$mastBaseModel"
	echo "   verDumpOffset_mast=$verDumpOffset_mast"
	echo "   verDumpLen_mast=$verDumpLen_mast"
	echo "   pnDumpOffset_mast=$pnDumpOffset_mast"
	echo "   pnDumpLen_mast=$pnDumpLen_mast"
	echo "   pnRevDumpOffset_mast=$pnRevDumpOffset_mast"
	echo "   pnRevDumpLen_mast=$pnRevDumpLen_mast"
	echo "   tnDumpOffset_mast=$tnDumpOffset_mast"
	echo "   tnDumpLen_mast=$tnDumpLen_mast"
	echo "   tdDumpOffset_mast=$tdDumpOffset_mast"
	echo "   tdDumpLen_mast=$tdDumpLen_mast"
	echo -e "  Done."
	
	echo -e " Done.\n"
}

checkBpFw() {
	local eth bpMode bpfw bpName
	publicVarAssign critical "eth" "$1"
	publicVarAssign critical "bpMode" "$2"
	
	test "$bpMode" = "bpctl" && {
		test -z "$(which bpctl_util)" || {
			bpctl_start > /dev/null 2>&1
			bpfw=$(bpctl_util $eth get_bypass_info |grep Firmware |awk -F' ' '{print $NF}')
			test -z "$bpfw" && warn "  Unable to get FW Version" || {
				test ! -z $(echo -n $bpfw |grep "0xff\|0xff") && exitFail "  BP FW Version: $bpfw" || echo "  BP FW Version: $bpfw"
			}
			bpfw=$(bpctl_util $eth get_bypass_build |grep Firmware |awk -F' ' '{print $NF}')
			test -z "$bpfw" && warn "  Unable to get FW Build" || {
				test ! -z $(echo -n $bpfw |grep "0xff\|0xff") && exitFail "  BP FW Build: $bpfw" || echo "  BP FW Build: $bpfw"
			}
		}
	} || {
		test -z "$(which bprdctl_util)" || {
			bprdctl_start > /dev/null 2>&1
			bpfw=$(bprdctl_util $eth get_bypass_info |grep Firmware |awk -F' ' '{print $NF}')
			bpName=$(bprdctl_util $eth get_bypass_info |grep Name |awk -F' ' '{print $NF}')
			test -z "$bpfw" && warn "  Unable to get FW Version" || echo "  BP FW Version: $bpfw"
			test -z "$bpName" && warn "  Unable to get Name" || echo "  Name: $bpName"
		}
	}
}

switchBP() {
	local bpBus newState bpCtlCmd baseModelLocal
	privateVarAssign "switchBP" "bpBus" "$1"
	privateVarAssign "switchBP" "newState" "$2"
	test ! -z "$(echo -n $mastBpBuses |grep $bpBus)" && baseModelLocal="$mastBaseModel" || baseModelLocal="$baseModel"
	case "$baseModelLocal" in
		PE310G4BPI71-SR) bpCtlCmd="bpctl_util";;
		PE310G2BPI71-SR) bpCtlCmd="bpctl_util";;
		PE310G4DBIR) bpCtlCmd="bprdctl_util";;
		PE210G2BPI9) bpCtlCmd="bpctl_util";;
		*) exitFail "Unknown baseModel: $baseModelLocal"
	esac
	test ! -z "$(echo $bpBuses$mastBpBuses |grep $bpBus)" && {
		case "$newState" in
			inline) {
				bpctlRes=$($bpCtlCmd $bpBus set_bypass off)
				dmsg inform "\t DEBUG: $bpctlRes"
				test ! -z "$(echo $bpctlRes |grep successfully)" &&	{
					echo -e -n "\t$bpBus: Set to inline mode"
					sleep 0.1
					bpctlRes=$($bpCtlCmd $bpBus get_bypass |cut -d ' ' -f6-)
					test ! -z "$(echo "$bpctlRes" |grep 'non-Bypass')" && bpctlRes="\e[0;32minline\e[m" ||  bpctlRes="\e[0;31mbypass\e[m"
					echo -e ", checking: $bpctlRes mode"
				} || exitFail "\t$bpBus: was unable to set to inline mode!"
			} ;;	
			bp) {
				bpctlRes=$($bpCtlCmd $bpBus set_bypass on)
				test ! -z "$(echo $bpctlRes |grep successfully)" &&	{
					echo -e -n "\t$bpBus: Set to bypass mode"
					sleep 0.1
					bpctlRes=$($bpCtlCmd $bpBus get_bypass |cut -d ' ' -f6-)
					test ! -z "$(echo "$bpctlRes" |grep 'non-Bypass')" && bpctlRes="\e[0;31minline\e[m" ||  bpctlRes="\e[0;32mbypass\e[m"
					echo -e ", checking: $bpctlRes mode"
				} || exitFail "\t$bpBus: was unable to set to bypass mode!"
			} ;;	
			*) exitFail "switchBP exception, unknown state: $newState"
		esac	
	} || exitFail "switchBP exception, bpBus is not in uutBpBuses or mastBpBuses"
}

allNetTests() {
	local nets netsDesc bpState uutModel
	privateVarAssign "allNetTests" "nets" "$1"
	privateVarAssign "allNetTests" "netsDesc" "$2"
	privateVarAssign "allNetTests" "bpState" "$3"
	privateVarAssign "allNetTests" "uutModel" "$4"
	allNetAct "$nets" "Check links are UP on $netsDesc ($bpState)" "testLinks" "yes" "$uutModel"
	allNetAct "$nets" "Check Data rates on $netsDesc" "getEthRates" "10000" "$uutModel"
	#allNetAct "$nets" "Check Selftest on $netsDesc" "getEthSelftest" --noargs
}

allBPBusMode() {
	local bpBuses bpBus bpMode
	bpBuses="$1"
	bpMode="$2"
	for bpBus in $bpBuses; do switchBP "$bpBus" "$bpMode"; done
	echo -e -n "\n"
}

netInfoDump() {
	local pnDumpRes verDumpRes pnRevDumpRes tnDumpRes tnDumpResCut tdDumpRes tdDumpResDate net netDesc baseModelLocal
	local verDumpOffsetLocal verDumpLenLocal pnDumpOffsetLocal pnDumpLenLocal pnRevDumpOffsetLocal pnRevDumpLenLocal tnDumpOffsetLocal tnDumpLenLocal tdDumpOffsetLocal tdDumpLenLocal	
	
	privateVarAssign "netInfoDump" "net" "$1"
	privateVarAssign "netInfoDump" "netDesc" "$2"
	
	test ! -z "$(echo -n $mastNets |grep $net)" && {
		baseModelLocal="$mastBaseModel"
		verDumpOffsetLocal=$verDumpOffset_mast
		let verDumpLenLocal=$verDumpLen_mast
		pnDumpOffsetLocal=$pnDumpOffset_mast
		let pnDumpLenLocal=$pnDumpLen_mast
		pnRevDumpOffsetLocal=$pnRevDumpOffset_mast
		let pnRevDumpLenLocal=$pnRevDumpLen_mast
		tnDumpOffsetLocal=$tnDumpOffset_mast
		let tnDumpLenLocal=$tnDumpLen_mast
		tdDumpOffsetLocal=$tdDumpOffset_mast
		let tdDumpLenLocal=$tdDumpLen_mast
	} || {
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
	}
	
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
			echo -e -n "\t $netDesc     PN: $pnDumpRes  $(test "$pnDumpRes" = "$uutPn" && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m")\n"
		}
		test -z "$(echo $pnRevDumpRes 2>&1 |xxd |grep 'ffff ffff')" && echo -e -n "\t $netDesc    Rev: $pnRevDumpRes   $([ $(expr "x$pnRevDumpRes" : "x[0-9]*$") -gt 0 ] && echo -e -n "\e[0;32mOK\e[m" || echo -e -n "\e[0;31mFAIL\e[m")\n" || critWarn "\t $netDesc    Rev: EMPTY"
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
		PE310G4BPI71-SR) 
			dumpRegsPE310GxBPI71 
			printRegsPE310GxBPI71
		;;
		PE310G2BPI71-SR) 
			dumpRegsPE310GxBPI71 
			printRegsPE310GxBPI71
		;;
		PE310G4DBIR) 
			dumpRegsPE310G4DBIR
			printRegsPE310G4DBIR
		;;
		PE210G2BPI9) 
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

bpSwitchTestsLoop() {
	test ! -z "$bpBuses" && {
		allBPBusMode "$bpBuses" "inline"
		allBPBusMode "$mastBpBuses" "inline"
		sleep $globLnkUpDel
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:IL" "$baseModel"
		allNetTests "$mastNets" "MASTER" "UUT:IL MAST:IL" "$mastBaseModel"
		

		allBPBusMode "$bpBuses" "bp"
		sleep $globLnkUpDel
		allNetAct "$uutNets" "Check links are DOWN on UUT (UUT:BP MAST:IL)" "testLinks" "no" "$baseModel"
		allNetTests "$mastNets" "MASTER" "UUT:BP MAST:IL" "$mastBaseModel"
		
		allBPBusMode "$bpBuses" "inline"
		allBPBusMode "$mastBpBuses" "bp"			
		sleep $globLnkUpDel
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:BP" "$baseModel"
		allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:IL MAST:BP)" "testLinks" "no" "$mastBaseModel"

		allBPBusMode "$bpBuses" "bp"
		sleep $globLnkUpDel
		allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:BP MAST:BP)" "testLinks" "no" "$mastBaseModel"
		allNetAct "$uutNets" "Check links are DOWN on UUT (UUT:BP MAST:BP)" "testLinks" "no" "$baseModel"
		
		allBPBusMode "$bpBuses" "inline"
		allBPBusMode "$mastBpBuses" "inline"
	} || {
		allBPBusMode "$mastBpBuses" "inline"
		sleep $globLnkUpDel
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:IL" "$baseModel"
		allNetTests "$mastNets" "MASTER" "UUT:IL MAST:IL" "$mastBaseModel"
		
		allBPBusMode "$mastBpBuses" "bp"
		sleep $globLnkUpDel
		allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:IL MAST:BP)" "testLinks" "no" "$mastBaseModel"
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:BP" "$baseModel"
	}
	allBPBusMode "$mastBpBuses" "inline"
}

bpSwitchTests() {
	local options loopCount ethTotalQty firstBpEth
	
	echo -e "\n  Checking BP FW"
	firstBpEth=$(echo $bpBuses |awk '{print $1}')
	test -z "$firstBpEth" && warn "  Unable to acquire firstBpEth!" || checkBpFw "$firstBpEth" "$bpCtlMode"
	echo -e "\n"
	
	echo -e "\n  Loop count:"
	options=("1" "3" "10")
	case `select_opt "${options[@]}"` in
		0) let loopCount=1;;
		1) let loopCount=3;;
		2) let loopCount=10;;
		*) let loopCount=1;;
	esac

	dmsg inform "mastNets: $mastNets"
	dmsg inform "uutNets: $uutNets"
	
	
	test -z "$virtEthDevQty" && let ethTotalQty=$physEthDevQty || let ethTotalQty=$physEthDevQty+$virtEthDevQty
	
	if [ $mastDevQty -gt $ethTotalQty ]; then
		warn "  Reassigning mastNets, excessive amount detected. ($mastNets reduced to " "nnl"
		mastNets=$(echo $mastNets |cut -d ' ' -f1-$ethTotalQty)
		warn "$mastNets)" "nnl" "sil"
		dmsg inform "mastNets=$mastNets"
	fi
	
		for ((b=1;b<=$loopCount;b++)); do 
			warn "\tLoop: $b"
			bpSwitchTestsLoop
		done
	
}

trafficTests() {
	case "$baseModel" in
		PE310G4BPI71-SR) inform "Traffic tests are not defined for $baseModel";;
		PE310G2BPI71-SR) inform "Traffic tests are not defined for $baseModel";;
		PE310G4DBIR) inform "Traffic tests are not defined for $baseModel";;
		PE210G2BPI9) inform "Traffic tests are not defined for $baseModel";;
		PE325G2I71) 
			source /root/PE325G2I71/library.sh 2>&1 > /dev/null
			dmsg which set_channels
			dmsg which adapt_off
			dmsg which check_receiver
			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 10000 "$baseModel"
		;;
		PE31625G4I71L) inform "Traffic tests are not defined for $baseModel";;
		M4E310G4I71) 
			allBPBusMode "$mastBpBuses" "bp"
			inform "\t  Sourcing $baseModel lib."
			source /root/M4E310G4I71/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 100000 "$baseModel"
		;;
		*) warn "trafficTests exception, unknown baseModel: $baseModel"
	esac
}

checkIfFailed() {
	local curStep severity
	
	privateVarAssign "checkIfFailed" "curStep" "$1"
	privateVarAssign "checkIfFailed" "severity" "$2"
	curStep="$1"
	severity="$2"
	dmsg warn "\t checkIfFailed debug: $(cat /tmp/statusChk.log | tr '[:lower:]' '[:upper:]' |grep FAIL)"
	test ! -z "$(cat /tmp/statusChk.log | tr '[:lower:]' '[:upper:]' |grep FAIL)" && {
		test "$severity" = "warn" && warn "$curStep" ||	exitFail "$curStep"
	}
}

assignBuses() {
	for ARG in "$@"
	do	
		dmsg inform "ASSIGNING BUS: $ARG"
		case "$ARG" in
			spc) publicVarAssign critical spcBuses $(grep '1180' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;	
			eth) publicVarAssign critical ethBuses $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			plx) publicVarAssign critical plxBuses $(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			acc) publicVarAssign critical accBuses $(grep '0b40' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			bp) 
				case "$baseModel" in
					PE310G4BPI71-SR) publicVarAssign critical bpBuses $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1 |grep $uutBus:);;
					PE310G2BPI71-SR) publicVarAssign critical bpBuses $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1 |grep $uutBus:);;
					PE310G4DBIR) publicVarAssign critical bpBuses $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1 |grep $uutBus:);;
					PE210G2BPI9) publicVarAssign critical bpBuses $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1 |grep $uutBus:);;
					*) exitFail "assignBuses exception, unknown baseModel: $baseModel"
				esac 
			;;
			*) exitFail "assignBuses exception, unknown bus type: $ARG"
		esac
	done
}

mainTest() {
	echoSection "PCI Info & Dev Qty"
	
		inform "\tUUT bus:"
		dmsg inform "\tmainTest DEBUG: pciArgs: \n${pciArgs[@]}"
		listDevsPciLib "${pciArgs[@]}" |& tee /tmp/statusChk.log
		dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
		
		inform "\tTraffic gen bus:"
		dmsg inform "\tmainTest DEBUG: pciArgs: \n${mastPciArgs[@]}"
		listDevsPciLib "${mastPciArgs[@]}" |& tee -a /tmp/statusChk.log
		dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
	
	checkIfFailed "PCI Info & Dev Qty failed!" exit
		
	echoSection "Info Dumps"
		netInfoDump $(echo -n $mastNets|awk '{print $1}') "MASTER" |& tee /tmp/statusChk.log
		netInfoDump $(echo -n $uutNets|awk '{print $1}') "UUT" |& tee -a /tmp/statusChk.log
	test -z "$ignDumpFail" && checkIfFailed "Info Dumps failed!" crit || checkIfFailed "Info Dumps failed!" warn
	dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"

	echoSection "BP Switch tests"
		bpSwitchTests |& tee /tmp/statusChk.log
		dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
	checkIfFailed "BP Switch tests failed!" exit
	
	echoSection "Traffic tests"
		trafficTests |& tee /tmp/statusChk.log
		dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
	checkIfFailed "Traffic tests failed!" exit
}

assignNets() {
	publicVarAssign warn uutNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $uutSlotBus |awk -F/ '{print $NF}')
}

initialSetup(){
	acquireVal "UUT slot" uutSlotArg uutSlotNum
	acquireVal "Traffic gen slot" masterSlotArg mastSlotNum
	acquireVal "Part Number" pnArg uutPn
	
	publicVarAssign warn uutBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $uutSlotNum |tail -n 1)
	publicVarAssign warn mastBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $mastSlotNum |tail -n 1)
	# publicVarAssign warn uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 $uutBus |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign fatal mastSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$mastBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign warn mastNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep 0000:$mastBus |awk -F/ '{print $NF}')
	assignNets
	test "$uutBus" = "ff" && exitFail "Card not detected, uutBus=ff"
	#publicVarAssign warn mastSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 $mastBus |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	# publicVarAssign warn ethBuses $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-)
	# uutEthBuses="$(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2- |grep $uutBus:)"
	publicVarAssign warn mastEthBuses $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2- |grep $mastBus:)
	
	preInitBpStartup
	
	publicVarAssign warn mastBpBuses $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1 |grep $mastBus:)
	
	defineRequirments
	checkRequiredFiles
}

main() {	
	setupLinks "$uutNets"
	setupLinks "$mastNets"
	
	test ! -z "$(echo -n $uutBus$mastBus|grep ff)" && {
		exitFail "UUT or Master invalid slot or not detected! uutBus: $uutBus mastBus: $mastBus"
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
	source /root/multiCard/arturLib.sh
	test "$?" = "0" || {
		echo -e "\t\e[0;31mLIBRARY NOT LOADED! UNABLE TO PROCEED\n\e[m"
		exit 1
	}
	echoHeader "$toolName" "$ver"
	echoSection "Startup.."
	parseArgs "$@"
	setEmptyDefaults
	initialSetup
	startupInit
	source /root/PE310G4BPI71/library.sh 2>&1 > /dev/null	
	main
	echo -e "See $(inform "--help" "--nnl" "--sil") for available parameters\n"
}
