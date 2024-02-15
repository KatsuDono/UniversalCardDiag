#!/bin/bash

echo -e '\n# arturd@silicom.co.il\n\n\e[0;47m\n\e[m\n'

diskWriteTest() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local diskDev skipBlockSizeMB writeBlockSizeMB testStatus
	privateVarAssign "${FUNCNAME[0]}" "diskDev" "$1"
	skipBlockSizeMB=$2
	writeBlockSizeMB=$3

	if [ -z "$skipBlockSizeMB" -o -z "$writeBlockSizeMB" ]; then
		let skipBlockSizeMB=128
		let writeBlockSizeMB=16
	else
		privateNumAssign "skipBlockSizeMB" "$2"
		privateNumAssign "writeBlockSizeMB" "$3"
	fi

	let testStatus=0
	testFile="/tmp/random_data_file.bin"
	mountedDev="$(mount |grep "$diskDev")"

	echo -ne "\tDevice path: $yl$diskDev$ec "
	if [ ! -e "$diskDev" ]; then 
		echo -e "${rd}FAIL$ec"
	else
		echo -e "${gr}OK$ec"
		if [ -z "$mountedDev" ]; then 
			privateNumAssign "totalSpaceMB" $(($(blockdev --getsize64 $diskDev)/1024/1024))
			let totalSpaceMB=$(($totalSpaceMB-$writeBlockSizeMB)) #for safety

			if [ $totalSpaceMB -lt 145 ]; then
				except "Device $diskDev size is $totalSpaceMB and is less than 161MB so cannot be used"
			fi

			echo -e "\tTotal device size: $gr$(($totalSpaceMB+$writeBlockSizeMB))MB$ec"
			echo -e "\tSeek block size: $yl${skipBlockSizeMB}MB$ec"
			echo -e "\tWrite block size: $yl${writeBlockSizeMB}MB$ec"
			echo -e "\tTotal test write count: $yl$(($totalSpaceMB/$skipBlockSizeMB))$ec\n\n"

			createRandomFile "$testFile" $writeBlockSizeMB
			sourceChecksum=$(calculateChecksum "$testFile")

			for ((startAddr = $skipBlockSizeMB; startAddr < totalSpaceMB; startAddr += $skipBlockSizeMB)); do
				endAddr=$((startAddr + $writeBlockSizeMB))

				backupFilePath="/tmp/backup_${startAddr}-${endAddr}MB.bin"
				backupBlock "$diskDev" "$startAddr" "$endAddr" "$backupFilePath" $writeBlockSizeMB
				writeZeros "$diskDev" "$startAddr" "$endAddr" $writeBlockSizeMB
				verifyZeros "$diskDev" "$startAddr" "$endAddr" $writeBlockSizeMB
				writeRandomData "$diskDev" "$startAddr" "$endAddr" "$testFile" $writeBlockSizeMB
				exec 3>&1
				dumpedChecksum=$(dumpAndCalculateChecksum "$diskDev" "$startAddr" "$endAddr" $writeBlockSizeMB 4>&1)
				exec 3>&-

				# The prompts are displayed using file descriptor 3 (>&3), 
				# and the actual results of the calculation are redirected to file descriptor 4 (>&4). 
				# By using >&3- in the subshell command grouping, 
				# we close file descriptor 3 for the calculation output, ensuring that 
				# only the prompts are displayed there. The resultsOfCalc variable captures 
				# only the contents of file descriptor 4, which contains the calculation results.

				printf '\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K\e[A\e[K'
				echo -ne "\tWrite test on ${startAddr}-${endAddr}MB "
				if [ "$sourceChecksum" = "$dumpedChecksum" ]; then
					echo -e "\t${gr}OK$ec"
				else
					echo -e "\t${rd}FAIL$ec"
					let testStatus++
				fi

				restoreBlock "$diskDev" "$startAddr" "$endAddr" "$backupFilePath" $writeBlockSizeMB
				printf '\e[A\e[K'
				
			done
			if [ $testStatus -eq 0 ]; then
				echo -e "\e[A\e[K\tResult: Write test PASSED\t\t\t\t\t\t\t\t"
			else
				echo -e "\e[A\e[K\tResult: Write test FAILED\t\t\t\t\t\t\t\t"
			fi
			rm -f "$testFile"
		else
			echo -e "\t${rd}Mount list:$yl\n$mountedDev$ec\n"
			except "Device $diskDev is in use and cannot be tested, unmount it first"
		fi
	fi
}

calculateChecksum() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local file
	privateVarAssign "${FUNCNAME[0]}" "file" "$1"
	checkPkgExist md5sum
	if [ -e "$file" ]; then
		md5sum "$file" |awk '{print $1}'
	else
		except "File $filePath does not exist"
	fi
}

