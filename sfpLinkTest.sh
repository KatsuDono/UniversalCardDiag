#!/bin/bash

declareVars() {
	ver="v0.02"
	toolName='X710 BP Link Test Tool'
	title="$toolName $ver"
	btitle="  arturd@silicom.co.il"	
	declare -a pciArgs=("null" "null")
	declare -a mastPciArgs=("null" "null")
	let exitExec=0
	let debugBrackets=0
	def2p="1 1 2 2"
	def4p="1 1 2 2 3 3 4 4"
	uutUIOdevNum="null"
	mastUIOdevNum="null"
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
			uut-tn) tnArg=${VALUE} ;;
			uut-rev) revArg=${VALUE} ;;
			ibs-mode) 
				inform "Launch key: IBS mode"
				ibsMode=1
			;;
			ignore-dumps-fail) 
				inform "Launch key: Ignoring dump fail, setting as warn level"
				ignDumpFail=1
			;;
			slDupSkp) 
				inform "Launch key: Ignoring slot duplicate"
				ignoreSlotDuplicate=1
			;;
			skip-init) 
				inform "Launch key: Skipping init of the card"
				skipInit=1
			;;
			silent) 
				silentMode=1 
				inform "Launch key: Silent mode, no beeps allowed"
			;;
			debug) 
				debugMode=1 
				inform "Launch key: Debug mode"
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
	warn "\n=================================" "" "sil"
	echo -e "$toolName"
	echo -e " Arguments:"
	echo -e " --help"
	echo -e "\tShow help message\n"	
	echo -e " --uut-slot-num=NUMBER"
	echo -e "\tUse specific slot for UUT\n"
	echo -e " --master-slot-num=NUMBER"
	echo -e "\tProduct number of UUT\n"
	echo -e " --uut-pn=NUMBER"	
	echo -e "\tTracking number of UUT\n"
	echo -e " --uut-tn=NUMBER"	
	echo -e "\tRevision of UUT\n"
	echo -e " --uut-rev=NUMBER"	
	echo -e "\tUse specific slot for traffic generation card\n"	
	echo -e " --skip-init"	
	echo -e "\tDoes not initializes the card\n"	
	echo -e " --silent"
	echo -e "\tWarning beeps are turned off\n"	
	echo -e " --debug"
	echo -e "\tDebug mode"		
	echo -e " --dbg-brk	"
	echo -e "\tDebug brackets"	
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
	# testFileExist "/dev/bprdctl0" "true" "silent"
	# test "$?" = "0" && {
		test -z "$(lsmod |grep bprdctl_mod)" && bprdctl_start 2>&1 > /dev/null
	# } || {
		# inform "  BPRDCtl dev not found!"
	# }
}

bpi71SrInit() {
	echo "  Loading i40e module"
	test -z "$(lsmod |grep i40e)" && ./loadmod.sh i40e 2>&1 > /dev/null
	echo "  Reseting all BP switches"
	bpctl_util all set_bp_manuf  2>&1 > /dev/null
	bpctl_util all set_bypass off 2>&1 > /dev/null
}

pe310g4bpi40Init() {
	echo "  Loading ixgbe module"
	test -z "$(lsmod |grep ixgbe)" && /root/PE310G4BPI40/loadmod.sh ixgbe 2>&1 > /dev/null
	echo "  Reseting all BP switches"
	bpctl_util all set_bp_manuf  2>&1 > /dev/null
	bpctl_util all set_bypass off 2>&1 > /dev/null
	inform "  Raising global link up delay to 5 seconds"
	publicVarAssign warn globLnkUpDel "5"
}


g4dbirInit() {
	echo "  Loading fm10k module"
	test -z "$(lsmod |grep $ethKern)" && {
		drvInstallRes="$(/root/PE310G4DBIR/iqvlinux.sh 2>&1)"
		test -z "$(echo $drvInstallRes |grep Passed)" && except "${FUNCNAME[0]}" "unable to install Intel driver!"
	}
	
	echo "  Compiling and installing fm10k module"
	if [[ ! -e "/root/PE310G4DBIR/fm10k-0.27.1.sl.3.12/src/fm10k.ko" ]]; then 
		drvInstallRes="$(/root/PE310G4DBIR/setup_ethernet.sh /root/PE310G4DBIR/fm10k-0.27.1.sl.3.12.tar.gz)"
		test -z "$(echo $drvInstallRes |grep 'Shell Script Complete Passed')" && except "${FUNCNAME[0]}" "unable to compile and install fm10k module!"
	fi
	
	echo "  Remounting fm10k module"
	drvInstallRes="$(rdif stop; rmmod $ethKern;insmod /root/PE310G4DBIR/fm10k.ko;echo status=$?)"
	#
	#drvInstallRes="$(rdif stop; rmmod $ethKern;insmod /root/PE310G4DBIR/fm10k-0.27.1.sl.3.12/src/fm10k.ko;echo status=$?)"
	test -z "$(echo $drvInstallRes |grep 'status=0')" && warn "Unable to remount fm10k module!"
	
	echo "  Compiling and installing bypass control module"
	test "$(which bprdctl_util)" = "/usr/bin/bprdctl_util" || {
		drvInstallRes="$(/root/PE310G4DBIR/setup_bypass.sh /root/PE310G4DBIR/bprd_ctl-1.0.17.tar.gz)"
		test -z "$(echo $drvInstallRes |grep 'Shell Script Complete Passed')" && except "${FUNCNAME[0]}" "unable to install bypass control module!"
	}
	
	echo "  Starting bypass control module"
	test -z "$(lsmod |grep -w bprdctl_mod)" && {
		test "$(bprdctl_start; echo -n $?)" = "0" || except "${FUNCNAME[0]}" "unable to start bypass control module!"
	}
	
	echo "  Reseting all BP switches to default configuration"
	test -z "$(bprdctl_util all set_bp_manuf |grep fail)" || except "${FUNCNAME[0]}" "unable to reset BP switches to default configuration!"
	
	echo "  Switching all BP switches to inline mode"
	test -z "$(bprdctl_util all set_bypass off |grep fail)" || except "${FUNCNAME[0]}" "unable to switch BP switches to inline mode!"	
		
	echo "  Setting up redirector control"
	test "$(which rdifctl)" = "/usr/bin/rdifctl" || {
		drvInstallRes="$(/root/PE310G4DBIR/setup_director.sh /root/PE310G4DBIR/rdif-6.0.10.7.33.6.3.tar.gz)"
		test -z "$(echo $drvInstallRes |grep 'Shell Script Complete Passed')" && except "${FUNCNAME[0]}" "unable to setup redirector control!"
	}
	
	echo "  Switching all BP switches to inline mode"
	test -z "$(bprdctl_util all set_bypass off |grep fail)" || except "${FUNCNAME[0]}" "unable to switch BP switches to inline mode!"	
	
	echo "  Copying config files"
	cp -f "/root/PE310G4DBIR/fm_platform_attributes.cfg.x1" "/etc/rdi/fm_platform_attributes.cfg"
	if [ $? -gt 0 ]; then except "${FUNCNAME[0]}" "Config files couldnt be copied"; fi

	echo "  Starting RDIF"
	rdifStartRes="$(/root/PE310G4DBIR/rdif_bpstart.sh ./ $uutSlotNum)"
	if [ -z "$(echo "$rdifStartRes" |grep -w "RDIFD Passed")" ]; then 
		warn "  Unable to start RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	fi
	
	echo "  Assigning RDIF dev IDs by UIO dev id"
	if [ -z "$(echo "$rdifStartRes" |grep "Found netdev")" ]; then 
		warn "  Unable to start RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	else
		netdevsDecl="$(echo "$rdifStartRes" |grep "Found netdev")"
		declare -a netdevsDeclArr
		shopt -s lastpipe
		echo "$netdevsDecl" | while IFS= read -r netdev ; do 
			netDevEthName=$(echo $netdev |awk '{print $3}')
			if [[ " ${mastNets[*]} " =~ " ${netDevEthName} " ]]; then
				mastUIOdevNum=$(echo $netdev |cut -d/ -f3 |cut -c4)	
			else
				uutUIOdevNum=$(echo $netdev |cut -d/ -f3 |cut -c4)	
			fi
		done 
		inform "  Master UIO device assigned: $mastUIOdevNum"
		inform "  UUT UIO device assigned: $uutUIOdevNum"		
	fi

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
		"--target-bus=$uutBus"
		
		"--eth-buses=$ethBuses"
		"--bp-buses=$bpBuses"
		
		"--eth-dev-id=$physEthDevId"
		"--eth-virt-dev-id=$virtEthDevId"
		
		"--eth-dev-qty=$physEthDevQty"
		"--eth-virt-dev-qty=$virtEthDevQty"
		"--bp-dev-qty=$bpDevQty"
		
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

g2dbirInit() {
	inform "  Raising global link up delay to 5 seconds"
	publicVarAssign warn globLnkUpDel "1"

	echo "  Loading fm10k module"
	test -z "$(lsmod |grep $ethKern)" && {
		drvInstallRes="$(/root/PE340G2DBIR/iqvlinux.sh 2>&1)"
		test -z "$(echo $drvInstallRes |grep Passed)" && except "${FUNCNAME[0]}" "unable to install Intel driver!"
	}
	
	
	echo "  Remounting fm10k module"
	drvInstallRes="$(rdif stop;/root/PE3100G2DBIR/uloadmod.sh fm10k;insmod /root/PE340G2DBIR/fm10k.ko;echo status=$?)"
	test -z "$(echo $drvInstallRes |grep 'status=0')" && warn "Unable to remount fm10k module!"
	
	
	echo "  Starting bypass control module"
	test -z "$(lsmod |grep -w bprdctl_mod)" && {
		test "$(bprdctl_start; echo -n $?)" = "0" || except "${FUNCNAME[0]}" "unable to start bypass control module!"
	}
	
	echo "  Assigning master BP buses"
	publicVarAssign warn mastBpBuses $(filterDevsOnBus $mastSlotBus $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1))


	echo "  Reseting all BP switches to default configuration"
	test -z "$(bprdctl_util all set_bp_manuf |grep fail)" || except "${FUNCNAME[0]}" "unable to reset BP switches to default configuration!"
	
	echo "  Switching all BP switches to inline mode"
	test -z "$(bprdctl_util all set_bypass off |grep fail)" || except "${FUNCNAME[0]}" "unable to switch BP switches to inline mode!"	
	
	echo "  Copying config files"
	cp -f "/root/PE340G2DBIR/fm_platform_attributes.cfg.x2" "/etc/rdi/fm_platform_attributes.cfg"
	if [ $? -gt 0 ]; then except "${FUNCNAME[0]}" "Config files couldnt be copied"; fi

	echo "  Starting RDIF"
	rdifStartRes="$(/root/PE340G2DBIR/rdif_start.sh)"
	if [ -z "$(echo "$rdifStartRes" |grep -w "RDIFD Passed")" ]; then 
		warn "  Unable to start RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	fi
	
	if [ ! "$(echo $(rdifctl get_dev_num) |awk '{print $6}')" = "2" ]; then
		except "${FUNCNAME[0]}" "RDIF device count is incorrect ($(echo $(rdifctl get_dev_num) |awk '{print $6}'))"
	else
		echo "  Checked RDI devs count: $(echo $(rdifctl get_dev_num) |awk '{print $6}')"
	fi

	echo "  Assigning RDIF dev IDs by UIO dev id"
	if [ -z "$(echo "$rdifStartRes" |grep "Found netdev")" ]; then 
		warn "  Unable to start RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	else
		netdevsDecl="$(echo "$rdifStartRes" |grep "Found netdev")"
		declare -a netdevsDeclArr
		shopt -s lastpipe
		echo "$netdevsDecl" | while IFS= read -r netdev ; do 
			netDevEthName=$(echo $netdev |awk '{print $3}')
			if [[ " ${mastNets[*]} " =~ " ${netDevEthName} " ]]; then
				mastUIOdevNum=$(echo $netdev |cut -d/ -f3 |cut -c4)	
			else
				uutUIOdevNum=$(echo $netdev |cut -d/ -f3 |cut -c4)	
			fi
		done 
		inform "  Master UIO device assigned: $mastUIOdevNum"
		inform "  UUT UIO device assigned: $uutUIOdevNum"		
	fi

	echo "  Setting RRC to NIC Mode"
	rdifStartRes="$(/root/PE340G2DBIR/rdif_config2.sh 2 2 $mastSlotNum $uutSlotNum)"
	test -z "$(echo "$rdifStartRes" |grep -w "Rdif Config Passed")" && {
		warn "  Unable to configure RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "Paired_Device=0")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	}
	
	echo "  Reassigning nets"
	assignNets
	
	echo "  Reassigning UUT buses"
	assignBuses eth bp plx
	
	echo "  Defining PCi args"
	dmsg inform "DEBUG1: ${pciArgs[@]}"
	pciArgs=(
		"--target-bus=$uutBus"
		"--plx-buses=$plxBuses"
		"--eth-buses=$ethBuses"
		"--bp-buses=$bpBuses"

		"--plx-dev-id=$plxDevId"
		"--eth-dev-id=$physEthDevId"

		"--plx-kernel=$plxKern"
		"--eth-kernel=$ethKern"
		"--bp-kernel=$ethKern"

		"--plx-dev-qty=$plxDevQty"
		"--plx-dev-sub-qty=$plxDevSubQty"
		"--plx-dev-empty-qty=$plxDevEmptyQty"
		"--eth-dev-qty=$physEthDevQty"
		"--bp-dev-qty=$bpDevQty"

		"--plx-dev-speed=$plxDevSpeed"
		"--plx-dev-width=$plxDevWidth"
		"--plx-dev-sub-speed=$plxDevSubSpeed"
		"--plx-dev-sub-width=$plxDevSubWidth"
		"--plx-dev-empty-speed=$plxDevEmptySpeed"
		"--plx-dev-empty-width=$plxDevEmptyWidth"
		"--plx-keyw=Physical Slot:"
		"--plx-virt-keyw=ABWMgmt+"
		"--eth-dev-speed=$physEthDevSpeed"
		"--eth-dev-width=$physEthDevWidth"
		"--bp-dev-speed=$physEthDevSpeed"
		"--bp-dev-width=$physEthDevWidth"
	)
	mastPciArgs=(
		"--target-bus=$mastBus"
		"--plx-buses=$plxBuses"
		"--eth-buses=$mastEthBuses"
		"--bp-buses=$mastBpBuses"

		"--plx-dev-id=$plxDevId"
		"--eth-dev-id=$physEthDevId"

		"--plx-kernel=$plxKern"
		"--eth-kernel=$ethKern"
		"--bp-kernel=$ethKern"

		"--plx-dev-qty=$plxDevQty"
		"--plx-dev-sub-qty=$plxDevSubQty"
		"--plx-dev-empty-qty=$plxDevEmptyQty"
		"--eth-dev-qty=$physEthDevQty"
		"--bp-dev-qty=$bpDevQty"

		"--plx-dev-speed=$plxDevSpeed"
		"--plx-dev-width=$plxDevWidth"
		"--plx-dev-sub-speed=$plxDevSubSpeed"
		"--plx-dev-sub-width=$plxDevSubWidth"
		"--plx-dev-empty-speed=$plxDevEmptySpeed"
		"--plx-dev-empty-width=$plxDevEmptyWidth"
		"--plx-keyw=Physical Slot:"
		"--plx-virt-keyw=ABWMgmt+"
		"--eth-dev-speed=$physEthDevSpeed"
		"--eth-dev-width=$physEthDevWidth"
		"--bp-dev-speed=$physEthDevSpeed"
		"--bp-dev-width=$physEthDevWidth"
	)
	inform "mastPciArgs were cloned from pciArgs of UUT" 
	dmsg inform "DEBUG2: ${pciArgs[@]}"
}
pe3100g2dbirInit() {
	inform "  Raising global link up delay to 5 seconds"
	publicVarAssign warn globLnkUpDel "1"

	echo "  Loading fm10k module"
	test -z "$(lsmod |grep $ethKern)" && {
		drvInstallRes="$(/root/PE3100G2DBIR/iqvlinux.sh 2>&1)"
		test -z "$(echo $drvInstallRes |grep Passed)" && except "${FUNCNAME[0]}" "unable to install Intel driver!"
	}
	
	
	echo "  Remounting fm10k module"
	drvInstallRes="$(rdif stop;/root/PE3100G2DBIR/uloadmod.sh fm10k;insmod /root/PE3100G2DBIR/fm10k.ko;echo status=$?)"
	test -z "$(echo $drvInstallRes |grep 'status=0')" && warn "Unable to remount fm10k module!"
	
	
	echo "  Starting bypass control module"
	test -z "$(lsmod |grep -w bprdctl_mod)" && {
		test "$(bprdctl_start; echo -n $?)" = "0" || except "${FUNCNAME[0]}" "unable to start bypass control module!"
	}

	echo "  Assigning master BP buses"
	publicVarAssign warn mastBpBuses $(filterDevsOnBus $mastSlotBus $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1))

	echo "  Reseting all BP switches to default configuration"
	test -z "$(bprdctl_util all set_bp_manuf |grep fail)" || except "${FUNCNAME[0]}" "unable to reset BP switches to default configuration!"
	
	echo "  Switching all BP switches to inline mode"
	test -z "$(bprdctl_util all set_bypass off |grep fail)" || except "${FUNCNAME[0]}" "unable to switch BP switches to inline mode!"	
	
	echo "  Copying config files"
	cp -f "/root/PE3100G2DBIR/fm_platform_attributes.cfg.x2" "/etc/rdi/fm_platform_attributes.cfg"
	if [ $? -gt 0 ]; then except "${FUNCNAME[0]}" "Config files couldnt be copied"; fi

	echo "  Starting RDIF"
	rdifStartRes="$(/root/PE3100G2DBIR/rdif_start.sh)"
	if [ -z "$(echo "$rdifStartRes" |grep -w "RDIFD Passed")" ]; then 
		warn "  Unable to start RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	fi
	
	if [ ! "$(echo $(rdifctl get_dev_num) |awk '{print $6}')" = "2" ]; then
		except "${FUNCNAME[0]}" "RDIF device count is incorrect ($(echo $(rdifctl get_dev_num) |awk '{print $6}'))"
	else
		echo "  Checked RDI devs count: $(echo $(rdifctl get_dev_num) |awk '{print $6}')"
	fi

	echo "  Assigning RDIF dev IDs by UIO dev id"
	if [ -z "$(echo "$rdifStartRes" |grep "Found netdev")" ]; then 
		warn "  Unable to start RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "RDIF daemon version")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	else
		netdevsDecl="$(echo "$rdifStartRes" |grep "Found netdev")"
		declare -a netdevsDeclArr
		shopt -s lastpipe
		echo "$netdevsDecl" | while IFS= read -r netdev ; do 
			netDevEthName=$(echo $netdev |awk '{print $3}')
			if [[ " ${mastNets[*]} " =~ " ${netDevEthName} " ]]; then
				mastUIOdevNum=$(echo $netdev |cut -d/ -f3 |cut -c4)	
			else
				uutUIOdevNum=$(echo $netdev |cut -d/ -f3 |cut -c4)	
			fi
		done 
		inform "  Master UIO device assigned: $mastUIOdevNum"
		inform "  UUT UIO device assigned: $uutUIOdevNum"		
	fi

	echo "  Setting RRC to NIC Mode"
	rdifStartRes="$(/root/PE3100G2DBIR/rdif_config2.sh 2 2 $mastSlotNum $uutSlotNum)"
	test -z "$(echo "$rdifStartRes" |grep -w "Rdif Config Passed")" && {
		warn "  Unable to configure RDIF"
		echo -e "\n\e[0;31m -- TRACE START --\e[0;33m\n"
		echo -e "$(echo "$rdifStartRes" |grep -A 99 -w "Paired_Device=0")"
		echo -e "\n\e[0;31m --- TRACE END ---\e[m\n"
	}
	
	echo "  Reassigning nets"
	assignNets
	
	echo "  Reassigning UUT buses"
	assignBuses eth bp plx
	
	echo "  Defining PCi args"
	dmsg inform "DEBUG1: ${pciArgs[@]}"
	pciArgs=(
		"--target-bus=$uutBus"
		"--plx-buses=$plxBuses"
		"--eth-buses=$ethBuses"
		"--bp-buses=$bpBuses"

		"--plx-dev-id=$plxDevId"
		"--eth-dev-id=$physEthDevId"

		"--plx-kernel=$plxKern"
		"--eth-kernel=$ethKern"
		"--bp-kernel=$ethKern"

		"--plx-dev-qty=$plxDevQty"
		"--plx-dev-sub-qty=$plxDevSubQty"
		"--plx-dev-empty-qty=$plxDevEmptyQty"
		"--eth-dev-qty=$physEthDevQty"
		"--bp-dev-qty=$bpDevQty"

		"--plx-dev-speed=$plxDevSpeed"
		"--plx-dev-width=$plxDevWidth"
		"--plx-dev-sub-speed=$plxDevSubSpeed"
		"--plx-dev-sub-width=$plxDevSubWidth"
		"--plx-dev-empty-speed=$plxDevEmptySpeed"
		"--plx-dev-empty-width=$plxDevEmptyWidth"
		"--plx-keyw=Physical Slot:"
		"--plx-virt-keyw=ABWMgmt+"
		"--eth-dev-speed=$physEthDevSpeed"
		"--eth-dev-width=$physEthDevWidth"
		"--bp-dev-speed=$physEthDevSpeed"
		"--bp-dev-width=$physEthDevWidth"
	)
	mastPciArgs=(
		"--target-bus=$mastBus"
		"--plx-buses=$plxBuses"
		"--eth-buses=$mastEthBuses"
		"--bp-buses=$mastBpBuses"

		"--plx-dev-id=$plxDevId"
		"--eth-dev-id=$physEthDevId"

		"--plx-kernel=$plxKern"
		"--eth-kernel=$ethKern"
		"--bp-kernel=$ethKern"

		"--plx-dev-qty=$plxDevQty"
		"--plx-dev-sub-qty=$plxDevSubQty"
		"--plx-dev-empty-qty=$plxDevEmptyQty"
		"--eth-dev-qty=$physEthDevQty"
		"--bp-dev-qty=$bpDevQty"

		"--plx-dev-speed=$plxDevSpeed"
		"--plx-dev-width=$plxDevWidth"
		"--plx-dev-sub-speed=$plxDevSubSpeed"
		"--plx-dev-sub-width=$plxDevSubWidth"
		"--plx-dev-empty-speed=$plxDevEmptySpeed"
		"--plx-dev-empty-width=$plxDevEmptyWidth"
		"--plx-keyw=Physical Slot:"
		"--plx-virt-keyw=ABWMgmt+"
		"--eth-dev-speed=$physEthDevSpeed"
		"--eth-dev-width=$physEthDevWidth"
		"--bp-dev-speed=$physEthDevSpeed"
		"--bp-dev-width=$physEthDevWidth"
	)
	inform "mastPciArgs were cloned from pciArgs of UUT" 
	dmsg inform "DEBUG2: ${pciArgs[@]}"
}

