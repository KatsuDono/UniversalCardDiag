#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

selectUSBTPLink() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubNum usbBusSelRes
	privateVarAssign "${FUNCNAME[0]}" "hubNum" "$1"
	local args="--hub-number=$hubNum --hub-dev-id=bda:411 --hub-dev-id=bda:5411 --minimal --margs=dgc"
	if fdExist 12; then inform "\t${FUNCNAME[0]} >fdExist=yes"; else  inform "\t${FUNCNAME[0]} >fdExist=no"; fi
	# usbBusSelRes=`selectUSBBusFDRedir "$hubNum" "${args}"`
	exec 12>&1
	usbBusSelRes=$(selectUSBBusFDRedir "$hubNum" "${args}")
	echo -e "\t${FUNCNAME[0]} >usbBusSelRes=$usbBusSelRes"
}

function selectUSBBusFDRedir () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubNum usbBusSelRes args
	privateVarAssign "${FUNCNAME[0]}" "hubNum" "$1" ;shift
	local args="$*"

	if ! fdExist 12; then exec 12>&-; fi #closing file descriptor 12 for prompts of select_opt_adv
	exec 12>&1  #opening file descriptor 12 for prompts of select_opt_adv
	echo "$(ls -la /proc/$$/fd/ |grep /dev |awk '{print $9}')" >&2
	usbBusSelRes=$(selectUSBBus "Select USB device on hub $hubNum" "${args}" 13>&1)

	echo -n $usbBusSelRes

	if fdExist 12; then exec 12>&-; fi #closing file descriptor 12 for prompts of select_opt_adv
}

