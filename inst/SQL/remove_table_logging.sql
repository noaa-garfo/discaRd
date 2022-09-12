begin
for r in ( select table_name from all_tables where owner='MAPS' and table_name like 'CAMS_DISCARD%' and logging='YES')
loop
execute immediate 'alter table MAPS.'|| r.table_name ||' NOLOGGING';
end loop;
end;


begin
for r in ( select table_name from all_tables where owner='CAMS_GARFO' and table_name like 'CAMS_DISCARD%' and logging='YES')
loop
execute immediate 'alter table CAMS_GARFO.'|| r.table_name ||' NOLOGGING';
end loop;
end;