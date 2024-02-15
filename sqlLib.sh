#!/bin/bash

sqlUpdateJobStatus() {
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		local sqlFunc="updateJobStatus"
		local cmdRes cmdResFilter newStatus jobHexID
		privateVarAssign "${FUNCNAME[0]}" "jobHexID" "$1"
		privateVarAssign "${FUNCNAME[0]}" "newStatus" "$2"

		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT $sqlFunc('$jobHexID', '$newStatus');\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on')"
		dmsg echo -e "Full res:\n$cmdRes"
		echo -n "$cmdResFilter"
	else
		echo -n -99
	fi
}

sqlUpdateJobCounters() {
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		local sqlFunc="updateJobCounters"
		local totalRuns currentRun runsLeft passedRuns failedRuns jobHexID
		local cmdRes cmdResFilter
		dmsg inform "args: $*"
		privateVarAssign "${FUNCNAME[0]}" "jobHexID" "$1"
		privateNumAssign "totalRuns" "$2"
		privateNumAssign "currentRun" "$3"
		privateNumAssign "runsLeft" "$4"
		privateNumAssign "passedRuns" "$5"
		privateNumAssign "failedRuns" "$6"
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT $sqlFunc('$jobHexID', $totalRuns, $currentRun, $runsLeft, $passedRuns, $failedRuns);\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on')"
		dmsg echo -e "Full res:\n$cmdRes"
		echo -n "$cmdResFilter"
	else
		echo -n -99
	fi
}

sqlCreateJob() {
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		local sqlFunc="createJob"
		local TN PN MAC srvHexID totalRuns slotNum jobHexID testName
		local cmdRes cmdResFilter
		dmsg inform "args: $*"
		privateVarAssign "${FUNCNAME[0]}" "jobHexID" "$1"
		privateVarAssign "${FUNCNAME[0]}" "TN" "$2"
		privateVarAssign "${FUNCNAME[0]}" "PN" "$3"
		privateVarAssign "${FUNCNAME[0]}" "MAC" "$4"
		privateVarAssign "${FUNCNAME[0]}" "srvHexID" "$5"
		privateNumAssign "slotNum" "$6"
		privateNumAssign "totalRuns" "$7"
		privateVarAssign "${FUNCNAME[0]}" "testName" "$8"
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT $sqlFunc('$jobHexID', '$TN', '$PN', '$MAC', '$srvHexID', $slotNum, $totalRuns, '$testName');\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on')"
		dmsg echo -e "Full res:\n$cmdRes"
		echo -n "$cmdResFilter"
	else
		echo -n -99
	fi
}

