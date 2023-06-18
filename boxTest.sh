#!/bin/bash

declareVars() {
	ver="v0.1"
	toolName='Box Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	let exitExec=0
	let debugBrackets=0
	let debugShowAssignations=0
	ippIP=172.30.7.26
	ippUsr=admin
	ippPsw=12345678
	pnArr=(
		"80500-0150-G02"
		"80500-0224-G02"
	)
	declare -ga ipmiSensReqArr=("null" "null")
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
			skip-info-fail) 
				skpInfoFail=1 
				inform "Launch key: Skip info fail, HW info is in low priority now"
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

function ctrl_c()
{
	echo
	echo
	echo -e "\n\e[0;31mTrapped Ctrl+C\nExiting.\e[m"
	case "$baseModel" in
		*) warn "Trap is undefined for baseModel: $baseModel"
	esac
	exit 
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
			"80500-0150-G02") ;;
			"80500-0224-G02") graniteINIT;;
			"nop") sshCheckServer;;
			*) except "init sequence unknown baseModel: $baseModel"
		esac
	}
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

graniteINIT() {
	ipPowerInit
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
		"80500-0150-G02"|"80500-0224-G02") 
			echo "  File list: $baseModel"
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
	if [[ " ${pnArr[*]} " =~ " ${uutPn} " ]]; then
		dmsg inform "DEBUG1: ${pciArgs[@]}"
		case "$uutPn" in 
			"80500-0150-G02")
				baseFamily="ATT"
				baseModel="80500-0150-G02"

				blkChip="${cy}U60$ec on HOST"
				blkQtyReq="3"
				blkSizeReq="58.2G"

				biosChip="${cy}U47$ec on I/O"
				biosVerReq="ATTXS-02.00.00.02e"
				biosChipNameReq="W25Q128"
				biosChipSizeReq="16384"
				
				cpuChip="${cy}U21$ec on HOST"
				cpuModelReq="C3558"
				cpuCoreReq=4
				cpuMicrocodeReq="0x2e"

				ramChip="${cy}U2-U10$ec on HOST"
				ramSizeReq="8.1"

				usbChip="${cy}U22$ec on I/O"
				usbChipNameReq="TUSB8041"
				usb2HubQtyReq=1
				usb2HubDevIdReq="0451:8140"
				usb3HubQtyReq=1
				usb3HubDevIdReq="0451:8142"
				usbImgRelVerReq="Sep 22 2019"

				x553SwChip="${cy}U23$ec on I/O"
				x553EEPChip="${cy}U14$ec on I/O"
				x553PciSpeedReq="2.5GT/s"
				x553PciWidthReq="x1"
				x553QtyReq=2
				x553MACQtyReq=2
				x553VerReq="0.58"

				mgntPciAddr="03:00.0"
				mgntSpeedReq="1000"
				i210SwChip="${cy}U12$ec on I/O"
				i210EEPChip="${cy}U59$ec on I/O"
				i210PciSpeedReq="2.5GT/s"
				i210PciWidthReq="x1"
				i210QtyReq=1
				i210MACQtyReq=1
				i210VerReq="3.25"

				i2cDevQty=2
				i2cChipsetNameReq="I801"
				i2cHostFruEepChip="${cy}U13$ec on HOST"
				i2cHostFruEepAddr="56"
				i2cClockBuffChip="${cy}U33$ec on HOST"
				i2cClockBuffAddr="6d"
				i2cDDRSpdEepChip="${cy}U12$ec on HOST"
				i2cDDRSpdEepAddr="50"
				i2cIR38062MChip="${cy}U86$ec on HOST"
				i2cIR38062MAddr="44"
				i2cIOFprIDEepChip="${cy}U51$ec on I/O"
				i2cIOFprIDEepAddr="57"
				i2cVoltMonChip="${cy}U78$ec on HOST"
				i2cVoltMonAddr="14"
				i2cGPIOExpChip="${cy}U27$ec on I/O"
				i2cGPIOExpAddr="74"
				i2cNMIDEepChip="${cy}U54$ec on I/O"
				i2cNMIDEepAddr="54"
				i2cPICEepChip="${cy}U64$ec on HOST"
				i2cPICEepAddr="5b"
				ncsiIoChips="${cy}Y7, U12, NCSI_RX, NCSI_TX$ec on I/O"
				ncsiHostChips="${cy}Y7, U12, NCSI_RX, NCSI_TX$ec on I/O"
				ipmiSensReqArr=(
					"Host CPU Temperature" "TEMP_HOST_CPU"
					"Host PCB Temperature" "TEMP_HOST_PCB"
					"Host air inlet Temperature" "TEMP_INLET_AMB"
					"FAN1 Speed" "FAN1_TACH"
					"Host 5V Voltage" "CPU_BRD 5V"
					"Host 3.3V Voltage" "CPU_BRD 3.3V"
					"Host VCCSRAM Voltage" "CPU_BRD VCCSRAM"
					"Host VCCP Voltage" "CPU_BRD VCCP"
					"Host 1.05V Voltage" "CPU_BRD 1.05V"
					"Host MEMVDDQ Voltage" "CPU_BRD MEMVDDQ"
					"Host VNN Voltage" "CPU_BRD VNN"
					"Host 1.8V Voltage" "CPU_BRD 1.8V"
				)
			;;
			"80500-0224-G02")
				baseFamily="GRANITE"

				baseModel="80500-0224-G02"

				blkChip="${cy}U22$ec"
				blkQtyReq="3"
				blkSizeReq="29.1G"

				biosChip="${cy}U32$ec"
				biosVerReq="EPIKGEN4-03.00.00.01t"
				
				cpuChip="${cy}U21$ec"
				cpuModelReq="C3336"
				cpuCoreReq=2
				cpuMicrocodeReq="0x36"

				ramChip="${cy}U6-U10$ec"
				ramSizeReq="1.9"

				usbChip=$cpuChip
				usb2HubQtyReq=1
				usb2HubDevIdReq="1d6b:0002"
				usb3HubQtyReq=1
				usb3HubDevIdReq="1d6b:0003"
				lteUsbChip="${cy}J34$ec"
				lteUsbQtyReq=1
				lteUsbDevIdReq="2c7c:0125"

				i2cDevQty=2
				i2cChipsetNameReq="I801"
				i2cRanges=("0x08" "0x30" "0x33" "0x77")

				i2cBuckBoostChargerChip="${cy}U19$ec"
				i2cBuckBoostChargerAddr="09"
				i2cSocChip=$cpuChip
				i2cSocAddr="08"
				i2cDDRSpdEepChip="${cy}U12$ec"
				i2cDDRSpdEepAddr="5c"
				i2cFruEepChip="${cy}U13$ec"
				i2cFruEepAddr="56"
				i2cuCChip="${cy}U16$ec"
				i2cuCAddr="74"

				gpioArr=(
					"10,MFG_MODE,1"
					"66,SOC-SIM1-DET-N,1"
					"67,SOC-SIM2-DET-N,1"
					"86,SOC-SIM-SEL,0"
					"87,PMU_PLTRST_N,0"
					"88,SUS_STAT_N,1"
					"90,SOC-BUF-M2E-EN,1"
					"91,SOC-BUF-SLOT-EN,1"
					"92,M2E-W-DISABLE2#,1"
					"93,SOC_SATA_PDETECT1,1"
				)
			;;
			*) except "$uutPn cannot be processed, requirements not defined for the case"
		esac
		case $baseFamily in
			"ATT") 
				uutBdsUser="root"
				uutBdsPass="sil7644"
				uutBMCUser="is_admin"
				uutBMCPass="1qaz2wsX"
				uutBMCShellUser="debug shell"
				uutBMCShellPass="She11#local"
				uutBaudRate=115200
			;;
			"GRANITE")
				uutBdsUser="root"
				uutBdsPass="admin"
				uutBaudRate=115200
			;;
			*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
		esac
		echoIfExists "  Base model:" "$baseModel"
	else
		except "$uutPn cannot be processed, requirements not defined"
	fi
	
	echo -e "  Done."
	
	echo -e " Done.\n"
}


