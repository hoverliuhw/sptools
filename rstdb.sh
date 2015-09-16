#!/bin/sh

# list=dblist
CEPEXEC=/sn/cr/cepexec

dblist=`psql -Uscncraft -At -c "select * from rtdb_app where db_name not in ('NDB', 'BDB', 'HLRV', 'HLRNV')"`
#for db in `psql -Uscncraft -At -c "select * from rtdb_app where db_name not in ('NDB', 'BDB', 'HLRV', 'HLRNV')"`
for db in $dblist
do
        echo "rmv db=$db"
        $CEPEXEC RMV_DB "RMV:DB=$db" &
done
isfinish=`ps -ef | grep "CEPEXEC NULL RMV : DB" | grep -v grep`
while [ ! -z "$isfinish" ]
do
	sleep 1
	isfinish=`ps -ef | grep "CEPEXEC NULL RMV : DB" | grep -v grep`
done

for db in $dblist
do
        echo "rst db=$db"
        $CEPEXEC RST_DB "RST:DB=$db" &
done
isfinish=`ps -ef | grep "CEPEXEC NULL RST : DB" | grep -v grep`
while [ ! -z "$isfinish" ]
do
        sleep 1
        isfinish=`ps -ef | grep "CEPEXEC NULL RST : DB" | grep -v grep`
done

echo "rst all rtdb done!"