createRandomFile() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local filePath mbCount timeoutN cmdL
	privateVarAssign "${FUNCNAME[0]}" "filePath" "$1"
	privateNumAssign "mbCount" "$2"

	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi
	cmdL='dd if=/dev/urandom of="'"$filePath"'" bs=1M count='"$mbCount"' status=none'
	execWithTimeout $timeoutN "$cmdL"
	if [ $? -ne 0 ]; then except "Failed to create random file"; fi
	if [ ! -e "$filePath" ]; then
		except "Random file $filePath does not exist"
	fi
}

backupBlock() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount timeoutN cmdL
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateVarAssign "${FUNCNAME[0]}" "backupFile" "$4"
	privateNumAssign "mbCount" "$5"

	if [ -e "$devPath" ]; then
		rm -f "$backupFile" &>/dev/null
		if [ ! -e "$backupFile" ]; then
			echo -ne "\tBacking up block from region ${startAddr}-${endAddr}MB.."
			if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi
			cmdL='dd if="'"$devPath"'" skip="'"$startAddr"'" bs=1M count='"$mbCount"' of="'"$backupFile"'" status=none'
			isDefined ddVerbose && echo -n "dumping->"
			execWithTimeout $timeoutN "$cmdL"
			if [ $? -ne 0 ]; then except "Backing up of the block failed"; fi
			isDefined ddVerbose && echo "dumped." || echo
		else
			except "Backup file: $backupFile was not removed"
		fi
	else
		except "Device $devPath does not exist"
	fi
}

writeZeros() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount timeoutN
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateNumAssign "mbCount" "$4"

	if [ -e "$devPath" ]; then
		echo -ne "\tWriting zeros to block from region ${startAddr}-${endAddr}MB.."
		if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi
		cmdL='dd if=/dev/zero of="'"$devPath"'" seek="'"$startAddr"'" bs=1M count='"$mbCount"' conv=notrunc status=none'
		isDefined ddVerbose && echo -n "writing->"
		execWithTimeout $timeoutN "$cmdL"
		if [ $? -ne 0 ]; then except "Zero write to the region failed"; fi
		isDefined ddVerbose && echo "written." || echo
	else
		except "Device $devPath does not exist"
	fi
}

verifyZeros() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount byteCount cmdL timeoutN compareFilePath dumpByteSize cmpRes
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateNumAssign "mbCount" "$4"
	privateNumAssign "byteCount" "$(($mbCount*1048576))"
	compareFilePath="/tmp/$(xxd -u -l 4 -p /dev/urandom).dump"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" ]; then
		echo -ne "\tVerifying zeros in block from region ${startAddr}-${endAddr}MB.."
		if [ ! -e "$compareFilePath" ]; then
			cmdL='dd if="'"$devPath"'" of="'"$compareFilePath"'" skip="'"$startAddr"'" bs=1M count='"$mbCount"' status=none'
			isDefined ddVerbose && echo -n "dumping->"
			execWithTimeout $timeoutN "$cmdL"
			if [ $? -ne 0 ]; then except "Dump of the region failed"; fi
			isDefined ddVerbose && echo -n "dumped.."
			if [ -e "$compareFilePath" ]; then
				privateNumAssign dumpByteSize $(du -b "$compareFilePath" |cut -d/ -f1 |tr -cd '[:digit:]')
				if [ $dumpByteSize -eq $byteCount ]; then
					cmdL='cmp -n '"$byteCount"' /dev/zero "'"$compareFilePath"'" &>/dev/null'
					isDefined ddVerbose && echo -n "comparing->"
					execWithTimeout $timeoutN "$cmdL"; cmpRes=$?
					isDefined ddVerbose && echo "compared." || echo
					if [ $cmpRes -eq 0 ]; then
						echo -e "\t${gr}Block verified as zeros$ec"
					else
						except "Block verification failed"
					fi
					
				else
					except "Dump size does not match, dump: $dumpByteSize, target count: $byteCount"
				fi
			else
				except "Dump failed"
			fi
		else
			except "Temporary compare file already exist"
		fi
	else
		except "Device $devPath does not exist"
	fi

	rm -f "$compareFilePath" &>/dev/null
}

writeRandomData() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount byteCount timeoutN cmdL
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateVarAssign "${FUNCNAME[0]}" "inputFile" "$4"
	privateNumAssign "mbCount" "$5"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" -a -e "$inputFile" ]; then
		echo -ne "\tWriting random data to block from region ${startAddr}-${endAddr}MB.."
		cmdL='dd if="'"$inputFile"'" of="'"$devPath"'" seek='"$startAddr"' bs=1M count='"$mbCount"' conv=notrunc status=none'
		isDefined ddVerbose && echo -n "writing->"
		execWithTimeout $timeoutN "$cmdL"
		if [ $? -ne 0 ]; then except "Writing to the region failed"; fi
		isDefined ddVerbose && echo "written." || echo
	else
		except "Device $devPath or file path $inputFile does not exist"
	fi
}