pe310g4bpi9Init() {
	echo "  Loading ixgbe module"
	test -z "$(lsmod |grep ixgbe)" && /root/PE310G4BPI9/loadmod.sh ixgbe 2>&1 > /dev/null
	echo "  Reseting all BP switches"
	bpctl_util all set_bp_manuf  2>&1 > /dev/null
	bpctl_util all set_bypass off 2>&1 > /dev/null
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
			PE310G4BPI71) bpi71SrInit;;
			PE310G2BPI71) bpi71SrInit;;
			PE340G2BPI71) bpi71SrInit;;
			PE310G4BPI40) pe310g4bpi40Init;;
			PE210G2BPI40) pe310g4bpi40Init;;
			PE310G4I40) pe310g4bpi40Init;;
			PE310G4DBIR) g4dbirInit;;
			PE340G2DBIR) g2dbirInit;;
			PE3100G2DBIR) pe3100g2dbirInit;;
			PE310G4BPI9) pe310g4bpi9Init;;
			PE210G2SPI9A) ;;
			PE325G2I71) pe325g2i71Init;;
			PE31625G4I71L)	pe31625gi71lInit;;
			M4E310G4I71)	m4E310g4i71Init;;
			*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
		esac
	}
	echo -e "  Initializing master"
		case "$mastBaseModel" in
			PE310G4BPI71) bpi71SrInit;;
			PE310G2BPI71) bpi71SrInit;;
			PE340G2BPI71) bpi71SrInit;;
			PE310G4BPI40) pe310g4bpi40Init;;
			PE310G4I40) pe310g4bpi40Init;;
			PE310G4DBIR) g4dbirInit;;
			PE340G2DBIR) inform "Master init skipped, special case";;
			PE3100G2DBIR) inform "Master init skipped, special case";;
			PE310G4BPI9) pe310g4bpi9Init;;
			PE210G2BPI9) bpi71SrInit;;
			PE210G2SPI9A) bpi71SrInit;;
			PE325G2I71) pe325g2i71Init;;
			PE31625G4I71L)	pe31625gi71lInit;;
			M4E310G4I71)	m4E310g4i71Init;;
			*) except "${FUNCNAME[0]}" "unknown mastBaseModel: $mastBaseModel"
		esac
	echo "  Clearing temp log"; rm -f /tmp/statusChk.log 2>&1 > /dev/null
	echo -e " Done.\n"
}

checkRequiredFiles() {
	local filePath filesArr
	echo -e " Checking required files.."
	
	declare -a filesArr=(
		"/root/PE310G4BPI71/library.sh"
		"/root/multiCard/arturLib.sh"
		"/root/multiCard/graphicsLib.sh"
	)
	
	case "$baseModel" in
		PE310G4BPI71) 
			echo "  File list: PE310G4BPI71"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE310G4BPI71/txgen2.sh"	
			)				
		;;
		PE310G2BPI71) 
			echo "  File list: PE310G2BPI71-SR"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE310G2BPI71/txgen2.sh"	
			)	
		;;
		PE340G2BPI71) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE340G2BPI71"	
			)	
		;;
		
		PE210G2BPI40) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE210G2BPI40"
				"/root/PE210G2BPI40/loadmod.sh"
			)	
		;;
		PE310G4BPI40) 
			echo "  File list: PE310G4BPI40"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE310G4BPI40"
				"/root/PE310G4BPI40/loadmod.sh"
			)	
		;;
		PE310G4I40) 
			echo "  File list: PE310G4I40"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE310G4I40"
				"/root/PE310G4I40/loadmod.sh"
			)	
		;;
		PE310G4DBIR) 
			echo "  File list: $baseModel"
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
				"/root/PE310G4DBIR/pcitxgenohup5-1_BPI-MOD.sh"
				"/root/PE310G4DBIR/fm10k.ko"
				"/root/PE310G4DBIR/fm_platform_attributes.cfg.x1"
				"/root/PE310G4DBIR/fm_platform_attributes.cfg.x2"
			)
		;;
		PE340G2DBIR) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE340G2DBIR"
				"/root/PE340G2DBIR/iqvlinux.sh" 
				"/root/PE340G2DBIR/fm10k.ko"
				"/root/PE340G2DBIR/fm_platform_attributes.cfg.x1"
				"/root/PE340G2DBIR/fm_platform_attributes.cfg.x2"
				"/root/PE3100G2DBIR/uloadmod.sh"
			)
		;;
		PE3100G2DBIR) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE3100G2DBIR"
				"/root/PE3100G2DBIR/iqvlinux.sh" 
				"/root/PE3100G2DBIR/fm10k.ko"
				"/root/PE3100G2DBIR/fm_platform_attributes.cfg.x1"
				"/root/PE3100G2DBIR/fm_platform_attributes.cfg.x2"
				"/root/PE3100G2DBIR/uloadmod.sh"
			)
		;;
		PE310G4BPI9) 
			echo "  File list: $baseModel"
			declare -a filesArr=(
				${filesArr[@]}				
				"/root/PE310G4BPI9"
				"/root/PE310G4BPI9/loadmod.sh"
			)	
		;;
		PE210G2BPI9) 
			echo "  File list: PE210G2BPI9"
		;;
		PE210G2SPI9A)
			echo "  File list: PE210G2SPI9A"
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
		IBSGP-T-MC-AM) 
			echo "  File list: IBSGP-T-MC-AM"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/multiCard/usb_cmd.sh"
			)
		;;
		IBS10GP) 
			echo "  File list: IBS10GP"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/multiCard/usb_cmd.sh"
			)
		;;
		IBSGP-T) 
			echo "  File list: IBSGP-T"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/multiCard/usb_cmd.sh"
			)
		;;
		*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
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
		except "${FUNCNAME[0]}" "FW file not found!"
	} || echo -e "  \e[0;32mok.\e[m"
}

