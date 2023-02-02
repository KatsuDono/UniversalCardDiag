#!/bin/bash

declareVars() {
	ver="v0.01"
	toolName='TimeSync Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	declare -a pciArgs=("null" "null")
	declare -a mastPciArgs=("null" "null")
	let exitExec=0
	let debugBrackets=0
	let debugShowAssignations=0
	let internetAcq=0 
	ippIP=172.30.4.207
	ippUsr=admin
	ippPsw=12345678
	goldSrvIp=172.30.6.199
}

parseArgs() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			uut-pn) pnArg=${VALUE} ;;
			psu-ip) psuIPArg=${VALUE} ;;
			gold-ip) goldSrvIp=${VALUE} ;;
			silent) 
				silentMode=1 
				minorArgs+="--silent "
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			debug) 
				debugMode=1 
				minorArgs+="--debug "
				inform "Launch key: Debug mode"
			;;
			debug-show-assign) 
				let debugShowAssignations=1
				debugMode=1 
				minorArgs+="--debug-show-assign "
				inform "Launch key: Debug mode, visible assignations"
			;;
			help) showHelp ;;
			menu-choice) ;; # passed from menu
			usb-test) 
				testArg=1
				pcUsbTest=1 
			;;
			*) echo "Unknown arg: $ARG"; showHelp
		esac
	done
}

showHelp() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	warn "\n=================================" "" "sil"
	echo -e "$toolName"
	echo -e " Arguments:"
	echo -e " --help"
	echo -e "\tShow help message\n"	
	echo -e " --uut-pn=NUMBER"
	echo -e "\tProduct number of UUT\n"
	echo -e " --psu-ip=IP"
	echo -e "\tIP address of PSU\n"
	echo -e " --silent"
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"	
	warn "=================================\n"
	exit
}

setEmptyDefaults() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e " Setting defaults.."
	publicVarAssign warn globLnkUpDel "0.3"
	publicVarAssign warn globLnkAcqRetr "7"
	publicVarAssign warn globRtAcqRetr "7"
	echo -e " Done.\n"
}


startupInit() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local drvInstallRes
	echo -e " StartupInit.."
	checkLxiPkg
	ipPowerInit
	if [ -z "$testArg" ]; then setupInternet; fi
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		"/root/multiCard/arturLib.sh"
		"/root/multiCard/graphicsLib.sh"
	)
	
	case "$baseModel" in
		TS4) 
			echo "  File list: TS4"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/multiCard/tsTest.sh"
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
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local ethToRemove
	echo -e "\n Defining requirements.."
	test -z "$uutPn" && except "requirements cant be defined, empty uutPn"
	if [[ ! -z $(echo -n $uutPn |grep "TS4\|nulll") ]]; then
		
		test ! -z $(echo -n $uutPn |grep "TS4") && {
			baseModel="TS4"
		} 

	else
		except "$uutPn cannot be processed, requirements not defined"
	fi
	
	echo -e " Done.\n"
}

checkIfFailed() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local curStep severity errMsg
	
	privateVarAssign "checkIfFailed" "curStep" "$1"
	privateVarAssign "checkIfFailed" "severity" "$2"
	curStep="$1"
	severity="$2"
	if [[ -e "/tmp/statusChk.log" ]]; then
		errMsg="$(cat /tmp/statusChk.log | tr '[:lower:]' '[:upper:]' |grep -v 'DBG>' |grep -e 'EXCEPTION\|FAIL')"
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

pcTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	
	echo "  Turning PSU output on"
	sendKikusuiCmd "output on"
	sleep 5
	chekcUsbDevs
	echo "  Turning PSU output off"
	sendKikusuiCmd "output off"
}

chekcUsbDevs() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local acmDev serialDev status
	let status=0
	acmDev=$(ls /dev |grep ttyACM)
	serialDev=$(ls /dev |grep ttyUSB0)
	echo -n "  USB devices: ACM-"
	if [[ ! -z "$acmDev" ]]; then 
		echo -e -n "\e[0;32mdetected\e[m"
	else 
		echo -e -n "\e[0;31mNOT detected\e[m"
		let status++
	fi
	echo -n "  SerialDev-"
	if [[ ! -z "$serialDev" ]]; then 
		echo -e "\e[0;32mdetected\e[m"
	else 
		echo -e "\e[0;31mNOT detected\e[m"
		let status++
	fi
	return $status
}