initialSetup(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	acquireVal "Part Number" pnArg uutPn
	
	defineRequirments
	
	case $baseFamily in
		"ATT") 
			selectSerial "  Select UUT serial device"
			publicVarAssign silent uutSerDev ttyUSB$?
		;;
		"GRANITE")
			echo -n "  Checking serial device is connected:"
			publicVarAssign silent uutSerDev $(dmesg |grep 'USB ACM device' |tail -n1 |awk '{print $4}' |cut -d: -f1)
		;;
		*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
	esac

	testFileExist "/dev/$uutSerDev"

	checkRequiredFiles
}

boxATTHWCheck() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local devInfoRes devInfoCmd sendCmd
	local blkQty blkSize biosChipInfo biosChipName biosChipSize biosVer cpuModel cpuCoreCount cpuMicrocode
	local ramSize x553PciInfo1 x553PciInfo2 x553DevQty x553LoadedDevQty x553MacQty x553NicNum x553EepVer
	local usbChipName usb2HubQty usb3HubQty usbImgRelVer i2cDevQty i2cDevList
	case $baseModel in
		"80500-0150-G02")  
			echo -n "  >Getting block qty.. "; blkQty=$(getATTQty $uutSerDev "lsblk |grep mmc |wc -l"); echo "done."
			echo -n "  >Getting block size.. "; blkSize="$(getATTString $uutSerDev "lsblk |grep -m1 mmc |awk '{print \\\$4}'")"; echo "done."
			echo -n "  >Getting BIOS chip.. "; biosChipInfo="$(getATTString --resp-timeout=15 $uutSerDev '/root/adi_smbios_util -r 2>&1 |grep W25Q128')"; echo "done."
			echo -n "  >Getting BIOS chip name.. "; biosChipName="$(echo "$biosChipInfo"|cut -d\" -f2)"; echo "done."
			echo -n "  >Getting BIOS chip size.. "; biosChipSize="$(echo "$biosChipInfo"|cut -d\( -f2 |cut -d, -f1)"; echo "done."
			echo -n "  >Getting BIOS version.. "; biosVer="$(getATTString $uutSerDev "dmidecode |grep Version |head -n 1 |cut -d' ' -f2-")"; echo "done."
			echo -n "  >Getting CPU model.. "; cpuModel="$(getATTString $uutSerDev "lscpu |grep name: |cut -d: -f2-")"; echo "done."
			echo -n "  >Getting CPU core count.. "; cpuCoreCount=$(getATTQty $uutSerDev "nproc"); echo "done."
			echo -n "  >Getting CPU microcode version.. "; cpuMicrocode=$(getATTString $uutSerDev "cat /proc/cpuinfo |grep -m1 -i microcode |awk '{print \\\$3}'"); echo "done."
			echo -n "  >Getting RAM size.. "; ramSize=$(echo "scale=1; $(getATTString $uutSerDev "cat /proc/meminfo |grep MemTotal |awk '{print \\\$2}'")/1000000" |bc); echo "done."
			echo -n "  >Getting X553 PCI info pt1.. "; x553PciInfo1="$(getATTString $uutSerDev "lspci -vvnns 05:00.0 |grep LnkCap: |cut -d, -f2-3")"; echo "done."
			echo -n "  >Getting X553 PCI info pt2.. "; x553PciInfo2="$(getATTString $uutSerDev "lspci -vvnns 05:00.1 |grep LnkCap: |cut -d, -f2-3")"; echo "done."
			echo -n "  >Getting X553 Device qty.. "; let x553DevQty=$(getATTQty $uutSerDev "lspci -d :15c2 |wc -l"); echo "done."
			echo -n "  >Getting X553 initialized device qty.. "; x553LoadedDevQty=$(getATTQty $uutSerDev "lspci -kd :15c2 |grep 'in use' |wc -l"); echo "done."
			echo -n "  >Getting X553 base eth name.. "; x553EthBase=$(getATTString $uutSerDev "ls -l /sys/class/net |cut -d'>' -f2 |grep -m1 '05:00.0'|cut -d/ -f8 |cut -df -f1"); echo "done."
			echo -n "  >Getting X553 burned MAC qty.. "; x553MacQty=$(getATTQty $uutSerDev "ip a |grep -A1 $x553EthBase |grep 00:e0:ed |wc -l"); echo "done."
			echo -n "  >Getting X553 NIC number.. "; x553NicNum=$(getATTQty $uutSerDev "eeupdate64e |grep -m1 '15C2' |awk '{print \\\$1}'"); echo "done."
			echo -n "  >Getting X553 EEPROM Version.. "; x553EepVer=$(getATTString --resp-timeout=10 $uutSerDev "eeupdate64e /nic=$x553NicNum /eepromver |grep EEPROM |awk '{print \\\$5}'"); echo "done."
			echo -n "  >Getting I210 PCI info.. "; i210PciInfo1="$(getATTString $uutSerDev "lspci -vvnns $mgntPciAddr |grep LnkCap: |cut -d, -f2-3")"; echo "done."
			echo -n "  >Getting I210 Device qty.. "; let i210DevQty=$(getATTQty $uutSerDev "lspci -d :1533 |wc -l"); echo "done."
			echo -n "  >Getting I210 initialized device qty.. "; i210LoadedDevQty=$(getATTQty $uutSerDev "lspci -kd :1533 |grep 'in use' |wc -l"); echo "done."
			echo -n "  >Getting I210 base eth name.. "; i210EthBase=$(getATTString $uutSerDev "ls -l /sys/class/net |cut -d'>' -f2 |grep -m1 '03:00.0'|cut -d/ -f8 |cut -df -f1"); echo "done."
			echo -n "  >Getting I210 burned MAC qty.. "; i210MacQty=$(getATTQty $uutSerDev "ip a |grep -A1 $i210EthBase |grep 00:e0:ed |wc -l"); echo "done."
			echo -n "  >Getting I210 NIC number.. "; i210NicNum=$(getATTQty $uutSerDev "eeupdate64e |grep -m1 '1533' |awk '{print \\\$1}'"); echo "done."
			echo -n "  >Getting I210 EEPROM Version.. "; i210EepVer=$(getATTString --resp-timeout=10 $uutSerDev "eeupdate64e /nic=$i210NicNum /eepromver |grep EEPROM |awk '{print \\\$5}'"); echo "done."
			echo -n "  >Getting USB chip name.. "; usbChipName="$(getATTString $uutSerDev "lsusb |grep TUSB |grep Bus")"; echo "done."
			echo -n "  >Getting TI USB hub 2.0 device quantity.. "; usb2HubQty=$(getATTQty $uutSerDev "lsusb -d $usb2HubDevIdReq |wc -l"); echo "done."
			echo -n "  >Getting TI USB hub 3.0 device quantity.. "; usb3HubQty=$(getATTQty $uutSerDev "lsusb -d $usb3HubDevIdReq |wc -l"); echo "done."
			echo -n "  >Getting USB image realease version.. "; usbImgRelVer="$(getATTString $uutSerDev "cat /opt/Release.txt")"; echo "done."
			echo -n "  >Getting I2C controller device quantity.. "; i2cDevQty=$(getATTQty $uutSerDev "i2cdetect -l |wc -l"); echo "done."
			echo -n "  >Getting I2C controller name.. "; i2cChipsetName=$(getATTString $uutSerDev "i2cdetect -l |grep 'I801'"); echo "done."
			echo -n "  >Getting I2C device list.. "; i2cDevList="$(getATTString $uutSerDev "echo \\\$(i2cdetect -y 1 |grep : |cut -d: -f2- |tr -d '-')")"; echo "done."
			echo -n "  >Getting Sensor data list.. "; sensDataList="$(getATTBlock $uutSerDev "ipmitool sensor")"; echo "done."

		;;
		*) except "$uutPn cannot be processed, boxHWCheck not defined for the case"
	esac
	echo -e "\n\n"
	checkIfContains "Checking MMC block qty ($blkChip)" "--$blkQtyReq" "$(echo -n"$blkQty"|grep -m 1 "$blkQtyReq")"
	checkIfContains "Checking MMC size ($blkChip)" "--$blkSizeReq" "$(echo -n "$blkSize"|grep -m 1 "$blkSizeReq")"; echo -ne "\n"
	checkIfContains "Checking BIOS chip name ($biosChip)" "--$biosChipNameReq" "$(echo -n "$biosChipName"|grep -m 1 "$biosChipNameReq")"
	checkIfContains "Checking BIOS chip size ($biosChip)" "--$biosChipSizeReq" "$(echo -n "$biosChipSize"|grep -m 1 "$biosChipSizeReq")"
	checkIfContains "Checking BIOS version ($biosChip)" "--$biosVerReq" "$(echo -n "$biosVer"|grep -m 1 "$biosVerReq")"; echo -ne "\n"
	checkIfContains "Checking CPU model ($cpuChip)" "--$cpuModelReq" "$(echo -n "$cpuModel"|grep -m 1 "$cpuModelReq")"
	checkIfContains "Checking CPU core count ($cpuChip)" "--$cpuCoreReq" "$(echo -n "$cpuCoreCount"|grep -m 1 "$cpuCoreReq")"
	checkIfContains "Checking CPU microcode version ($cpuChip)" "--$cpuMicrocodeReq" "$(echo -n "$cpuMicrocode"|grep -m 1 "$cpuMicrocodeReq")"
	checkIfContains "Checking RAM size ($ramChip)" "--$ramSizeReq" "$(echo -n "$ramSize"|grep -m 1 "$ramSizeReq")"; echo -ne "\n"
	checkIfContains "Checking X553 PCI lane 1 Speed ($x553SwChip)" "--$x553PciSpeedReq" "$(echo -n "$x553PciInfo1"|grep -m 1 "$x553PciSpeedReq")"
	checkIfContains "Checking X553 PCI lane 1 Width ($x553SwChip)" "--$x553PciWidthReq" "$(echo -n "$x553PciInfo1"|grep -m 1 "$x553PciWidthReq")"
	checkIfContains "Checking X553 PCI lane 2 Speed ($x553SwChip)" "--$x553PciSpeedReq" "$(echo -n "$x553PciInfo2"|grep -m 1 "$x553PciSpeedReq")"
	checkIfContains "Checking X553 PCI lane 2 Width ($x553SwChip)" "--$x553PciWidthReq" "$(echo -n "$x553PciInfo2"|grep -m 1 "$x553PciWidthReq")"
	checkIfContains "Checking X553 device qty ($x553SwChip)" "--$x553QtyReq" "$(echo -n "$x553DevQty"|grep -m 1 "$x553QtyReq")"
	checkIfContains "Checking X553 loaded device qty ($x553SwChip)" "--$x553QtyReq" "$(echo -n "$x553LoadedDevQty"|grep -m 1 "$x553QtyReq")"
	checkIfContains "Checking X553 burned MAC qty ($x553SwChip)" "--$x553MACQtyReq" "$(echo -n "$x553MacQty"|grep -m 1 "$x553MACQtyReq")"
	checkIfContains "Checking X553 EEPROM FW version ($x553EEPChip)" "--$x553VerReq" "$(echo -n "$x553EepVer"|grep -m 1 "$x553VerReq")"; echo -ne "\n"
	checkIfContains "Checking I210 PCI Speed ($i210SwChip)" "--$i210PciSpeedReq" "$(echo -n "$i210PciInfo1"|grep -m 1 "$i210PciSpeedReq")"
	checkIfContains "Checking I210 PCI Width ($i210SwChip)" "--$i210PciWidthReq" "$(echo -n "$i210PciInfo1"|grep -m 1 "$i210PciWidthReq")"
	checkIfContains "Checking I210 device qty ($i210SwChip)" "--$i210QtyReq" "$(echo -n "$i210DevQty"|grep -m 1 "$i210QtyReq")"
	checkIfContains "Checking I210 loaded device qty ($i210SwChip)" "--$i210QtyReq" "$(echo -n "$i210LoadedDevQty"|grep -m 1 "$i210QtyReq")"
	checkIfContains "Checking I210 burned MAC qty ($i210SwChip)" "--$i210MACQtyReq" "$(echo -n "$i210MacQty"|grep -m 1 "$i210MACQtyReq")"
	checkIfContains "Checking I210 EEPROM FW version ($i210EEPChip)" "--$i210VerReq" "$(echo -n "$i210EepVer"|grep -m 1 "$i210VerReq")"; echo -ne "\n"
	checkIfContains "Checking TI USB chip name ($usbChip)" "--$usbChipNameReq" "$(echo -n "$usbChipName"|grep -m 1 "$usbChipNameReq")"
	checkIfContains "Checking TI USB hub 2.0 device quantity ($usbChip)" "--$usb2HubQtyReq" "$(echo -n "$usb2HubQty"|grep -m 1 "$usb2HubQtyReq")"
	checkIfContains "Checking TI USB hub 3.0 device quantity ($usbChip)" "--$usb3HubQtyReq" "$(echo -n "$usb3HubQty"|grep -m 1 "$usb3HubQtyReq")"
	checkIfContains "Checking USB image realease version (${cy}USB Drive$ec)" "--$usbImgRelVerReq" "$(echo -n "$usbImgRelVer"|grep -m 1 "$usbImgRelVerReq")"; echo -ne "\n"
	checkIfContains "Checking I2C controller device quantity ($cpuChip)" "--$i2cDevQty" "$(echo -n "$i2cDevQty"|grep -m 1 "$i2cDevQty")"
	checkIfContains "Checking I2C controller name ($cpuChip)" "--$i2cChipsetNameReq" "$(echo -n "$i2cChipsetName"|grep -m 1 "$i2cChipsetNameReq")"
	checkIfContains "Checking I2C Host FRU EEPROM present ($i2cHostFruEepChip)" "--$i2cHostFruEepAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cHostFruEepAddr")"
	checkIfContains "Checking I2C PCIe clock buffer present ($i2cClockBuffChip)" "--$i2cClockBuffAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cClockBuffAddr")"
	checkIfContains "Checking I2C DDR4 SPD EEPROM present ($i2cDDRSpdEepChip)" "--$i2cDDRSpdEepAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cDDRSpdEepAddr")"
	checkIfContains "Checking I2C IR38062M VR present ($i2cIR38062MChip)" "--$i2cIR38062MAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cIR38062MAddr")"
	checkIfContains "Checking I2C IO FRP ID EEPROM present ($i2cIOFprIDEepChip)" "--$i2cIOFprIDEepAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cIOFprIDEepAddr")"
	checkIfContains "Checking I2C Voltage monitor present ($i2cVoltMonChip)" "--$i2cVoltMonAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cVoltMonAddr")"
	checkIfContains "Checking I2C IO GPIO Expander present ($i2cGPIOExpChip)" "--$i2cGPIOExpAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cGPIOExpAddr")"
	checkIfContains "Checking I2C NM ID EEPROM present ($i2cNMIDEepChip)" "--$i2cNMIDEepAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cNMIDEepAddr")"
	checkIfContains "Checking I2C PIC EEPROM present ($i2cPICEepChip)" "--$i2cPICEepAddr" "$(echo -n "$i2cDevList"|grep -m 1 "$i2cPICEepAddr")"; echo -ne "\n"
	if ! [ "${ipmiSensReqArr[0]}" = "null" ]; then
		echo -e "\tChecking sensor and voltage readings: "
		for ((ipmiArrIdx=0;ipmiArrIdx<${#ipmiSensReqArr[@]};ipmiArrIdx++)); do
			ipmiLine=$(echo -n "${sensDataList[@]}" |grep "${ipmiSensReqArr[$(($ipmiArrIdx+1))]}")
			sensReading=$(cut -d '|' -f2-3 <<<$ipmiLine | sed 's/'" |"'//g')
			checkIfContains "  Checking ${ipmiSensReqArr[$ipmiArrIdx]} (${cy}$sensReading$ec)" "--ok" "$(cut -d '|' -f4 <<<$ipmiLine |grep -m 1 "ok")"
			let ipmiArrIdx+=1
		done
	fi
}

boxATTGPIOTest(){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local gpioInfo cnt
	echo "  Getting GPIO info from I/O BMC"
	cmdRes="$(sendATTBMC --resp-timeout=20 --shell $uutSerDev "sudo lsgpio")"
	gpio0AddrArr=(19 23 26 27 29 31)
	gpio0ValAddrArr=(-1 23 26 27 -1 -1)
	gpio0ValReqAddrArr=(-1 1 1 0 -1 -1)

	gpio1AddrArr=(12 13 14 15 22 23 24 25 28 29)
	gpio1ValAddrArr=(44 45 -1 47 -1 -1 -1 -1 -1 61)
	gpio1ValReqAddrArr=(1 1 -1 1 -1 -1 -1 -1 -1 1)

	gpio2AddrArr=(0 1 2 3 4 5 8 22 23 24 25)
	gpio2ValAddrArr=(-1 65 66 -1 68 -1 -1 86 -1 -1 -1)
	gpio2ValReqAddrArr=(-1 1 1 -1 1 -1 -1 0 -1 -1 -1)
	let cnt=0
	echo "   Checking GPIO bank0:"
	for gpioAddr in ${gpio0AddrArr[*]}; do
		echo -n "    GPIO pin $gpioAddr: "
		gpioDesc=$(grep -A32 'gpiochip0'<<<"$cmdRes" |grep " $gpioAddr:" |cut -d '"' -f2)
		if [ -z "$gpioDesc" ]; then
			echo -e "${rd}FAIL$ec"
		else
			if [ ${gpio0ValAddrArr[$cnt]} -gt 0 ]; then
				gpioCmd="cat /sys/class/gpio/gpiochip0/device/gpiochip0/gpio/gpio${gpio0ValAddrArr[$cnt]}/value"
				gpioVal=$(sendATTBMC --shell $uutSerDev "$gpioCmd" |grep -v 'a\|e\|o' | sed 's/[^0-9]//g')
				echo -n "$gpioDesc = $gpioVal "|tr -d '\n'
				if [ -z "$gpioVal" ]; then
					echo -e "${yl}EMPTY - ${rd}FAIL$ec"
				else
					if [ ${gpio0ValReqAddrArr[$cnt]} -eq $gpioVal ]; then echo -e "${gr}OK$ec"; else echo -e "${rd}FAIL$ec";fi
				fi
			else
				echo "$gpioDesc"
			fi
		fi
		let cnt++
	done

	let cnt=0
	echo -e "\n   Checking GPIO bank1:"
	for gpioAddr in ${gpio1AddrArr[*]}; do
		echo -n "    GPIO pin $gpioAddr: "
		gpioDesc=$(grep -A32 'gpiochip1'<<<"$cmdRes" |grep " $gpioAddr:" |cut -d '"' -f2)
		if [ -z "$gpioDesc" ]; then
			echo -e "${rd}FAIL$ec"
		else
			if [ ${gpio1ValAddrArr[$cnt]} -gt 0 ]; then
				gpioCmd="cat /sys/class/gpio/gpiochip32/device/gpiochip1/gpio/gpio${gpio1ValAddrArr[$cnt]}/value"
				gpioVal=$(sendATTBMC --shell $uutSerDev "$gpioCmd" |grep -v 'a\|e\|o' | sed 's/[^0-9]//g')
				echo -n "$gpioDesc = $gpioVal "|tr -d '\n'
				if [ ${gpio1ValReqAddrArr[$cnt]} -eq $gpioVal ]; then echo -e "${gr}OK$ec"; else echo -e "${rd}FAIL$ec";fi
			else
				echo "$gpioDesc"
			fi
		fi
		let cnt++
	done


	let cnt=0
	echo -e "\n   Checking GPIO bank2:"
	for gpioAddr in ${gpio2AddrArr[*]}; do
		echo -n "    GPIO pin $gpioAddr: "
		gpioDesc=$(grep -A32 'gpiochip2'<<<"$cmdRes" |grep " $gpioAddr:" |cut -d '"' -f2)
		if [ -z "$gpioDesc" ]; then
			echo -e "${rd}FAIL$ec"
		else
			if [ ${gpio2ValAddrArr[$cnt]} -gt 0 ]; then
				gpioCmd="cat /sys/class/gpio/gpiochip64/device/gpiochip2/gpio/gpio${gpio2ValAddrArr[$cnt]}/value"
				gpioVal=$(sendATTBMC --shell $uutSerDev "$gpioCmd"  |grep -v 'a\|e\|o' | sed 's/[^0-9]//g')
				echo -n "$gpioDesc = $gpioVal "|tr -d '\n'
				if [ ${gpio2ValReqAddrArr[$cnt]} -eq $gpioVal ]; then echo -e "${gr}OK$ec"; else echo -e "${rd}FAIL$ec";fi
			else
				echo "$gpioDesc"
			fi
		fi
		let cnt++
	done
}

boxATTSetupEth() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local targIp targEth
	privateVarAssign "${FUNCNAME[0]}" "targIp" "$1"
	privateVarAssign "${FUNCNAME[0]}" "targEth" "$2"

	echo -e "\n Setting management IP.."
	echo -n "  Stopping Network service."
	sendATT $uutSerDev "systemctl stop systemd-networkd.service" 2>&1 >/dev/null
	echo -n "  Setting $mgntEthName DOWN, "
	sendATT $uutSerDev "ifconfig $mgntEthName down" 2>&1 >/dev/null
	echo -n "flushing, "
	sendATT $uutSerDev "ip a flush dev $mgntEthName" 2>&1 >/dev/null
	echo -n "setting UP, "
	sendATT $uutSerDev "ifconfig $mgntEthName up" 2>&1 >/dev/null
	echo -n "setting IP to $ipReq, "
	sendATT $uutSerDev "ifconfig $mgntEthName $ipReq" 2>&1 >/dev/null
	echo "done."
	
	ifaceActIp=$(grep "$ipReq" <<< "$(getATTString $uutSerDev "ifconfig $mgntEthName |grep $ipReq")")
	if [ ! -z "$ifaceActIp" ]; then
		echo -e "  Management IP set ${gr}OK$ec: $ifaceActIp"
	else
		except "Unable to setup management IP address!"
	fi
	echo -e " Done."
}

ATTFtpCopyCycleTest() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local fileSizeSelRes cycleCntSelRes cycleCntList sizeList blockCount cycleCntReq
	local fileName filePath ddRes cmdLine trgCRC srcCRC respTimeout
	privateVarAssign "${FUNCNAME[0]}" "trgFtpIp" "$1"

	sizeList=( "1 MB" "10 MB" "50 MB" "200 MB" "1 GB" "2 GB" )
	cycleCntList=( 5 10 50 100 200 400 )
	respTimeout=5

	echo -e " Select File size:"
	fileSizeSelRes=$(select_opt "${sizeList[@]}")
	echo -e " Select cycle count:"
	cycleCntSelRes=$(select_opt "${cycleCntList[@]}")

	case $fileSizeSelRes in
		0) blockCount=1; respTimeout=5;;
		1) blockCount=10; respTimeout=10;;
		2) blockCount=50; respTimeout=20;;
		3) blockCount=200; respTimeout=30;;
		4) blockCount=1000; respTimeout=60;;
		5) blockCount=2000; respTimeout=120;;
		*) except "illegal fileSizeSelRes=$fileSizeSelRes"
	esac
	case $cycleCntSelRes in
		0) cycleCntReq=5;;
		1) cycleCntReq=10;;
		2) cycleCntReq=50;;
		3) cycleCntReq=100;;
		4) cycleCntReq=200;;
		5) cycleCntReq=400;;
		*) except "illegal cycleCntSelRes=$cycleCntSelRes"
	esac
	fileName="rand_$(tr -d ' ' <<< ${sizeList[$fileSizeSelRes]}).file"
	filePath="/tmp/FTP_PUB/$fileName"
	remoteFilePath="/tmp/$fileName"
	createFtpShare "/tmp/FTP_PUB/"
	
	echo "  Clearing temp file: $fileName"; rm -f $filePath 2>&1 > /dev/null
	echo "  Creating temp file to copy.. "; ddRes=$(dd if=/dev/urandom of=$filePath bs=1M count=$blockCount 2>&1)
	if [ -e "$filePath" ]; then
		echo "  Generating CRC of temp file.. "; srcCRC=$(cksum $filePath |awk '{print $1$2}')
		for ((cycleCnt=0; cycleCnt<=$cycleCntReq; cycleCnt++)) ; do
			echo "  Removing temp file on HOST"; sendATT --resp-timeout=$respTimeout $uutSerDev "rm -f $remoteFilePath" 2>&1 >/dev/null
			cmdLine='(echo \"quote USER anonymous\" && echo \"quote PASS\" && echo \"binary\" && echo \"get /'"$fileName"' '"$remoteFilePath"'\" && echo \"quit\" ) \| ftp -n '$trgFtpIp
			echo "  Copying temp file to HOST by FTP"; sendATT --resp-timeout=$respTimeout $uutSerDev "${cmdLine}" 2>&1 >/dev/null
			echo "  Sending sync to HOST"; sendATT --resp-timeout=$respTimeout $uutSerDev "sync" 2>&1 >/dev/null
			echo "  Getting CRC of temp file on HOST"; trgCRC=$(getATTString --resp-timeout=$respTimeout $uutSerDev "cksum $remoteFilePath |awk '{print \\\$1\\\$2}'")
			echo "  Removing temp file on HOST"; sendATT --resp-timeout=$respTimeout $uutSerDev "rm -f $remoteFilePath" 2>&1 >/dev/null
			if [ "$srcCRC" = "$trgCRC" ]; then
				echo -e "  CRC is ${gr}OK$ec (server: $srcCRC, remote host: $trgCRC"
			else
				except "CRC does not correspond, file copy failed"
			fi
		done
	else
		except "Temp file was not created"
	fi
}