checkFWFiles() {
	local filePath filesArr
	echo -e " Checking required FW files.."
	
	declare -a filesArr=(
		"/root/multiCard/arturLib.sh"
	)

	if [[ -z "$fwPath" ]]; then
		getFwFromServ "$baseModel" "$fwSyncPn"
	fi

	fwFolder=$(basename $fwPath)

	case "$fwSyncPn" in
		Pe310g4bpi71.SR)
			echo "  FW Files list: PE310G4BPI71-SR"	
			case "$fwFolder" in
				3.30)	fwFileName="PE310G4BPi71-SRD_2v00.bin"	;;
				3.50)	fwFileName="PE310G4BPi71-SRD_3v00.bin"	;;
				3.80)	fwFileName="PE310G4BPi71-SRD_5v00.bin"	;;
				5.50)	fwFileName="PE310G4BPi71-SRD_8r15-7v00.bin"	;;
				*) warn "checkFWFiles exception, unknown fwFolder: $fwFolder"
			esac
		;;
		PE310G2BPI71-SR)
			echo "  FW Files list: PE310G2BPI71-SR"
			inform "\t UNDEFINED!"
		;;
		PE310G4DBIR)
			echo "  FW Files list: PE310G4DBIR"
			inform "\t UNDEFINED!"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE310G4DBIR"
			)
		;;
		PE310G4BPI9)
			echo "  FW Files list: PE310G4BPI9"
			inform "\t UNDEFINED!"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE310G4BPI9"
			)
		;;
		PE210G2BPI9)
			echo "  FW Files list: PE210G2BPI9"
			inform "\t UNDEFINED!"
		;;
		PE325G2I71)
			echo "  FW Files list: PE325G2I71"
			inform "\t UNDEFINED!"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE325G2I71"
			)
		;;
		PE31625G4I71L)
			echo "  FW Files list: PE31625G4I71L-XR-CX"
			inform "\t UNDEFINED!"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/PE31625G4I71L"
			)
		;;
		M4E310G4I71)
			echo "  FW Files list: M4E310G4I71"
			inform "\t UNDEFINED!"
			declare -a filesArr=(
				${filesArr[@]}
				"/root/M4E310G4I71"
			)
		;;
		*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
	esac
	
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
			if [[ "$?" -eq "0" ]]; then echo "    Revision patched."; else except "${FUNCNAME[0]}" "failed to patch revision"'!'; let status+=$?; fi
		else
			except "${FUNCNAME[0]}" "revision length exceeds the FW size and cannot be patched onto it!"
		fi
		if (( "$fwCurSize" >= "$timeEndAddr" )); then
			echo -n "$timePatch" | dd bs=1 seek=$timeOffset of="$patchedFwFile" conv=notrunc >/dev/null 2>&1
			if [[ "$?" -eq "0" ]]; then echo "    Date patched."; else except "${FUNCNAME[0]}" "failed to patch date"'!'; let status+=$?; fi
		else
			except "${FUNCNAME[0]}" "date length exceeds the FW size and cannot be patched onto it!"
		fi
		if (( "$fwCurSize" >= "$trackEndAddr" )); then
			echo -n "$track" | dd bs=1 seek=$trackOffset of="$patchedFwFile" conv=notrunc >/dev/null 2>&1
			if [[ "$?" -eq "0" ]]; then echo "    Tracking patched."; else except "${FUNCNAME[0]}" "failed to patch tracking"'!'; let status+=$?; fi
		else
			except "${FUNCNAME[0]}" "track length exceeds the FW size and cannot be patched onto it!"
		fi


		if [[ "$status" -eq "0" ]]; then
			echo -e "   Patching done!"
		else
			except "${FUNCNAME[0]}" "FW Patching failed!"
		fi
	else
		except "${FUNCNAME[0]}" "patchedFwFile is not found by path: $patchedFwFile"
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

defineRequirments() {
	local ethToRemove
	echo -e "\n Defining requirements.."
	test -z "$uutPn" && except "${FUNCNAME[0]}" "requirements cant be defined, empty uutPn"
	if [[ ! -z $(echo -n $uutPn |grep "PE310G4BPI71-SR\|PE310G4BPI71-LR\|PE210G2BPI40-T\|PE310G4BPI40\|PE310G4I40\|PE310G2BPI71-SR\|PE340G2BPI71-QS43\|PE310G4DBIR\|PE310G4BPI9-LR\|PE310G4BPI9-SR\|PE210G2BPI9\|PE210G2SPI9A-XR\|PE325G2I71\|PE31625G4I71L-XR-CX\|M4E310G4I71-XR-CP\|PE340G2DBIR-QS41\|PE3100G2DBIR\|IBSGP-T-MC-AM\|IBS10GP-LR-RW\|IBSGP-T\|IBS10GP-*\|IBSGP-T*") ]]; then
		dmsg inform "DEBUG1: ${pciArgs[@]}"
		
		test ! -z $(echo -n $uutPn |grep "PE310G4BPI71-SR") && {
			uutPortMatch="$def4p"
			ethKern="i40e"
			ethMaxSpeed="10000"
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
			baseModel="PE310G4BPI71"
			syncPn="PE310G4BPI71-SR"
			fwSyncPn="Pe310g4bpi71.SR"
			baseModelPath="/root/PE310G4BPI71"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			slcmMode="slcm"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth bp
			pciArgs=(
				"--target-bus=$uutBus"
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

		test ! -z $(echo -n $uutPn |grep "PE310G4BPI71-LR") && {
			uutPortMatch="$def4p"
			ethKern="i40e"
			ethMaxSpeed="10000"
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
			baseModel="PE310G4BPI71"
			syncPn="PE310G4BPI71-LR"
			fwSyncPn="Pe310g4bpi71.LR"
			baseModelPath="/root/PE310G4BPI71"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			slcmMode="slcm"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth bp
			pciArgs=(
				"--target-bus=$uutBus"
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

		test ! -z $(echo -n $uutPn |grep "PE210G2BPI40-T") && {
			uutPortMatch="$def2p"
			ethKern="ixgbe"
			ethMaxSpeed="10000"
			let physEthDevQty=2
			let bpDevQty=1
			baseModel="PE210G2BPI40"
			syncPn="PE210G2BPI40"
			# fwSyncPn="Pe310g4bpi71.LR"
			baseModelPath="/root/PE210G2BPI40"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			uutDRates=("100" "1000" "10000")
			
			let physEthDevSpeed=5
			let physEthDevWidth=8
						

			assignBuses eth bp
			pciArgs=(
				"--target-bus=$uutBus"
				"--eth-buses=$ethBuses"
				"--bp-buses=$bpBuses"

				"--eth-dev-id=$physEthDevId"

				"--eth-kernel=$ethKern"
				"--bp-kernel=$ethKern"

				"--eth-dev-qty=$physEthDevQty"
				"--bp-dev-qty=$bpDevQty"

				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
				"--bp-dev-speed=$physEthDevSpeed"
				"--bp-dev-width=$physEthDevWidth"
			)
		}

		test ! -z $(echo -n $uutPn |grep "PE310G4BPI40") && {
			ethKern="ixgbe"
			ethMaxSpeed="10000"
			let physEthDevQty=4
			let bpDevQty=2
			baseModel="PE310G4BPI40"
			syncPn="PE310G4BPI40"
			# fwSyncPn="Pe310g4bpi71.LR"
			baseModelPath="/root/PE310G4BPI40"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			uutDRates=("100" "1000" "10000")
			
			let physEthDevSpeed=5
			let physEthDevWidth=8
			
			plxKern="pcieport"
			let plxDevQty=1
			let plxDevSubQty=2
			let plxDevEmptyQty=1
			plxDevId="8724"
			let plxDevSpeed=8
			let plxDevWidth=8
			let plxDevSubSpeed=5
			let plxDevSubWidth=8
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=0
			

			assignBuses plx eth bp
			pciArgs=(
				"--target-bus=$uutBus"
				"--plx-buses=$plxBuses"
				"--eth-buses=$ethBuses"
				"--bp-buses=$bpBuses"

				"--plx-dev-id=$plxDevId"
				"--eth-dev-id=$physEthDevId"

				"--plx-kernel=$plxKern"
				"--eth-kernel=$ethKern"
				"--bp-kernel=$ethKern"

				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-empty-qty=$plxDevEmptyQty"
				"--eth-dev-qty=$physEthDevQty"
				"--bp-dev-qty=$bpDevQty"

				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--plx-dev-empty-speed=$plxDevEmptySpeed"
				"--plx-dev-empty-width=$plxDevEmptyWidth"
				"--plx-keyw=Physical Slot:"
				"--plx-virt-keyw=ABWMgmt+"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
				"--bp-dev-speed=$physEthDevSpeed"
				"--bp-dev-width=$physEthDevWidth"
			)
		}

		test ! -z $(echo -n $uutPn |grep "PE310G4I40") && {
			ethKern="ixgbe"
			ethMaxSpeed="10000"
			let physEthDevQty=4
			baseModel="PE310G4I40"
			syncPn="PE310G4I40"
			# fwSyncPn="Pe310g4bpi71.LR"
			baseModelPath="/root/PE310G4I40"
			physEthDevId="15A4"
			uutDRates=("100" "1000" "10000")
			
			let physEthDevSpeed=5
			let physEthDevWidth=8
			
			plxKern="pcieport"
			let plxDevQty=1
			let plxDevSubQty=2
			let plxDevEmptyQty=1
			plxDevId="8724"
			let plxDevSpeed=8
			let plxDevWidth=8
			let plxDevSubSpeed=5
			let plxDevSubWidth=8
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=0
			

			assignBuses plx eth
			pciArgs=(
				"--target-bus=$uutBus"
				"--plx-buses=$plxBuses"
				"--eth-buses=$ethBuses"

				"--plx-dev-id=$plxDevId"
				"--eth-dev-id=$physEthDevId"

				"--plx-kernel=$plxKern"
				"--eth-kernel=$ethKern"

				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-empty-qty=$plxDevEmptyQty"
				"--eth-dev-qty=$physEthDevQty"

				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--plx-dev-empty-speed=$plxDevEmptySpeed"
				"--plx-dev-empty-width=$plxDevEmptyWidth"
				"--plx-keyw=Physical Slot:"
				"--plx-virt-keyw=ABWMgmt+"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
			)
		}

		test ! -z $(echo -n $uutPn |grep "PE310G2BPI71-SR") && { 
			uutPortMatch="$def2p"
			ethKern="i40e"
			ethMaxSpeed="10000"
			let physEthDevQty=2
			let bpDevQty=1
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
			baseModel="PE310G2BPI71"
			syncPn="PE310G2BPI71-SR"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			slcmMode="slcm"
			fwSyncPn="PE310G2BPi71.SR"
			baseModelPath="/root/PE310G2BPI71"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth bp
			pciArgs=(
				"--target-bus=$uutBus"
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

		test ! -z $(echo -n $uutPn |grep "PE340G2BPI71-QS43") && { 
			uutPortMatch="$def2p"
			ethKern="i40e"
			ethMaxSpeed="40000"
			let physEthDevQty=2
			let bpDevQty=1
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
			baseModel="PE340G2BPI71"
			syncPn="PE340G2BPI71"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			slcmMode="slcmi"
			fwSyncPn="PE340G2BPI71.sr"
			baseModelPath="/root/PE340G2BPI71"
			
			let physEthDevSpeed=8
			let physEthDevWidth=8
			
			assignBuses eth bp
			pciArgs=(
				"--target-bus=$uutBus"
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
		
		test ! -z $(echo -n $uutPn |grep "PE310G4DBIR") && {
			uutPortMatch="$def4p"
			ethKern="fm10k"
			ethVirtKern="fm10k"
			ethMaxSpeed="10000"
			let uutDevQty=5
			let uutNetQty=5
			let bpDevQty=2
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

		test ! -z $(echo -n $uutPn |grep "PE310G4BPI9-SR\|PE310G4BPI9-LR") && {
			ethKern="ixgbe"
			ethMaxSpeed="10000"
			let physEthDevQty=4
			let bpDevQty=2
			baseModel="PE310G4BPI9"
			syncPn="PE310G4BPI9-SR"
			# fwSyncPn="Pe310g4bpi71.LR"
			baseModelPath="/root/PE310G4BPI9"
			physEthDevId="15A4"
			bpCtlMode="bpctl"
			
			let physEthDevSpeed=5
			let physEthDevWidth=8
			
			plxKern="pcieport"
			let plxDevQty=1
			let plxDevSubQty=2
			let plxDevEmptyQty=1
			plxDevId="8724"
			let plxDevSpeed=8
			let plxDevWidth=8
			let plxDevSubSpeed=5
			let plxDevSubWidth=8
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=0
			

			assignBuses plx eth bp
			pciArgs=(
				"--target-bus=$uutBus"
				"--plx-buses=$plxBuses"
				"--eth-buses=$ethBuses"
				"--bp-buses=$bpBuses"

				"--plx-dev-id=$plxDevId"
				"--eth-dev-id=$physEthDevId"

				"--plx-kernel=$plxKern"
				"--eth-kernel=$ethKern"
				"--bp-kernel=$ethKern"

				"--plx-dev-qty=$plxDevQty"
				"--plx-dev-sub-qty=$plxDevSubQty"
				"--plx-dev-empty-qty=$plxDevEmptyQty"
				"--eth-dev-qty=$physEthDevQty"
				"--bp-dev-qty=$bpDevQty"

				"--plx-dev-speed=$plxDevSpeed"
				"--plx-dev-width=$plxDevWidth"
				"--plx-dev-sub-speed=$plxDevSubSpeed"
				"--plx-dev-sub-width=$plxDevSubWidth"
				"--plx-dev-empty-speed=$plxDevEmptySpeed"
				"--plx-dev-empty-width=$plxDevEmptyWidth"
				"--plx-keyw=Physical Slot:"
				"--plx-virt-keyw=ABWMgmt+"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
				"--bp-dev-speed=$physEthDevSpeed"
				"--bp-dev-width=$physEthDevWidth"
			)
		}			

		test ! -z $(echo -n $uutPn |grep "PE210G2BPI9") && {
			uutPortMatch="$def2p"
			ethKern="ixgbe"
			ethMaxSpeed="10000"
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
				"--target-bus=$uutBus"
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
		
		test ! -z $(echo -n $uutPn |grep "PE210G2SPI9A-XR") && {
			uutPortMatch="$def2p"
			ethKern="ixgbe"
			ethMaxSpeed="10000"
			let physEthDevQty=2
			baseModel="PE210G2SPI9A"
			syncPn="PE210G2SPI9A"
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
			
			assignBuses eth
			dmsg inform "DEBUG1: ${pciArgs[@]}"
			pciArgs=(
				"--target-bus=$uutBus"
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
			ethMaxSpeed="10000"
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
				"--target-bus=$uutBus"
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
			ethMaxSpeed="10000"
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
				"--target-bus=$uutBus"
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
			ethMaxSpeed="10000"
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
				"--target-bus=$uutBus"
				"--eth-buses=$ethBuses"
				"--eth-dev-id=$physEthDevId"
				"--eth-kernel=$ethKern"
				"--eth-dev-qty=$physEthDevQty"
				"--eth-dev-speed=$physEthDevSpeed"
				"--eth-dev-width=$physEthDevWidth"
			)
			dmsg inform "DEBUG2: ${pciArgs[@]}"
		}
		
		test ! -z $(echo -n $uutPn |grep "PE340G2DBIR-QS41") && {
			uutPortMatch="$def2p"
			ethKern="fm10k"
			ethVirtKern="fm10k"
			ethMaxSpeed="40000"
			let uutDevQty=2
			let uutNetQty=2
			let bpDevQty=1
			let physEthDevQty=2
			baseModel="PE340G2DBIR"
			syncPn="PE340G2DBIR"
			mastBaseModel="PE340G2DBIR"
			physEthDevId="15A4"
			let physEthDevSpeed=8
			let physEthDevWidth=8

			plxKern="pcieport"
			let plxDevQty=1
			let plxDevSubQty=2
			let plxDevEmptyQty=1
			plxDevId="8747"
			let plxDevSpeed=8
			let plxDevWidth=16
			let plxDevSubSpeed=8
			let plxDevSubWidth=8
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=0
			
			bpCtlMode="bprdctl"				
		}
		
		test ! -z $(echo -n $uutPn |grep "PE3100G2DBIR") && {
			uutPortMatch="$def2p"
			ethKern="fm10k"
			ethVirtKern="fm10k"
			ethMaxSpeed="100000"
			let uutDevQty=2
			let uutNetQty=2
			let bpDevQty=1
			let physEthDevQty=2
			baseModel="PE3100G2DBIR"
			syncPn="PE3100G2DBIR"
			mastBaseModel="PE3100G2DBIR"
			physEthDevId="15A4"
			let physEthDevSpeed=8
			let physEthDevWidth=8

			plxKern="pcieport"
			let plxDevQty=1
			let plxDevSubQty=2
			let plxDevEmptyQty=1
			plxDevId="8747"
			let plxDevSpeed=8
			let plxDevWidth=16
			let plxDevSubSpeed=8
			let plxDevSubWidth=8
			plxDevEmptySpeed="2.5"
			let plxDevEmptyWidth=0
			
			bpCtlMode="bprdctl"				
		}

		test ! -z $(echo -n $uutPn |grep "IBSGP-T-MC-AM") && {
			uutPortMatch="1 1 2 2 3 3 4 4"
			uutDRates=("100" "1000" "10000")
			let physEthDevQty=4
			let bpDevQty=1
			baseModel="IBSGP-T-MC-AM"
			uutBdsUser="badas"
			uutBdsPass="4fdG912z"
			uutRootUser="root"
			uutRootPass="bRd59kP"
			uutBaudRate=115200

			ibsHwVerInfo='5.3.0.21 (PPC ver. 2.2)'
			ibsFwVer="0.3.3.6"
			ibsSwVer="1.4.1.14"
			ibsUbootVer="1.3.0"
			ibsKernVer="2.6.23-S-001"
			ibsProdName="IBSGP-T-MC"
			ibsBdsVer="3.51"
			ibsRootfsNandSIze="0xdc0000"
		}
		
		test ! -z $(echo -n $uutPn |grep "IBS10GP-LR-RW") && {
			uutPortMatch="1 1 2 2 3 3 4 4"
			uutDRates=("100" "1000" "10000")
			let physEthDevQty=4
			let bpDevQty=1
			baseModel="IBS10GP"
			uutBdsUser="badas"
			uutBdsPass="3grab7bW"
			uutRootUser="root"
			uutRootPass="rG31tm8"
			uutBaudRate=115200

			ibsHwVerInfo='0.3.0.21 (PPC ver. 2.2)'
			ibsFwVer="0.3.3.7"
			ibsSwVer="1.4.2.74"
			ibsUbootVer="1.3.0"
			ibsKernVer="2.6.23-S-001"
			# ibsProdName="IBSGP-T-MC"
			# ibsBdsVer="3.51"
			# ibsRootfsNandSIze="0xdc0000"
		}

		test ! -z $(echo -n $uutPn |grep "IBS10GP-*") && {
			uutPortMatch="1 1 2 2 3 3 4 4"
			uutDRates=("100" "1000" "10000")
			let physEthDevQty=4
			let bpDevQty=1
			baseModel="IBS10GP"
			uutBaudRate=115200
			untestedPn=1
		}

		test ! -z $(echo -n $uutPn |grep "IBSGP-T*") && {
			uutPortMatch="1 1 2 2 3 3 4 4"
			uutDRates=("100" "1000" "10000")
			let physEthDevQty=4
			let bpDevQty=1
			baseModel="IBSGP-T"
			uutBaudRate=115200
			untestedPn=1
		}
		
		
		echoIfExists "  Port count:" "$uutDevQty"
		echoIfExists "  Net count:" "$uutNetQty"
		echoIfExists "  BP count:" "$uutBpDevQty"
		echoIfExists "  Physical Ethernet device count:" "$physEthDevQty"
		echoIfExists "  Virtual Ethernet device count:" "$virtEthDevQty"
		echoIfExists "  UUT Data rates:" ${uutDRates[@]}
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
		except "${FUNCNAME[0]}" "$uutPn cannot be processed, requirements not defined"
	fi
	
	echo -e "  Defining requirements for the master"

	mastSfpSrDefine(){
		mastDefiner="${FUNCNAME[0]}"
		ibsRjRequired=1
		let mastPciSpeedReq=8
		let mastPciWidthReq=8
		if [ -z "$mastDevQty" ]; then let mastDevQty=4; fi
		if [ -z "$mastBpDevQty" ]; then let mastBpDevQty=2; fi
		if [ -z "$mastNetQty" ]; then let mastNetQty=4; fi		
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
		
		if [ -z "$mastBaseModel" ]; then mastBaseModel="PE310G4BPI71"; fi
		mastDevId=1572
		mastKern="i40e"
		mastSlcmMode="slcm"
		
		mastPciArgs=("--target-bus=$mastBus"
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
	}
	mastRjDefine(){
		mastDefiner="${FUNCNAME[0]}"
		assignBuses plx
		mastKern="ixgbe"

		if [ -z "$mastDevQty" ]; then let mastDevQty=4; fi
		if [ -z "$mastBpDevQty" ]; then let mastBpDevQty=2; fi
		mastBaseModel="PE310G4BPI40"
		syncPn="PE310G4BPI40"; inform "potential collision with UUT syncPn, need to investigate"
		# fwSyncPn="Pe310g4bpi71.LR"
		baseModelPath="/root/PE310G4BPI40"
		mastDevId="1572"
				

		let mastPciSpeedReq=5
		let mastPciWidthReq=8
		
		mastPlxKern="pcieport"
		let mastPlxDevQty=1
		let mastPlxDevSubQty=2
		let mastPlxDevEmptyQty=1
		mastPlxDevId="8724"
		let mastPlxDevSpeed=8
		let mastPlxDevWidth=8
		let mastPlxDevSubSpeed=5
		let mastPlxDevSubWidth=8
		mastPlxDevEmptySpeed="2.5"
		let mastPlxDevEmptyWidth=0
		mastPciArgs=(
			"--target-bus=$mastBus"
			"--plx-buses=$plxBuses"
			"--eth-buses=$ethBuses"
			"--bp-buses=$mastBpBuses"

			"--plx-dev-id=$mastPlxDevId"
			"--eth-dev-id=$mastDevId"

			"--plx-kernel=$mastPlxKern"
			"--eth-kernel=$mastKern"
			"--bp-kernel=$mastKern"

			"--plx-dev-qty=$mastPlxDevQty"
			"--plx-dev-sub-qty=$mastPlxDevSubQty"
			"--plx-dev-empty-qty=$mastPlxDevEmptyQty"
			"--eth-dev-qty=$mastDevQty"
			"--bp-dev-qty=$mastBpDevQty"

			"--eth-dev-speed=$mastPciSpeedReq"
			"--eth-dev-width=$mastPciWidthReq"
			"--bp-dev-speed=$mastPciSpeedReq"
			"--bp-dev-width=$mastPciWidthReq"
			"--plx-dev-speed=$mastPlxDevSpeed"
			"--plx-dev-width=$mastPlxDevWidth"
			"--plx-dev-sub-speed=$mastPlxDevSubSpeed"
			"--plx-dev-sub-width=$mastPlxDevSubWidth"
			"--plx-dev-empty-speed=$mastPlxDevEmptySpeed"
			"--plx-dev-empty-width=$mastPlxDevEmptyWidth"
			"--plx-keyw=Physical Slot:"
			"--plx-virt-keyw=ABWMgmt+"
		)
	}

	case "$baseModel" in
		PE310G4BPI71) mastSfpSrDefine;;
		PE310G2BPI71) mastSfpSrDefine;;
		PE310G2BPI71-SR) mastSfpSrDefine;;
		PE340G2BPI71) 
			inform "${FUNCNAME[0]}: mastBaseModel is cloned from baseModel of UUT" 
			mastBaseModel=$baseModel
			mastSfpSrDefine
		;;
		PE210G2BPI40) mastRjDefine;;
		PE310G4BPI40) mastRjDefine;;
		PE310G4I40) mastRjDefine;;
		PE310G4DBIR) mastSfpSrDefine;;
		PE340G2DBIR) inform "Master req definement skipped, special case";;
		PE3100G2DBIR) inform "Master req definement skipped, special case";;
		PE310G4BPI9) mastSfpSrDefine;;
		PE210G2BPI9) mastSfpSrDefine;;
		PE210G2SPI9A) mastSfpSrDefine;;
		PE325G2I71) mastSfpSrDefine;;
		PE31625G4I71L) mastSfpSrDefine;;
		M4E310G4I71) mastSfpSrDefine;;
		IBSGP-T) mastRjDefine;;
		IBSGP-T-MC-AM) mastRjDefine;;
		IBS10GP) mastSfpSrDefine;;
		*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
	esac

	if [ ! -z "$physEthDevQty" -a -z "$(echo $baseModel |grep DBIR)" ]; then
		# echo 1 > /sys/bus/pci/rescan
		if [ -z "$virtEthDevQty" ]; then let ethTotalQty=$physEthDevQty; else let ethTotalQty=$physEthDevQty+$virtEthDevQty; fi
		if [ $mastDevQty -gt $ethTotalQty ]; then
			warn "  Reassigning mastNets, excessive amount detected. ($mastNets reduced to " "nnl" "sil"
			mastNets=$(echo $mastNets |cut -d ' ' -f1-$ethTotalQty)
			ethBusesToRemove=$(echo $mastEthBuses |cut -d ' ' -f$(expr $ethTotalQty + 1)-)
			warn "$mastNets)"
			if [ ! -z "$ethBusesToRemove" ]; then removePciDev $ethBusesToRemove; fi
			dmsg inform "mastNets=$mastNets"
			let mastDevQty=2
			let mastBpDevQty=1
			warn "  Redefining master values"
			$mastDefiner
			warn "  Reassigning master BP bus"
			publicVarAssign warn mastBpBuses $(filterDevsOnBus $mastSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1))
		fi
	fi

	echoIfExists "  mastPciSpeedReq:" "$mastPciSpeedReq"
	echoIfExists "  mastPciWidthReq:" "$mastPciWidthReq"
	echoIfExists "  mastDevQty:" "$mastDevQty"
	echoIfExists "  mastBpDevQty:" "$mastBpDevQty"
	echoIfExists "  mastDevId:" "$mastDevId"
	echoIfExists "  mastNetQty:" "$mastNetQty"
	echoIfExists "  mastKern:" "$mastKern"
	echoIfExists "  mastBaseModel:" "$mastBaseModel"
	echoIfExists "  verDumpOffset_mast:" "$verDumpOffset_mast"
	echoIfExists "  verDumpLen_mast:" "$verDumpLen_mast"
	echoIfExists "  pnDumpOffset_mast:" "$pnDumpOffset_mast"
	echoIfExists "  pnDumpLen_mast:" "$pnDumpLen_mast"
	echoIfExists "  pnRevDumpOffset_mast:" "$pnRevDumpOffset_mast"
	echoIfExists "  pnRevDumpLen_mast:" "$pnRevDumpLen_mast"
	echoIfExists "  tnDumpOffset_mast:" "$tnDumpOffset_mast"
	echoIfExists "  tnDumpLen_mast:" "$tnDumpLen_mast"
	echoIfExists "  tdDumpOffset_mast:" "$tdDumpOffset_mast"
	echoIfExists "  tdDumpLen_mast:" "$tdDumpLen_mast"

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