pcTests() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local loopCount b
	acquireVal "Kikusui IP" psuIPArg kikusuiIP
	kikusuiInit $kikusuiIP
	kikusuiSetupDefault

	echo -e "\n  Loop count:"
	options=("1" "10" "100" "1000" "10000")
	case `select_opt "${options[@]}"` in
		0) let loopCount=1;;
		1) let loopCount=10;;
		2) let loopCount=100;;
		3) let loopCount=1000;;
		4) let loopCount=10000;;
		*) let loopCount=1;;
	esac
	
	for ((b=1;b<=$loopCount;b++)); do 
		warn "\tLoop: $b"
		pcTest
		sleep 5
	done
}

initGolden25g() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr netIface sshCmd
	if [[ -z "$busAddr25G" ]]; then
		echo "  Getting 25G card first Eth bus"
		sshCmd="lspci -nnd :158b |head -n1 |awk '{print \$1}'"
		busAddr=$(sshSendCmd $goldSrvIp root ${sshCmd})
		if [[ -z "$busAddr" ]]; then
			except "25G card not found!"
		else
			publicVarAssign warn busAddr25G "$busAddr"
		fi
	fi
	if [[ -z "$firstEthNameGOLD25G" ]]; then
		echo "  Getting 25G card first Eth iface name"
		sshCmd="ls -l /sys/class/net |cut -d'>' -f2 |grep $busAddr25G |awk -F/ '{print \$NF}'"
		netIface=$(sshSendCmd $goldSrvIp root ${sshCmd})
		if [[ -z "$netIface" ]]; then
			except "25G card first eth not found!"
		else
			publicVarAssign warn firstEthNameGOLD25G "$netIface"
		fi
	fi
	
}

initGolden10g() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr sshCmd
	if [[ -z "$busAddr10G" ]]; then
		echo "  Getting 10G card first Eth bus"
		sshCmd="lspci -nnd :1572 |head -n1 |awk '{print \$1}'"
		busAddr=$(sshSendCmd $goldSrvIp root ${sshCmd})
		if [[ -z "$busAddr" ]]; then
			except "10G card not found!"
		else
			publicVarAssign warn busAddr10G "$busAddr"
		fi
	fi
	
	if [[ -z "$firstEthNameGOLD10G" ]]; then
		echo "  Getting 10G card first Eth iface name"
		sshCmd="ls -l /sys/class/net |cut -d'>' -f2 |grep $busAddr10G |awk -F/ '{print \$NF}'"
		netIface=$(sshSendCmd $goldSrvIp root ${sshCmd})
		if [[ -z "$netIface" ]]; then
			except "10G card first eth not found!"
		else
			publicVarAssign warn firstEthNameGOLD10G "$netIface"
		fi
	fi

	echo -n "  Checking 10G card first Eth iface MAC base: "
	sshCmd="ifconfig $firstEthNameGOLD10G |grep ether | grep '00:00:00'"
	emptyMac=$(sshSendCmd $goldSrvIp root ${sshCmd})
	if [[ ! -z "$emptyMac" ]]; then
		except "10G card first eth MAC is not burned!"
	else
		echo -e "\e[0;32mOK\e[m"
	fi

	
}

