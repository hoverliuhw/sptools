#!/bin/ksh
# This tl is enhanced teel, it integrates LogCMB, and combines log in background while tailering, 
# So it will shorten combining time after tailer finishes
#	Liu Hongwei
#	2017/06/24

#Information about your workstation
CONF="/u/ainet/hongwehl/bin/CONFIGURE"

for VAR in `cat $CONF | egrep -v "^#|^$"`
do
	eval $VAR
done

TAILER_FINISHED="/tmp/TAILER_FINISHED".$$
COMBINE_FINISHED="/tmp/COMBINE_FINISHED".$$
test -f $TAILER_FINISHED && rm  $TAILER_FINISHED
test -f $COMBINE_FINISHED && rm $COMBINE_FINISHED

function genGetLogScript {
    getLogScript=/tmp/gettmplog
    if [ ! -f $getLogScript ]
    then
        cat <<!END >$getLogScript
#!/bin/sh
    
USER=ainet
PASSWD=ainet1
logloc=\$1

logname=\`basename \$logloc\`
blade=\`echo \$logloc |awk -F\. '{print \$3}'\`
    
/usr/bin/expect -c "
    set timeout 5
    spawn /usr/bin/sftp \${USER}@\${blade}
    expect \"*?assword:*\"
    send -- \\"\${PASSWD}\\r\\"
    expect \\"sftp*\\"
    send -- \\"get \${logloc} /tmp\\r\\"
    expect \\"sftp*\\"
    send -- \\"rm \${logloc}\\r\\"
    expect \\"sftp*\\"
    send -- \\"bye\\r\\"
    expect eof" >/dev/null
!END
        chmod 755 $getLogScript
    fi
}

function logcmb {
    getLogScript=/tmp/gettmplog
    genGetLogScript
    
    tmp_log=$LOGNAME.tmp
    >$tmp_log
    isFinished=""
    
    start=1
    while [ -z $isFinished ]
    do
        sleep 1
        end=$(($(wc -l $LOGNAME | awk '{print $1}') - 1))
        if [ -f "$TAILER_FINISHED" ]
        then
            isFinished=y
            end=$(($end + 1))
        fi
    
        if [ $start -ge $end ]
        then 
            continue
        fi
        
        sed -n "$start","$end"p $LOGNAME | gawk -v getLogScript=$getLogScript -v tmp_cmb_log=$tmp_log '
        BEGIN{
            RS="\n\001\n";
            ORS="\n\001\n"
        }
        
        /\/sn\/log\/CRmsg/{
            match($0, /\/sn\/log\/CRmsg.*\.0-0-[0-9]+/)
            logloc = substr($0, RSTART, RLENGTH)
            split(logloc, t, "/")
            logname = t[5]
            system(getLogScript " " logloc)
    
            tmplogname = "/tmp/"logname
            if (system("test -f " tmplogname)) {
                print logname " not exist" >>tmp_cmb_log
                next
            }
            printf("Restoring from %s\n", logname)
            while (getline line <tmplogname) {
                print line >>tmp_cmb_log
            }
            system("rm " tmplogname)
        }
        
        !/\/sn\/log\/CRmsg/{
            print >>tmp_cmb_log
        }
        '
    
        start=$(($end + 1))
    done
    
    mv $tmp_log $LOGNAME
    rm $TAILER_FINISHED
    echo "Combining Done!!!"
    touch $COMBINE_FINISHED
}

#This fuction used to colloect log
# 1) waiting for combining finished
# 2) upload log to workstation
# 3) replace >>> to > in log, this is for reading convenience in gvim
# 4) check whether there is "subscript at" in log
# 5) check whether there is tmp log missing after combining
logCollect()
{
    echo "*************** Collecting Log ***************"

    touch $TAILER_FINISHED
    while [ ! -f $COMBINE_FINISHED ]
    do
        sleep 1
    done
    rm $COMBINE_FINISHED

    sed -i "s/>>>/>/g" $LOGNAME
    echo "*************** Uploading Log ***************"
#    ftp -in $HOST <<!
#user $LOGIN $PASSWD
#bin
#cd $LOGDIR
#put $LOGNAME
#bye
#!
    /usr/bin/expect <<!EOF
set timeout 600
spawn scp debuglog $LOGIN@$HOST:$LOGDIR
expect {
    "*yes/no\)*" {
        send "yes\n"
        exp_continue
    }
    "*assword:" {
        send "$PASSWD\n"
        exp_continue
    }
}
!EOF

    isSubscriptAt=`grep "subscript at" $LOGNAME`
    if [ ! -z "$isSubscriptAt" ]
    then
	echo -e "\n\n\n\n"
	echo -e  "\t####################################"
	echo -e  "\t#                                  #"
	echo -e  "\t#  WARNING: subscript at exists!!  #"
	echo -e  "\t#                                  #"
	echo -e  "\t####################################\n\n"
    fi

    egrep ".*\.tmp[0-9]+\.0-0-[0-9]+ not exist" $LOGNAME
}

>$LOGNAME
logcmb &
tailer deb|tee $LOGNAME
trap 'logCollect' 0 1 2 3 15