setupLinks() {
	local allNets linkSetup baseModelLocal
	allNets=$1
	test -z "$allNets" && warn "No nets were detected! Is firmware flashed?" || {
		echo -e "  Initializing nets: "$allNets
		test ! -z "$(echo -n "$mastNets" |grep "$allNets")" && baseModelLocal="$mastBaseModel" || baseModelLocal="$baseModel"
		case "$baseModelLocal" in
			PE310G4BPI71) linkSetup=$(link_setup $allNets);;
			PE310G2BPI71) linkSetup=$(link_setup $allNets);;
			PE340G2BPI71) linkSetup=$(link_setup $allNets);;
			PE210G2BPI40) linkSetup=$(link_setup $allNets);;
			PE310G4BPI40) linkSetup=$(link_setup $allNets);;
			PE310G4I40) linkSetup=$(link_setup $allNets);;
			PE310G4DBIR) linkSetup="$(/root/PE310G4DBIR/iplinkup.sh $uutSlotNum)";;
			PE340G2DBIR) inform "${FUNCNAME[0]} skipped, special case";;
			PE3100G2DBIR) inform "${FUNCNAME[0]} skipped, special case";;
			PE310G4BPI9) linkSetup=$(link_setup $allNets);;
			PE210G2BPI9) linkSetup=$(link_setup $allNets);;
			PE210G2SPI9A) linkSetup=$(link_setup $allNets);;
			PE325G2I71) linkSetup=$(link_setup $allNets);;
			PE31625G4I71L) linkSetup=$(link_setup $allNets);;
			M4E310G4I71) linkSetup=$(link_setup $allNets);;
			*) except "${FUNCNAME[0]}" "Unknown baseModelLocal: $baseModelLocal"
		esac		
		test -z "$(echo $linkSetup |grep "Failed")" || echo -e "\e[0;31m   Link setup failed!\e[m" && echo -e "\e[0;32m   Link setup passed.\e[m"	
	}
}