initUUTeth() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local busAddr secBusAddr sshCmd
	if [[ -z "$busAddrUUT10G" ]]; then
		echo "  Getting UUT 10G card first Eth bus"
		
		busAddr=$(lspci -d :1591 |grep .7 |cut -d: -f1)
		if [[ -z "$busAddr" ]]; then
			except "UUT card not found! (busAddr=$busAddr)"
		fi
		checkIfNumber $((16#$busAddr))
		echo "  Getting UUT 25G card first Eth bus"
		secBusAddr=$(printf '%#X' "$((0x$busAddr + 0x01))" |cut -dX -f2)
		if [[ -z "$(lspci -nns $secBusAddr:00.0 |grep E810)" ]]; then
			except "second bus does not correspond to E810 device (bus=$secBusAddr)"
		else
			publicVarAssign warn busAddrUUT10G "$busAddr:00.0"
			publicVarAssign warn busAddrUUT25G "$secBusAddr:00.0"
		fi
	fi
	
	if [[ -z "$firstEthNameUUT10G" ]]; then
		echo "  Getting 10G card first Eth iface name"
		publicVarAssign warn firstEthNameUUT10G $(ls -l /sys/class/net |cut -d'>' -f2 |grep $busAddrUUT10G |awk -F/ '{print $NF}')
		publicVarAssign warn firstEthNameUUT25G $(ls -l /sys/class/net |cut -d'>' -f2 |grep $busAddrUUT25G |awk -F/ '{print $NF}')
	fi

	echo -n "  Check UUT port count: "
	uutPortCount=$(lspci -d :1591 |wc -l)
	checkIfNumber $uutPortCount; let uutPortCount=$uutPortCount
	if ! [ $uutPortCount -eq 12 ]; then
		except "port count on UUT is incorrect: $uutPortCount"
	else
		echo -e "\e[0;32mOK\e[m"
	fi
}

setUpGolden10g() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshCmd cmdRes
	echo "  Setting 25G card eth down on gold server"
	sshCmd="ifconfig $firstEthNameGOLD25G down"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}
	sshCheckLink $goldSrvIp root $firstEthNameGOLD25G no

	echo "  Setting 10G card eth up on gold server"
	sshCmd="ifconfig $firstEthNameGOLD10G 10.10.10.11/24 up"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo -n "  Checking gold server 10G card eth IP: "
	sshCmd="ifconfig $firstEthNameGOLD10G |grep 'inet 10.10.10.11'"
	sshCheckContains $goldSrvIp root "inet 10.10.10.11" ${sshCmd}

	echo -n "  Checking gold server 10G link is UP: "
	sshCmd="ethtool $firstEthNameGOLD10G |grep 'Link detected'"
	sshCheckContains $goldSrvIp root "yes" ${sshCmd}
	if ! [ $? -eq 0 ]; then	except "No link on first GOLDEN server 10G Eth!"; fi	

	echo -n "  Setting gold server 10G card rate: "
	sshCmd="/root/bin/netsetrate.sh 0x80000000000 10000 $firstEthNameGOLD10G"
	sshCheckContains $goldSrvIp root "Rate Mode Passed" ${sshCmd}

}

setUpGolden25g() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	:
}

setUpUUT10g() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes
	echo "  Setting 25G card eth down on UUT"
	ifconfig $firstEthNameUUT25G down
	# sshCheckLink $goldSrvIp root $firstEthNameGOLD25G no

	echo "  Setting 10G card eth up on UUT"
	cmdRes="$(ifconfig $firstEthNameUUT10G 10.10.10.10/24 up 2>&1)"

	echo -n "  Checking UUT 10G eth IP: "
	cmdRes="$(ifconfig $firstEthNameUUT10G 2>&1)"
	checkContains "inet 10.10.10.10" ${cmdRes}

	echo -n "  Checking UUT 10G eth link is UP: "
	cmdRes="$(ethtool $firstEthNameUUT10G |grep 'Link detected' 2>&1)"
	checkContains "yes" ${cmdRes}
	if ! [ $? -eq 0 ]; then	except "No link on first UUT server 10G Eth!"; fi	

	echo -n "  Setting UUT 10G rate: "
	cmdRes="$(/root/bin/netsetrate.sh 0x80000 10000 $firstEthNameUUT10G 2>&1)"
	checkContains "Rate Mode Passed" ${cmdRes}
}


pwUpTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	startServer $goldSrvIp
}

pwDwTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	stopServer $goldSrvIp
}

initGoldenServer() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	startServer $goldSrvIp
	initGolden10g
	initGolden25g
}

iperfTests() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local sshCmd cmdRes
	echo -e "\n Initializing golden server"
	initGoldenServer
	echo -e " Done.\n\n Initializing 10G card on golden server"
	setUpGolden10g
	echo -e " Done.\n\n Initializing UUT Eth"
	initUUTeth
	echo -e " Done.\n\n Initializing 10G UUT"
	setUpUUT10g

	iperfTrafficTest
}

iperfTrafficTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\n Starting traffic test"
	echo "  Killing iperf on gold server"
	sshCmd="kill -9 \$(top -b -n1 |grep iperf |awk '{print \$1}')"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Starting iperf on gold server"
	sshSendCmdNohup $goldSrvIp root "iperf -s -u"

	iperfSendTraffic

	echo "  Killing iperf on gold server"
	sshCmd="kill -9 \$(top -b -n1 |grep iperf |awk '{print \$1}')"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}
	echo -e " Done."
}

