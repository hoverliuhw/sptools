#!/usr/bin/expect

set ROOT_PASSWD "r00t"
spawn su -
expect {
	"*assword:" {
		send "$ROOT_PASSWD\n" 
		expect "*root-#"

		send "cd /usr/local/bin\n"
		expect "*bin-#"

		send "rm teel LogCMB trbp rstspa rstdb ldb ldfrm 2>/dev/null\n"
		expect "*bin-#"

		send "cd\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/teel /usr/local/bin/teel\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/LogCMB /usr/local/bin/LogCMB\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/trbp.sh /usr/local/bin/trbp\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/rstspa /usr/local/bin/rstspa\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/rstdb.sh /usr/local/bin/rstdb\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/ldb /usr/local/bin/ldb\n"
		expect "*root-#"

		send "ln -s /u/ainet/hongwehl/bin/ldfrm /usr/local/bin/ldfrm\n"
		expect "*root-#"
		send "\n"
	}
}