boxATTMGMTTest() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	acquireVal "Management IP" ipReq ipReq
	verifyIp "${FUNCNAME[0]}" $ipReq
	echo -n "  Getting management interface name.. "
	privateVarAssign "${FUNCNAME[0]}" "mgntEthName" "$(getATTString $uutSerDev "ls -l /sys/class/net |cut -d'>' -f2 |grep -m1 $mgntPciAddr|cut -d/ -f8 |cut -df -f1")"	
	echo "$mgntEthName"
	boxATTSetupEth $ipReq $mgntEthName
	countDownDelay 5 "  Waiting for link up.."

	echo -n "  Checking link status.. "
	privateVarAssign "${FUNCNAME[0]}" "mgntLnkSta" "$(getATTString $uutSerDev "ethtool $mgntEthName | grep 'Link detected' | awk '{print \\\$3}'")"
	if ! [ -z "$(grep "yes" <<< "$mgntLnkSta")" ]; then echo -e "${gr}OK$ec"; else except "No link on $mgntEthName"; fi

	echo -n "  Checking port rate.. "
	privateVarAssign "${FUNCNAME[0]}" "mgntLnkSpd" "$(getATTString $uutSerDev "ethtool $mgntEthName | grep 'Speed:' | awk '{print \\\$2}'")"
	if ! [ -z "$(grep "$mgntSpeedReq" <<< "$mgntLnkSpd")" ]; then echo -e "${gr}OK$ec"; else except "Speed test fail on $mgntEthName"; fi

	echo "  Checking ping.. "
	sshWaitForPing 30 $ipReq 2

	echo "  Getting server IP.. "
	srvIp=$(ip a |grep -m1 172.30 |awk '{print $2}' |cut -d/ -f1)
	verifyIp "${FUNCNAME[0]}" $srvIp
	ATTFtpCopyCycleTest $srvIp

}