iperfSendTraffic() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -n "  Sending iperf traffic: "
	cmdRes="$(iperf -c 10.10.10.11 -n 1024K -u)"
	checkContains "1.00 MBytes" ${cmdRes}
	echo -n "  Checking iperf traffic loses: "
	checkContains "(0%" ${cmdRes}
}

startTsyncService() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	stopTsyncService
	echo "  Starting tsyncd_gps service on UUT server"
	systemctl start tsyncd_gps.service
	countDownDelay 140 "  Waiting for the GPS service init:"
}

stopTsyncService() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo "  Stopping tsyncd_gps service on UUT server"
	systemctl stop tsyncd_gps.service
	echo "  Clearing log file on UUT server"
	date > /var/log/tsyncd.log
	sleep 1
}

initUUTBCM() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	chekcUsbDevs
	if ! [ $? -eq 0 ]; then except "USB devices were not detected. Chech USB cable and run again"; fi
	echo "  Check tsyncd_gps service status on UUT server"
	tsyncdStat="$(systemctl status tsyncd_gps.service |grep 'active (running)')"
	if [[ -z "$tsyncdStat" ]]; then
		startTsyncService
	else
		echo "  Check if config is done"
		waitForLog "/var/log/tsyncd.log" 8 2 "PHY BCM81385 INIT Done, 0"
		if ! [ $? -eq 0 ]; then 
			warn "  TsyncD service was unable to start properly"
			startTsyncService
		fi
	fi


	echo "  Check if config is done"
	waitForLog "/var/log/tsyncd.log" 460 2 "PHY BCM81385 INIT Done, 0"
	if ! [ $? -eq 0 ]; then
		except "TsyncD service was unable to start properly"
	fi
}

initUUTGPS() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local tsyncdStat

	initUUTBCM

	echo "  Check if antenna is connected"
	
	waitForLog "/var/log/tsyncd.log" 2 2 "Antenna connected" 2>&1 > /dev/null
	if ! [ $? -eq 0 ]; then 
		countDownDelay 90 "  Waiting for the GPS antenna init:"
		waitForLog "/var/log/tsyncd.log" 210 2 "Antenna connected"
		if ! [ $? -eq 0 ]; then 
			except "  Antenna failed to connect"
		fi
	fi
}

ptp4lTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"

	iperfTrafficTest

	echo "  Setting false Time on gold server"
	sshCmd="date -s 'Thu Jan 19 11:18:01 IST 2022'"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Writing RTC on gold server"
	sshSendCmdSilent $goldSrvIp root "hwclock -w"

	echo "  Configuring ptp4l on gold server"
	sshCmd="echo 'OPTIONS=-f /etc/ptp4l.conf -i '$firstEthNameGOLD10G > /etc/sysconfig/ptp4l"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Configuring phc2sys on gold server"
	sshCmd="echo 'OPTIONS=-O 0 -r -m -s '$firstEthNameGOLD10G > /etc/sysconfig/phc2sys"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}
	
	echo "  Killing ptp4l on gold server"
	sshCmd="kill -9 \$(top -b -n1 |grep ptp4l |awk '{print \$1}')"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Clearing ptp4l log file gold server"
	sshCmd="echo -n\"\">/root/ptp4l.99"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Starting ptp4l on gold server"
	sshCmd="ptp4l -f /etc/ptp4l.conf -i $firstEthNameGOLD10G -m -s > /var/log/ptp4l.log 2>&1"
	sshSendCmdNohup $goldSrvIp root ${sshCmd}

	countDownDelay 60 "  Waiting for the ptp4l init:"

	echo "  Killing ptp4l on gold server"
	sshCmd="kill -9 \$(top -b -n1 |grep ptp4l |awk '{print \$1}')"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Copying ptp4l log on gold server"
	sshCmd="cp -f /root/ptp4l.99 /var/log/ptp4l.log"
	sshSendCmdSilent $goldSrvIp root ${sshCmd}

	echo "  Check ptp4l log results on gold server"
	sshCmd="cat /var/log/ptp4l.log |grep ': rms' |cut -d: -f2- |awk '{print \"     Mean offset:\"\$2\"ns;Maximum offset:\"\$4\"ns;Mean frequency deviation:\"\$6\"ppb;Path delay:\"\$8\"ns;Standart deviation:\"\$10\"ns\"}'| column -t -s \";\""
	sshCmdRes="$(sshSendCmd $goldSrvIp root ${sshCmd})"
	echo -e "\tptp4l results:\n$sshCmdRes\n"
	if [[ -z "$(echo "$sshCmdRes" |grep 'deviation:-' |grep 'Mean offset:5ns')" ]]; then
		critWarn "\tUnusual ptp4l results! See full trace:"
		sshCmd="cat /var/log/ptp4l.log"
		sshCmdRes="$(sshSendCmd $goldSrvIp root ${sshCmd})"
		echo -e "\n\e[0;31m -- FULL TRACE START --\e[0;33m\n"
		echo -e "$sshCmdRes"
		echo -e "\n\e[0;31m --- FULL TRACE END ---\e[m\n"
	else
		echo "  Removing ptp4l logs on gold server"
		sshCmd="rm -f /root/ptp4l.99; rm -f /var/log/ptp4l.log"
		sshSendCmdSilent $goldSrvIp root ${sshCmd}
	fi
}

