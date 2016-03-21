sed -i "1ipsql -h pglocalhost -U scncraft <<!eof\nBEGIN;" *.sql
sed -i "\$aCOMMIT;\n!eof" *.sql
sed -i "s/SZ1OCS1/SPVM71A/g" *.sql
ls $PWD/*.sql > sql.list
chmod 755 sql.list
chmod 755 *.sql
