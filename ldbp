#!/bin/sh

if [ $# = 0 ]
then
	cat <<!
	usage: ./ldbp.sh -[lr] <bp file in absolute path>
!
	exit 1
	
fi
local=""
remote=""
tmpsubshl="/tmp/temp.subshl"

while getopts lr option
do
	case $option in
	l)
		local="yes"
		;;
	r)
		remote="yes"
		;;
	\?)
		echo "can't handle option $option" >&2
                ;;
        esac
done

shift `expr $OPTIND - 1`
bpfile=$1 # must be in absolute path
echo $bpfile

if [ -z "$bpfile" ]
then
	echo "please specify bpfile location"
	exit 0
fi

if [ ! -z "$local" ]
then
	echo debug:spa=EPAY29F,client=all,source=\"$bpfile\",ucl >$tmpsubshl
	subshl -F $tmpsubshl
	echo "finish loading $bpfile locally"
fi

if [ ! -z "$remote" ]
then
	ip="135.252.167.235"
	username=ainet
	passwd=ainet1
	/usr/bin/expect -c "
                spawn ssh $username@$ip
                expect {
                "*assword:" {
                        send \"$passwd\n\"
                        expect \"*-> \"
                        send \"echo 'debug:spa=EPAY29F,client=all,source=\\\"$bpfile\\\",ucl' >$tmpsubshl\n\"
                        expect \"*-> \"
                        # send \"subshl -f /u/ainet/hongwehl/bin/print.subshl\n\"
                        send \"subshl -F $tmpsubshl\n\"
                        expect \"*-> \"
                }
        }
        " #>/dev/null
	echo "finish loading $bpfile remotely"
fi
