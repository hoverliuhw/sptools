#!/usr/bin/expect

set ROOT_PASSWD "r00t"
set TOOL_LIST="LogCMB teel teela eteela dama damaf edamaf trbp rstspa rstdb ldb ldfrm audit ccri ccru ccrt ngini nginu ngint ccre createdb stopall.sh"
set BASE_DIR="/u/ainet/hongwehl"
spawn su -
expect {
	"*assword:" {
		send "$ROOT_PASSWD\n" 
		expect "*root-#"

		send "cd /usr/local/bin\n"
		expect "*bin-#"

		send "rm $TOOL_LIST 2>/dev/null\n"
		expect "*bin-#"

		send "cd\n"
		expect "*root-#"

		send "for script in $TOOL_LIST;do ln -s $BASE_DIR/$script /usr/local/bin/$script;done\n"
		expect "*root-#"
		send "\n"
	}
}