trafficTest() {
	local pcktCnt dropAllowed slotNum pn portQty sendDelay queryCnt orderFile execFile sourceDir rootDir buffSize sendMode taskCount srcPort trgPort
	local uutModel pnLocal
	privateVarAssign "trafficTest" "slotNum" "$1"
	shift
	privateVarAssign "trafficTest" "pcktCnt" "$1"
	shift 
	privateVarAssign "trafficTest" "pn" "$1"
	
	echo -e "\tTraffic tests (profile $pn): \n"

	case "$pn" in
		PE3100G2DBIR)
			inform "\tTraffic profile copied from PE340G2DBIR"
			pnLocal="PE340G2DBIR"
		;;
		PE3100G2DBIR)
			inform "\tTraffic profile copied from PE340G2DBIR"
			pnLocal="PE340G2DBIR"
		;;
		*) pnLocal=$pn
	esac
	
	case "$pnLocal" in
		PE310G4BPI71) 
			portQty=4
			sendDelay=0x0
			buffSize=4096
			execFile="./txgen2.sh"  
			sourceDir="$(pwd)"
			rootDir="/root/PE310G4BPI71"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="TxRx Passed" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"
		;;
		PE310G2BPI71) 
			portQty=2
			sendDelay=0x0
			buffSize=4096
			execFile="./txgen2.sh"  
			sourceDir="$(pwd)"
			rootDir="/root/PE310G2BPI71"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="TxRx Passed" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"

		;;
		PE340G2BPI71)
			portQty=2
			sendDelay=0x0
			sendMode=0x3
			taskCount=01
			let srcPort=1
			let trgPort=2
			execFile="./anagenohuptask2.sh"  
			sourceDir="$(pwd)"
			rootDir="/root/PE340G2BPI71"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$sendMode $taskCount $pcktCnt $sendDelay $portQty $mastSlotNum $slotNum"
			echo -e "\tSending traffic (MASTER in IL, UUT in IL)..\n"
			execScript "$execFile" "$sendMode $taskCount $pcktCnt $sendDelay $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"

			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are DOWN on MASTER" "testLinks" "no" "$mastBaseModel"
			echo -e "\tSending traffic (MASTER in BP, UUT in IL)..\n"
			sendMode=0x4
			execFile="./anagenohuptask1.sh"
			dmsg inform "$sendMode $taskCount $pcktCnt $sendDelay $srcPort $trgPort $slotNum"
			execScript "$execFile" "$sendMode $taskCount $pcktCnt $sendDelay $srcPort $trgPort $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"


			allBPBusMode "$bpBuses" "bp"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are DOWN on UUT" "testLinks" "no" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			echo -e "\tSending traffic (MASTER in IL, UUT in BP)..\n"
			dmsg inform "$sendMode $taskCount $pcktCnt $sendDelay $srcPort $trgPort $slotNum"
			execScript "$execFile" "$sendMode $taskCount $pcktCnt $sendDelay $srcPort $trgPort $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"


			allBPBusMode "$bpBuses" "inline"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$sendMode $taskCount $pcktCnt $sendDelay $portQty $mastSlotNum $slotNum"
			execFile="./anagenohuptask2.sh" 
			sendMode=0x3
			echo -e "\tSending traffic (MASTER in IL, UUT in IL)..\n"
			execScript "$execFile" "$sendMode $taskCount $pcktCnt $sendDelay $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"

		;;
		PE210G2BPI40)
			portQty=2
			minSpeed=900
			dropAllowed=1
			execFile="./pcinoaux2.sh"  
			rootDir="/root/PE210G2BPI40"
			orderFile="order"
			sourceDir="$(pwd)"
			cd "$rootDir"
			echo -n "1 2" >$rootDir/$orderFile
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"

			setCardDRate "UUT" "$baseModel" 10000 $uutNets
			setCardDRate "MASTER" "$mastBaseModel" 10000 $mastNets
			sleep $globLnkUpDel
			checkCardDRate "UUT" "$baseModel" 10000 $uutNets
			checkCardDRate "MASTER" "$mastBaseModel" 10000 $mastNets
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic in 10G mode..  (ALL in IL)\n"
			execScript "$execFile" "$pcktCnt $dropAllowed $minSpeed $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"

			execFile="./pcinoaux.sh"  
			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			checkCardDRate "UUT" "$baseModel" 10000 $uutNets
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are DOWN on MASTER" "testLinks" "no" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic in 10G mode..  (MASTER in BP)\n"
			execScript "$execFile" "$pcktCnt $dropAllowed $minSpeed $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"

			allBPBusMode "$bpBuses" "bp"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			checkCardDRate "MASTER" "$mastBaseModel" 10000 $mastNets
			allNetAct "$uutNets" "Check links are DOWN on UUT" "testLinks" "no" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $mastSlotNum"
			echo -e "\tSending traffic in 10G mode..  (UUT in BP)\n"
			execScript "$execFile" "$pcktCnt $dropAllowed $minSpeed $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
		;;
		PE310G4BPI40) 
			portQty=4
			sendDelay=0x0
			minSpeed=400
			execFile="./pcipktgen2.sh"  
			rootDir="/root/PE310G4BPI40"
			orderFile="order"
			sourceDir="$(pwd)"
			cd "$rootDir"
			echo -n "1 2 3 4" >$rootDir/$orderFile
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"

			setCardDRate "UUT" "$baseModel" 1000 $uutNets
			setCardDRate "MASTER" "$mastBaseModel" 1000 $mastNets
			sleep $globLnkUpDel
			checkCardDRate "UUT" "$baseModel" 1000 $uutNets
			checkCardDRate "MASTER" "$mastBaseModel" 1000 $mastNets
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic in 1G mode..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $minSpeed $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
			
			minSpeed=900
			setCardDRate "UUT" "$baseModel" 10000 $uutNets
			setCardDRate "MASTER" "$mastBaseModel" 10000 $mastNets
			sleep $globLnkUpDel
			checkCardDRate "UUT" "$baseModel" 10000 $uutNets
			checkCardDRate "MASTER" "$mastBaseModel" 10000 $mastNets
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic in 10G mode..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $minSpeed $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"

			execFile="./pcipktgen.sh"  
			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			checkCardDRate "UUT" "$baseModel" 10000 $uutNets
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			allNetAct "$mastNets" "Check links are DOWN on MASTER" "testLinks" "no" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic in 10G mode (MASTER in BP)..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $minSpeed $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"

			allBPBusMode "$bpBuses" "bp"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			checkCardDRate "MASTER" "$mastBaseModel" 10000 $mastNets
			allNetAct "$uutNets" "Check links are DOWN on UUT" "testLinks" "no" "$baseModel"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $mastSlotNum"
			echo -e "\tSending traffic in 10G mode (UUT in BP)..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $minSpeed $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Pktgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
		;;
		PE310G4I40) exitFail "Traffic test is defined for PE310G4BPI40 instead";;
		PE310G4DBIR)
			portQty=5
			sendDelay=4000
			buffSize=4096
			execFile="./pcitxgenohup5-1_BPI-MOD.sh"  
			rootDir="/root/PE310G4DBIR"
			sourceDir="$(pwd)"
			cd "$rootDir"
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"

			uutModel=$baseModel
			echo -e "\tSetting UUT to NIC Mode\n"
			rdfiConfCmd=$($rootDir/rdif_config1vf4_mod.sh 2 2 $uutSlotNum $uutSlotNum $uutSlotNum)
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic (MASTER in IL, UUT in IL)..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"

			echo -e "\tSetting UUT RRC to Bypass Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config1vf4_mod.sh 1 1 $uutSlotNum $uutSlotNum $uutSlotNum)
				portQty=4
				orderFile="order"
				echo -n "1 2 3 4" >$rootDir/$orderFile
				execFile="./pcitxgenohup1.sh" 
				echo -e "\tCheck traffic on MASTER trough UUT RRC Bypass\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"



			echo -e "\tSetting UUT to NIC Mode\n"
			rdfiConfCmd=$($rootDir/rdif_config1vf4_mod.sh 2 2 $uutSlotNum $uutSlotNum $uutSlotNum)
			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are DOWN on MASTER" "testLinks" "no" "$mastBaseModel"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic (MASTER in PAS BP, UUT in IL)..\n"
			portQty=5
			echo -n "1 2 3 4 5" >$rootDir/$orderFile
			execFile="./pcitxgenohup1vf4.sh" 
			execScript "$execFile" "1000000 $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"


			allBPBusMode "$bpBuses" "bp"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are DOWN on UUT" "testLinks" "no" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
			echo -e "\tCheck traffic on MASTER trough UUT Passive Bypass\n"
			portQty=4
			echo -n "1 2 3 4" >$rootDir/$orderFile
			execFile="./pcitxgenohup1.sh" 
			dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
			execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
			test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
		;;
		PE340G2DBIR)
			portQty=2
			sendDelay=0x0
			buffSize=4096
			execFile="./pcitxgenohup2.sh"  
			rootDir="/root/PE340G2DBIR"
			orderFile="order"
			sourceDir="$(pwd)"
			cd "$rootDir"
			echo -n "1 2" >$rootDir/$orderFile
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"

			uutModel=$baseModel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel" "$mastUIOdevNum"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic (MASTER in IL, UUT in IL)..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
			test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			
			echo -e "\tSetting UUT RRC to Disconnect Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 2 5 $mastSlotNum $slotNum)
				execFile="./txgen1.sh" 
				echo -e "\t Check that MASTER is not in TAP or Bypass Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"

				execFile="./txgen2-txrx.sh" 
				echo -e "\t Check that MASTER is not in TAP or Monitor Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting MASTER RRC to Disconnect Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 5 2 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck that UUT is not in TAP or Bypass Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"

				execFile="./txgen2-txrx.sh" 
				echo -e "\tCheck that UUT is not in TAP or Monitor Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting UUT RRC to Monitor Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 2 4 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck that MASTER is not in TAP or Bypass Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
					
				execFile="./txgen2-txrx.sh" 
				echo -e "\tCheck that MASTER has Half Duplex Link in a Monitor Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting MASTER RRC to Monitor Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 4 2 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck that UUT is not in TAP or Bypass Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $slotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
					
				execFile="./txgen2-rxtx.sh" 
				echo -e "\tCheck that UUT has Half Duplex Link in a Monitor Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting UUT RRC to Bypass Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 2 1 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck Data Link on MASTER trough UUT bypass\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
					
				execFile="./txgen2-txrx.sh" 
				echo -e "\tCheck that MASTER is not in TAP or Monitor Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"

				execFile="./pcitxgenohup1.sh" 
				echo -e "\tSending traffic (MASTER in IL, UUT in Virtual BP)..\n"
				dmsg inform "$execFile $pcktCnt $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting MASTER RRC to Bypass Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 1 2 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck Data Link on UUT trough MASTER Bypass\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
					
				execFile="./txgen2-txrx.sh" 
				echo -e "\tCheck that UUT is not in TAP or Monitor Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "nulll" "Traffic test FAILED" --exp-kw="Receiver Failed" --exp-kw="Txgen Test Failed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"

				execFile="./pcitxgenohup1.sh" 
				echo -e "\tSending traffic (UUT in IL, MASTER in Virtual BP)..\n"
				dmsg inform "$execFile $pcktCnt $sendDelay $buffSize $portQty $orderFile $slotNum"
				execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting UUT RRC to TAP Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 2 3 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck Data Link on MASTER trough UUT bypass\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
					
				execFile="./txgen2-txrx.sh" 
				echo -e "\tCheck that MASTER has Half Duplex Link in a TAP Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			
				execFile="./pcitxgenohup1.sh" 
				echo -e "\tSending traffic (MASTER in IL, UUT in TAP Mode)..\n"
				dmsg inform "$execFile $pcktCnt $sendDelay $buffSize $portQty $orderFile $mastSlotNum"
				execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting MASTER RRC to TAP Mode\n"
				rdfiConfCmd=$($rootDir/rdif_config2.sh 3 2 $mastSlotNum $slotNum)

				execFile="./txgen1.sh" 
				echo -e "\tCheck Data Link on UUT trough MASTER bypass\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $orderFile $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
					
				execFile="./txgen2-rxtx.sh" 
				echo -e "\tCheck that UUT has Half Duplex Link in a TAP Mode\n"
				dmsg inform "$execFile 100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
				execScript "$execFile" "100000 $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			
				execFile="./pcitxgenohup1.sh" 
				echo -e "\tSending traffic (UUT in IL, MASTER in TAP Mode)..\n"
				dmsg inform "$execFile $pcktCnt $sendDelay $buffSize $portQty $orderFile $slotNum"
				execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed" --nonVerb
				test "$?" = "0" && echo -e "\t\t\e[0;32mPASSED\e[m\n" || echo -e "\t\t\e[0;31mFAILED\e[m\n"
			echo -e "\t---------------------------------------------------\n"

			echo -e "\tSetting UUT and MASTER to NIC Mode\n"
			rdfiConfCmd=$($rootDir/rdif_config2.sh 2 2 $mastSlotNum $slotNum)
			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are DOWN on MASTER" "testLinks" "no" "$mastBaseModel" "$mastUIOdevNum"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic (MASTER in BP, UUT in IL)..\n"
			# execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			# test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
			execFile="./txgen1.sh" 
			execScript "$execFile" "1000000 $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"



			allBPBusMode "$bpBuses" "bp"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are DOWN on UUT" "testLinks" "no" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel" "$mastUIOdevNum"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $mastSlotNum"
			echo -e "\tSending traffic (MASTER in IL, UUT in BP)..\n"
			# execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			# test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
			execScript "$execFile" "1000000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
		;;
		PE3100G2DBIR)
			portQty=2
			sendDelay=0x0
			buffSize=4096
			execFile="./pcitxgenohup2.sh"  
			rootDir="/root/PE3100G2DBIR"
			orderFile="order"
			sourceDir="$(pwd)"
			cd "$rootDir"
			echo -n "1 2" >$rootDir/$orderFile
			sourceDir="$(pwd)"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"

			uutModel=$baseModel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel" "$mastUIOdevNum"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic (MASTER in IL, UUT in IL)..\n"
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"

			allBPBusMode "$mastBpBuses" "bp"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are DOWN on MASTER" "testLinks" "no" "$mastBaseModel" "$mastUIOdevNum"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $slotNum"
			echo -e "\tSending traffic (MASTER in BP, UUT in IL)..\n"
			# execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			# test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
			execFile="./txgen1.sh" 
			execScript "$execFile" "1000000 $sendDelay $buffSize $portQty $orderFile $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"



			allBPBusMode "$bpBuses" "bp"
			allBPBusMode "$mastBpBuses" "inline"
			sleep $globLnkUpDel
			allNetAct "$uutNets" "Check links are DOWN on UUT" "testLinks" "no" "$baseModel" "$uutUIOdevNum"
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel" "$mastUIOdevNum"
			dmsg inform "$pcktCnt $sendDelay $portQty $execFile $mastSlotNum"
			echo -e "\tSending traffic (MASTER in IL, UUT in BP)..\n"
			# execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $slotNum $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			# test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
			execScript "$execFile" "1000000 $sendDelay $buffSize $portQty $orderFile $mastSlotNum" "Failed" "Traffic test FAILED" --exp-kw="Txgen Test Passed"
			test "$?" = "0" && echo -e "\tTests summary: \e[0;32mPASSED\e[m\n" || echo -e "\tTests summary: \e[0;31mFAILED\e[m\n"
		;;
		PE310G4BPI9) 
			portQty=4
			sendDelay=0x0
			buffSize=4096
			execFile="./pcitxgenohup4.sh"  
			sourceDir="$(pwd)"
			rootDir="/root/PE310G4BPI9"
			cd "$rootDir"
			dmsg inform "pwd=$(pwd)"
			dmsg inform "PARAMS-- $pcktCnt $sendDelay $buffSize $portQty $mastSlotNum $slotNum"
			execScript "$execFile" "$pcktCnt $sendDelay $buffSize $portQty $mastSlotNum $slotNum" "Failed" "Traffic test FAILED" --exp-kw="Bus Error Test Passed" --exp-kw="Txgen Test Passed" --exp-kw="PCI Test Passed"
			test "$?" = "0" && echo -e "\n\tTests summary: \e[0;32mPASSED\e[m" || echo -e "\n\tTests summary: \e[0;31mFAILED\e[m"
		;;
		PE210G2BPI9) inform "Traffic test is not defined for $baseModel";;
		PE210G2SPI9A) inform "Traffic test is not defined for $baseModel";;
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
	cd "$sourceDir" > /dev/null 2>&1
}

	# 0x002                       10baseT Full
	# 0x008                       100baseT Full
	# 0x020                       1000baseT Full
	# 0x800000000000              2500baseT Full
	# 0x1000000000000             5000baseT Full
	# 0x1000                      10000baseT Full
	# 0x80000000000               10000baseSR Full
	# 0x100000000000              10000baseLR Full


