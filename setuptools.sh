#!/bin/sh

###################################################
# usage: 
#	./setuptools.sh 
#
# description:
#	install scripts to mcas for testing
#	scripts in $toollist are linked to /usr/local/bin
#	so that no need type their full path
#
# author: 
#	Liu Hongwei
# 	hong_wei.hl.liu@alcatel-lucent.com
#	2016/03/17
#	2016/04/18	add: openrc closerc clrc genfrm
#	2016/04/20	add: decode_ama tool configuration
#	2016/04/26	add: ckcus
#	2016/04/28	add: refrc
#	2016/07/06	update: decode_ama part,
#			add creating /ubilling and /billtemp
#################################################

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

# copy tools
toollist="LogCMB teel teela eteela dama damaf edamaf rstama trbp rstspa rstdb ldb pldb getdb.py ldfrm audit ccri ccru ccrt ngini nginu ngint ccre createdb stopall.sh keygen ckcip chr openrc closerc clrc genfrm refrc ckcus genBP updsql ckop mutemeas"

if [ ! -d $basedir ]
then
	mkdir -p $basedir
fi

if [ ! -d $basedir/src ]
then
	mkdir -p $basedir/src
fi

if [ ! -d $basedir/log ]
then
	mkdir -p $basedir/log
fi

if [ -d $bindir ]
then
	rm -rf $bindir.old 2>/dev/null
	mv $bindir $bindir.old
fi

echo "copying scripts from remote server ..."
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
" >/dev/null 2>&1

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
" >/dev/null 2>&1

find $bindir/ -type f| xargs sed -i "s,$tempconfigfile,$configfile,g"
find $bindir/ -type f| xargs sed -i "s,$tempbasedir,$basedir,g"
#sed -i "s,$tempbasedir,$basedir,g" $configfile
cp $0 $bindir 2>/dev/null
chmod 755 $bindir/*
rm -rf $bindir/.git 2>/dev/null

# generating diameter related files
# sed -i "s,$tempbindir,$bindir,g" $bindir/gdiamfrm
diamspa=`psql -Uscncraft -At -c "select span from spa_tbl where span like 'DIAMCL%' order by span desc limit 1"`
if [ ! -z "$diamspa" ]
then
	echo "Configuring CCR related scripts with $diamspa"
	$bindir/gdiamfrm $diamspa
fi
#

# configure decode_ama tool
# include copy decode_ama, ama.filter, and update /cs/sn/bill/billing.config
# creating /billtemp and /ubilling
# note: this is only for default, for new ama structure, need more config, refer to VFCZ
echo "configuring AMA related scripts"

if [ ! -d /billtemp ]
then
	echo "creating dir /billtemp"
	/usr/bin/expect -c "
	spawn su -
	expect {
		"*assword:" {
			send \"$rootpasswd\n\"
			expect "*root-#"

			send \"AddLV vg=user1 name=billtemp size=1G mount=/billtemp replicate=yes\n\"
			expect "*root-#"

			send \"\n\"
		}
	}
	"
fi

if [ ! -d /ubilling ]
then
	echo "creating dir /ubilling"
	/usr/bin/expect -c "
	spawn su -
	expect {
		"*assword:" {
			send \"$rootpasswd\n\"
			expect "*root-#"

			send \"AddLV vg=user1 name=ubilling size=1G mount=/ubilling replicate=yes\n\"
			expect "*root-#"

			send \"\n\"
		}
	}
	"

fi

#version=`psql -Uscncraft -At -c "select version_name from sa_name_map where spa_base='ENWTPPS'" | sed "s/ENWTPPS2[89]/28/g"`
version=`psql -Uscncraft -At -c "select version_name from sa_name_map where spa_base='ENWTPPS'" | sed "s/ENWTPPS//g" |sed "s/^2[89]/28/g"`
if [ ! -z "$version" ]
then
	decode_ama_tar=`ls $bindir/ama.conf/EPAY*.decode_ama.full.tar | grep -i "EPAY$version"`
	if [ -f $decode_ama_tar ]
	then
		tar xfv $decode_ama_tar -C $bindir
		chmod 755 $bindir/decode_ama
	fi
#	rm $bindir/ama.conf/EPAY*.decode_ama.full.tar

	ama_filter_file=`ls $bindir/ama.conf/ama.filter* | grep -i $version`
	if [ ! -f "/cs/sn/bill/ama.filter" ] && [ -f "$ama_filter_file" ]
	then
		cp $ama_filter_file /cs/sn/bill/ama.filter
		chmod 644 /cs/sn/bill/ama.filter
	fi
fi

/usr/bin/expect -c "
spawn su -
expect {
	"*assword:" {
		send \"$rootpasswd\n\"
		expect "*root-#"

		send \"cd /cs/sn/bill\n\"
		expect "*bill-#"

		send \"cp billing.config billing.config.bak\n\"
		expect "*bill-#"

		send \"sed -i s/^blocksize=1531$/blocksize=10/g billing.config\n\"
		expect "*bill-#"

		send \"\n\"
	}
}
" >/dev/null 2>&1
rstama
# Finish configuring ama

cat <<!eof

Finished, installed tool list: 
`for tool in $toollist;do echo " * $tool";done`

* usage of tools is in $bindir/README
* before using, please update $configfile

!eof
