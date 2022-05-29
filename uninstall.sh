#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

export MC_SCRIPT_PATH=/root/multiCard

if [[ ! -e "${MC_SCRIPT_PATH}" ]]; then 
	mkdir "${MC_SCRIPT_PATH}"
fi



checkStartup="$(cat ${MC_SCRIPT_PATH}/startup.sh 2>&1 |grep -v "No such file")"
if [[ ! -z "$checkStartup" ]]; then 
	rm -f ${MC_SCRIPT_PATH}/startup.sh
fi

checkAutostart="$(cat /root/.bash_profile 2>&1 |grep "${MC_SCRIPT_PATH}/startup.sh")"
if [[ ! -z "$checkAutostart" ]]; then 
	awk '!/multiCard/' /root/.bash_profile > tempF && mv -f tempF /root/.bash_profile
fi

rm -f /usr/bin/uninstallScript