denvertonPingTest() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local cmdRes lnkRes

	echo -n "  Check uBMC version is MANUFACTURE: "
	cmdRes="$(sendATTBMC --resp-timeout=10 $uutSerDev "show version" |grep 'Vendor:' |grep 'MANUFACTURE')"
	if [ -z "$cmdRes" ]; then
		echo -e "${rd}FAIL$ec"
	else 
		echo -e "${gr}OK$ec"
		echo -n "  Getting HOST X553 first interface name.. "
		x553EthIface=$(getATTString $uutSerDev "ls -l /sys/class/net |cut -d'>' -f2 |grep -m1 '05:00.0'|cut -d/ -f8")
		echo -e "$yl$x553EthIface$ec"

		echo "  Setting HOST X553 ip address"
		cmdRes=$(getATTString $uutSerDev "ifconfig $x553EthIface down")

		echo "  Flushing HOST X553 interface"
		cmdRes=$(getATTString $uutSerDev "ip a flush dev $x553EthIface")

		echo "  Flushing I/O X553 interface"
		cmdRes="$(sendATTBMC --shell $uutSerDev "sudo ip a flush dev eth0")"

		echo "  Remounting ixgbe driver"
		cmdRes=$(getATTString $uutSerDev "rmmod ixgbe;sleep 1;modprobe ixgbe")

		echo -n "  Configuring switch to LAN2WAN configuration: "
		cmdRes=$(getATTBlock --resp-timeout=22 $uutSerDev "cd /root; ./mcli_cmd.sh lan2wan")
		lanCfg=$(grep '1    3 3 0 0 0 0 0 0 0 0 3' <<<"$cmdRes")
		if [ ! -z "$lanCfg" ]; then echo -e "${gr}OK$ec"; else echo -e "${rd}FAIL$ec";fi

		echo "  Setting HOST X553 ip address"
		cmdRes=$(getATTString $uutSerDev "ifconfig $x553EthIface 10.10.10.2 up")

		echo -n "  Checking HOST X553 ip address: "
		cmdRes="$(getATTBlock $uutSerDev "ifconfig $x553EthIface" |grep 'inet ' |awk '{print $2}')"
		echo -e "$yl$cmdRes$ec"

		echo "  Setting I/O X553 ip address"
		cmdRes="$(sendATTBMC --shell $uutSerDev "sudo ifconfig eth0 10.10.10.1 up")"
		
		#countDownDelay 5 "  Waiting for ip config.."

		echo -n "  Checking I/O X553 ip address: "
		cmdRes="$(sendATTBMC --shell $uutSerDev "sudo ifconfig eth0" |grep 'inet addr:' |cut -d: -f2 |awk '{print $1}')"
		echo -e "$yl$cmdRes$ec"

		echo -n "  Checking I/O X553 link detected: "
		cmdRes="$(sendATTBMC --shell $uutSerDev "sudo ethtool eth0" |grep 'Link detected' |tr -d '\r\n')"
		lnkRes=$(grep yes <<<$cmdRes)
		if [ ! -z "$lnkRes" ]; then echo -e "${gr}UP$ec"; else echo -e "${rd}DOWN (FAIL)$ec";fi	

		echo -n "  Checking HOST X553 link detected: "
		privateVarAssign "${FUNCNAME[0]}" "x553LnkSta" "$(getATTString $uutSerDev "ethtool $x553EthIface | grep 'Link detected' | awk '{print \\\$3}'" |tr -d '\r')"
		lnkRes=$(grep 'yes' <<<"$x553LnkSta")
		if [ ! -z "$lnkRes" ]; then echo -e "${gr}UP$ec"; else echo -e "${rd}DOWN (FAIL)$ec";fi

		echo -ne "  Checking NCSI port is up on I/O ($ncsiIoChips): "
		cmdRes="$(sendATTBMC --shell $uutSerDev "dmesg |grep 'NCSI interface'" |grep 'eth1' |grep -v 'interface down')"
		if [ ! -z "$cmdRes" ]; then echo -e "${gr}UP$ec"; else echo -e "${rd}DOWN (FAIL)$ec";fi

		echo -n "  Sending PING from I/O to HOST: "
		cmdRes="$(sendATTBMC --resp-timeout=20 --shell $uutSerDev "ping -I 10.10.10.1 10.10.10.2 -c 50 -i 0.2" |grep -A60 'bytes of data')"
		pingOK=$(grep ' 0% packet loss'<<<"$cmdRes")
		if [ ! -z "$pingOK" ]; then echo -e "${gr}OK$ec"; else echo -e "${rd}FAIL$ec";fi
	fi
}

