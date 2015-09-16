#!/bin/sh

spalist=`psql -Uscncraft -At -c "select span from spm_tbl"`
for spaname in $spalist
do
        echo aborting $spaname
        /cs/sn/cr/cepexec ABORT_SPA "ABT:SPA=$spaname"
        if [ $? != 0 ]
        then
                echo "abort SPA fail!"
        fi
done
