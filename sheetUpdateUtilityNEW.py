import sys,gspread,os,time

def next_available_row(worksheet):
	str_list = list(filter(None, worksheet.col_values(1)))
	return str(len(str_list)+1)

def next_available_row_num(worksheet):
	last_row_str = worksheet.acell('B2').value
	return (int(last_row_str)+1)

def increase_queue_count(worksheet):
	print('Increasing total queue count')
	currCnt = int(worksheet.acell('F2').value)
	worksheet.update_acell("F2",str(currCnt+1))
	return (currCnt+1)

def get_queue_count(worksheet):
	print('Getting total queue count')
	currCnt = int(worksheet.acell('F2').value)
	return (currCnt)

def increase_next_queue_count(worksheet):
	print('Increasing queue count')
	currCnt = int(worksheet.acell('G2').value)
	worksheet.update_acell("G2",str(currCnt+1))
	return (currCnt+1)

def get_next_queue_count(worksheet):
	print('Getting next in queue count')
	currCnt = int(worksheet.acell('G2').value)
	return (currCnt)

def reserve_rows(worksheet,listRes):
	print('Reserving rows for the uploaded queue')
	reserveCount = len(listRes)
	currCnt = int(worksheet.acell('B2').value)
	newReserve = currCnt+reserveCount
	print('Current reserve: '+str(currCnt)+' list count: '+str(reserveCount)+' new reserved until: '+str(newReserve))
	worksheet.update_acell("B2",str(newReserve))

globalList = []
for fileName in sys.argv[1:]:
	print ("File passed:"+fileName)
	with open(fileName) as file:
		for line in file:
			print('Processing file: '+str(fileName))
			curLine = str(line.rstrip())
			mixTypeList = []
			for item in curLine.split(';'):
				if item.isdigit() :
					mixTypeList.append(int(item))
				else :
					mixTypeList.append(str(item))		
			print('Appending to global list:')
			print(mixTypeList)
			globalList.append(mixTypeList)


print('Connecting to service account')
gc = gspread.service_account()
print('Opening sheet')
sh = gc.open("logImporter")
print('Setting worksheet')
wks = sh.worksheet("importSheet")
swks = sh.worksheet("serviceSheet")

print('Checking for active import in background')
if swks.acell('E2').value == 'Yes' :
	print('Import is active')
	importStatus=True
else :
	print('Import is inactive')
	importStatus=False
	
queueID=increase_queue_count(swks)

while(True):
	if not importStatus :
		print('Setting lock for update')
		swks.update("E2", [['Yes']])
	
	nextInQueue=get_next_queue_count(swks)
	if queueID == nextInQueue :
		

		print('Looking up for next row')
		next_row = next_available_row_num(swks)
		reserve_rows(swks,globalList)
		print('Next free space: '+str(next_row))
		print('Sending global list:')
		print(globalList)
		wks.insert_rows(globalList,row=next_row,value_input_option='RAW', inherit_from_before=False)

		nextInQueue=get_next_queue_count(swks)
		if queueID == nextInQueue :
			print('Unsetting lock for update')
			swks.update_acell("E2",'')
			
		increase_next_queue_count(swks)
		break
	else :
		print('Waiting in line.. Current queue ID processing: '+str(nextInQueue)+' My ID: '+str(queueID))
		time.sleep(10)

for fileName in sys.argv[1:]:
	print('Removing file: '+fileName)
	os.remove(fileName)