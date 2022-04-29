--The first checks for a list of all table names in a schema , and loops through the list giving grant select to CAMS_GARFO

BEGIN
   FOR cur_rec IN (SELECT object_name, object_type
                     FROM user_objects
                    WHERE object_type IN
                             ('TABLE'))
   LOOP
      BEGIN
            EXECUTE IMMEDIATE    'GRANT SELECT ON '
                              --|| cur_rec.object_type
                              || ' "'
                              || cur_rec.object_name
                              || '" TO CAMS_GARFO';
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (   'FAILED: DROP '
                                  || cur_rec.object_type
                                  || ' "'
                                  || cur_rec.object_name
                                  || '"'
                                 );
      END;
   END LOOP;
END;
/
--
--Second grabs a list of Tables where like 'CAMS_' from  MAPS then loops through doing a build table in CAMS_GARFO

BEGIN
   FOR cur_rec IN (
    SELECT object_name, object_type
    FROM all_objects
    WHERE object_type = 'TABLE'
    and owner = 'MAPS'
    --and object_name = 'CAMS_CFDETS_2019_AA'
and object_name like 'CAMS_%'
   )
   LOOP
      BEGIN
            EXECUTE IMMEDIATE    'CREATE TABLE '
                              || '"CAMS_GARFO"."'
                              || cur_rec.object_name
                              || '" as SELECT * FROM '
                              || '"MAPS"."'
                              || cur_rec.object_name
                              || '"';
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (   'FAILED: DROP '
                                  || cur_rec.object_type
                                  || ' "'
                                  || cur_rec.object_name
                                  || '"'
                                 );
      END;
   END LOOP;
END;
/

--grants 

BEGIN
   FOR cur_rec IN (SELECT object_name, object_type
                     FROM user_objects
                    WHERE object_type IN
                             ('TABLE'))
   LOOP
      BEGIN
            EXECUTE IMMEDIATE    'GRANT SELECT ON '
                              --|| cur_rec.object_type
                              || ' "'
                              || cur_rec.object_name
                              || '" TO  JMOSER, APSD, SWIGLEY, GSHIELD, CLEGAULT, CAMS_GARFO_FOR_NEFSC';
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (   'FAILED: DROP '
                                  || cur_rec.object_type
                                  || ' "'
                                  || cur_rec.object_name
                                  || '"'
                                 );
      END;
   END LOOP;
END;
/

--Second grabs a list of Tables where like 'CAMS_' from  MAPS then loops through doing a build table in CAMS_GARFO

BEGIN
   FOR cur_rec IN (
    SELECT object_name, object_type
    FROM all_objects
    WHERE object_type = 'TABLE'
    and owner = 'MAPS'
    --and object_name = 'CAMS_CFDETS_2019_AA'
and object_name like 'CAMS_DISCARD_EX%'
   )
   LOOP
      BEGIN
            EXECUTE IMMEDIATE    'CREATE VIEW '
                              || '"MAPS"."'
                              || cur_rec.object_name
                              || '" as SELECT * FROM '
                              || '"MAPS"."'
                              || cur_rec.object_name
                              || '"';
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (   'FAILED: DROP '
                                  || cur_rec.object_type
                                  || ' "'
                                  || cur_rec.object_name
                                  || '"'
                                 );
      END;
   END LOOP;
END;
/


BEGIN
   FOR cur_rec IN (
    SELECT object_name, object_type
    FROM all_objects
    WHERE object_type = 'TABLE'
    and owner = 'MAPS'
and object_name like 'CAMS_DISCARD_EX%'
   )
   LOOP
      BEGIN
            EXECUTE IMMEDIATE    'CREATE OR REPLACE VIEW '
                              || '"MAPS.CAMS_DISCARD_ALL_YEARS'                            
                              || '" as SELECT * FROM '
                              || '"MAPS"."'
                              || cur_rec.object_name
                              || '"'
                              ||'"UNION ALL"'
                              ||'" SELECT * FROM MAPS.CAMS_DISCARD_ALL_YEARS"';
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (   'FAILED: DROP '
                                  || cur_rec.object_type
                                  || ' "'
                                  || cur_rec.object_name
                                  || '"'
                                 );
      END;
   END LOOP;
END;


CREATE OR REPLACE VIEW MAPS.CAMS_DISCARD_ALL_YEARS AS 
select * from MAPS.CAMS_DISCARD_EXAMPLE_GF19 
UNION ALL 
select * from MAPS.CAMS_DISCARD_EXAMPLE_GF18
;

select distinct(species_itis)
from MAPS.CAMS_DISCARD_ALL_YEARS
;

select round(sum(discard)) as total_discard
, species_stock
, COMMON_NAME
, species_itis
, FY
, GF
from MAPS.CAMS_DISCARD_ALL_YEARS
group by species_itis, fy, species_stock, GF, COMMON_NAME
order by COMMON_NAME



;

CREATE OR REPLACE VIEW MAPS.CAMS_DISCARD_ALL_YEARS AS 
select * from MAPS.CAMS_DISCARD_EXAMPLE_CY_BARNDOORSKATE_19 
UNION ALL 
select * from MAPS.CAMS_DISCARD_EXAMPLE_CY_BLACKSEABASS_19  