ubloxTests() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local geoResp ubloxResp timeAcc satQty posLon posLat addrName
	initUUTGPS
	echo "  UBlox GPS tests:"
	echo "   Gathering UBlox GPS data:"
	privateVarAssign "${FUNCNAME[0]}" "ubloxResp" "$(ubxtool -p CFG-GNSS)"

	echo "    Gathering time accuracy"
	privateNumAssign "timeAcc" "$(echo "$ubloxResp" | grep tAcc |head -1 | awk '{print $2}')"
	echo "    Gathering sattelite quantinty"
	privateNumAssign "satQty" "$(echo "$ubloxResp" | grep numSV |head -1 | awk '{print $2}')"
	echo "    Gathering GPS x pos"
	privateNumAssign "posLon" "$(echo "$ubloxResp" | grep numSV |head -1 | awk '{print $4}')"
	echo "    Gathering GPS y pos"
	privateNumAssign "posLat" "$(echo "$ubloxResp" | grep numSV |head -1 | awk '{print $6}')"
	echo -e "   Done\n"
	if [ $internetAcq -eq 1 ]; then
		checkJQPkg
		if ! ping -c 1 nominatim.openstreetmap.org &> /dev/null; then
			warn "  openstreetmap is unreachable, skipping coordinates resolving"
		else
			geoResp="$(curl "https://nominatim.openstreetmap.org/reverse?lat=$(echo $posLat|awk 'NF{print $1/10000000}')&lon=$(echo $posLon|awk 'NF{print $1/10000000}')&zoom=10&format=json&accept-language=en_US" 2>/dev/null )"
			if [[ ! -z "$geoResp" ]]; then addrName=$(echo -n "$geoResp" | jq -r '.display_name'); fi
		fi
	else
		warn "  interned is not set up, skipping coordinates resolving"
	fi

	echo -e "   GPS data:\n"
	echo -e "     $yl"'Time accuracy: '"$gr$timeAcc$ec"
	echo -e "     $yl"'Sattelite quantity: '"$gr$satQty$ec"
	echo -e "     $yl"'Position longitude: '"$gr$posLon$ec"
	echo -e "     $yl"'Position latitude: '"$gr$posLat$ec"
	if [[ ! -z "$addrName" ]]; then 
		echo -e "     $yl"'Full Address: '"$gr$addrName$ec"
	fi
	echo -e "\n\n"
}

tsTests() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdRes

	echo -e "\n Initializing golden server"
	initGoldenServer
	echo -e " Done.\n\n Initializing 10G card on golden server"
	setUpGolden10g
	echo -e " Done.\n\n Initializing UUT Eth"
	initUUTeth
	echo "  Checking USB devices"
	chekcUsbDevs

	initUUTGPS

	echo -n "  Checking Iface SyncE up: "
	cmdRes="$(cat /var/log/tsyncd.log 2>&1)"
	checkContains "SyncE Port $firstEthNameUUT10G: FAIL -> NORMAL, QL set PRTC" ${cmdRes}

	echo -n "  Checking UUT TSync date: "
	cmdRes="$(cat /var/log/tsyncd.log |grep 'GNSS Parameters Initialization completed' |awk '{print $1}' 2>&1)"
	echo "$cmdRes"

	echo -n "  Checking UUT Serv date: "
	echo "$(date)"

	echo -e " Initializing 10G UUT"
	setUpUUT10g

	ptp4lTest

	ubloxTests
}

