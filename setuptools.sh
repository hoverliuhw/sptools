#!/bin/sh
# 
#

remoteip="135.242.106.115"
remoteuser=ainet
remotepasswd=ainet1
remotedir="/home/ainet/hongwehl/spvm53/bin"

rootpasswd="r00t"
destdir="/u/ainet/hongwehl"
basedir=$destdir/bin

toollist="LogCMB teel teela eteela dama damaf edamaf trbp rstspa rstdb ldb ldfrm audit ccri ccru ccrt ngini nginu ngint ccre createdb stopall.sh"

if [ ! -d $destdir ]
then
	mkdir -p $destdir
fi

if [ -d $basedir ]
then
	rm -rf $basedir
fi

/usr/bin/expect -c "
	spawn scp -r $remoteuser@$remoteip:$remotedir $destdir
	expect {
		"*assword:" {
			send \"$remotepasswd\n\"
			exp_continue
		}
		"yes/no" {
			send \"yes\n\"
		}
	}
" 2>/dev/null
echo

/usr/bin/expect -c "
spawn su -
expect {
	"*assword:" {
		send "$rootpasswd\n" 
		expect "*root-#"

		send "cd /usr/local/bin\n"
		expect "*bin-#"

		send "rm $toollist 2>/dev/null\n"
		expect "*bin-#"

		send "cd\n"
		expect "*root-#"

		send "for script in $toollist;do ln -s $basedir/$script /usr/local/bin/$script;done\n"
		expect "*root-#"
		send "\n"
	}
}
"
echo