switchBP() {
	local bpBus newState bpCtlCmd baseModelLocal
	privateVarAssign "switchBP" "bpBus" "$1"
	privateVarAssign "switchBP" "newState" "$2"
	dmsg inform "switchBP, switching bpBus:$bpBus to state newState:$newState"
	if [[ ! -z "$(echo -n $mastBpBuses |grep -w $bpBus)" ]]; then baseModelLocal="$mastBaseModel"; else baseModelLocal="$baseModel"; fi
	case "$baseModelLocal" in
		PE310G4BPI71) bpCtlCmd="bpctl_util";;
		PE310G2BPI71) bpCtlCmd="bpctl_util";;
		PE340G2BPI71) bpCtlCmd="bpctl_util";;
		PE210G2BPI40) bpCtlCmd="bpctl_util";;
		PE310G4BPI40) bpCtlCmd="bpctl_util";;
		PE310G4DBIR) bpCtlCmd="bprdctl_util";;
		PE340G2DBIR) bpCtlCmd="bprdctl_util";;
		PE3100G2DBIR) bpCtlCmd="bprdctl_util";;
		PE310G4BPI9) bpCtlCmd="bpctl_util";;
		PE210G2BPI9) bpCtlCmd="bpctl_util";;
		IBSGP-T-MC-AM) bpCtlCmd="bssf";;
		IBS10GP) bpCtlCmd="bssf";;
		IBSGP-T) bpCtlCmd="bssf";;
		*) except "${FUNCNAME[0]}" "in $funcName: baseModel: $baseModelLocal not expected!"
	esac
		if [ ! -z "$(echo $bpBuses$mastBpBuses |grep $bpBus)" -o ! -z "$ibsMode" ]; then
			case "$newState" in
				inline) {
					if [[ "$bpCtlCmd" = "bssf" ]]; then
						bpctlRes=$(sendIBS $uutSerDev $bpCtlCmd set_normal)
						if [[ ! -z "$(echo $bpctlRes |grep -w PASS)" ]]; then
							echo -e -n "\t$bpBus: Set to inline mode"
							sleep 0.1
							bpctlRes=$(sendIBS $uutSerDev $bpCtlCmd get_state |grep Passive |cut -d. -f1 |awk '{print $3}')
							if [[ ! -z "$(echo "$bpctlRes" |grep 'inline')" ]]; then 
								bpctlRes="\e[0;32minline\e[m" 
							else
								bpctlRes="\e[0;31mbypass\e[m"
							fi
							echo -e ", checking: $bpctlRes mode"
						else
							exitFail "\t$bpBus: failed to to set to inline mode!"
						fi
					else
						bpctlRes=$($bpCtlCmd $bpBus set_bypass off)
						dmsg inform "\t DEBUG: $bpctlRes"
						test ! -z "$(echo $bpctlRes |grep successfully)" &&	{
							echo -e -n "\t$bpBus: Set to inline mode"
							sleep 0.1
							bpctlRes=$($bpCtlCmd $bpBus get_bypass |cut -d ' ' -f6-)
							test ! -z "$(echo "$bpctlRes" |grep 'non-Bypass')" && bpctlRes="\e[0;32minline\e[m" ||  bpctlRes="\e[0;31mbypass\e[m"
							echo -e ", checking: $bpctlRes mode"
						} || exitFail "\t$bpBus: failed to to set to inline mode!"
					fi
				} ;;	
				bp) {
					if [[ "$bpCtlCmd" = "bssf" ]]; then
						bpctlRes=$(sendIBS $uutSerDev $bpCtlCmd set_bypass)
						if [[ ! -z "$(echo $bpctlRes |grep -w PASS)" ]]; then
							echo -e -n "\t$bpBus: Set to bypass mode"
							sleep 0.1
							bpctlRes=$(sendIBS $uutSerDev $bpCtlCmd get_state |grep Passive |cut -d. -f1 |awk '{print $3}')
							if [[ ! -z "$(echo "$bpctlRes" |grep 'bypass')" ]]; then 
								bpctlRes="\e[0;32mbypass\e[m" 
							else
								bpctlRes="\e[0;31minline\e[m"
							fi
							echo -e ", checking: $bpctlRes mode"
						else
							exitFail "\t$bpBus: failed to to set to inline mode!"
						fi
					else
						bpctlRes=$($bpCtlCmd $bpBus set_bypass on)
						test ! -z "$(echo $bpctlRes |grep successfully)" &&	{
							echo -e -n "\t$bpBus: Set to bypass mode"
							sleep 0.1
							bpctlRes=$($bpCtlCmd $bpBus get_bypass |cut -d ' ' -f6-)
							test ! -z "$(echo "$bpctlRes" |grep 'non-Bypass')" && bpctlRes="\e[0;31minline\e[m" ||  bpctlRes="\e[0;32mbypass\e[m"
							echo -e ", checking: $bpctlRes mode"
						} || exitFail "\t$bpBus: failed to set to bypass mode!"
					fi
				} ;;
				discOff) {
					if [[ "$bpCtlCmd" = "bssf" ]]; then
						except "${FUNCNAME[0]}" "unsupported mode: $newState for IBS"
					else
						bpctlRes=$($bpCtlCmd $bpBus set_disc off)
						test ! -z "$(echo $bpctlRes |grep successfully)" &&	{
							echo -e -n "\t$bpBus: Disable Disconnect"
							sleep 0.1
							bpctlRes=$($bpCtlCmd $bpBus get_disc)
							test -z "$(echo "$bpctlRes" |grep 'in the non-Disconnect mode')" && bpctlRes="\e[0;31mDisconnect enabled\e[m" ||  bpctlRes="\e[0;32mDisconnect disabled\e[m"
							echo -e ", checking: $bpctlRes mode"
						} || exitFail "\t$bpBus: failed to set disable disconnect!"
					fi
				} ;;	
				discOn) {
					if [[ "$bpCtlCmd" = "bssf" ]]; then
						except "${FUNCNAME[0]}" "unsupported mode: $newState for IBS"
					else
						bpctlRes=$($bpCtlCmd $bpBus set_disc on)
						test ! -z "$(echo $bpctlRes |grep successfully)" &&	{
							echo -e -n "\t$bpBus: Enable Disconnect"
							sleep 0.1
							bpctlRes=$($bpCtlCmd $bpBus get_disc)
							test -z "$(echo "$bpctlRes" |grep 'in the Disconnect mode')" && bpctlRes="\e[0;31mDisconnect disabled\e[m" ||  bpctlRes="\e[0;32mDisconnect enabled\e[m"
							echo -e ", checking: $bpctlRes mode"
						} || exitFail "\t$bpBus: failed to set enable disconnect!"
					fi
				} ;;
				*) except "${FUNCNAME[0]}" "unknown state: $newState"
			esac	
		else
			except "${FUNCNAME[0]}" "bpBus is not in uutBpBuses or mastBpBuses"
		fi
}

allNetTests() {
	local nets netsDesc bpState uutModel maxRate
	privateVarAssign "allNetTests" "nets" "$1"
	privateVarAssign "allNetTests" "netsDesc" "$2"
	privateVarAssign "allNetTests" "bpState" "$3"
	privateVarAssign "allNetTests" "uutModel" "$4"
	shift; shift; shift; shift;
	privateVarAssign "allNetTests" "maxRate" "$ethMaxSpeed"

	if [[ -z "$ibsMode" ]]; then 
		allNetAct "$nets" "Check links are UP on $netsDesc ($bpState)" "testLinks" "yes" "$uutModel" "$@"
		allNetAct "$nets" "Check Data rates on $netsDesc" "getEthRates" "$maxRate" "$uutModel" "$@"
	else
		allNetAct "$nets" "Check links are UP on $netsDesc ($bpState)" "testLinks" "yes" "$uutModel" 3	
	fi
	#allNetAct "$nets" "Check Selftest on $netsDesc" "getEthSelftest" --noargs
}

allBPBusMode() {
	local bpBuses bpBus bpMode
	bpBuses="$1"
	bpMode="$2"
	dmsg inform "allBPBusMode, switching all bpBuses:$bpBuses to state bpMode:$bpMode"
	for bpBus in $bpBuses; do switchBP "$bpBus" "$bpMode"; done
	echo -e -n "\n"
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
		PE340G2BPI71) 
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
		*) except "${FUNCNAME[0]}" "Unknown baseModelLocal: $baseModelLocal"
	esac
}

loadSlcmModule() {
	local cmdRes
	echo -e "\t Loading SLCM module"
	echo -e "\t  Stopping slcmi_module"
	cmdRes="$(slcmi_stop 2>&1 > /dev/null)"; dmsg inform "$cmdRes"
	echo -e "\t  Stopping slcm_module"
	cmdRes="$(slcm_stop 2>&1 > /dev/null)"; dmsg inform "$cmdRes"
	if [ "$1" = "slcm" ]; then
		echo -e "\t  Starting slcm_module"
		cmdRes="$(slcm_start 2>&1 > /dev/null)"; dmsg inform "$cmdRes"
		if [[ "$?" -eq 0 ]]; then 
			echo -e "\t  slcm_module started"
		else
			except "${FUNCNAME[0]}" "unable to start slcm_module"
		fi
	else
		echo -e "\t  Starting slcmi_module"
		cmdRes="$(slcmi_start 2>&1 > /dev/null)"; dmsg inform "$cmdRes"
		if [[ "$?" -eq 0 ]]; then 
			echo -e "\t  slcmi_module started"
		else
			except "${FUNCNAME[0]}" "unable to start slcmi_module"
		fi
	fi
	echo -e "\t Done."
}

transceiverCheck() {
	local slcmModeLocal bus
	if [[ -z "$(echo $* |grep slcm)" ]]; then warn "${FUNCNAME[0]}: skipped, slcmMode is not defined for $baseModel"
	else
		privateVarAssign "${FUNCNAME[0]}" "slcmModeLocal" "$1" ;shift
		privateVarAssign "${FUNCNAME[0]}" "slcmBuses" "$*"
		loadSlcmModule "$slcmModeLocal"
		for bus in $slcmBuses; do
			if [ "$slcmModeLocal" = "slcmi" ]; then
				echo -e -n "\t Getting QSFP info on bus $bus\n\tTransceiver PN: "
				transPn=$(slcmi_util $bus get_qsfp_info |grep PartNumber |cut -d ' ' -f2)
				echo -e "$blw$transPn$ec"
			else
				echo -e -n "\t Getting SFP info on bus $bus\n\tTransceiver PN: "
				transPn=$(slcm_util $bus get_sfp_info |grep "vendor PN:" |cut -d ' ' -f3)
				echo -e "$blw$transPn$ec"
			fi
		done
	fi
}

transDiag() {
	local rdifCmdRes net nets KEY VALUE uioDev txOut rxIn chanCnt ch targModel
	local sfpVcc sfpVen sfpVenPn sfpVenSn sfpInfoRes sfpDiagRes slcmCmd slcmCmdRes ethBuses ethBus
	for ARG in "$@"; do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			targModel)	privateVarAssign "${FUNCNAME[0]}" "targModel" "${VALUE}" ;;
			nets)		privateVarAssign "${FUNCNAME[0]}" "nets" "${VALUE}" ;;
			uioDev)		privateVarAssign "${FUNCNAME[0]}" "uioDev" "${VALUE}";;
			ethBuses)	privateVarAssign "${FUNCNAME[0]}" "ethBuses" "${VALUE}";;
			*) inform "${FUNCNAME[0]}: unknown arg: $KEY" ;;
		esac
	done

	case "$targModel" in
		PE310G4DBIR) rdifCmd="rdifctl dev $uioDev get_power port"; let chanCnt=0;;
		PE340G2DBIR) rdifCmd="rdifctl dev $uioDev get_power port" ;;
		PE3100G2DBIR) rdifCmd="rdifctl dev $uioDev get_power port" ;;
		PE310G4BPI71) slcmCmd="slcm_util" ;;
		PE310G2BPI71) slcmCmd="slcm_util" ;;
		*) 
			if [[ ! -z "$slcmMode" ]]; then
				slcmCmd="slcm_util"
			else
				inform "${FUNCNAME[0]}: skipped, not defined for $targModel"
			fi
	esac

	

	if [[ ! -z "$rdifCmd" ]]; then
		if [[ -z "$chanCnt" ]]; then let chanCnt=3; fi
		if [[ -z "$nets" ]]; then 
			inform "${FUNCNAME[0]}: exception, nets are undefined"
		else
			for net in $nets; do
				rdifCmdRes=$($rdifCmd $net)
				echo -e "\tNet $net"
				for ((ch=0;ch<=$chanCnt;ch++)); do 
					txOut=$(echo "$rdifCmdRes" |grep -A2 "channel $ch" |grep -m1 TX |cut -d= -f2- |cut -d ' ' -f1-2)
					rxIn=$(echo "$rdifCmdRes" |grep -A2 "channel $ch" |grep -m1 RX |cut -d= -f2- |cut -d ' ' -f1-2)
					echo -e "\t  Channel $curChan: TX=$yl$txOut$ec  RX=$yl$rxIn$ec"
				done
			done
		fi

	fi

	if [[ ! -z "$slcmCmd" ]]; then
		if [[ -z "$ethBuses" ]]; then 
			inform "${FUNCNAME[0]}: exception, ethBuses are undefined"
		else
			for ethBus in $ethBuses; do
				echo -e -n "\tBus $ethBus "
				slcmCmdRes="$($slcmCmd $ethBus get_sfp_diag)"
				txOut=$(echo "$slcmCmdRes" |grep -m1 TX |cut -d= -f2- |cut -d ' ' -f1-2)
				rxIn=$(echo "$slcmCmdRes" |grep -m1 RX |cut -d= -f2- |cut -d ' ' -f1-2)
				sfpVcc=$(echo "$slcmCmdRes" |grep -m1 Vcc |cut -d= -f2- |cut -d ' ' -f1-2)
				
				slcmCmdRes="$($slcmCmd $ethBus get_sfp_info)"
				sfpVen=$(echo "$slcmCmdRes" |grep "vendor:" |cut -d ' ' -f2)
				sfpVenPn=$(echo "$slcmCmdRes" |grep "vendor PN:" |cut -d ' ' -f3)
				sfpVenSn=$(echo "$slcmCmdRes" |grep "vendor sn:" |cut -d ' ' -f3)

				echo -e "$sfpVen $sfpVenPn (SN: $sfpVenSn) TX=$yl$txOut$ec  RX=$yl$rxIn$ec  Vcc=$sfpVcc"
			done
		fi
	fi
}

