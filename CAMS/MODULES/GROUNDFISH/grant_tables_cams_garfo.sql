/*

move CAMS discard tables from MAPS to CAMS_GARFO

Ben Galuardi

Jan 28, 2022



*/

-- Run rom MAPS

grant select on MAPS.CAMS_STATAREA_STOCK to CAMS_GARFO
/ 
grant select on MAPS.CAMS_DISCARD_MORTALITY_STOCK to CAMS_GARFO
/
grant select on MAPS.CAMS_GEARCODE_STRATA to CAMS_GARFO
/
grant select on MAPS.CAMS_MASTER_GEAR to CAMS_GARFO
/
grant select on MAPS.CAMS_OBS_CATCH to CAMS_GARFO
/

-- Run from CAMS_GARFO
-- CREATE TABLES
create table CAMS_GARFO.CAMS_STATAREA_STOCK as select * from MAPS.CAMS_STATAREA_STOCK
/
create table CAMS_GARFO.CAMS_DISCARD_MORTALITY_STOCK as  select * from MAPS.CAMS_DISCARD_MORTALITY_STOCK
/
create table CAMS_GARFO.CAMS_GEARCODE_STRATA as select * from MAPS.CAMS_GEARCODE_STRATA
/
create table CAMS_GARFO.CAMS_MASTER_GEAR as select * from MAPS.CAMS_MASTER_GEAR

/
drop table CAMS_GARFO.CAMS_OBS_CATCH
/
create table CAMS_GARFO.CAMS_OBS_CATCH as select * from MAPS.CAMS_OBS_CATCH
/


-- GRANTS 
grant select on CAMS_GARFO.CAMS_OBS_CATCH to CAMS_GARFO_FOR_NEFSC
/
grant select on CAMS_GARFO.CAMS_STATAREA_STOCK to CAMS_GARFO_FOR_NEFSC
/
grant select on CAMS_GARFO.CAMS_DISCARD_MORTALITY_STOCK to CAMS_GARFO_FOR_NEFSC
/
grant select on CAMS_GARFO.CAMS_GEARCODE_STRATA to CAMS_GARFO_FOR_NEFSC
/
grant select on CAMS_GARFO.CAMS_MASTER_GEAR to CAMS_GARFO_FOR_NEFSC


/

BEGIN
FOR cur_rec IN (SELECT object_name, object_type
FROM user_objects
WHERE object_type IN
('TABLE'))
LOOP
BEGIN
EXECUTE IMMEDIATE 'GRANT SELECT ON '
--|| cur_rec.object_type
|| ' "'
|| cur_rec.object_name
|| '" TO JMOSER, APSD, SWIGLEY, GSHIELD, CLEGAULT, CAMS_GARFO_FOR_NEFSC';
EXCEPTION
WHEN OTHERS
THEN
DBMS_OUTPUT.put_line ( 'FAILED: DROP '
|| cur_rec.object_type
|| ' "'
|| cur_rec.object_name
|| '"'
);
END;
END LOOP;
END;
/