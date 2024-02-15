#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

echoHeader() {
	local addEl hdrText toolName ver
	toolName="$1"
	ver="$2"
	hdrTest="$toolName  $ver"
	for ((e=0;e<=${#hdrTest};e++)); do addEl="$addEl="; done		
	echo -e "\n\t  =====$addEl====="
	echo -e "\t  ░░   $hdrTest    ░░"
	echo -e "\t  =====$addEl=====\n"
}

echoPass() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\n\e[0;32m     ██████╗░░█████╗░░██████╗░██████╗"
	echo "     ██╔══██╗██╔══██╗██╔════╝██╔════╝"
	echo "     ██████╔╝███████║╚█████╗░╚█████╗░"
	echo "     ██╔═══╝░██╔══██║░╚═══██╗░╚═══██╗"
	echo "     ██║░░░░░██║░░██║██████╔╝██████╔╝"
	echo -e "     ╚═╝░░░░░╚═╝░░╚═╝╚═════╝░╚═════╝░\e[m\n\n"
}

echoFail() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	echo -e "\n\e[0;31m     ███████╗░█████╗░██╗██╗░░░░░" 1>&2
	echo "     ██╔════╝██╔══██╗██║██║░░░░░" 1>&2
	echo "     █████╗░░███████║██║██║░░░░░" 1>&2
	echo "     ██╔══╝░░██╔══██║██║██║░░░░░" 1>&2
	echo "     ██║░░░░░██║░░██║██║███████╗" 1>&2
	echo -e "     ╚═╝░░░░░╚═╝░░╚═╝╚═╝╚══════╝\e[m\n\n" 1>&2
}

echoSection() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"		
	local addEl
	sendToKmsg 'Section "'$yl$1$ec'" has started..'
	for ((e=0;e<=${#1};e++)); do addEl="$addEl="; done		
	echo -e "\n  =====$addEl====="
	echo -e "  ░░   $1    ░░"
	echo -e "  =====$addEl=====\n"
}

echoRes() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local cmdLn
	cmdLn="$@"
	cmdRes="$($cmdLn; echo "res:$?")"
	test -z "$(echo "$cmdRes" |grep -w 'res:1')" && echo -n -e "\e[0;32mOK\e[m\n" || echo -n -e "\e[0;31mFAIL"'!'"\e[m\n" 1>&2
}

echoIfExists() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	test -z "$2" || {
		echo -n "$1 "
		shift
		echo "$*"
	}
}

replugUSBMsg() {
	local title btitle conRows conCols
	title="USB Reconnect"
	btitle="  arturd@silicom.co.il"	
	whiptail --nocancel --notags --title "$title" --backtitle "$btitle" --msgbox "Reconnect USB cable to the UUT" 8 35 3>&2 2>&1 1>&3
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tText lib for testing (support: arturd@silicom.co.il)'
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