pciTests() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local slotNum devCount

	devCount="$(lspci -d :1591 |wc -l 2>&1)"
	if [ $devCount -eq 12 ]; then
		publicNumAssign "slotNum" $(lspci -vvvnnd :1591 |grep "Physical Slot" |grep -v 0 |uniq |cut -d ' ' -f3 2>&1)
		export MC_SCRIPT_PATH=/root/multiCard &> /dev/null
		testFileExist "${MC_SCRIPT_PATH}/sfpLinkTest.sh" > /dev/null
		${MC_SCRIPT_PATH}/sfpLinkTest.sh --minor-launch --noMasterMode --slDupSkp --uut-slot-num=$slotNum --uut-pn="TS4" --test-sel=pciTest $minorArgs
	else
		except "dev count is not expected ($devCount), check port count"
	fi	 
}

linksFlushAndUP() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local linkStatus net nets
	privateVarAssign "${FUNCNAME[0]}" "nets" "$*"
	let linkStatus=0
	for net in $nets; do
		echo -n "  Setting $net DOWN, "
		ifconfig $net down
		let linkStatus+=$?
		echo -n "flushing, "
		ip a flush dev $net
		let linkStatus+=$?
		echo -n "setting UP. "
		ifconfig $net up
		let linkStatus+=$?
		echo "(status=$linkStatus)"
	done
	if ! [ $linkStatus -eq 0 ]; then echo -e "\e[0;31m   Link setup failed!\e[m\n"; else echo -e "\e[0;32m   Link setup passed.\e[m\n"; fi
}

linkTests() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	
	local uutSlotBus net linkStatus
	
	initUUTBCM
	initUUTeth
	publicVarAssign warn uutNets10G $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $(echo $busAddrUUT10G |cut -d. -f1 ) |awk -F/ '{print $NF}')
	publicVarAssign warn uutNets25G $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $(echo $busAddrUUT25G |cut -d. -f1 ) |awk -F/ '{print $NF}')
	publicVarAssign warn uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$(echo $busAddrUUT10G |cut -d: -f1-2 ) |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	publicVarAssign warn uutAllNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $uutSlotBus |awk -F/ '{print $NF}')

	linksFlushAndUP $uutAllNets

	allNetAct "$uutNets10G" "Check links are UP on UUT 10G ports" "testLinks" "yes" "P425G410G8TS81"
	allNetAct "$uutNets10G" "Check Data rates on UUT 10G ports" "getEthRates" "10000" "P425G410G8TS81"

	allNetAct "$uutNets25G" "Check links are UP on UUT 25G ports" "testLinks" "yes" "P425G410G8TS81"
	allNetAct "$uutNets25G" "Check Data rates on UUT 25G ports" "getEthRates" "25000" "P425G410G8TS81"
}

trafficTests() {
	local slotNum
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	linkTests
	inform "  Defining uutSlotNum before passsing it to sfpLinkTest"
	publicNumAssign "slotNum" $(lspci -vvvnnd :1591 |grep "Physical Slot" |grep -v 0 |uniq |cut -d ' ' -f3 2>&1)
	export MC_SCRIPT_PATH=/root/multiCard &> /dev/null
	testFileExist "${MC_SCRIPT_PATH}/sfpLinkTest.sh" > /dev/null
	dmsg uutNets10G=$uutNets10G
	declare -g utNets10G=$uutNets10G
	declare -g utNets25G=$uutNets25G
	${MC_SCRIPT_PATH}/sfpLinkTest.sh --minor-launch --noMasterMode --slDupSkp --uut-slot-num=$slotNum --uut-pn="TS4" --test-sel=trfTest $minorArgs
}

mainTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local pciTest linkTest trafficTest dumpTest bpTest drateTest trfTest tsTest iperfTest pwUpGolden

	if [[ ! -z "$untestedPn" ]]; then untestedPnWarn; fi
	
	if [[ -z "$testArg" ]]; then
		echo -e "\n  Select tests:"
		options=("FT> FULL FT Test" "  PCI Test" "  Link Test" "  Traffic Test" "TS> FULL TS Test" "  IPerf Ping Test" "  UBlox Test" "  GPS Initialize" "  BCM Initialize" "  Power DOWN golden")
		case `select_opt "${options[@]}"` in
			0) 
				pciTest=1
				linkTest=1
				trafficTest=1
			;;
			1) pciTest=1;;
			2) linkTest=1;;
			3) trafficTest=1;;
			4) tsTest=1;;
			5) iperfTest=1;;
			6) ubloxTest=1;;
			7) gpsInit=1;;
			8) bcmInit=1;;
			9) pwDwGolden=1;;
			*) except "unknown option";;
		esac
	fi 

	if [ ! -z "$pciTest" ]; then
		echoSection "PCI Test"
			pciTests |& tee /tmp/statusChk.log
		checkIfFailed "PCI Test failed!" exit
	else
		inform "\tPCI Test skipped"
	fi

	if [ ! -z "$linkTest" ]; then
		echoSection "Link Test"
			linkTests |& tee /tmp/statusChk.log
		checkIfFailed "Link Test failed!" exit
	else
		inform "\tLink Test skipped"
	fi

	if [ ! -z "$trafficTest" ]; then
		echoSection "Traffic Test"
			trafficTests |& tee /tmp/statusChk.log
		checkIfFailed "Traffic Test failed!" exit
	else
		inform "\tTraffic Test skipped"
	fi

	if [ ! -z "$tsTest" ]; then
		echoSection "TimeSync Test"
			tsTests |& tee /tmp/statusChk.log
		checkIfFailed "TimeSync Test failed!" exit
	else
		inform "\tTimeSync Test skipped"
	fi

	if [ ! -z "$iperfTest" ]; then
		echoSection "IPerf Ping Test"
			iperfTests |& tee /tmp/statusChk.log
		checkIfFailed "IPerf Ping Test failed!" exit
	else
		inform "\tIPerf Ping Test skipped"
	fi

	if [ ! -z "$ubloxTest" ]; then
		echoSection "UBlox Test"
			ubloxTests |& tee /tmp/statusChk.log
		checkIfFailed "UBlox Test failed!" exit
	else
		inform "\tUBlox Test skipped"
	fi

	if [ ! -z "$gpsInit" ]; then
		echoSection "GPS Initialize"
			initUUTGPS |& tee /tmp/statusChk.log
		checkIfFailed "GPS Initialize failed!" exit
	fi

	if [ ! -z "$bcmInit" ]; then
		echoSection "BCM Initialize"
			initUUTBCM |& tee /tmp/statusChk.log
		checkIfFailed "BCM Initialize failed!" exit
	fi

	if [ ! -z "$pcUsbTest" ]; then
		echoSection "PowerCycle USB Test"
			pcTests |& tee /tmp/statusChk.log
		checkIfFailed "PowerCycle USB Test failed!" exit
	fi

	if [ ! -z "$pwUpGolden" ]; then
		echoSection "Power UP Golden"
			pwUpTest |& tee /tmp/statusChk.log
		checkIfFailed "Power up Golden failed!" exit
	fi
	if [ ! -z "$pwDwGolden" ]; then
		echoSection "Power DOWN Golden"
			pwDwTest |& tee /tmp/statusChk.log
		checkIfFailed "Power DOWN Golden failed!" exit
	fi
}


initialSetup() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	acquireVal "Part Number" pnArg uutPn
	defineRequirments
	checkRequiredFiles
}

main() {
	mainTest
	passMsg "\n\tDone!\n"
}

function ctrl_c () {
	echo -e "'\n\n\n\e[0;31mTrapped Ctrl+C\nExiting.\e[m"
	tput cnorm
	exit 
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \ttsTest has been loaded as lib (support: arturd@silicom.co.il)'
else
	echo -e '\n# arturd@silicom.co.il\n\n'
	trap "exit 1" 10
	trap ctrl_c SIGINT
	trap ctrl_c SIGQUIT
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
	echo -e "See $(inform "--help" "--nnl" "--sil" 2>&1) for available parameters\n"
fi
