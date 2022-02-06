#!/bin/bash

parseArgs() {
	for ARG in "$@"
	do
		KEY=$(echo $ARG|cut -c3- |cut -f1 -d=)
		VALUE=$(echo $ARG |cut -f2 -d=)
		case "$KEY" in
			debug) debugMode=1 ;;
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
		"sfpD3" 	"| PE310G2BPI71-SR"
		"sfpD4" 	"| PE310G4DBIR"
		"sfpD5" 	"| PE325G2I71-XR-CX"
		"sfpD5-1" 	"| PE325G2I71-XR-SP"
		"sfpD6" 	"| PE31625G4I71L-XR-CX"
		"delim" 	"==========================="
		"delim" 	"|  Etc.."
		"transRep" "| PE310G4BPI71-SR (transceiver repair)"
		"delim" 	"==========================="
		"Exit" 		"| Exit"
		"delim" 	"==========================="
	)
	#subfArg="acc ACC_Diagnostics sfpD SFP-based_Diagnostics Exit Exit"
	testFileExist "/root/multiCard/acc_diag_lib.sh"
	testFileExist "/root/multiCard/sfpLinkTest.sh"
	whptRes=$(whiptail --nocancel --notags --title "$title" --backtitle "$btitle" --menu "Select card or tool" 29 45 20 ${cardArgs[@]} 3>&2 2>&1 1>&3)
	case "$whptRes" in
		acc) 		/root/multiCard/acc_diag_lib.sh;;
		acc1)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE3IS2CO3LS" $@;;
		acc2)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE3IS2CO3LS-CX" $@;;
		acc3)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE2ISCO3-CX" $@;;
		acc4)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE3ISLBTL" $@;;
		acc4-1)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE3ISLBTL-FU" $@;;
		acc4-2)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE3ISLBTL-FN" $@;;
		acc5)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE3ISLBLL" $@;;
		acc6)		/root/multiCard/acc_diag_lib.sh --uut-pn="PE316IS2LBTLB-CX" $@;;
		acc7)		/root/multiCard/acc_diag_lib.sh --uut-pn="P3IMB-M-P1" $@;;
		sfpD1) 		/root/multiCard/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SR" $@;;
		sfpD1-1)	/root/multiCard/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SRSD-BC8" $@;;
		sfpD1-2)	/root/multiCard/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SR-SD" $@;;
		sfpD1-3)	/root/multiCard/sfpLinkTest.sh --uut-pn="PE210G2BPI9-SRD-SD" $@;;
		sfpD2) 		/root/multiCard/sfpLinkTest.sh --uut-pn="PE310G4BPI71-SR" $@;;
		sfpD3) 		/root/multiCard/sfpLinkTest.sh --uut-pn="PE310G2BPI71-SR" $@;;
		sfpD4) 		/root/multiCard/sfpLinkTest.sh --uut-pn="PE310G4DBIR" $@;;
		sfpD5) 		/root/multiCard/sfpLinkTest.sh --uut-pn="PE325G2I71-XR-CX" $@;;
		sfpD5-1)	/root/multiCard/sfpLinkTest.sh --uut-pn="PE325G2I71-XR-SP" $@;;
		sfpD6) 		/root/multiCard/sfpLinkTest.sh --uut-pn="PE31625G4I71L-XR-CX" $@;;
		showSlots) 	showPciSlots;;
		transRep)	
			testFileExist "/root/PE310G4BPI71"
			cd /root/PE310G4BPI71
			testFileExist "/root/PE310G4BPI71/sfpDiag.sh"
			/root/PE310G4BPI71/sfpDiag.sh --full-reg-ver --show-fail-regs --sfp-read-count=5 --show-sn
		;;
		delim) exit;;
		Exit) exit;;
		*) exitFail echo "Unknown menu entry: $whptRes"
	esac
	unset debugMode
}

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'
trap "exit 1" 10
PROC="$$"
libPath="/root/multiCard/arturLib.sh"
if [[ -e "$libPath" ]]; then 
	echo -e "  \e[0;32mLib found.\e[m"
	source $libPath
	parseArgs "$@"
	main "$@"
else
	echo -e "  \e[0;31mLib not found by path: $libPath\e[m"
fi