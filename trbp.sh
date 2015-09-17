#!/bin/sh
##############################################
# name: trbp.sh
# usage: trbp.sh <spa name>
# description: a script to apply trace and bp
#	before using, make sure /u/ainet/hongwehl/src/<spaname>.bp is up to date
#
# author: Liu Hongwei
# 	  hong_wei.hl.liu@alcatel-lucent.com
#############################################

if [ $# != 1 ]
then
	echo "Usage: trbp <SPA NAME> "
	exit 1
fi

spaname=$1

isIS=`psql -Uscncraft -At -c "select span from spm_tbl where span='$spaname'"`
if [ -z "$isIS" ]
then
	echo "SPA $spaname is in NOT IS state, please install:proc first! quit "
	exit 1
fi

traceTemplate="/u/ainet/hongwehl/bin/trbp.general"
isAudit=`echo $spaname | grep EPPSA`
if [ ! -z "$isAudit" ]
then
	traceTemplate="/u/ainet/hongwehl/bin/trbp.audit"
fi

trbpfile="/tmp/trbpfile.tmp"
sed "s,SPANAME,$spaname,g" $traceTemplate > $trbpfile
subshl -f $trbpfile
rm $trbpfile