bpSwitchTestsLoop() {
	local specArg
	dmsg inform "bpDevQty=$bpDevQty bpBuses=$bpBuses"
	case "$baseModel" in
		PE340G2DBIR|PE3100G2DBIR) 
			specArgUUT="$uutUIOdevNum"
			specArgMast="$mastUIOdevNum"
			dmsg inform "specArgUUT=$specArgUUT  specArgMast=$specArgMast"
		;;
		PE310G4DBIR)
			specArgUUT="$uutUIOdevNum"
			dmsg inform "specArgUUT=$specArgUUT"
		;;
		*) 
			bpctl_util all set_bp_manuf 2>&1 >/dev/null
			bprdctl_util all set_bp_manuf 2>&1 >/dev/null
		;;
	esac
	test ! -z "$bpDevQty" && {
		if [[ -z "$bpBuses" ]]; then except "${FUNCNAME[0]}" "bpBuses undefined!"; fi
		allBPBusMode "$bpBuses" "inline"
		allBPBusMode "$mastBpBuses" "inline"
		sleep $globLnkUpDel
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:IL" "$baseModel" "$specArgUUT"
		allNetTests "$mastNets" "MASTER" "UUT:IL MAST:IL" "$mastBaseModel" "$specArgMast"
		

		allBPBusMode "$bpBuses" "bp"
		sleep $globLnkUpDel
		allNetAct "$uutNets" "Check links are DOWN on UUT (UUT:BP MAST:IL)" "testLinks" "no" "$baseModel" "$specArgUUT"
		allNetTests "$mastNets" "MASTER" "UUT:BP MAST:IL" "$mastBaseModel" "$specArgMast"
		
		allBPBusMode "$bpBuses" "inline"
		allBPBusMode "$mastBpBuses" "bp"			
		sleep $globLnkUpDel
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:BP" "$baseModel" "$specArgUUT"
		allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:IL MAST:BP)" "testLinks" "no" "$mastBaseModel" "$specArgMast"

		allBPBusMode "$bpBuses" "bp"
		allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:BP MAST:BP)" "testLinks" "no" "$mastBaseModel" "$specArgMast"
		allNetAct "$uutNets" "Check links are DOWN on UUT (UUT:BP MAST:BP)" "testLinks" "no" "$baseModel" "$specArgUUT"
		
		allBPBusMode "$bpBuses" "inline"
		allBPBusMode "$mastBpBuses" "inline"

		allBPBusMode "$bpBuses" "discOn"
		allNetAct "$uutNets" "Check links are DOWN on UUT (UUT:BP MAST:IL)" "testLinks" "no" "$baseModel" "$specArgUUT"
		allBPBusMode "$bpBuses" "discOff"
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:IL" "$baseModel" "$specArgUUT"
	} || {
		allBPBusMode "$mastBpBuses" "inline"
		sleep $globLnkUpDel
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:IL" "$baseModel" "$specArgUUT"
		allNetTests "$mastNets" "MASTER" "UUT:IL MAST:IL" "$mastBaseModel" "$specArgMast"
		
		allBPBusMode "$mastBpBuses" "bp"
		sleep $globLnkUpDel
		allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:IL MAST:BP)" "testLinks" "no" "$mastBaseModel" "$specArgMast"
		allNetTests "$uutNets" "UUT" "UUT:IL MAST:BP" "$baseModel" "$specArgUUT"
	}
	allBPBusMode "$mastBpBuses" "inline"
}

checkCardDRate() {
	local targRate targNets targModel targRole
	privateVarAssign "checkCardDRate" "targRole" "$1"
	shift
	privateVarAssign "checkCardDRate" "targModel" "$1"
	shift
	privateVarAssign "checkCardDRate" "targRate" "$1"
	shift
	privateVarAssign "checkCardDRate" "targNets" "$*"

	allNetAct "$targNets" "Check Data rates on $targRole nets" "getEthRates" "$targRate" "$targModel"
}

setDRate() {
	local targRate targNets targModel targRole
	privateVarAssign "checkCardDRate" "targNet" "$1"
	privateVarAssign "checkCardDRate" "targRole" "$2"
	privateVarAssign "checkCardDRate" "targModel" "$3"
	privateVarAssign "checkCardDRate" "targRate" "$4"
	

	case "$targModel" in
		PE310G4BPI71) 		warn "setDRate, not implemented for $targModel";;
		PE310G2BPI71) 		warn "setDRate, not implemented for $targModel";;
		PE340G2BPI71) 		warn "setDRate, not implemented for $targModel";;
		PE210G2BPI40) 		drateRes=$(ethtool -s $targNet speed $targRate duplex full autoneg off);;
		PE310G4BPI40) 		drateRes=$(ethtool -s $targNet speed $targRate duplex full autoneg off);;
		PE310G4I40) 		drateRes=$(ethtool -s $targNet speed $targRate duplex full autoneg off);;
		PE310G4DBIR) 		warn "setDRate, not implemented for $targModel";;
		PE340G2DBIR) 		warn "setDRate, not implemented for $targModel";;
		PE3100G2DBIR) 		warn "setDRate, not implemented for $targModel";;
		PE310G4BPI9) 		warn "setDRate, not implemented for $targModel";;
		PE210G2BPI9) 		warn "setDRate, not implemented for $targModel";;
		PE210G2SPI9A) 		warn "setDRate, not implemented for $targModel";;
		PE325G2I71) 		warn "setDRate, not implemented for $targModel";;
		PE31625G4I71L) 		warn "setDRate, not implemented for $targModel";;
		M4E310G4I71) 		warn "setDRate, not implemented for $targModel";;
		*) except "${FUNCNAME[0]}" "unknown targModel: $targModel"
	esac

	dmsg inform "drateRes=$drateRes"
	test ! -z "$drateRes" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m"
}

setCardDRate() {
	local targRate targNets targModel targRole
	privateVarAssign "setCardDRate" "targRole" "$1"
	shift
	privateVarAssign "setCardDRate" "targModel" "$1"
	shift
	privateVarAssign "setCardDRate" "targRate" "$1"
	shift
	privateVarAssign "setCardDRate" "targNets" "$*"

	allNetAct "$targNets" "Set data rate to $targRate on $targRole" "setDRate" "$targRole" "$targModel" "$targRate"
}

resetCardDrate() {
	local targNet targSpeeds
	privateVarAssign "resetCardDrate" "targNet" "$1"
	shift
	privateVarAssign "resetCardDrate" "targSpeeds" "$*"

	dmsg inform "executing: ethtool -s $targNet $targSpeeds duplex full autoneg on"
	rstRes=$(ethtool -s $targNet $targSpeeds duplex full autoneg on)
	dmsg inform "rstRes=$rstRes"
	test ! -z "$rstRes" && echo -e -n "\e[0;31mFAIL\e[m" || echo -e -n "\e[0;32mOK\e[m"
}

	# 0x002                       10baseT Full
	# 0x008                       100baseT Full
	# 0x020                       1000baseT Full
	# 0x800000000000              2500baseT Full
	# 0x1000000000000             5000baseT Full
	# 0x1000                      10000baseT Full
	# 0x80000000000               10000baseSR Full
	# 0x100000000000              10000baseLR Full

dataRateTest() {
	local drate drateArg
	dmsg inform "uutDRates=${uutDRates[@]}"
	dmsg inform "uutDRates count=${#uutDRates[@]}"
	if [[ ! "${#uutDRates[@]}" = "0" ]]; then
		for drate in "${uutDRates[@]}"; 
		do
			drateArg+="speed $drate "
			setCardDRate "UUT" "$baseModel" $drate $uutNets
			setCardDRate "MASTER" "$mastBaseModel" $drate $mastNets
			sleep $globLnkUpDel

			checkCardDRate "UUT" "$baseModel" $drate $uutNets
			allNetAct "$uutNets" "Check links are UP on UUT" "testLinks" "yes" "$baseModel"
			checkCardDRate "MASTER" "$mastBaseModel" $drate $mastNets
			allNetAct "$mastNets" "Check links are UP on MASTER" "testLinks" "yes" "$mastBaseModel"
		done

		allNetAct "$uutNets" "Reseting data rate on UUT" "resetCardDrate" $drateArg
		allNetAct "$mastNets" "Reseting data rate on MASTER" "resetCardDrate" $drateArg
	else
		warn "dataRateTest skipped, uutDRates is undefined!"
	fi
}

bpModeTest() {
	allBPBusMode "$bpBuses" "discOn"
	allBPBusMode "$bpBuses" "discOff"
}


transTests() {
	echo -e "\tChecking UUT transceiver status:"
		case "$baseModel" in
			PE310G4BPI71) 		transDiag --targModel=$baseModel --ethBuses="$(filterDevsOnBus $uutSlotBus $ethBuses)";;
			PE310G2BPI71) 		transDiag --targModel=$baseModel --ethBuses="$(filterDevsOnBus $uutSlotBus $ethBuses)";;
			PE340G2BPI71) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE210G2BPI40) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4BPI40) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4I40) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4DBIR) 		transDiag --targModel="$baseModel" --nets="1 2 3 4" --uioDev="$uutUIOdevNum" --ethBuses="$(filterDevsOnBus $uutSlotBus $ethBuses)";;
			PE340G2DBIR) 		transDiag --targModel="$baseModel" --nets="1 2" --uioDev="$uutUIOdevNum";;
			PE3100G2DBIR) 		transDiag --targModel="$baseModel" --nets="1 2" --uioDev="$uutUIOdevNum";;
			PE310G4BPI9) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE210G2BPI9) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE210G2SPI9A) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE325G2I71) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE31625G4I71L) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			M4E310G4I71) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
		esac
	echo -e "\n"
}

bpModeTests() {
	echo -e "\tChecking UUT BP modes:"
		case "$baseModel" in
			PE310G4BPI71) 		bpModeTest;;
			PE310G2BPI71) 		bpModeTest;;
			PE340G2BPI71) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE210G2BPI40) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4BPI40) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4I40) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4DBIR) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE340G2DBIR) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE3100G2DBIR) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE310G4BPI9) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE210G2BPI9) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE210G2SPI9A) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE325G2I71) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			PE31625G4I71L) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			M4E310G4I71) 		warn "${FUNCNAME[0]}, not implemented for $baseModel";;
			*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
		esac
	echo -e "\n"
}

bpSwitchTests() {
	local options loopCount firstBpEth
	
	echo -e "\n  Checking BP FW"
	if [[ ! -z "$bpBuses" ]]; then
		firstBpEth=$(echo $bpBuses |awk '{print $1}')
		test -z "$firstBpEth" && warn "  Unable to acquire firstBpEth!" || checkBpFw "$firstBpEth" "$bpCtlMode"
	else
		inform "\t Skipped, because no bpBuses present"
	fi
	echo -e "\n"
	
	echo -e "\tUUT transceiver tests:"
		transTests
	echo -e "\n"

	echo -e "\tUUT BP modes tests:"
		bpModeTests
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
	
	
	
	for ((b=1;b<=$loopCount;b++)); do 
		warn "\tLoop: $b"
		bpSwitchTestsLoop
	done
	
}

trafficTests() {
	case "$baseModel" in
		PE310G4BPI71) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			inform "\t  Sourcing $baseModel lib."
			source /root/PE310G4BPI71/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 100000 "$baseModel"
		;;
		PE310G2BPI71)
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			inform "\t  Sourcing $baseModel lib."
			source /root/PE310G2BPI71/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 100000 "$baseModel"
		;;
		PE340G2BPI71) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			inform "\t  Sourcing $baseModel lib."
			source /root/PE340G2BPI71/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 10000000 "$baseModel"
		;;
		PE210G2BPI40)  
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			inform "\t  Sourcing $baseModel lib."
			source /root/$baseModel/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 1000000 "$baseModel"
		;;
		PE310G4BPI40) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			inform "\t  Sourcing $baseModel lib."
			source /root/PE310G4BPI40/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 1000000 "$baseModel"
		;;
		PE310G4I40) 
			allBPBusMode "$mastBpBuses" "inline"
			inform "\t  Sourcing $baseModel lib."
			source /root/PE310G4I40/library.sh 2>&1 > /dev/null
			sleep $globLnkUpDel				# to prevent duplication, hardcoded PN used
			trafficTest "$uutSlotNum" 1000000 "PE310G4BPI40"
		;;
		PE310G4DBIR) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 1000000 "PE310G4DBIR";;
		PE340G2DBIR) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 10000000 "PE340G2DBIR"
		;;
		PE3100G2DBIR) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			sleep $globLnkUpDel
			trafficTest "$uutSlotNum" 10000000 "PE3100G2DBIR"
		;;
		PE310G4BPI9) 
			allBPBusMode "$mastBpBuses" "inline"
			allBPBusMode "$bpBuses" "inline"
			trafficTest "$uutSlotNum" 1000000 "$baseModel"
		;;
		PE210G2BPI9) inform "Traffic tests are not defined for $baseModel";;
		PE210G2SPI9A) inform "Traffic tests are not defined for $baseModel";;
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

ibsBpTests() {
	if [[ -z "$uutPortMatch" ]]; then
		warn "Scheme of UUT connection to server is unknown!"
		warn "Reffer to the ATP!"
	else
		connWarnMsg $uutPortMatch
	fi

	if [[ -z "$ibsRjRequired" ]]; then
		allNetAct "$mastNets" "Reseting data rates on MASTER (cap at 1G)" "resetCardDrate" "speed 100 speed 1000"
	fi

	switchBP "SEG1" "inline"
	echo -e -n "\tSetting bypas mode INLINE: "; sendIBS $uutSerDev "set_bypass_mode inline" 2>&1 > /dev/null; if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	echo -e -n "\tSetting HB OFF: "; sendIBS $uutSerDev "set_hb_act_mode off" 2>&1 > /dev/null; if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi	
	allBPBusMode "$mastBpBuses" "inline"
	sleep $globLnkUpDel
	allNetTests "$uutNets" "UUT" "UUT:IL MAST:IL" "$baseModel"
	allNetTests "$mastNets" "MASTER" "UUT:IL MAST:IL" "$mastBaseModel"
	
	echo -e -n "\tSetting bypas mode BYPASS: "; sendIBS $uutSerDev "set_bypass_mode bypass" 2>&1 > /dev/null; if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	switchBP "SEG1" "bp"
	# sleep $globLnkUpDel
	allNetAct "$(echo $uutNets |cut -dM -f1)" "Check NET links are DOWN on UUT (UUT:BP MAST:IL)" "testLinks" "no" "$baseModel" 3
	allNetAct "$(echo $uutNets |cut -d1 -f2- |cut -d ' ' -f2-)" "Check MON links are UP on UUT (UUT:BP MAST:IL)" "testLinks" "yes" "$baseModel" 3
	allNetTests "$mastNets" "MASTER" "UUT:BP MAST:IL" "$mastBaseModel"
	
	switchBP "SEG1" "inline"
	echo -e -n "\tSetting bypas mode INLINE: "; sendIBS $uutSerDev "set_bypass_mode inline" 2>&1 > /dev/null; if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	allBPBusMode "$mastBpBuses" "bp"			
	sleep $globLnkUpDel
	allNetTests "$uutNets" "UUT" "UUT:IL MAST:BP" "$baseModel"
	allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:IL MAST:BP)" "testLinks" "no" "$mastBaseModel"

	echo -e -n "\tSetting bypas mode BYPASS: "; sendIBS $uutSerDev "set_bypass_mode bypass" 2>&1 > /dev/null; if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	switchBP "SEG1" "bp"
	sleep $globLnkUpDel
	allNetAct "$mastNets" "Check links are DOWN on MASTER (UUT:BP MAST:BP)" "testLinks" "no" "$mastBaseModel"
	allNetAct "$(echo $uutNets |cut -dM -f1)" "Check NET links are DOWN on UUT (UUT:BP MAST:IL)" "testLinks" "no" "$baseModel" 3
	allNetAct "$(echo $uutNets |cut -d1 -f2- |cut -d ' ' -f2-)" "Check MON links are UP on UUT (UUT:BP MAST:IL)" "testLinks" "yes" "$baseModel" 3
	
	switchBP "SEG1" "inline"
	echo -e -n "\tSetting bypas mode INLINE: "; sendIBS $uutSerDev "set_bypass_mode inline" 2>&1 > /dev/null; if [ $? -eq 0 ]; then echo -e "\e[0;32mOK\e[m"; else echo -e "\e[0;31mFAILED\e[m"; fi
	allBPBusMode "$mastBpBuses" "inline"
}