function selectUSBBus () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local selDesc usbDevs usbSelRes usbDevsList usbDevBuses
	local usbArgs dev devsList
	
	if fdExist 12; then inform "\t${FUNCNAME[0]} >fdExist=yes" >&2; else  inform "\t${FUNCNAME[0]} >fdExist=no" >&2; fi
	echo "$(ls -la /proc/$$/fd/ |grep /dev |awk '{print $9}')" >&2
	if ! fdExist 12; then  #checking if file descriptor 12 was opened for prompts of select_opt_adv
		except "File descriptor 12 was not created before execution of ${FUNCNAME[0]}"
	else
		privateVarAssign "${FUNCNAME[0]}" "selDesc" "$1"; shift
		echo -e "$selDesc" >&12 #sending to file descriptor 12 for prompts
		privateVarAssign "${FUNCNAME[0]}" "usbArgs" "$*"
		privateVarAssign "${FUNCNAME[0]}" "devsList" "$(getUsbDevsOnHub $usbArgs |sort)"

		while read dev; 
		do
			if [[ ! -z "$dev" ]]; then
				usbDevs+=( "Port: $(cut -d';' -f1 <<<"$dev") -> $(cut -d';' -f3 <<<"$dev")" )
				usbDevBuses+=( $(cut -d';' -f2 <<<"$dev") )
			fi
		done <<<"$devsList"	

		if [ ${#usbDevs[@]} -eq ${#usbDevBuses[@]} ]; then
			for ((cnt=0;cnt<${#usbDevs[@]};cnt++));
			do
				usbDevsList+=("${usbDevs[$cnt]} (bus: ${usbDevBuses[$cnt]})")
			done
		else
			warn "USB count and USB bus device count does not correspond, skipping verbalization" >&12 #sending to file descriptor 12 for prompts
		fi
		if [[ ! -z "${usbDevs[@]}" ]]; then
			if [ -z "$usbDevsList" ]; then
				usbSelRes=$(select_opt_adv "${usbDevs[@]}" 13>&1) #redirecting all FD 13, which is for the results to the stdout
			else
				usbSelRes=$(select_opt_adv "${usbDevsList[@]}" 13>&1) #redirecting all FD 13, which is for the results to the stdout
			fi
			echo -n "${usbDevBuses[$usbSelRes]}" >&13 #sending to file descriptor 13 for results
		else
			except "no usb devs found!"
		fi
	fi
	
	exec 12>&- #closing file descriptor 12 for prompts of select_opt_adv
}

reloadUSBPortByHandle() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubAddr pciHubAddr
	privateVarAssign "${FUNCNAME[0]}" "handleN" "$1"
	#	driverName could be also driver id or device id or any other in uevent
	privateNumAssign "reloadTimeout" "$2"
	hubAddr=$(grep $handleN /sys/bus/usb/devices/*/uevent |grep '\.0' |awk -F: '{print $1}' |awk -F/ '{print $(NF)}')
	if [ ! -z "$hubAddr" ]; then
		pciHubAddr=$(find /sys/bus/pci/devices/*/ -type d -name "$hubAddr")
		if [ ! -z "$pciHubAddr" ]; then
			echo 0 > $pciHubAddr/authorized
			sleep $reloadTimeout
			echo 1 > $pciHubAddr/authorized
		fi
	fi
}

printTPLinkHub() {
	local hubIdx
	privateNumAssign "hubIdx" "$1"
	getUsbDevsOnHub --hub-number=$hubIdx --hub-dev-id=bda:411 --hub-dev-id=bda:5411 | { head -1; sort; }
}

getUsbHubs() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubDevId hubKeyw hubList hubDevsList hubDev hubOk hubArr hubHWPath

	hubList="$(lsusb -d :$hubDevId 2>/dev/null)"
	if [ ! -z "$hubList" ]; then
		hubDevsList=$(awk '{print $4}'<<<"$hubList" |cut -d: -f1)
		for hubDev in $hubDevsList; do
			hubOk=$(timeout 2s lsusb -vs :$hubDev 2>/dev/null |grep "$hubKeyw")
			if [ ! -z "$hubOk" ]; then
				hubBus=$(lsusb -s :$hubDev 2>/dev/null |awk '{print $2}' |cut -d: -f1)
				hubHWPath=$(udevadm info --query=all -n /dev/bus/usb/$hubBus/$hubDev 2>&1 |grep DEVPATH |awk -F/ '{print $NF}')
				if [ ! -z "$hubHWPath" ]; then hubArr+=("$hubHWPath"); fi
			fi
		done
	fi
	if [ ! -z "$hubArr" ]; then echo -n "${hubArr[*]}"; fi
}

getUsbHubsByID() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubDevId hubKeyw hubList hubDevsList hubDev hubOk hubPathArr hubBusArr hubDevsArr hub hubArrIdx hubHWPath
	privateVarAssign "${FUNCNAME[0]}" "hubDevQuery" "$1"
	hubKeyw="Compound device"
	hubList="$(lsusb -d $hubDevQuery 2>/dev/null)"
	if [ ! -z "$hubList" ]; then
		while read hub; 
		do 		
			if isDefined hub; then
				dmsg inform "processing hub: $hub"
				hubBusArr+=("$(awk '{print $2}'<<<"$hub" |cut -d: -f1)")
				hubDevsArr+=("$(awk '{print $4}'<<<"$hub" |cut -d: -f1)")
			fi
		done <<< "$hubList"	
		for ((hubArrIdx=0;hubArrIdx<${#hubDevsArr[@]};hubArrIdx++)); do
			unset hubDevPathOk
			dmsg inform "processing dev: ${hubDevsArr[$hubArrIdx]}"
			hubDevPathOk=$(udevadm info --query=all -n /dev/bus/usb/${hubBusArr[$hubArrIdx]}/${hubDevsArr[$hubArrIdx]} 2>/dev/null |grep DEVPATH)
			if isDefined hubDevPathOk; then
				dmsg inform "hubDevPathOk: $hubDevPathOk"
				hubOk=$(timeout 2s lsusb -vs ${hubBusArr[$hubArrIdx]}:${hubDevsArr[$hubArrIdx]} 2>/dev/null | grep "$hubKeyw")
				if isDefined hubOk; then
					dmsg inform "hubOk: $hubOk"
					hubHWPath=$(udevadm info --query=all -n /dev/bus/usb/${hubBusArr[$hubArrIdx]}/${hubDevsArr[$hubArrIdx]} 2>&1 |grep DEVPATH |awk -F/ '{print $NF}')
					dmsg inform "getting hubHWPath: $hubHWPath"
					if [ ! -z "$hubHWPath" ]; then hubPathArr+=("$hubHWPath"); fi
				fi
			fi
		done
	fi
	if [ ! -z "$hubPathArr" ]; then echo -n "${hubPathArr[*]}"; fi
}

getUsbDevsOnHub() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubList hubNum hubIdx hubHWAddr hub devBus hubDevIDList hubDevId hubsInList hubPortReq
	local devName devParentPath devPath devUevent devInfo devId devSubId devBusnum devDevnum devVerbName
	local busSpeed busGen devIsSecondary hubHWAddrArr
	local devPort usbDir usbDirNamernotepad usbDirsOnParent maxChld maxChildren devRemovable portIdx portEval
	local ARG KEY VALUE minimalMode delimSym

	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			hub-number) privateNumAssign "hubNum" "${VALUE}" ;;
			hub-dev-id) 
				if isDefined VALUE; then
					hubDevIDList+="${VALUE} "
				else
					except "--hub-dev-id should be provided with Device ID!"
				fi
			;;
			hub-port-req)
				if isDefined VALUE; then
					privateNumAssign "hubPortReq" "${VALUE}"
				else
					except "--hub-port-req should be provided with port number!"
				fi
			;;
			delim) 
				if isDefined VALUE; then
					delimSym=${VALUE:0:1}
				else
					except "--delim should be provided with delimeter symbol"
				fi
			;;
			minimal) minimalMode=1 ;;
			margs)
				if isDefined VALUE; then
					margsList="${VALUE}"
					local chrIdx
					for (( chrIdx=0; chrIdx<${#margsList}; chrIdx++ )); do
						chrArg=${margsList:$chrIdx:1}
						case "$chrArg" in
							d) local noDevId=1;;
							g) local noUsbGen=1;;
							b) local noBusAdr=1;;
							c) local noSerCrc=1;;
							*) except "illegal minimal mode argument: $chrArg";;
						esac
					done
				else
					except "--margs should be provided with minimal mode arguments!"
				fi
			;;
			*) dmsg inform "Unknown arg: $ARG"
		esac
	done

	if ! isDefined delimSym; then delimSym=';'; fi
	let maxChildren=0
	
	for hubDevId in $hubDevIDList; do
		let hubIdx=0
		dmsg inform "processing: $hubDevId"
		hubList="$(getUsbHubsByID $hubDevId)"
		for hub in $hubList; do
			let hubIdx++
			if [ $hubNum -eq $hubIdx ]; then 
				hubHWAddrArr+=($hub)
				dmsg inform "hub arr: ${hubHWAddrArr[*]}"
				break
			fi
		done
	done

	if ! isDefined minimalMode && ! isDefined hubPortReq; then
		printf "$blb%*s %*s %*s %*s %*s %*s %*s$ec\n" 5 "Port" 6 "Speed" 8 "Bus:Dev" 10 "ID:SubID" 21 "Name" 21 "Serial CRC"
	fi
	
	for hubHWAddr in ${hubHWAddrArr[*]}; do
		devBus=$(cut -d '-' -f1 <<<"$hubHWAddr")
		hubDevPath="/sys/bus/usb/devices/usb$devBus/$hubHWAddr"
		#devsOnHub="$(ls -l /sys/bus/usb/devices/ |grep "$hubHWAddr\..*:1\..$\|$hubHWAddr\.1\..*:1\..$" |grep -v "$hubHWAddr\.1:1\.0" |awk -F/ '{print $NF}')"
		
		devsOnHub="$(find `find $hubDevPath/* -name authorized |rev |cut -d/ -f2- |rev` -maxdepth 1 -name bInterfaceClass |rev |cut -d/ -f2- |rev)"
		hubsInList=$(grep DRIVER=hub $(sed -e 's|$|/uevent|' <<<"$devsOnHub") |rev |cut -d/ -f2- |rev)
		devsOnHub="$(grep -vF "$hubsInList" <<<"$devsOnHub" |awk -F/ '{print $NF}')" #removing hubs from list

		dmsg inform "devsOnHub: $devsOnHub"

		if [ -e "/sys/bus/usb/devices/usb$devBus/" ]; then
			dmsg inform "Device exist> /sys/bus/usb/devices/usb$devBus/"
			busSpeed=$(cat /sys/bus/usb/devices/usb$devBus/speed 2>/dev/null)

			if isNumber busSpeed; then
				if ! isDefined minimalMode; then
					if [ $busSpeed -gt 3000 ]; then busGen=" ${gr}USB3$ec"; else busGen=" ${org}USB2$ec"; fi
				else
					if [ $busSpeed -gt 3000 ]; then busGen="USB3"; else busGen="USB2"; fi
				fi
			else
				busGen=" ${rd} N/A$ec"
			fi
			
			for dev in $devsOnHub; do
				dmsg inform "Processing dev> $dev"
				devName=$(cut -d: -f1 <<<$dev)
				devPort=$(awk -F'.' '{print $NF}' <<<$devName)
				devPath="$(find "/sys/bus/usb/devices/usb$devBus/" -name dev |grep -m1 "$devName/dev" |rev |cut -d/ -f2- |rev)"
				devParentPath="$(find "/sys/bus/usb/devices/usb$devBus/" -name dev |grep -m1 "$devName/dev" |rev |cut -d/ -f3- |rev)"
				if [ "$hubDevPath" = "$devParentPath" ]; then devIsSecondary=1; else unset devIsSecondary; fi
				devsOnParent="$(find `ls -l -d $devParentPath/*/ |awk '{print $NF}'` -maxdepth 1 -name dev |awk -F/ '{print $(NF-1)}')"
				usbDirsOnParent="$(find `ls -l -d $devParentPath/*/ |awk '{print $NF}'` -maxdepth 1 -name dev |rev |cut -d/ -f2- |rev)"
				parentMaxChildren=$(cat $devParentPath/maxchild 2>/dev/null)
				if ! isNumber parentMaxChildren; then
					except "Parent cant have children, aborting"
				fi

				# dmsg inform "devPath: $devPath"
				dmsg inform "devsOnParent: $devsOnParent"
				dmsg inform "usbDirsOnParent: $usbDirsOnParent"

				let usbDevIdx=0
				let portIdx=0
				let fixedIdx=0
				for usbDir in $usbDirsOnParent; do 
					if [ -e "$usbDir/removable" ]; then 
						let usbDevIdx++
						devRemovable=$(grep "removable" $usbDir/removable 2>/dev/null)
						if isDefined devRemovable; then
							let portIdx++
						else
							if [ -e "$usbDir/maxchild" ]; then 
								dmsg inform "Checking maxchild of $usbDir: "$(cat $usbDir/maxchild)
								maxChld=$(cat $usbDir/maxchild 2>/dev/null)
								if isNumber maxChld; then
									if [ $maxChld -eq 0 ]; then
										let portIdx++
									else
										let fixedIdx++
										unset devRemovable
									fi
								else
									unset devRemovable
								fi
							else
								let fixedIdx++
							fi
						fi
					else
						unset devRemovable
					fi
					dmsg inform " $usbDir > PORTIdx: $portIdx devRemovable: $devRemovable"
					usbDirName=$(awk -F/ '{print $NF}'<<<"$usbDir")
					if [ "$devName" = "$usbDir" ] || [ "$devName" = "$usbDirName" ]; then
						dmsg inform " port found, breaking loop.."
						break
					else
						dmsg inform "$devName is not equial to $usbDir or "
					fi
				done
				if isDefined devIsSecondary; then
					let devPort+=$parentMaxChildren
				fi
				devUevent="$(cat $devPath/uevent)"
				devBusnum=$(grep 'BUSNUM=' <<<"$devUevent" |cut -d= -f2-)
				devDevnum=$(grep 'DEVNUM=' <<<"$devUevent" |cut -d= -f2-)
				devInfo=$(udevadm info -q property -n /dev/bus/usb/$devBusnum/$devDevnum)
				devId=$(grep -oE 'PRODUCT=([0-9a-zA-Z]+)/' <<<"$devInfo" | cut -d'=' -f2 | cut -d'/' -f1 |printf "%04X" "$((16#$(cat)))")
				devSubId=$(grep -oE 'PRODUCT=([0-9a-zA-Z]+)/([0-9a-zA-Z]+)/' <<<"$devInfo" | cut -d'=' -f2 | cut -d'/' -f2 |printf "%04X" "$((16#$(cat)))")
				devVerbName=$(grep 'ID_MODEL=' <<<"$devInfo" | cut -d'=' -f2 |sed "s/_/ /")
				devSerCrc=$(grep 'ID_SERIAL_SHORT=' <<<"$devInfo"| cut -d'=' -f2 | cksum | awk '{print $1}'| printf "%08X\n" "$(cat)" | tr '[:lower:]' '[:upper:]')
				dmsg inform "devPort=$devPort  usbDevIdx=$usbDevIdx  fixedIdx=$fixedIdx"
				portEval=$(($devPort-$fixedIdx))
				dmsg inform "  PORTIdx: $portIdx evalCnt: $portEval"
				if isDefined hubPortReq; then
					if [ $portEval -eq $hubPortReq ]; then
						echo -n "$dev"
						break
					fi
				else
					if isDefined minimalMode; then
						if ! isDefined noDevId; then local devIdMsg=$devId:$devSubId$delimSym; fi
						if ! isDefined noUsbGen; then local busGenMsg=$busGen$delimSym; fi
						if ! isDefined noBusAdr; then local devBusMsg=$devBusnum:$devDevnum$delimSym; fi
						if ! isDefined noSerCrc; then local devSerCrcMsg=$devSerCrc; fi
						echo "$portEval$delimSym$busGenMsg$devBusMsg$devIdMsg${devVerbName:0:30}$delimSym$devSerCrcMsg"
					else
						printf "%-5s %b $blp%*s$ec $blp%-11s$ec $cyg%-30s$ec  $pr%-8s$ec\n" "  $portEval" "$busGen" 10 "[$devBusnum:$devDevnum]" "[$devId:$devSubId]" "${devVerbName:0:30}" "$devSerCrc"
					fi
				fi
			done
		fi
	done
}

