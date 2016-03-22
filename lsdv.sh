#!/bin/sh

TMPFILE="/tmp/dvlist.out"
echo "op:status,dataview=all;" | /sn/cr/textsh -F lab >$TMPFILE 2>/dev/null

cat $TMPFILE | grep "_" | awk '
BEGIN{
	col1 = "DATAVIEW";
	col2 = "SERVER";
	col3 = "PORT";
	col4 = "STATUS";
	printf("%-30s%s\t%s\t%s\n",col1,col2,col3,col4) 
	print "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++";

}
{
	printf("%-30s%s\t%s\t%s\n",$1,$2,$3,$5)
}'
