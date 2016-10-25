#!/bin/sh
#
dest_script="config_notif.sh"
hostname=`hostname | sed "s/-0-0-1//g"`
enwtpps=`psql -Uscncraft -At -c "select version_name from sa_name_map where spa_base='ENWTPPS'"`
epay=EPAY`echo $enwtpps | sed "s/ENWTPPS//g"`
eppsa=EPPSA`echo $enwtpps | sed "s/ENWTPPS//g"`

rcscc="public rc table Server_Connect_Conf_tbl"
rcsmppfsm="client fsm SMPP_PRTCL_FSM"

sqlscc=`psql -Uscncraft -At -c "select item from rcmenutbl where title='$rcscc' and parent='$enwtpps'"`
sqlsmppfsmepay=`psql -Uscncraft -At -c "select item from rcmenutbl where title='$rcsmppfsm' and parent='$epay'"`
sqlsmppfsmeppsa=`psql -Uscncraft -At -c "select item from rcmenutbl where title='$rcsmppfsm' and parent='$eppsa'"`

singlequote="'"
updsmppfsmepay=`gawk -v smppfsm=$sqlsmppfsmepay -v quote=$singlequote '
BEGIN{
    RS = "";
    FS = "\n";
}
$1 ~/client fsm SMPP_PRTCL_FSM/{
    split($6, attr, ";");
    server = attr[3];
    split($7, attr, ";");
    port = attr[3];
    printf("update %s set %s=%sSPVM53_HOST%s, %s=%s4444%s", smppfsm, server, quote, quote, port, quote, quote);
}' /sn/sps/$epay/$epay.sym`

if [ -d /sn/sps/$eppsa ]
then
    updsmppfsmeppsa=`gawk -v smppfsm=$sqlsmppfsmeppsa -v quote=$singlequote '
    BEGIN{
        RS = "";
        FS = "\n";
    }
    $1 ~/client fsm SMPP_PRTCL_FSM/{
        split($6, attr, ";");
        server = attr[3];
        split($7, attr, ";");
        port = attr[3];
        printf("update %s set %s=%sSPVM53_HOST%s, %s=%s4444%s", smppfsm, server, quote, quote, port, quote, quote);
    }' /sn/sps/$eppsa/$eppsa.sym`
fi

ti_config="INSERT INTO ti_config VALUES ('SPVM53_HOST', '1', '9999999', '32', '1', '0', '0', 0, '0')"
ti_exit_tcp="INSERT INTO ti_exit VALUES ('SPVM53_HOST', '6666', 'NONE', 'NONE', 'NONE', '0')"
ti_exit_smpp="INSERT INTO ti_exit VALUES ('SPVM53_HOST', '4444', 'NONE', 'NONE', 'NONE', '0')"


cat <<!eof >$dest_script
#!/bin/sh
psql -Uscncraft -At -c "TRUNCATE TABLE $sqlscc"
psql -Uscncraft -c "$updsmppfsmepay"
[ -d /sn/sps/$eppsa ] && psql -Uscncraft -c "$updsmppfsmeppsa"
psql -Uscncraft -At -c "$ti_config"
psql -Uscncraft -At -c "$ti_exit_tcp"
psql -Uscncraft -At -c "$ti_exit_smpp"

ldfrm /tmp/scc.frm
/cs/sn/cepexec INIT_PROC "INIT:PROC=TCPIPSCH,LEVEL=1,MACHINE=0-0-2,UCL"
!eof
chmod 755 $dest_script

is_exist=`grep -i spvm53_host /etc/hosts`
if [ -z "$is_exist" ]
then
    /usr/bin/expect -c "
    spawn su -
    expect {
        "*assword:" {
            send \"r00t\n\" 
            expect "*root-#"

            send \"echo '135.242.106.115	SPVM53_HOST'>>/etc/hosts\n\"
            expect "*root-#"
            send \"\n\"
        }
    }
    " >/dev/null 2>&1
fi
cat <<!eof >/tmp/scc.frm
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPAY:N*",index.Server_Name="EPAY:S*",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPAY:S*",index.Server_Name="SPVM53_HOST",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPAY:S*",index.Server_Name="SPVM53_HOST",index.Service_Name="UCNotification",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPAY:N*",index.Server_Name="EPAY:S*",index.Service_Name="UCConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:N*",index.Server_Name="EPPSA:S*",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:S*",index.Server_Name="SPVM53_HOST",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:S*",index.Server_Name="SPVM53_HOST",index.Service_Name="UCNotification",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:N*",index.Server_Name="EPPSA:S*",index.Service_Name="UCConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
!eof

