#!/bin/sh

newdate=010109002033
if [ $# -gt 1 ]
then
	newdate=$1
fi
blades=`ls /opt/config/servers/`

user=`whoami`
root_passwd="r00t"

if [ $user = "root" ]
then
	for blade in $blades
	do
		ssh $blade date $newdate
	done

	touch /sn/log/de*
	touch /sn/log/OM*
	touch /sn/log/meas*

	exit 0
fi

/usr/bin/expect -c "
        spawn su -
        expect {
        "*assword:" {
                send \"$root_passwd\n\"
                expect \"*root-#\"
                send \"for blade in \`ls /opt/config/servers/\`;do ssh \\\$blade date $newdate;done\n\"
                expect \"*root-#\"
                send \"touch /sn/log/de*;touch /sn/log/OM*;touch /sn/log/meas*\n\"
                expect \"*root-#\"
        }
}"