boxNANOHWCheck() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local devInfoRes devInfoCmd sendCmd
	case $baseModel in
		"80500-0224-G02")  
			echo -n "  >Getting block qty.. "; blkQty=$(getNANOQty $uutSerDev "lsblk |grep mmc |grep disk |wc -l"); echo "done."
			echo -n "  >Getting block size.. "; blkSize="$(getNANOString $uutSerDev "lsblk |grep -m1 mmc |awk '{print \\\$4}'")"; echo "done."
			echo -n "  >Getting BIOS version.. "; biosVer="$(getNANOString $uutSerDev "dmidecode |grep Version |head -n 1 |cut -d' ' -f2-")"; echo "done."
			echo -n "  >Getting CPU model.. "; cpuModel="$(getNANOString $uutSerDev "lscpu |grep name: |cut -d: -f2-")"; echo "done."
			echo -n "  >Getting CPU core count.. "; cpuCoreCount=$(getNANOQty $uutSerDev "nproc"); echo "done."
			echo -n "  >Getting CPU microcode version.. "; cpuMicrocode=$(getNANOString $uutSerDev "cat /proc/cpuinfo |grep -m1 -i microcode |awk '{print \\\$3}'"); echo "done."
			echo -n "  >Getting RAM size.. "; ramSize=$(echo "scale=1; $(getNANOString $uutSerDev "cat /proc/meminfo |grep MemTotal |awk '{print \\\$2}'")/1000000" |bc); echo "done."
			echo -n "  >Getting Internal USB hub 2.0 device quantity.. "; usb2HubQty=$(getNANOQty $uutSerDev "lsusb -d $usb2HubDevIdReq |wc -l"); echo "done."
			echo -n "  >Getting Internal USB hub 3.0 device quantity.. "; usb3HubQty=$(getNANOQty $uutSerDev "lsusb -d $usb3HubDevIdReq |wc -l"); echo "done."
			echo -n "  >Getting LTE USB device quantity.. "; lteUsbQty="$(getNANOQty $uutSerDev "lsusb -d $lteUsbDevIdReq |wc -l")"; echo "done."
		;;
		*) except "$uutPn cannot be processed, boxHWCheck not defined for the case"
	esac
	echo -e "\n\n"
	checkIfContains "Checking MMC block qty ($blkChip)" "--$blkQtyReq" "$(echo -n"$blkQty"|grep -m 1 "$blkQtyReq")"
	checkIfContains "Checking MMC size ($blkChip)" "--$blkSizeReq" "$(echo -n "$blkSize"|grep -m 1 "$blkSizeReq")"; echo -ne "\n"
	checkIfContains "Checking BIOS version ($biosChip)" "--$biosVerReq" "$(echo -n "$biosVer"|grep -m 1 "$biosVerReq")"; echo -ne "\n"
	checkIfContains "Checking CPU model ($cpuChip)" "--$cpuModelReq" "$(echo -n "$cpuModel"|grep -m 1 "$cpuModelReq")"
	checkIfContains "Checking CPU core count ($cpuChip)" "--$cpuCoreReq" "$(echo -n "$cpuCoreCount"|grep -m 1 "$cpuCoreReq")"
	checkIfContains "Checking CPU microcode version ($cpuChip)" "--$cpuMicrocodeReq" "$(echo -n "$cpuMicrocode"|grep -m 1 "$cpuMicrocodeReq")"
	checkIfContains "Checking RAM size ($ramChip)" "--$ramSizeReq" "$(echo -n "$ramSize"|grep -m 1 "$ramSizeReq")"; echo -ne "\n"
	checkIfContains "Checking Internal USB hub 2.0 device quantity ($usbChip)" "--$usb2HubQtyReq" "$(echo -n "$usb2HubQty"|grep -m 1 "$usb2HubQtyReq")"
	checkIfContains "Checking Internal USB hub 3.0 device quantity ($usbChip)" "--$usb3HubQtyReq" "$(echo -n "$usb3HubQty"|grep -m 1 "$usb3HubQtyReq")"
	checkIfContains "Checking LTE USB device quantity ($lteUsbChip)" "--$lteUsbQtyReq" "$(echo -n "$lteUsbQty"|grep -m 1 "$lteUsbQtyReq")"
}