sqlGetPrintDataCSV() {
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		local TN PN MAC srvHexID totalRuns slotNum jobHexID
		local cmdRes cmdResFilter
		dmsg inform "args: $*"
		dmsg inform "ENV vars: User:${SQL_USER} Pass:${SQL_PASSWORD} DB:${DB_NAME}"
		privateVarAssign "${FUNCNAME[0]}" "jobHexID" "$1"
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT * from JobPrintView where (\\\`JobHexID\\\` = \\\"$jobHexID\\\") ;\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on')"
		cmdError="$(grep ERROR<<<"$cmdResFilter")"
		dmsg echo -e "Full res:\n$cmdRes"
		if isDefined cmdError; then 
			echo 'Failed,to,execute,request,error_found'
		else
			echo 'JobID,PN,TN,FailedRuns,RunsLeft,TotalRuns,TestName,DBID,MAC,MBName'
			shopt -s lastpipe
			echo "$cmdResFilter" | while IFS= read -r row ; do 
				let fCnt=0
				for field in $row; do
					if [ $fCnt -eq 0 ]; then
						echo -n "$field"
					else
						echo -n ",$field"
					fi
					let fCnt++
				done
				echo -ne "\n"
			done 
		fi
	else
		echo 'Failed,to,get,sql,creds'
	fi
}

printSqlJob() {
	dmsg dbgWarn "### $(caller): $(printCallstack)"
	local hexID  TN PN MAC srvHexID totalRuns slotNum jobHexID i printReady printRes cardSpec printFileName viewFunc
	local cmdRes cmdResFilter varNameArr testCodeRes TestName DBID MAC MB TotalRuns RunsLeft FailedRuns TN PN JobID printValues
	privateVarAssign "${FUNCNAME[0]}" "hexID" "$1"
	privateVarAssign "${FUNCNAME[0]}" "cardSpec" "$2"
	if [ -z "$3" ] ; then viewFunc="JobPrintView"; else viewFunc="$3"; fi
	varNameArr=("JobID" "PN" "TN" "FailedRuns" "RunsLeft" "TotalRuns" "TestName" "DBID" "MAC" "MB")
	
	let printReady=0
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		dmsg inform "ENV vars: User:${SQL_USER} Pass:${SQL_PASSWORD} DB:${DB_NAME}"
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT * from $viewFunc where (\\\`JobHexID\\\` = \\\"$hexID\\\") ;\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on' |tail -n1)" #taking only last line
		cmdError="$(grep ERROR<<<"$cmdRes")"
		dmsg echo -e "Full res:\n$cmdRes"
		if isDefined cmdError; then 
			except "Failed,to,execute,request,error_found\n$cmdRes"
		else
			shopt -s lastpipe
			IFS=$'\t' read -ra printValues <<< "$cmdResFilter"
			for ((i=0; i<${#varNameArr[@]}; i++)); do
				privateVarAssign "${FUNCNAME[0]}" "${varNameArr[$i]}" "${printValues[$i]}"
				dmsg inform "${varNameArr[$i]}=${printValues[$i]}"
			done
		fi
	else
		except 'Failed,to,get,sql,creds'
	fi

	printFileName="printFile_${JobID}_$(xxd -u -l 2 -p /dev/urandom)"
	dmsg inform "TestName=$TestName"
	testCodeRes=$(getTestCode $TestName)

	if isDefined testCodeRes; then
		if [ $FailedRuns -eq 0 ]; then
			echo "  _____________________________" >/tmp/$printFileName
			echo "  _________________$(date +'%d/%m/%Y')__" >>/tmp/$printFileName
			echo "  " >>/tmp/$printFileName
			echo "  MB:    $MB" >>/tmp/$printFileName
			echo "  PN:    $PN" >>/tmp/$printFileName
			echo "  TN:    $TN" >>/tmp/$printFileName
			echo "  MAC:   $MAC" >>/tmp/$printFileName
			echo "  " >>/tmp/$printFileName
			echo "  =============================" >>/tmp/$printFileName
			echo "  Total Runs:  $TotalRuns" >>/tmp/$printFileName
			echo "  Failed Runs: $FailedRuns" >>/tmp/$printFileName
			echo "  =============================" >>/tmp/$printFileName

			case $cardSpec in 
				"2BGA-4PORT-NOPLX")
					if [ "$testCodeRes" = "POK" ]; then 
						echo "  BGA 1:    $testCodeRes" >>/tmp/$printFileName
						echo "  BGA 2:    $testCodeRes" >>/tmp/$printFileName
					else
						echo "  BGA 1:    POK" >>/tmp/$printFileName
						echo "  BGA 2:    POK" >>/tmp/$printFileName
					fi
					if [ "$testCodeRes" = "POK" ]; then 
						echo "  PORT 1:   N/T" >>/tmp/$printFileName
						echo "  PORT 2:   N/T" >>/tmp/$printFileName
						echo "  PORT 3:   N/T" >>/tmp/$printFileName
						echo "  PORT 4:   N/T" >>/tmp/$printFileName
					else
						echo "  PORT 1:   $testCodeRes" >>/tmp/$printFileName
						echo "  PORT 2:   $testCodeRes" >>/tmp/$printFileName
						echo "  PORT 3:   $testCodeRes" >>/tmp/$printFileName
						echo "  PORT 4:   $testCodeRes" >>/tmp/$printFileName
					fi
				;;
				"2BGA-4PORT-wPLX")
					if [ "$testCodeRes" = "POK" ]; then 
						echo "  PLX Phys:        $testCodeRes" >>/tmp/$printFileName
						echo "  PLX Upstream:    $testCodeRes" >>/tmp/$printFileName
						echo "  PLX Downstr 1:   $testCodeRes" >>/tmp/$printFileName
						echo "  PLX Downstr 2:   $testCodeRes" >>/tmp/$printFileName
						echo "  PLX Downstr 3:   $testCodeRes" >>/tmp/$printFileName
						echo "  BGA 1:    $testCodeRes" >>/tmp/$printFileName
						echo "  BGA 2:    $testCodeRes" >>/tmp/$printFileName
					else
						echo "  PLX Phys:        POK" >>/tmp/$printFileName
						echo "  PLX Upstream:    POK" >>/tmp/$printFileName
						echo "  PLX Downstr 1:   POK" >>/tmp/$printFileName
						echo "  PLX Downstr 2:   POK" >>/tmp/$printFileName
						echo "  PLX Downstr 3:   POK" >>/tmp/$printFileName
						echo "  BGA 1:    POK" >>/tmp/$printFileName
						echo "  BGA 2:    POK" >>/tmp/$printFileName
					fi
					if [ "$testCodeRes" = "POK" ]; then 
						echo "  PORT 1:   N/T" >>/tmp/$printFileName
						echo "  PORT 2:   N/T" >>/tmp/$printFileName
						echo "  PORT 3:   N/T" >>/tmp/$printFileName
						echo "  PORT 4:   N/T" >>/tmp/$printFileName
					else
						echo "  PORT 1:   $testCodeRes" >>/tmp/$printFileName
						echo "  PORT 2:   $testCodeRes" >>/tmp/$printFileName
						echo "  PORT 3:   $testCodeRes" >>/tmp/$printFileName
						echo "  PORT 4:   $testCodeRes" >>/tmp/$printFileName
					fi
				;;
				"UNKNOWN") critWarn "Unknown cardspec, unable to print label";;
				*) except "unexpected cardSpec provided: $cardSpec"
			esac

			echo "  =============================" >>/tmp/$printFileName
			echo "  " >>/tmp/printFile
			echo "  JobID:    $JobID" | sed 's/.\{29\}/&\n            /g' >>/tmp/$printFileName
			echo "  DBID:     $DBID" | sed 's/.\{29\}/&\n            /g' >>/tmp/$printFileName
			echo "  _____________________________" >>/tmp/$printFileName
			
			dmsg inform "$(cat /tmp/$printFileName)"

			if [ -e "/tmp/$printFileName" ]; then
				if ! isDefined printDryRun; then
					printRes="$(lp -d "BI_Printer" -o media=6x5.5in -o page-border=single  -o fit-to-page -o position=top-left /tmp/$printFileName 2>&1)"
					dmsg inform "$printRes"
				fi
				rm -f /tmp/$printFileName
			else
				except "print file: /tmp/$printFileName does not exist"
			fi
		else
			except "unable to print failed job: $hexID"
		fi
	else
		except "unable to get testCode for job: $hexID"
	fi
}

sqlAddRecord() {
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		local sqlFunc="addLogRecord"
		local hexID totalRuns slotNum recordValue recVal
		local cmdRes cmdResFilter
		dmsg inform "args: $*"
		privateVarAssign "${FUNCNAME[0]}" "hexID" "$1"
		privateVarAssign "${FUNCNAME[0]}" "recordValue" "$2"
		privateVarAssign "${FUNCNAME[0]}" "recordValue" $(cut -c3- <<< $recordValue |cut -f1 -d=)
		case "$recordValue" in
			"ssh-startup-failed") recVal=1 ;;
			"ssh-power-down-failed") recVal=2 ;;
			"ipmi-connection-failed") recVal=3 ;;
			"ipmi-power-up-failed") recVal=4 ;;
			"ipmi-power-down-failed") recVal=5 ;;
			"ssh-connection-failed") recVal=6 ;;
			"ssh-connection-ok") recVal=7 ;;
			"ssh-startup-ok") recVal=8 ;;
			"cycle-started") recVal=9 ;;
			"cycle-ended") recVal=10 ;;
			"run-started") recVal=11 ;;
			"run-ended") recVal=12 ;;
			"run-passed") recVal=13 ;;
			"run-failed") recVal=14 ;;
			"sheet-sync-started") recVal=15 ;;
			"sheet-sync-ended") recVal=16 ;;
			"onedrive-sync-started") recVal=17 ;;
			"onedrive-sync-ended") recVal=18 ;;
			"onedrive-sync-passed") recVal=19 ;;
			"onedrive-sync-failed") recVal=20 ;;
			"onedrive-share-failed") recVal=21 ;;
			"onedrive-share-passed") recVal=22 ;;
			"server-up") recVal=23 ;;
			"db-locked") recVal=24 ;;
			"db-unlocked") recVal=25 ;;
			"reboot-unsuccessfull") recVal=26 ;;
			*) except "unknown record value"
		esac
		dmsg echo "CMD> mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT $sqlFunc('$hexID', $recVal);\""
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT $sqlFunc('$hexID', $recVal);\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on')"
		dmsg echo -e "Full res:\n$cmdRes"
		echo -n "$cmdResFilter"
	else
		echo -n -99
	fi
}

sqlExportViewCSV() {
	checkSqlCreds 1>/dev/null
	if [ $? -eq 0 ]; then
		local cmdRes cmdResFilter viewName line
		dmsg inform "args: $*"
		dmsg inform "ENV vars: User:${SQL_USER} Pass:${SQL_PASSWORD} DB:${DB_NAME}"
		privateVarAssign "${FUNCNAME[0]}" "viewName" "$1"
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT * from $viewName;\"" 2>&1)"
		cmdResFilter="$(echo "$cmdRes" |grep -v 'Using a password on')"
		dmsg echo -e "Full res:\n$cmdRes"
		shopt -s lastpipe
		echo "$cmdResFilter" | while IFS= read -r row ; do 
			let fCnt=0
			for field in $row; do
				if [ $fCnt -eq 0 ]; then
					echo -n "$field"
				else
					echo -n ";$field"
				fi
				let fCnt++
			done
			echo -ne "\n"
		done 
	else
		echo 'Failed;to;get;sql;creds'
	fi
}

function checkSqlCreds() {
	local credOk
	let credOk=0
	if [ -z "${DB_NAME}" -o -z "${SQL_USER}" -o -z "${SQL_PASSWORD}" ]; then
		dmsg echo -e "\tSQL credentials are undefined, connecting to SyncServer"
		if [ -z "$syncSrvIp" ]; then dmsg critWarn "Sync server IP is not defined, fallback to default"; syncSrvIp="172.30.7.17"; fi
		local smbShare="//$syncSrvIp/smbLogs/.sql/"
		local localPath="/root/sql_tmp"

		if [ ! -e "${localPath}/sqlCreds.sh" ]; then
			if [ -e "/home/smbLogs/.sql/sqlCreds.sh" ]; then
				dmsg echo -e "\tUsing local file."
				localPath="/home/smbLogs/.sql"
			else
				if [ ! -d "${localPath}" ]; then
					sudo mkdir -p "${localPath}"
				fi
				umount "${localPath}" &>/dev/null
				mount.cifs "${smbShare}" "${localPath}" -o "user=smbLogs,password=smbLogs" &>/dev/null
				let credOk+=$?
			fi
		fi
		if [ $credOk -eq 0 ]; then
			if [ -e "${localPath}/sqlCreds.sh" ]; then
				source "${localPath}/sqlCreds.sh"
				if [ -z "${DB_NAME}" -o -z "${SQL_USER}" -o -z "${SQL_PASSWORD}" ]; then
					critWarn "SQL credentials could not be defined!"; let credOk++
				else
					dmsg echo -e "\tSQL creds are loaded."
				fi
			else
				critWarn "SQL credentials exporter script is not found by path: ${localPath}/sqlCreds.sh"; let credOk++
			fi
		else
			dmsg inform "mount failed."; let credOk++
		fi
	else
		dmsg echo -e "\tSQL credentials are defined."
	fi
	return $credOk
}


if (return 0 2>/dev/null) ; then
	let loadStatus=0
	echo -e '  Loaded module: \tSQL access lib for testing (support: arturd@silicom.co.il)'
	source /root/multiCard/arturLib.sh; let loadStatus+=$?
	if [[ ! "$loadStatus" = "0" ]]; then 
		echo -e "\t\e[0;31mLIBRARIES ARE NOT LOADED! UNABLE TO PROCEED\n\e[m"
		exit 1
	fi
else	
	critWarn "This file is only a library and ment to be source'd instead"
fi