getUsbTTYOnHub() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hubPortNumReq hubPortNum hubList hubNum hubIdx hubHWAddr hub devBus hubDevID dev ttyOnDev varName

	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			hub-number) privateNumAssign "hubNum" "${VALUE}" ;;
			hub-dev-id) 
				if isDefined VALUE; then
					hubDevID=${VALUE}
				else
					except "--hub-dev-id should be provided with Device ID!"
				fi
			;;
			hub-port-req)
				if isDefined VALUE; then
					privateNumAssign "hubPortNumReq" "${VALUE}"
				else
					except "--hub-port-req should be provided with port number!"
				fi
			;;
			*) dmsg inform "Unknown arg: $ARG"
		esac
	done

	for varName in hubNum hubPortNumReq; do
		if ! isDefined $varName; then
			except "$varName is undefined!"
		fi
	done

	if isDefined hubDevID; then
		hubList="$(getUsbHubsByID $hubDevID)" #default devid fopr TPLINK 2.0 usb hub is bda:5411
	else
		hubList="$(getUsbHubs)"
	fi

	if [ $hubDevID = "0bda:5411" ]; then
		dev=$(getUsbDevsOnHub --hub-dev-id=$hubDevID --hub-number=$hubNum --hub-port-req=$hubPortNumReq)
		if isDefined dev; then
			ttyOnDev=$(find /sys/bus/usb/devices/usb*/ -name dev |grep "$dev" |grep -m1 tty |awk -F/ '{print $(NF-1)}')
			if isDefined ttyOnDev; then 
				echo -n "$ttyOnDev"
			fi
		fi
	else
		let hubIdx=0
		
		for hub in $hubList; do
			let hubIdx++
			if [ $hubNum -eq $hubIdx ]; then hubHWAddr=$hub; fi
		done

		devBus=$(cut -d '-' -f1 <<<"$hubHWAddr")
		devsOnHub="$(ls -l /sys/bus/usb/devices/ |grep "$hubHWAddr\..*:1\..$\|$hubHWAddr\.4\..*:1\..$" |grep -v "$hubHWAddr\.4:1\.0" |awk -F/ '{print $NF}')"
		#devsOnHub="$(ls -l /sys/bus/usb/devices/ |grep "$hubHWAddr\..:1\|$hubHWAddr\.4\..:1\.0" |grep -v "$hubHWAddr\.4:1\.0" |awk -F/ '{print $NF}')"
		if [ -e "/sys/bus/usb/devices/usb$devBus/" ]; then
			dmsg inform "Device exist> /sys/bus/usb/devices/usb$devBus/"
			for dev in $devsOnHub; do
				dmsg inform "Processing dev> $dev"
				ttyOnDev=$(find /sys/bus/usb/devices/usb$devBus/ -name dev |grep "$dev" |grep -m1 tty |awk -F/ '{print $(NF-1)}')
				if [ ! -z "$ttyOnDev" ]; then
					dmsg inform "TTY exist> $ttyOnDev"
					privateNumAssign "hubPortNum" "$(cut -d. -f2 <<<"$dev" |cut -d: -f1)"
					if [ $hubPortNum -gt 3 ]; then #second part of hub, address have to be adjusted
						privateNumAssign "hubPortNum" "$(cut -d. -f3 <<<"$dev" |cut -d: -f1)"
						let hubPortNum=$(($hubPortNum+3))
					fi
					dmsg inform "  Found dev on port $hubPortNum: $ttyOnDev"
					if [ $hubPortNumReq -eq $hubPortNum ]; then
						echo -n "$ttyOnDev"
					fi
				fi
			done
		fi
	fi
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tUSB lib for testing (support: arturd@silicom.co.il)'
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
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi