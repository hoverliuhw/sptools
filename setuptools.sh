#!/bin/sh
# 
# usage: 
#	./setuptools.sh 
#
# description:
#	install scripts to mcas for testing
#
# author: 
#	Liu Hongwei
# 	hong_wei.hl.liu@alcatel-lucent.com
#	2016/03/17
#

# remote host information, no need update
remoteip="135.242.106.115"
remoteuser=ainet
remotepasswd=ainet1
remotedir="/home/ainet/hongwehl/spvm53/bin"

# local host(working mCAS) information, update per user's need
rootpasswd="r00t"
basedir="/u/ainet/hongwehl"
bindir=$basedir/bin
sysbindir="/usr/local/bin"

# original temp variable, no need update
tempconfigfile="/u/ainet/hongwehl/bin/CONFIGURE"
tempbasedir="/u/ainet/hongwehl"
tempbindir="$tempbasedir/bin"
configfile="$bindir/CONFIGURE"

toollist="LogCMB teel teela eteela dama damaf edamaf rstama trbp rstspa rstdb ldb ldfrm audit ccri ccru ccrt ngini nginu ngint ccre createdb stopall.sh keygen"

if [ ! -d $basedir ]
then
	mkdir -p $basedir
fi

if [ -d $bindir ]
then
	rm -rf $bindir.old 2>/dev/null
	mv $bindir $bindir.old
fi

/usr/bin/expect -c "
	spawn scp -r $remoteuser@$remoteip:$remotedir $basedir
	expect {
		"*yes/no\)*" {
			send \"yes\n\"
			exp_continue
		}
		"*assword:" {
			send \"$remotepasswd\n\"
			exp_continue
		}
	}
" 2>/dev/null

/usr/bin/expect -c "
spawn su -
expect {
	"*assword:" {
		send \"$rootpasswd\n\" 
		expect "*root-#"

		send \"cd $sysbindir\n\"
		expect "*bin-#"

		send \"rm $toollist 2>/dev/null\n\"
		expect "*bin-#"

		send \"cd\n\"
		expect "*root-#"

		send \"for script in $toollist;do ln -s $bindir/\\\$script $sysbindir/\\\$script;done\n\"
		expect "*root-#"
		send \"\n\"
	}
}
" 2>/dev/null

find $bindir/ -type f| xargs sed -i "s,$tempconfigfile,$configfile,g"
sed -i "s,$tempbasedir,$basedir,g" $configfile
cp $0 $bindir 2>/dev/null
chmod 755 $bindir/*
rm -rf $bindir/.git 2>/dev/null

# generating diameter related files
sed -i "s,$tempbindir,$bindir,g" $bindir/gdiamfrm
diamspa=""
spalist=`psql -Uscncraft -At -c "select span from spa_tbl where span like 'DIAMCL%'"`
if [ ! -z "$spalist" ]
then
	for spa in $spalist
	do
		diamspa=$spa
	done
fi
echo "installing CCR related scripts with $diamspa"
$bindir/gdiamfrm $diamspa
#

cat <<!eof

Finished, installed tool list: 
`for tool in $toollist;do echo " * $tool";done`

* usage of tools is in $bindir/README
* before using, please update $configfile

!eof
