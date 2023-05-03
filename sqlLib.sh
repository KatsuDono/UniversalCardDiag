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
		local TN PN MAC srvHexID totalRuns slotNum jobHexID
		local cmdRes cmdResFilter
		dmsg inform "args: $*"
		privateVarAssign "${FUNCNAME[0]}" "jobHexID" "$1"
		privateVarAssign "${FUNCNAME[0]}" "TN" "$2"
		privateVarAssign "${FUNCNAME[0]}" "PN" "$3"
		privateVarAssign "${FUNCNAME[0]}" "MAC" "$4"
		privateVarAssign "${FUNCNAME[0]}" "srvHexID" "$5"
		privateNumAssign "slotNum" "$6"
		privateNumAssign "totalRuns" "$7"
		cmdRes="$(eval "mysql -s -s -s -u ${SQL_USER} -p${SQL_PASSWORD} ${DB_NAME} -e \"SELECT $sqlFunc('$jobHexID', '$TN', '$PN', '$MAC', '$srvHexID', $slotNum, $totalRuns);\"" 2>&1)"
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