checkIfFailed() {
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

bootMonitor() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local resCmd
	case $baseFamily in
		"ATT") 
			warn "${FUNCNAME[0]} not defined for $baseFamily family"
		;;
		"GRANITE")
			echo  " Sending poweroff"
			poweroffRes="$(sendNANO $uutSerDev --power-off 2>&1 |grep 'null')"

			echo -e "$cy Killing writers on serial port$ec"
			killSerialWriters $uutSerDev
			
			echo -e "$cy Unloading cdc_acm$ec"
			rmmod cdc_acm || except "Unload failed"
			echo -e "$yl Reloading USB device by id 05cd:0800 $ec"
			reloadUSBPortByHandle "5cd/800" 1
			# echo -e "$cy Setting sTTY settings$ec"
			# stty -F /dev/$uutSerDev 115200

			countDownDelay 5 " Waiting for services.."

			for ((retCnt=0;retCnt<=12;retCnt++)); do
				srvAct=$(getACMttyServices $uutSerDev)
				if [ -z "$srvAct" ]; then
					echo -e " Services$gr down.$ec"
					break
				else
					if [ retCnt > 0 ]; then printf '\e[A\e[K'; fi
					countDownDelay 10 " Waiting for services to go down.."
				fi
			done
			publicVarAssign silent uutSerDev $(dmesg |grep 'USB ACM device' |tail -n1 |awk '{print $4}' |cut -d: -f1)
			killActiveSerialWriters $uutSerDev

			if [ -z "$poweroffRes" ]; then
				countDownDelay 20 " Waiting for power down.."
			fi
			echo  " Powering down IPPower"
			ipPowerSetPowerDOWN
			countDownDelay 3 " Waiting for power down.."
			echo  " Powering up IPPower"
			ipPowerSetPowerUP
			countDownDelay 1 " Waiting for power up.."


			echo -e "$cy Initializing serial port$ec"
			initSerialNANO $uutSerDev $uutBaudRate

			echo -e "$cy Starting boot monitor.$ec"
			NANObootMonitor $uutSerDev
		;;
		*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
	esac
}

