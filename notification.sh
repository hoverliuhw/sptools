#!/bin/sh
# this is a script to configure notification related tables
# if it is run on mCAs, it does:
#    1) configure notification server related tables, including:
#       Server_Connect_Conf_tbl - ENWTPPS
#       SMPP_PRTCL_FSM - EPAY/EPPSA
#       TI_CONFIG - Platform 9.1
#       TI_EXIT - platform 9.2, 4444 for SMPP, 6666 for TCP
#       add $servername(notification server) IP in /etc/hosts, default server is SPVM43 135.242.106.65

dest_sql="notification.sql"
hostname=`hostname | sed "s/-0-0-1//g"`
servername="NOTIHOST"
serverip="135.242.106.65"
enwtpps=`psql -Uscncraft -At -c "select version_name from sa_name_map where spa_base='ENWTPPS'"`
version=$(echo $enwtpps | sed "s/ENWTPPS//g")
epay=EPAY$version
eppsa=EPPSA$version

# replace hostname in sql files
# config diameter related

# configure SCC related table
rcscc="public rc table Server_Connect_Conf_tbl"
rcsmppfsm="client fsm SMPP_PRTCL_FSM"

sqlscc=`psql -Uscncraft -At -c "select item from rcmenutbl where title='$rcscc' and parent='$enwtpps'"`
sqlsmppfsmepay=`psql -Uscncraft -At -c "select item from rcmenutbl where title='$rcsmppfsm' and parent='$epay'"`
sqlsmppfsmeppsa=`psql -Uscncraft -At -c "select item from rcmenutbl where title='$rcsmppfsm' and parent='$eppsa'"`

singlequote="'"
updsmppfsmepay=`gawk -v smppfsm=$sqlsmppfsmepay -v quote=$singlequote -v servername=$servername '
BEGIN{
    RS = "";
    FS = "\n";
}
$1 ~/client fsm SMPP_PRTCL_FSM/{
    split($6, attr, ";");
    server = attr[3];
    split($7, attr, ";");
    port = attr[3];
    printf("UPDATE %s SET %s=%s%s%s, %s=%s4444%s", smppfsm, server, quote, servername, quote, port, quote, quote);
}' /sn/sps/$epay/$epay.sym`

if [ -d /sn/sps/$eppsa ]
then
    updsmppfsmeppsa=`gawk -v smppfsm=$sqlsmppfsmeppsa -v quote=$singlequote -v servername=$servername '
    BEGIN{
        RS = "";
        FS = "\n";
    }
    $1 ~/client fsm SMPP_PRTCL_FSM/{
        split($6, attr, ";");
        server = attr[3];
        split($7, attr, ";");
        port = attr[3];
        printf("UPDATE %s SET %s=%s%s%s, %s=%s4444%s", smppfsm, server, quote, servername, quote, port, quote, quote);
    }' /sn/sps/$eppsa/$eppsa.sym`
fi

ti_config="INSERT INTO TI_CONFIG(host_name, poll_interval, data_limit,reads_per_interval,window_size,read_size,write_size,diff_serv,window_size_kb) VALUES ('$servername', '1', '9999999', '32', '1', '0', '0', 0, '0')"
ti_exit_tcp="INSERT INTO TI_EXIT(host_name, port_number, treatment, security_type, cipher_suite,node_id) VALUES ('$servername', '6666', 'NONE', 'NONE', 'NONE', '0')"
ti_exit_smpp="INSERT INTO TI_EXIT(host_name, port_number, treatment, security_type, cipher_suite,node_id) VALUES ('$servername', '4444', 'NONE', 'NONE', 'NONE', '0')"

is_exist=""
is_exist=$(psql -Uscncraft -At -c "select * from ti_config where host_name='$servername'")
if [ ! -z "$is_exist" ]
then
    ti_config=""
fi
is_exist=$(psql -Uscncraft -At -c "select * from ti_exit where host_name='$servername' and port_number='6666'")
if [ ! -z "$is_exist" ]
then
    ti_exit_tcp=""
fi
is_exist=$(psql -Uscncraft -At -c "select * from ti_exit where host_name='$servername' and port_number='4444'")
if [ ! -z "$is_exist" ]
then
    ti_exit_smpp=""
fi

cat <<!eof >$dest_sql
psql -Uscncraft <<!eos
TRUNCATE TABLE $sqlscc;
$updsmppfsmepay;
$updsmppfsmeppsa;
$ti_config;
$ti_exit_tcp;
$ti_exit_smpp;
!eos
!eof

is_exist=""
is_exist=`grep -i $servername /etc/hosts`
if [ -z "$is_exist" ]
then
    /usr/bin/expect -c "
    spawn su -
    expect {
        "*assword:" {
            send \"r00t\n\" 
            expect "*root-#"

            send \"echo '$serverip	$servername'>>/etc/hosts\n\"
            expect "*root-#"
            send \"\n\"
        }
    }
    " >/dev/null 2>&1

    echo "$servername $serverip is added into /etc/hosts"
else
    echo "\"$is_exist\" has been already in /etc/hosts"
fi
cat <<!eof >scc.frm
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPAY:N*",index.Server_Name="EPAY:S*",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPAY:S*",index.Server_Name="$servername",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPAY:S*",index.Server_Name="$servername",index.Service_Name="UCNotification",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPAY:N*",index.Server_Name="EPAY:S*",index.Service_Name="UCConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:N*",index.Server_Name="EPPSA:S*",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="4444",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:S*",index.Server_Name="$servername",index.Service_Name="SMPPConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="1",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:S*",index.Server_Name="$servername",index.Service_Name="UCNotification",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
FORM=$sqlscc&NEW,index.Port_Number="6666",index.SCP_Name="$hostname",index.SPA_ID="EPPSA:N*",index.Server_Name="EPPSA:S*",index.Service_Name="UCConnection",Backlog_Size="1000",Block_Duration="100",Number_Of_Connection="2",Number_Of_Retry="1",Priority="Priority_Primary",Protocol="PRT_TCPIP",Retry_Interval="10",Timeout="4",NEW!
!eof

chmod 755 $dest_sql
echo "please execute ./$dest_sql, and then ldfrm scc.frm"