checkIbsMgntRate() {
	local cmdRes speedReq spdAcqRes linkAcqRes
	privateVarAssign "${FUNCNAME[0]}" "speedReq" "$1"
	cmdRes="$(sendRootIBS $uutSerDev ethtool eth0)"
	linkAcqRes=$(echo "$cmdRes" |grep 'Link detected:' |cut -d: -f2 |cut -d ' ' -f2 |cut -c1-3)
	spdAcqRes=$(echo "$cmdRes" |grep 'Speed: ')
	echo -n -e "\tChecking IBS MGNT speed: "
	if [[ "$linkAcqRes" = "yes" ]]; then
		if [[ -z "$(echo "$spdAcqRes" |sed 's/[^0-9]*//g' |grep -x $speedReq)" ]]; then
			echo -e "\e[0;31m$(echo -n "$spdAcqRes" | sed 's/[^0-9]//g')Mb/s (FAIL)\e[m" 
		else
			echo -e "\e[0;32m$(echo -n "$spdAcqRes" | sed 's/[^0-9]//g')Mb/s\e[m"
		fi
	else
		echo -e "\e[0;31mFAILED! NO LINK DETECTED!\e[m" 
	fi
}

ibsMgntTest() {
	local masterNetsLocal mastBaseModelLocal linkSetup
	if [[ ! -z "$ibsRjRequired" ]]; then
		ibsSelectMgntMasterPort
		masterNetsLocal="eth$?"
		mastBaseModelLocal="PE310G4BPI40"
		linkSetup=$(link_setup "$masterNetsLocal")
		if [[ ! -z "$(echo $linkSetup |grep "Failed")" ]]; then
			echo -e "\e[0;31m   RJ45 MASTER $masterNetsLocal link setup failed!\e[m" 
		else
			echo -e "\e[0;32m   RJ45 MASTER $masterNetsLocal link setup passed.\e[m"
		fi
	else
		masterNetsLocal=$mastNets
		mastBaseModelLocal="$mastBaseModel"
		connWarnMsgMgnt
	fi


	allNetAct "$masterNetsLocal" "Reseting data rates on MASTER (cap at 1G)" "resetCardDrate" "speed 100 speed 1000"

	setCardDRate "MASTER" "$mastBaseModelLocal" 100 $(echo $masterNetsLocal |cut -d ' ' -f1)
	sleep $globLnkUpDel
	checkCardDRate "MASTER" "$mastBaseModelLocal" 100 $(echo $masterNetsLocal |cut -d ' ' -f1)
	allNetAct "$(echo $masterNetsLocal |cut -d ' ' -f1)" "Check first link is UP on MASTER" "testLinks" "yes" "$mastBaseModelLocal"
	checkIbsMgntRate 100

	setCardDRate "MASTER" "$mastBaseModelLocal" 1000 $(echo $masterNetsLocal |cut -d ' ' -f1)
	sleep $globLnkUpDel
	checkCardDRate "MASTER" "$mastBaseModelLocal" 1000 $(echo $masterNetsLocal |cut -d ' ' -f1)
	allNetAct "$(echo $masterNetsLocal |cut -d ' ' -f1)" "Check first link is UP on MASTER" "testLinks" "yes" "$mastBaseModelLocal"
	checkIbsMgntRate 1000
}

ibsInfoCheck() {
	local verInfoRes prodInfoRes rootfsInfoRes
	verInfoRes="$(sendIBS $uutSerDev get_ver)"
	prodInfoRes="$(sendIBS $uutSerDev get_prd_name)"
	rootfsInfoRes="$(sendIBS $uutSerDev verb get_nand_rootfs_size)"

	checkIfContains "Checking BDS version" "--$ibsBdsVer" "$(echo "$verInfoRes" |grep -m 1 "$ibsBdsVer")"
	checkIfContains "Checking HW version" "--$ibsHwVerInfo" "$(echo "$verInfoRes" |grep -m 1 "$ibsHwVerInfo")"
	checkIfContains "Checking FW version" "--$ibsFwVer" "$(echo "$verInfoRes" |grep -m 1 "$ibsFwVer")"
	checkIfContains "Checking SWD version" "--$ibsSwVer" "$(echo "$verInfoRes" |grep -m 1 "$ibsSwVer")"
	checkIfContains "Checking U-Boot version" "--$ibsUbootVer" "$(echo "$verInfoRes" |grep -m 1 "$ibsUbootVer")"
	checkIfContains "Checking Kernel version" "--$ibsRootfsNandSIze" "$(echo "$rootfsInfoRes" |grep -m 1 "$ibsRootfsNandSIze")"
	checkIfContains "Checking Prod name" "--$ibsProdName" "$(echo "$prodInfoRes" |grep -m 1 "$ibsProdName")"
	checkIfContains "Checking rootfs NAND size" "--$ibsKernVer" "$(echo "$verInfoRes" |grep -m 1 "$ibsKernVer")"
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
			spc) publicVarAssign critical spcBuses $(grep '1180' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;	
			eth) publicVarAssign critical ethBuses $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			plx) publicVarAssign critical plxBuses $(grep '0604' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			acc) publicVarAssign critical accBuses $(grep '0b40' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-) ;;
			bp) 
				if [[ -z "$ibsMode" ]]; then
					case "$baseModel" in
						PE210G2BPI40) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE310G4BPI40) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE310G4BPI71) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE310G2BPI71) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE340G2BPI71) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE310G4DBIR) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE340G2DBIR) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE3100G2DBIR) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE310G4BPI9) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						PE210G2BPI9) publicVarAssign critical bpBuses $(filterDevsOnBus $uutSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1));;
						*) except "${FUNCNAME[0]}" "unknown baseModel: $baseModel"
					esac 
				else
					inform "  BP Bus assignation skipped for UUT"
				fi
			;;
			*) except "${FUNCNAME[0]}" "unknown bus type: $ARG"
		esac
	done
}

mainTest() {
	local pciTest dumpTest bpTest drateTest trfTest
	
	if [[ ! -z "$untestedPn" ]]; then untestedPnWarn; fi
	
	if [[ ! -z "$ibsMode" ]]; then
		acquireVal "BadasName" uutBdsUser uutBdsUser
		acquireVal "BadasPassword" uutBdsPass uutBdsPass
		acquireVal "RootName" uutRootUser uutRootUser
		acquireVal "RootPassword" uutRootPass uutRootPass

		echo -e "\n  Select tests:"
		options=("Full test" "Info test" "BP test" "Management rate test")
		case `select_opt "${options[@]}"` in
			0) 
				ibsInfoTest=1
				bpTest=1
				drateTest=1
			;;
			1) ibsInfoTest=1;;
			2) bpTest=1;;
			3) drateTest=1;;
			*) except "${FUNCNAME[0]}" "unknown option";;
		esac

		if [ ! -z "$ibsInfoTest" ]; then
			echoSection "IBS Info test"
				ibsInfoCheck |& tee /tmp/statusChk.log
			checkIfFailed "IBS Info test failed!" warn
		else
			inform "\tIBS Info test"
		fi

		if [ ! -z "$bpTest" ]; then
			echoSection "IBS BP test"
				ibsBpTests |& tee /tmp/statusChk.log
			checkIfFailed "IBS BP test failed!" exit
		else
			inform "\tIBS BP test"
		fi

		if [ ! -z "$drateTest" ]; then
			echoSection "IBS Management rate test"
				ibsMgntTest |& tee /tmp/statusChk.log
			checkIfFailed "IBS Management rate test failed!" exit
		else
			inform "\tIBS Management rate test"
		fi
	else
		if [ ! -z "$ignoreSlotDuplicate" ]; then pciTest=1; dumpTest=1;
		else
			echo -e "\n  Select tests:"
			options=("Full test" "PCI test" "Dump test" "BP Switch test" "Data rate test" "Traffic test")
			case `select_opt "${options[@]}"` in
				0) 
					pciTest=1
					dumpTest=1
					bpTest=1
					drateTest=1
					trfTest=1
				;;
				1) pciTest=1;;
				2) dumpTest=1;;
				3) bpTest=1;;
				4) drateTest=1;;
				5) trfTest=1;;
				*) except "${FUNCNAME[0]}" "unknown option";;
			esac
		fi 
		dmsg inform "pciTest=$pciTest dumpTest=$dumpTest bpTest=$bpTest drateTest=$drateTest trfTest=$trfTest"

		if [ ! -z "$pciTest" ]; then
			echoSection "PCI Info & Dev Qty"

				inform "\tUUT bus:"
				# dmsg inform "\tmainTest DEBUG: pciArgs: \n${pciArgs[@]}"
				listDevsPciLib "${pciArgs[@]}" |& tee /tmp/statusChk.log
				# dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
				
				inform "\tTraffic gen bus:"
				dmsg inform "\tmainTest DEBUG: mastPciArgs: \n${mastPciArgs[@]}"
				listDevsPciLib "${mastPciArgs[@]}" |& tee -a /tmp/statusChk.log
				# dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
			
			checkIfFailed "PCI Info & Dev Qty failed!" exit
		else
			inform "\tPCI test skipped"
		fi
			
		if [ ! -z "$dumpTest" ]; then
			echoSection "Info Dumps"
				netInfoDump $(echo -n $mastNets|awk '{print $1}') "MASTER" |& tee /tmp/statusChk.log
				netInfoDump $(echo -n $uutNets|awk '{print $1}') "UUT" |& tee -a /tmp/statusChk.log
				inform "\tUUT transceivers:"
				transceiverCheck $slcmMode "$(filterDevsOnBus $uutSlotBus $ethBuses)" |& tee -a /tmp/statusChk.log
				inform "\tMaster transceivers:"
				transceiverCheck $mastSlcmMode "$mastEthBuses" |& tee -a /tmp/statusChk.log
			test -z "$ignDumpFail" && checkIfFailed "Info Dumps failed!" crit || checkIfFailed "Info Dumps failed!" warn
			# dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
		else
			inform "\tDump test skipped"
		fi

		if [[ ! -z "$bpTest$drateTest$trfTest" ]]; then
			if [[ -z "$uutPortMatch" ]]; then
				warn "Scheme of UUT connection to server is unknown!"
				warn "Reffer to the ATP!"
			else
				connWarnMsg $uutPortMatch
			fi
		fi

		if [[ ! -z "$bpTest" ]]; then
			echoSection "BP Switch tests"
				bpSwitchTests |& tee /tmp/statusChk.log
				# dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
			checkIfFailed "BP Switch tests failed!" exit
		else
			inform "\tBP Switch test skipped"
		fi

		if [[ ! -z "$drateTest" ]]; then
			echoSection "Data rate tests"
				dataRateTest
			checkIfFailed "Data rate tests failed!" exit
		else
			inform "\tData rate test skipped"
		fi

		if [[ ! -z "$trfTest" ]]; then
			echoSection "Traffic tests"
				trafficTests |& tee /tmp/statusChk.log
				# dmsg inform "\tmainTest DEBUG: /tmp/statusChk.log: \n$(cat /tmp/statusChk.log)"
			checkIfFailed "Traffic tests failed!" exit
		else
			inform "\tTraffic test skipped"
		fi
	fi
}

assignNets() {
	publicVarAssign warn uutNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep $uutSlotBus |awk -F/ '{print $NF}')
}

initialSetup(){
	
	if [[ -z "$ibsMode" ]]; then
		if [[ -z "$uutSlotArg" ]]; then 
			selectSlot "  Select UUT:"
			uutSlotNum=$?
			dmsg inform "uutSlotNum=$uutSlotNum"
		else acquireVal "UUT slot" uutSlotArg uutSlotNum; fi
	else
		inform "  IBS Mode active, skipping slot selection for UUT"
		skipInit=1
		selectSerial "  Select UUT serial device"
		uutSerDev=ttyUSB$?
		testFileExist "/dev/$uutSerDev"
	fi
	
	if [[ -z "$masterSlotArg" ]]; then 
		if [ -z "$ignoreSlotDuplicate" ]; then
			selectSlot "\n  Select MASTER:"
			mastSlotNum=$?
		else
			mastSlotNum=$uutSlotNum
		fi
		dmsg inform "mastSlotNum=$mastSlotNum"
	else 
		acquireVal "Traffic gen slot" masterSlotArg mastSlotNum
	fi

	if [ "$mastSlotNum" = "$uutSlotNum" -a -z "$ignoreSlotDuplicate" ] ; then except "${FUNCNAME[0]}" "illegal slot selected!"; fi

	acquireVal "Part Number" pnArg uutPn
	
	
	if [[ -z "$ibsMode" ]]; then publicVarAssign warn uutBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $uutSlotNum |tail -n 1); fi
	publicVarAssign warn mastBus $(dmidecode -t slot |grep "Bus Address:" |cut -d: -f3 |head -n $mastSlotNum |tail -n 1)
	if [[ -z "$ibsMode" ]]; then publicVarAssign fatal uutSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$uutBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}'); fi
	publicVarAssign fatal mastSlotBus $(ls -l /sys/bus/pci/devices/ |grep -m1 :$mastBus: |awk -F/ '{print $(NF-1)}' |awk -F. '{print $1}')
	if [[ -z "$ibsMode" ]]; then publicVarAssign fatal devsOnUutSlotBus $(ls -l /sys/bus/pci/devices/ |grep $uutSlotBus |awk -F/ '{print $NF}'); fi
	publicVarAssign fatal devsOnMastSlotBus $(ls -l /sys/bus/pci/devices/ |grep :$mastBus: |awk -F/ '{print $NF}')


	publicVarAssign warn mastNets $(ls -l /sys/class/net |cut -d'>' -f2 |sort |grep 0000:$mastBus |awk -F/ '{print $NF}')
	
	if [[ -z "$ibsMode" ]]; then 
		assignNets
		test "$uutBus" = "ff" && except "${FUNCNAME[0]}" "card not detected, uutBus=ff"
	else
		publicVarAssign fatal uutNets "NET0 NET1 MON0 MON1"
	fi
	dmsg inform " assigning master eth buses on bus: $mastBus"
	publicVarAssign warn mastEthBuses $(filterDevsOnBus $(echo -n ":$mastBus:") $(grep '0200' /sys/bus/pci/devices/*/class |awk -F/ '{print $(NF-1)}' |cut -d: -f2-))
	
	preInitBpStartup
	
	dmsg inform " assigning master bp buses on bus: $mastBus"
	if [[ -e "/dev/bpctl0" ]]; then 
		publicVarAssign warn mastBpBuses $(filterDevsOnBus $mastSlotBus $(bpctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1))
	else
		publicVarAssign warn mastBpBuses $(filterDevsOnBus $mastSlotBus $(bprdctl_util all is_bypass |grep master |sort -u |cut -d ' ' -f1))
	fi

	defineRequirments
	checkRequiredFiles
}

main() {	
	if [[ -z "$ibsMode" ]]; then setupLinks "$uutNets"; else inform "  Link setup skipped, IBS mode"; fi
	setupLinks "$mastNets"
	
	test ! -z "$(echo -n $uutBus$mastBus|grep ff)" && {
		except "${FUNCNAME[0]}" "UUT or Master invalid slot or not detected! uutBus: $uutBus mastBus: $mastBus"
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
	source /root/PE310G4BPI71/library.sh 2>&1 > /dev/null
	main
	echo -e "See $(inform "--help" "--nnl" "--sil") for available parameters\n"
}