boxHWCheck (){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	case $baseFamily in
		"ATT") 
			boxATTHWCheck
		;;
		"GRANITE")
			boxNANOHWCheck
		;;
		*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
	esac
}

boxGPIOTest (){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	case $baseFamily in
		"ATT") 
			boxATTGPIOTest
		;;
		"GRANITE")
			warn "${FUNCNAME[0]} not defined for $baseFamily family"
		;;
		*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
	esac
}

boxMGMTTest (){
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	case $baseFamily in
		"ATT") 
			boxATTMGMTTest
		;;
		"GRANITE")
			warn "${FUNCNAME[0]} not defined for $baseFamily family"
		;;
		*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
	esac
}

powerOffUUT() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local poweroffRes
	case $baseFamily in
		"ATT") 
			sendATT --resp-timeout=10 $uutSerDev "poweroff"
		;;
		"GRANITE")
			killActiveSerialWriters $uutSerDev
			echo  " Sending poweroff"
			poweroffRes="$(sendNANO $uutSerDev --power-off 2>&1 |grep 'null')"
			if [ -z "$poweroffRes" ]; then
				countDownDelay 20 " Waiting for power down.."
			fi
			echo  " Powering down IPPower"
			ipPowerSetPowerDOWN
		;;
		*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
	esac
}

