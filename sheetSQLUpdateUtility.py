import sys,gspread,os,time

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
wks = sh.worksheet("sqlImport")
print('Sending global list:')
print(globalList)
wks.clear()
wks.insert_rows(globalList,row=1,value_input_option='RAW', inherit_from_before=False)

for fileName in sys.argv[1:]:
	print('Removing file: '+fileName)
	os.remove(fileName)