function dumpAndCalculateChecksum () {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount resRet checksum timeoutN cmdL dumpByteSize byteCount dumpPath
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateNumAssign "mbCount" "$4"
	# The prompts are displayed using file descriptor 3 (>&3), 
	# and the actual results of the calculation are redirected to file descriptor 4 (>&4). 
	# By using >&3- in the subshell command grouping, 
	# we close file descriptor 3 for the calculation output, ensuring that 
	# only the prompts are displayed there. The resultsOfCalc variable captures 
	# only the contents of file descriptor 4, which contains the calculation results.
	let resRet=1
	privateNumAssign "byteCount" "$(($mbCount*1048576))"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" ]; then
		dumpPath="/tmp/dump_${startAddr}-${endAddr}MB.bin"; rm -f "$dumpPath" &>/dev/null
		echo -ne "\tDumping block from region ${startAddr}-${endAddr}MB.." >&3
		if [ ! -e "$dumpPath" ]; then
			cmdL='dd if="'"$devPath"'" of="'"$dumpPath"'" skip='"$startAddr"' bs=1M count='"$mbCount"' status=none'
			isDefined ddVerbose && echo -n "dumping->" >&3
			execWithTimeout $timeoutN "$cmdL"
			if [ $? -ne 0 ]; then except "Dump of the region failed"; fi
			isDefined ddVerbose && echo -n "dumped.." >&3
			if [ -e "$dumpPath" ]; then
				privateNumAssign dumpByteSize $(du -b "$dumpPath" |cut -d/ -f1 |tr -cd '[:digit:]')
				if [ $dumpByteSize -eq $byteCount ]; then
					isDefined ddVerbose && echo -n "chksum->" >&3
					local checksum=$(calculateChecksum "$dumpPath")
					isDefined ddVerbose && echo "done." >&3 || echo >&3
					if [ ! -z "$checksum" ]; then
						echo -e "\tChecksum of dumped block: ${checksum}" >&3
						echo -n "${checksum}" >&4
						let resRet=0
					else
						except "Checksum of dumped block is empty!"
					fi
					rm -f "$dumpPath" &>/dev/null
				else
					except "Dump size does not match, dump: $dumpByteSize, target count: $byteCount"
				fi
			else
				except "Dump failed"
			fi
		else
			except "Dump file: $dumpPath already exist"
		fi
	else
		except "Device $devPath does not exist"
	fi
	return $resRet
}

restoreBlock() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local devPath startAddr endAddr mbCount timeoutN
	privateVarAssign "${FUNCNAME[0]}" "devPath" "$1"
	privateVarAssign "${FUNCNAME[0]}" "startAddr" "$2"
	privateVarAssign "${FUNCNAME[0]}" "endAddr" "$3"
	privateVarAssign "${FUNCNAME[0]}" "backupFile" "$4"
	privateNumAssign "mbCount" "$5"
	if isDefined ddTimeout; then let timeoutN=$ddTimeout; else let timeoutN=240; fi

	if [ -e "$devPath" -a -e "$backupFile" ]; then
		echo -ne "\tRestoring backed up block to region ${startAddr}-${endAddr}MB from file.."
		cmdL='dd if="'"$backupFile"'" of="'"$devPath"'" seek='"$startAddr"' bs=1M count='"$mbCount"' conv=notrunc status=none'
		isDefined ddVerbose && echo -n "writing->"
		execWithTimeout $timeoutN "$cmdL"
		if [ $? -ne 0 ]; then except "Writing to the region failed"; fi
		isDefined ddVerbose && echo "written." || echo
		echo -ne "\tRemoving backup file.."
		isDefined ddVerbose && echo -n "removing->"
		rm -f "$backupFile"
		if [ -e "$backupFile" ]; then 
			except "Backup file $backupFile cant be removed"
		else
			isDefined ddVerbose && echo "removed." || echo
		fi
	else
		except "Device $devPath or backup file path $backupFile does not exist"
	fi
}

if (return 0 2>/dev/null) ; then
	echo -e '  Loaded module: \tI/O lib for testing (support: arturd@silicom.co.il)'
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
	if ! [ "$(type -t echoFail 2>&1)" == "function" ]; then 
		source /root/multiCard/textLib.sh
		if [ $? -ne 0 ]; then 
			echo -e "\t\e[0;31mTEXT LIBRARY IS NOT LOADED! UNABLE TO PROCEED\n\e[m"
			exit 1
		fi
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
	source "${0} $@"
fi