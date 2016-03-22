#!/usr/bin/expect

set ROOT_PASSWD "r00t"
spawn su -
expect {
	"*assword:" {
		send "$ROOT_PASSWD\n" 
		
		expect "*root-#"
		send "ln -s /u/ainet/hongwehl/bin/ccri /usr/local/bin/ccri\n"
		expect "*root-#"
		send "ln -s /u/ainet/hongwehl/bin/ccru /usr/local/bin/ccru\n"
		expect "*root-#"
		send "ln -s /u/ainet/hongwehl/bin/ccrt /usr/local/bin/ccrt\n"
		expect "*root-#"
		send "ln -s /u/ainet/hongwehl/bin/ni /usr/local/bin/ngini\n"
		expect "*root-#"
		send "ln -s /u/ainet/hongwehl/bin/nu /usr/local/bin/nginu\n"
		expect "*root-#"
		send "ln -s /u/ainet/hongwehl/bin/nt /usr/local/bin/ngint\n"
		expect "*root-#"
		send "\n"
	}
}
