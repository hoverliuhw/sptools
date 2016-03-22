#!/bin/sh
########################################################
# This script is to simulate a long diameter session
# which send ccr every 15min(can be configured)
# and backup rtdb, 
# decode ama will be added in the future enhancement
#
#	Liu Hongwei
#	2015/11/14
########################################################

function showinfo {
	db=$1
	dbfilter=$2
	sub_key=$3

	timesuffix=`date "+%Y%m%d%H%M%S"`
	tmpfile=/tmp/tmp.db
	destfile=/tmp/$db.data.$timesuffix
	/sn/cr/cepexec BACKUP_DB "BACKUP:DB=$db,DEST=\"$tmpfile\""
	sed -n "1,2p" $tmpfile > $destfile
	sed -n "/$sub_key/p" $tmpfile >> $destfile

	gawk -f $dbawk $dbfilter $destfile
#	rm -rf $tmpfile
}

conf="/u/ainet/hongwehl/bin/ps.conf"

usu_form_name=SPA_DIAMCL29B_12
usu_frm="/tmp/usage.frm"
dbawk=/u/ainet/hongwehl/bin/ckdb.awk

msisdn=`grep MSISDN $conf | awk -F= '{print $2}'`
groupid=`grep GROUP_ID $conf | awk -F= '{print $2}'`

ccri

while [ i -lt 10 ]
do
	usu_key=`grep USU_U_KEY $conf | awk -F= '{print $2}'`
	usu_val=`grep USU_U_VAL $conf | awk -F= '{print $2}'`
	echo "FORM=$usu_form_name&CHG,index="12",CC_Total_Octets=\"$usu_val\",CHG!" >$usu_frm
	/sn/cr/cepexec RCV_TEXT "RCV:TEXT,SPA" < $usu_frm
	ccru
	echo "usu: $usu_val"
	sleep 5

	# print subscriber
	db=SIMDB28C
	dbconf=/u/ainet/hongwehl/bin/simdb.conf
	showinfo $db $dbconf $msisdn
	
	db=CTRTDB28C
	dbconf=/u/ainet/hongwehl/bin/ctrtdb.conf
	showinfo $db $dbconf $msisdn

	# print group
	db=AIRTDB28C
	dbconf=/u/ainet/hongwehl/bin/airtdb.conf
	showinfo $db $dbconf $msisdn
	
	db=CTRTDB28C
	dbconf=/u/ainet/hongwehl/bin/ctrtdb.conf
	showinfo $db $dbconf $groupid

	interval=`grep CCR_INTERVAL $conf | awk -F= '{print $2}'`
	sleep $interval
done

ccrt
