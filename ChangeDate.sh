#!/bin/sh

newdate=0102090933

for blade in `ls /opt/config/servers/`
do
	ssh $blade date $newdate
done

touch /sn/log/de*
touch /sn/log/OM*
touch /sn/log/meas*
