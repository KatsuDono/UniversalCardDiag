#!/bin/bash

mountAndParse() {
	sync
	unmountAll
	echo "Making dir bootPart"; mkdir /mnt/bootPart &> /dev/null
	echo "Mounting bootPart"; mount /dev/sda3 /mnt/bootPart

	if ! [[ -e "${GRUB_CFG_PATH}/grub.cfg" ]]; then echo -e "\e[0;31mGRUB config could not be found by path: \e[1;41;33m${GRUB_CFG_PATH}/grub.cfg\e[m"; return 1; fi
	if ! [[ -e "${GRUB_CFG_PATH}/grubenv" ]]; then echo -e "\e[0;31mGRUB enviroment file could not be found by path: \e[1;41;33m${GRUB_CFG_PATH}/grubenv\e[m"; return 1; fi
	
	stdName=$(cat ${GRUB_CFG_PATH}/grub.cfg |grep menuentry |cut -d\' -f2 |grep 'STANDART')
	pomonaName=$(cat ${GRUB_CFG_PATH}/grub.cfg |grep menuentry |cut -d\' -f2 |grep 'POMONA')
	currEntry=$(cat ${GRUB_CFG_PATH}/grubenv |grep saved_entry |cut -d= -f2)
}

unmountAll() {
	if [ ! -z "$(mount |grep bootPart)" ]; then echo "Unmounting bootPart"; umount /mnt/bootPart; fi
}

function main () {
	if [ -z "$1" ]; then
		echo -e "\e[0;31mNew boot entry is not specified. Please specify, --pomona, --standart or --check-mode \e[m"
	else
		case "$1" in
			#--pomona) 	newEntry=$(echo -n $pomonaName | sed -e "s#/#\\\/#g") ;;
			#--standart) newEntry=$(echo -n $stdName | sed -e "s#/#\\\/#g") ;;
			--pomona) 	mountAndParse; newEntry=$pomonaName ;;
			--standart) mountAndParse; newEntry=$stdName ;;
			--check-mode) 
				if [ -z "$(echo $currEntry |grep POMONA)" ]; then
					echo "Current entry: standart"
				else
					echo "Current entry: pomona"
				fi
				return 0
			;;
			*) 
				echo -e "\e[0;31mNew boot entry option '"$1"'is not recognized. Please specify, --pomona, --standart or --check-mode \e[m"
				return 1
		esac


		if [ "$currEntry" = "$newEntry"  ]; then 
			echo -e "\e[0;32mCurrent entry is already set, skipping\e[m"
			return 0
		else 
			echo -e "Current entry active: \e[0;33m$currEntry\e[m"
			echo -e "New entry: \e[0;33m$newEntry\e[m"
			sed -i "s:saved_entry=.*:saved_entry=$newEntry:" ${GRUB_CFG_PATH}/grubenv
			currEntry=$(cat ${GRUB_CFG_PATH}/grubenv |grep saved_entry |cut -d= -f2)
			if [ "$currEntry" = "$newEntry"  ]; then 
				echo -e "\e[0;32mChanged the entry.\e[m"
				echo -e "Current entry active: \e[0;33m$(cat ${GRUB_CFG_PATH}/grubenv |grep saved_entry)\e[m"
				return 0
			else
				echo "\e[0;31mFailed to change the entry!\e[m"
				echo -e "Current entry active: \e[0;33m$(cat ${GRUB_CFG_PATH}/grubenv |grep saved_entry)\e[m"
				return 1
			fi
		fi
	fi
}

export GRUB_CFG_PATH=/mnt/bootPart/grub2

echo -e '\n# arturd@silicom.co.il\n'
toolName="GRUB config changing tool"
for ((e=0;e<=${#toolName};e++)); do addEl="$addEl="; done		
echo -e "\n\n    =====$addEl====="
echo -e "    ░░   $toolName    ░░"
echo -e "    =====$addEl=====\n"

main "$@"
unmountAll
echo -ne "\n"