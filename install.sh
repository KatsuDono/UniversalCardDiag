#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

export MC_SCRIPT_PATH=/root/multiCard

if [[ ! -e "${MC_SCRIPT_PATH}" ]]; then 
	mkdir "${MC_SCRIPT_PATH}"
fi

if [[ ! -e "${MC_SCRIPT_PATH}/arturLib.sh" ]]; then
	cp $(dirname "$0")/arturLib.sh ${MC_SCRIPT_PATH}
	if [ $? -eq 0 ]; then echo -e "Copied Lib.."; else echo -e "Failed to copy Lib!"; exit; fi
	chmod +777 "${MC_SCRIPT_PATH}/arturLib.sh"
fi

if [[ ! -e "${MC_SCRIPT_PATH}/uninstall.sh" ]]; then
	cp $(dirname "$0")/uninstall.sh ${MC_SCRIPT_PATH}
	if [ $? -eq 0 ]; then echo -e "Copied uninstall script.."; else echo -e "Failed to copy uninstall script"'!'; exit; fi
	chmod +777 "${MC_SCRIPT_PATH}/uninstall.sh"
fi

checkStartup="$(cat ${MC_SCRIPT_PATH}/startup.sh 2>&1 |grep -v "No such file")"
if [[ -z "$checkStartup" ]]; then 
	echo -e "#"'!'"/bin/bash\nsource ${MC_SCRIPT_PATH}/arturLib.sh 2>&1 > /dev/null\nshowPciSlots --minimalMode\necho -e 'To uninstall this script: run "'"uninstallScript"'"'\necho ''" |tee ${MC_SCRIPT_PATH}/startup.sh 2>&1 > /dev/null
	chmod +777 ${MC_SCRIPT_PATH}/startup.sh
fi

checkAutostart="$(cat /root/.bash_profile 2>&1 |grep "${MC_SCRIPT_PATH}/startup.sh")"
if [[ -z "$checkAutostart" ]]; then 
	sed -i -e '$i \/root/multiCard/startup.sh\n' /root/.bash_profile
fi

ln -s /root/multiCard/uninstall.sh /usr/bin/uninstallScript  2>&1 > /dev/null;chmod +777 /usr/bin/uninstallScript