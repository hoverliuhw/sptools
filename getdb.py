#!/usr/bin/python

# this script is to get RTDB data from log, then load it to RTDB
#
# usage: getdb.py  <logfile> <EPAY src file> <rtdb_type digit>
# supported rtdb_type:
#		0 - SIM_RTDB
#	 	1 - AI_RTDB
#		2 - Counter_RTDB
#		3 - SGL_RTDB
#	e.g. getdb.py debuglog EPAY29H.src 0 
#
# Author: Liu Hongwei
#	 hong_wei.hl.liu@alcatel-lucent.com
#	 2016/03/07	created
#

import sys
import os

def usage():
	print('''
	usage: getdb.py  <logfile> <EPAY src file> <rtdb_type digit>
	supported rtdb_type:
		0 - SIM_RTDB
	 	1 - AI_RTDB
		2 - Counter_RTDB
		3 - SGL_RTDB
		4 - SY_RTDB
	e.g. getdb.py debuglog EPAY29H.src 0 
	''')
	sys.exit(1)

# generate a map rcv and value
def get_data_hash(single_data_str):
	global src_rcv
	rcv_value = dict()
	for line in single_data_str.split(','):
		index = line.find('=')
		src_name = line[0:index]
		rcv_name = src_rcv[src_name]
		value = line[index + 1:]
		if value == 'true':
			value = 'Y'
		if value == 'false':
			value = 'N'
		rcv_value[rcv_name] = value
	
	return rcv_value

def gen_dbrec(rcv_value):
	global rcv_type
	global rcvfields

	data_str = "'I'"
	for rcv_name in rcvfields:
		field_type = rcv_type[rcv_name]
		value = rcv_value[rcv_name]
		if field_type == 'hex_value' and value.startswith('0x'):
			value = value[2:]
		if field_type in field_type_quote:
			data_str = data_str + " '" + value + "'"
		else:
			data_str = data_str + " " + value

	data_str = data_str + " |"
	return data_str

def write_datafile(datafile, data_str):
	if os.path.exists(datafile) == False:
		return False
	dhandler = open(datafile, 'a')
	dhandler.write(data_str + '\n')
	dhandler.close()
	return True

if len(sys.argv) < 4:
	usage()

rtdb_type_list = ('SIM_RTDB', 'AI_RTDB', 'Counter_RTDB', 'SGL_RTDB', 'SY_RTDB')

logfile = sys.argv[1]
srcfile = sys.argv[2]

index = -1
if sys.argv[3].isdigit:
	index = int(sys.argv[3])
if sys.argv[3].isdigit() == False or index < 0 or index >= len(rtdb_type_list):
	usage()

rtdb_type = rtdb_type_list[index]

field_type_quote = ('Billing_Day_Type',
	'PTP_Status_Enum', 
	'Subs_Scr_Ind_Enum',
	'UC_Func_Status_Enum',
	'flag',
	'hex_value', 
	'long_counter',
	'string')
field_type_no_quote = ('Active_Recharge_Event_Type',
	'Audit_Recharge_Day_Type',
	'Call_Count_Type',
	'Custom_NSelection_Type',
	'Inst_Num_Type',
	'Last_Recharge_Event_Type',
	'Max_Sec_Neg_Bal_Type',
	'Recharge_Count_Type',
	'SMSC_Count_Type',
	'SMS_Cont_Bought_Type',
	'Tariff_Selec_Count_Type',
	'Time_Count_Type',
	'Unit_Count_Type',
	'Wrong_PIN_Type',
	'counter')

# get db name from EPAY src
db_name_line = ''
db_def = ''
db_read = ''

if rtdb_type == 'SIM_RTDB':
	db_name_line = 'set Glb_SIM_Table = "SIMDB'
elif rtdb_type == 'AI_RTDB':
	db_name_line = 'set GLB_AI_RTDB_Table_Name  = "AIRTDB'
elif rtdb_type == 'Counter_RTDB':
	db_name_line = 'set GLB_Counter_RTDB_Table_Name  = "CTRTDB'
elif rtdb_type == 'SGL_RTDB':
	db_name_line = 'set GLB_SGL_RTDB_Table_Name '
elif rtdb_type == 'SY_RTDB':
	db_name_line = 'set GLB_SY_RTDB_Table_Name '
else:
	print(rtdb_type + ' does not support')
	sys.exit(1)

db_def = rtdb_type + '    table record {'
db_read = rtdb_type + '!read_completed('

srcname = os.path.basename(srcfile)
if srcname.startswith('EPPSA'):
	if rtdb_type == 'SIM_RTDB':
		db_read = rtdb_type + '!get_next_completed('
	elif rtdb_type == 'AI_RTDB':
# note: in eppsa log, sometimes use get_next_completed, sometimes read_completed
		db_read = rtdb_type + '!get_next_completed('
		db_name_line = 'set Glb_AI_Table = "AIRTDB'
	else:
		pass

src_handler = open(srcfile, 'r')

for line in src_handler.readlines():
	line = line.strip()
	if line.startswith(db_name_line):
		break
src_handler.close()

tmp_list = line.split('"')
db_name = tmp_list[1]
datafile = db_name + '.data'

# get field list in rcv menu
rcvfields = []
rcvfile = '/cs/sn/rdb/' + db_name + '.ti'
if os.path.exists(rcvfile) == False:
	print(db_name + ' is not installed on this machine')
	sys.exit(1)

rcv_handler = open(rcvfile, 'r')
rcv_handler.readline() #remove first line

for line in rcv_handler.readlines():
	tmp_list = line.split()
	rcvfields.append(tmp_list[1])

rcv_handler.close()

# get two maps from EPAY src: rcv_type, src_rcv
rcv_type = dict()
src_rcv = dict()
find_flag = False
src_handler = open(srcfile, 'r')

for line in src_handler.readlines():
	if line.find(db_def) >= 0:
		find_flag = True
		continue
	if find_flag == True:
		line = line.strip()
		if not line or line.startswith('#'):
			continue
		if line.endswith('}'):
			break
		tmp_list = line.split()
		src_name = tmp_list[0]
		field_type = tmp_list[1]
		if field_type.startswith('string'):
			field_type = 'string'
		tmp_list = line.split('"')
		rcv_name = tmp_list[1]
		rcv_type[rcv_name] = field_type
		src_rcv[src_name] = rcv_name
		
src_handler.close()

# get data from log
data_str = ''
find_flag = False

log_handler = open(logfile, 'r')

for line in log_handler.readlines():
	if line.find(db_read) >= 0:
		find_flag = True
	if find_flag == True:
		data_str = data_str + line.strip()
		if line.find(')') >= 0:
			find_flag = False

log_handler.close()
if len(data_str) <= 0:
	print(rtdb_type + '!read_complete trace is not found in ' + logfile)
	sys.exit(1)

dataheader = "'20050706085324Z' '00000000000' 1 'This is a tape label' 1$\n"
data_handler = open(datafile, 'w')
data_handler.write(dataheader + "\n")
data_handler.close()

found_keys = []
start = data_str.find(db_read)
while start > 0:
	start = start + len(db_read)
	start = data_str.find('(', start) + 1
	end = data_str.find(')', start)
	single_data_str = data_str[start: end]

	rcv_value = get_data_hash(single_data_str)
	db_key = rcv_value[rcvfields[0]]
	if db_key not in found_keys:
		data_record = gen_dbrec(rcv_value)
		write_datafile(datafile, data_record)
		found_keys.append(db_key)
	
	start = data_str.find(db_read, end)

print(db_name + ' data is stored into ' + datafile)

