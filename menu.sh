#!/bin/bash

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			debug) debugMode=1 ;;
			help)
				echoSection "ACC diagnostics"
				${MC_SCRIPT_PATH}/acc_diag_lib.sh --help
				echoSection "SFP diagnostics"
				${MC_SCRIPT_PATH}/sfpLinkTest.sh --help
				exit
			;;
			menu-choice) menuChoice=${VALUE} ;;
			*) dmsg echo "Unknown arg: $ARG"
		esac
	done
}


main() {
	title="Tool selector menu"
	btitle="  arturd@silicom.co.il"	
	declare -a cardArgs=(
		"delim" 	"==========================="
		"delim" 	"|  TOOLS"
		"showSlots" "| Show PCI Slots"
		"showSlM"	"| Show PCI Slots (minimal)"
		"delim" 	"==========================="
		"delim" 	"|  ACCELERATION CARDS"
		#"acc" 		" Acceleration Tool"
		"acc1" 		"| PE3IS2CO3LS"
		"acc2" 		"| PE3IS2CO3LS-CX"
		"acc3" 		"| PE2ISCO3-CX"
		"acc4" 		"| PE3ISLBTL"
		"acc4-1" 	"| PE3ISLBTL-FU"
		"acc4-2" 	"| PE3ISLBTL-FN"
		"acc5" 		"| PE3ISLBLL"
		"acc6" 		"| PE316IS2LBTLB-CX"
		"acc7" 		"| P3IMB-M-P1"
		"delim" 	"==========================="
		"delim" 	"|  SFP CARDS"
		"sfpD1" 	"| PE210G2BPI9-SR"
		"sfpD1-1" 	"| PE210G2BPI9-SRSD-BC8"
		"sfpD1-2" 	"| PE210G2BPI9-SR-SD"
		"sfpD1-3" 	"| PE210G2BPI9-SRD-SD"
		"sfpD2" 	"| PE310G4BPI71-SR"
		"sfpD2-1" 	"| PE310G4BPI71-LR"
		"sfpD3" 	"| PE310G2BPI71-SR"
		"sfpD4" 	"| PE310G4DBIR"
		"sfpD5" 	"| PE310G4BPI9-SR"
		"sfpD5-1" 	"| PE310G4BPI9-LR"
		"sfpD6" 	"| PE325G2I71-XR-CX"
		"sfpD6-1" 	"| PE325G2I71-XR-SP"
		"sfpD7" 	"| PE31625G4I71L-XR-CX"
		"sfpD8" 	"| M4E310G4I71-XR-CP2"
		"delim" 	"==========================="
		"delim" 	"|  RJ45 CARDS"
		"rjD1" 		"| PE310G4BPI40-T"
		"rjD2" 		"| PE310G4I40-T"
		"delim" 	"==========================="
		"delim" 	"|  IBS"
		"ibsD1" 	"| IBSGP-T* (universal)"
		"ibsD2" 	"| IBSGP-T"
		"ibsD3" 	"| IBSGP-T-MC-AM"
		"ibsD4" 	"| IBS10GP-* (universal)"
		"ibsD5" 	"| IBS10GP-LR-RW"
		"delim" 	"==========================="
		# "delim" 	"|  Etc.."
		# "transRep" 	"| PE310G4BPI71-SR (transceiver check"
		# "transRep1" "| PE310G4BPI71-SR (transceiver clone)"
		# "delim" 	"==========================="
		"Exit" 		"| Exit"
		"delim" 	"==========================="
	)

	testFileExist "${MC_SCRIPT_PATH}/acc_diag_lib.sh"
	testFileExist "${MC_SCRIPT_PATH}/sfpLinkTest.sh"
	# getTracking
	# createLog
	test -z "$menuChoice" && whptRes=$(whiptail --nocancel --notags --title "$title" --backtitle "$btitle" --menu "Select card or tool" 29 45 20 ${cardArgs[@]} 3>&2 2>&1 1>&3) || whptRes=$menuChoice
	case "$whptRes" in
		acc) 		${MC_SCRIPT_PATH}/acc_diag_lib.sh;;
		acc1)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE3IS2CO3LS" $@;;
		acc2)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE3IS2CO3LS-CX" $@;;
		acc3)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE2ISCO3-CX" $@;;
		acc4)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE3ISLBTL" $@;;
		acc4-1)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE3ISLBTL-FU" $@;;
		acc4-2)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE3ISLBTL-FN" $@;;
		acc5)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE3ISLBLL" $@;;
		acc6)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="PE316IS2LBTLB-CX" $@;;
		acc7)		${MC_SCRIPT_PATH}/acc_diag_lib.sh --uut-pn="P3IMB-M-P1" $@;;
		sfpD1) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SR" $@;;
		sfpD1-1)	${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SRSD-BC8" $@;;
		sfpD1-2)	${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SR-SD" $@;;
		sfpD1-3)	${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SRD-SD" $@;;
		sfpD2) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE310G4BPI71-SR" $@;;
		sfpD2-1) 	${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE310G4BPI71-LR" $@;;
		sfpD3) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE310G2BPI71-SR" $@;;
		sfpD4) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE310G4DBIR" $@;;
		sfpD5) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn=" PE310G4BPI9-SR" $@;;
		sfpD5-1)	${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn=" PE310G4BPI9-LR" $@;;
		sfpD6) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE325G2I71-XR-CX" $@;;
		sfpD6-1)	${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE325G2I71-XR-SP" $@;;
		sfpD7) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE31625G4I71L-XR-CX" $@;;
		sfpD8) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="M4E310G4I71-XR-CP2" $@;;
		rjD1) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE310G4BPI40-T" $@;;
		rjD2) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="PE310G4I40-T" $@;;
		ibsD1) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="IBSGP-T*" --ibs-mode $@;;
		ibsD2) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="IBSGP-T" --ibs-mode $@;;
		ibsD3) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="IBSGP-T-MC-AM" --ibs-mode $@;;
		ibsD4) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="IBS10GP-*" --ibs-mode $@;;
		ibsD5) 		${MC_SCRIPT_PATH}/sfpLinkTest.sh --uut-pn="IBS10GP-LR-RW" --ibs-mode $@;;

		showSlots) 	showPciSlots;;
		showSlM) 	showPciSlots --minimalMode;;
		transRep)	
			testFileExist "/root/PE310G4BPI71"
			cd /root/PE310G4BPI71
			testFileExist "/root/PE310G4BPI71/sfpDiag.sh"
			/root/PE310G4BPI71/sfpDiag.sh --full-reg-ver --show-fail-regs --sfp-read-count=5 --show-sn
		;;
		transRep1)	
			testFileExist "/root/PE310G4BPI71"
			cd /root/PE310G4BPI71
			testFileExist "/root/PE310G4BPI71/sfpClone.sh"
			/root/PE310G4BPI71/sfpClone.sh
		;;
		delim) exit;;
		Exit) exit;;
		*) exitFail echo "Unknown menu entry: $whptRes"
	esac
	# uploadLog
	unset debugMode
}

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
trap "exit 1" 10
PROC="$$"
libPath="/root/multiCard/arturLib.sh"
export MC_SCRIPT_PATH=/root/multiCard
if [[ -e "$libPath" ]]; then 
	echo -e "  \e[0;32mLib found.\e[m"
	source $libPath
	source /root/multiCard/graphicsLib.sh
	parseArgs "$@"
	main "$@"
else
	echo -e "  \e[0;31mLib not found by path: $libPath\e[m"
fi