psql -Uscncraft -At -c "select * from rtdb_app where db_name not in ('NDB','BDB','HLRV','HLRNV')"