function mainTest() {
	dmsg dbgWarn "### FUNC: ${FUNCNAME[0]} $(caller):  $(printCallstack)"
	local boxHWInfoTest powerOff credVar
	
	if [ -z "$testSelArg" ]; then
		if [[ ! -z "$untestedPn" ]]; then untestedPnWarn; fi

		case $baseFamily in
			"ATT") 
				for credVar in uutBdsUser uutBdsPass uutBMCUser uutBMCPass uutBMCShellUser uutBMCShellPass; do
					checkDefined $credVar
				done
				bootMonitorTest=-1
				boxHWInfoTest=0
				managementTest=0
				gpioTest=0
				denvertonTest=0
				powerOff=0
				echo -e "\n  Select tests for $baseFamily:"
				options=("Full test" "Box HW Info test" "Management port test" "I/O GPIO Test" "Denverton Ping Test" "Power off UUT")
				case `select_opt "${options[@]}"` in
					0) 
						boxHWInfoTest=1
						managementTest=1
						gpioTest=1
						denvertonTest=1
						powerOff=1
					;;
					1) boxHWInfoTest=1;;
					2) managementTest=1;;
					3) gpioTest=1;;
					4) denvertonTest=1;;
					5) powerOff=1;;
					*) except "unknown option";;
				esac
			;;
			"GRANITE") 
				for credVar in uutBdsUser uutBdsPass; do
					checkDefined $credVar
				done
				bootMonitorTest=0
				boxHWInfoTest=0
				managementTest=-1
				gpioTest=0
				denvertonTest=-1
				powerOff=0
				echo -e "\n  Select tests for $baseFamily:"
				options=("Full test" "Full test (with boot)" "Box HW Info test" "I/O GPIO Test" "Power off UUT" "Boot Monitor")
				case `select_opt "${options[@]}"` in
					0) 
						boxHWInfoTest=1
						gpioTest=1
						powerOff=1
					;;
					1) 
						bootMonitorTest=1
						boxHWInfoTest=1
						gpioTest=1
						powerOff=1
					;;
					2) boxHWInfoTest=1;;
					3) gpioTest=1;;
					4) powerOff=1;;
					5) bootMonitorTest=1;;
					*) except "unknown option";;
				esac
			;;
			*) except "$baseFamily family cannot be processed, ${FUNCNAME[0]} not defined for the case"
		esac
	else
		privateVarAssign "${FUNCNAME[0]}" "$testSelArg" "1"
	fi

	case $bootMonitorTest in
		"-1") ;;
		"0") inform "\tBoot Monitor test skipped" ;;
		"1")
			echoSection "Boot Monitor"
				bootMonitor |& tee /tmp/statusChk.log
			if [ -z "$skpInfoFail" ]; then
				checkIfFailed "Boot Monitor failed!" crit; let retStatus+=$?
			else
				checkIfFailed "Boot Monitor failed!" warn
			fi
		;;
		*) critWarn "unknown case for bootMonitorTest"
	esac

	case $boxHWInfoTest in
		"-1") ;;
		"0") inform "\tBox HW Info test skipped" ;;
		"1")
			echoSection "Box HW Info test"
				boxHWCheck |& tee /tmp/statusChk.log
			if [ -z "$skpInfoFail" ]; then
				checkIfFailed "Box HW Info test failed!" crit; let retStatus+=$?
			else
				checkIfFailed "Box HW Info test failed!" warn
			fi
		;;
		*) critWarn "unknown case for boxHWInfoTest"
	esac

	case $managementTest in
		"-1") ;;
		"0") inform "\tManagement port test skipped" ;;
		"1")
			echoSection "Management port test"
				boxMGMTTest |& tee /tmp/statusChk.log
			checkIfFailed "Management port test failed!" crit; let retStatus+=$?
		;;
		*) critWarn "unknown case for managementTest"
	esac

	case $gpioTest in
		"-1") ;;
		"0") inform "\tI/O GPIO test skipped" ;;
		"1")
			echoSection "I/O GPIO test"
				boxGPIOTest |& tee /tmp/statusChk.log
			checkIfFailed "I/O GPIO test failed!" crit; let retStatus+=$?
		;;
		*) critWarn "unknown case for gpioTest"
	esac

	case $denvertonTest in
		"-1") ;;
		"0") inform "\tDenverton ping test skipped" ;;
		"1")
			echoSection "Denverton ping test"
				denvertonPingTest |& tee /tmp/statusChk.log
			checkIfFailed "Denverton ping test failed!" crit; let retStatus+=$?
		;;
		*) critWarn "unknown case for denvertonTest"
	esac
	
	if [ ! -z "$powerOff" ]; then
		echoSection "Shutting down UUT"
			echo -e "\n  Shutdown UUT?"
			ynOpts=("Yes" "No")
			case `select_opt "${ynOpts[@]}"` in
				0) powerOffUUT ;;
				1) ;;			
				*) except "unknown opt in case"
			esac
		checkIfFailed "Shutting down UUT failed!" crit; let retStatus+=$?
	fi
	return $retStatus
}


main() {
	case $baseModel in
		"IS100G-Q-RU") selectMod "is100";;
		"IS401U-RU") selectMod "is40";;
		"IS-UNIV") 
			trap ctrl_c SIGINT
			trap ctrl_c SIGQUIT
			let modSelect=-1
			publicVarAssign silent internalTTY $(find /sys/bus/usb/devices/usb3/ -name dev |grep '3-7:1.0' |cut -d/ -f9)
			if [ -z "$(echo $internalTTY |grep ttyUSB)" ]; then
				except "internal COM cable is not connected to MB header. Check internal cable and try again"
			else
				if [ "$uutSerDev" = "$internalTTY" ]; then except "invalid COM selected"; fi 
			fi
		;;
		"80500-0150-G02"|"80500-0224-G02") ;;
		*) except "invalid baseModel: $baseModel";;
	esac
	
	mainTest
	if [ -z "$minorLaunch" ]; then passMsg "\n\tDone!\n"; else echo "  Returning to caller"; fi
}


if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tboxTest has been loaded as lib (support: arturd@silicom.co.il)'
else
	echo -e '\n# arturd@silicom.co.il\n\n'
	trap "exit 1" 10
	PROC="$"
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
	if [ -z "$minorLaunch" ]; then echo -e "See $yl--help$ec for available parameters\n"; fi
fi
