#!/bin/sh

#DBNAME=SIMDB28C
DBNAME=$1
CEPEXEC=/cs/sn/cr/cepexec
DBFILE=$2

DBFILE=`readlink -f $DBFILE`
#echo DBFILE is $DBFILE 

CMD="LOAD:DB=$DBNAME,FILE=$DBFILE,UCL"
eval $CEPEXEC LOAD_DB \'LOAD:DB=$DBNAME,FILE=\"$DBFILE\",UCL\'
if [ $? = 0 ]
then
	echo "load $DBNAME success"
else
	echo "load $DBNAME fail"
fi
#$CEPEXEC LOAD_DB $CMD

