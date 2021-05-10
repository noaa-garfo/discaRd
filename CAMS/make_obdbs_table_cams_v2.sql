/*

Create table of discarded speceis for a calendar year 
this follows the steps used in Mid-Atlantic discard estaimtion for year end reports

The eventual goal is to replace the CASE code for gear, mesh and area with tale based joins. 

Created by: Ben Galuardi, modified from Jay Hermsen's code

12-23-20

modified 
3-18-21

The year variable can be defined, and then the entire script run (F5 in sqldev)

This version ues left joins in the first set of tables which preserves more information than previous versions which used hard matches

we also keep all hauls, not just observed hauls, so prorating can be done

*/

DEF year = 2021
/
DROP TABLE bg_obdbs_cams_mock&year
/
DROP TABLE bg_obtables_join_1_&year
/

CREATE TABLE bg_obtables_join_1_&year AS

SELECT a.FLEET_TYPE, 
a.DATELAND, 
a.DATESAIL, 
a.DEALNUM, 
a.GEARCAT, 
a.HULLNUM1, 
a.LINK1, 
a.MONTH, 
a.PERMIT1, 
a.PORT, 
a.STATE, 
a.VMSCODE, 
a.VTRSERNO, 
a.YEAR, 
a.YEARLAND, 
a.TRIPEXT,
b.LINK3, 
b.NEGEAR, 
b.NEMAREA, 
b.AREA, 
b.OBSRFLAG, 
b.ONEFFORT, 
b.QDSQ, 
b.QTR, 
b.TENMSQ, 
b.TRIPID,
b.LATHBEG,
b.LATSBEG,
b.LATHEND,
b.LATSEND, 
e.FISHDISPDESC, 
s.catdisp, 
s.drflag, 
s.estmeth, 
s.fishdisp, 
s.hailwt, 
s.nespp4,  
s.program, 
s.wgttype
FROM obdbs.obtrp@nova a
left join (select * from obdbs.obhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.obspp@nova) s
on b.LINK3 = s.LINK3
left join (select * from obdbs.obfishdisp@nova) e
on s.FISHDISP = e.FISHDISP
where a.YEAR = '&year'
AND b.YEAR = '&year'
AND s.fishdisp <> '039'
--AND b.OBSRFLAG <> '1' -- this contorls observed vs unobserved hauls
AND s.program <> '127'
AND a.tripext IN ('C', 'X')

/
---Pull data from the ASM tables in the OBDBS tables on NOVA  

/

DROP TABLE bg_asmtables_join_1_&year 

/

CREATE TABLE bg_asmtables_join_1_&year AS
SELECT a.FLEET_TYPE, 
a.DATELAND, 
a.DATESAIL, 
a.DEALNUM, 
a.GEARCAT, 
a.HULLNUM1, 
a.LINK1, 
a.MONTH, 
a.PERMIT1, 
a.PORT, 
a.STATE, 
a.VMSCODE, 
a.VTRSERNO, 
a.YEAR, 
a.YEARLAND, 
a.TRIPEXT,
b.LINK3, 
b.NEGEAR, 
b.NEMAREA, 
b.AREA, 
b.OBSRFLAG, 
b.ONEFFORT, 
b.QDSQ, 
b.QTR, 
b.TENMSQ, 
b.TRIPID,
b.LATHBEG,
b.LATSBEG,
b.LATHEND,
b.LATSEND, 
e.FISHDISPDESC, 
s.catdisp, 
s.drflag, 
s.estmeth, 
s.fishdisp, 
s.hailwt, 
s.nespp4,  
s.program, 
s.wgttype

FROM obdbs.asmtrp@nova a
left join (select * from obdbs.asmhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.asmspp@nova) s
on b.LINK3 = s.LINK3
left join (select * from obdbs.obfishdisp@nova) e
on s.FISHDISP = e.FISHDISP
where a.YEAR = '&year'
AND b.YEAR = '&year'
AND s.fishdisp <> '039'
--AND b.OBSRFLAG <> '1' -- this contorls observed vs unobserved hauls
AND s.program <> '127'
AND a.tripext IN ('C', 'X')

--
--FROM obdbs.asmtrp@nova a, obdbs.asmhau@nova b, obdbs.asmspp@nova s, obdbs.obfishdisp@nova e--, obdbs.obspec@nova i
--WHERE a.LINK1 = b.LINK1
----AND b.LINK3 = s.LINK3
--AND s.FISHDISP = e.FISHDISP
----AND i.nespp4 = s.nespp4
--AND a.YEAR = '&year'
--AND b.YEAR = '&year'
--AND s.fishdisp <> '039'
----AND b.OBSRFLAG = '1'
--AND s.program <> '127'
--AND a.tripext IN ('C', 'X')
--AND i.inc IS NULL --exclude incidental takes
/

DROP TABLE bg_obtables_join_1a_&year

/
CREATE TABLE bg_obtables_join_1a_&year AS
SELECT s.*, s.hailwt*c.cf_rptqty_lndlb*c.cf_lndlb_livlb livewt
FROM bg_obtables_join_1_&year s LEFT OUTER JOIN obdbs.obspecconv@nova c
ON s.nespp4 = c.nespp4_obs
AND s.catdisp = c.catdisp_code
AND s.drflag = c.drflag_code
/

DROP TABLE bg_asmtables_join_1a_&year

/

CREATE TABLE bg_asmtables_join_1a_&year AS
SELECT s.*, s.hailwt*c.cf_rptqty_lndlb*c.cf_lndlb_livlb livewt
FROM bg_asmtables_join_1_&year s LEFT OUTER JOIN obdbs.obspecconv@nova c
ON s.nespp4 = c.nespp4_obs
AND s.catdisp = c.catdisp_code
AND s.drflag = c.drflag_code

/
---UNION THE TWO TABLES CREATED ABOVE  
DROP TABLE bg_obdbs_tables_1_&year

/

CREATE TABLE bg_obdbs_tables_1_&year 
as
select *
from
(select * from bg_obtables_join_1a_&year)
union all
(select * from bg_asmtables_join_1a_&year)

/
--- GENERATE A TABLE OF KEPT ALL SPECIES BY TRIP (trip is defined by link1, not tripid or vtrserno 
---in the observer database)  
DROP TABLE bg_obdbs_keptall_&year
/
CREATE TABLE bg_obdbs_keptall_&year AS
SELECT link1, sum(livewt) keptall
FROM bg_obdbs_tables_1_&year 
GROUP BY link1
/
---AND UNION THAT TABLE TO THE OBSERVER TABLE CREATED ABOVE 
/
DROP TABLE bg_obdbs_tables_3_&year
/
CREATE TABLE bg_obdbs_tables_3_&year
AS SELECT a.AREA, a.CATDISP, a.FLEET_TYPE, 
a.DATELAND, a.DATESAIL, a.DEALNUM, a.DRFLAG, 
a.ESTMETH, a.FISHDISP, a.FISHDISPDESC, 
a.GEARCAT, a.HAILWT, a.HULLNUM1, a.LATHBEG, 
a.LATHEND, a.LATSBEG, a.LATSEND, a.LINK1, 
a.LINK3, a.LIVEWT, a.MONTH, a.NEGEAR, 
a.NEMAREA, a.NESPP4, a.OBSRFLAG, a.ONEFFORT, 
a.PERMIT1, a.PORT, a.PROGRAM, a.QDSQ, a.QTR, 
a.STATE, a.TENMSQ, a.TRIPEXT, a.TRIPID, 
a.VMSCODE, a.VTRSERNO, a.WGTTYPE, a.YEAR, 
a.YEARLAND, b.keptall
FROM bg_obdbs_tables_1_&year a LEFT OUTER JOIN bg_obdbs_keptall_&year b
ON a.link1 = b.link1 
WHERE a.DATELAND BETWEEN '01-jan-&year' AND '31-DEC-&year'
/
--CREATE A MESHSIZE TABLE AND ADD IT TO THE TABLE CREATED ABOVE  
---the first table pulls mesh sixe for otter trawl gear  
DROP TABLE bg_obdbs_meshsize1_&year
/
CREATE TABLE bg_obdbs_meshsize1_&year AS
SELECT DISTINCT(a.LINK1), 
a.LINK3, 
a.LINK4, 
a.CODLINERUSD, 
a.CODMSIZE, 
a.LINERMSIZE, 
a.MONTH, 
a.NEGEAR, 
a.PROGRAM, 
a.TRIPID, 
a.YEAR 
FROM obdbs.obotgh@nova a
WHERE a.YEAR = '&year'
UNION ALL
SELECT DISTINCT(a.LINK1), 
a.LINK3, 
a.LINK4, 
a.CODLINERUSD, 
a.CODMSIZE, 
a.LINERMSIZE, 
a.MONTH, 
a.NEGEAR, 
a.PROGRAM, 
a.TRIPID, 
a.YEAR 
FROM obdbs.asmotgh@nova a
WHERE a.YEAR = '&year'
/
---the second table pulls mesh size info for gillnet gear 
DROP TABLE bg_obdbs_meshsize2_&year
/
CREATE TABLE bg_obdbs_meshsize2_&year AS
SELECT DISTINCT(a.HAULNUM), 
a.LINK1, 
a.LINK3, 
a.LINK4, 
a.MSMAX, 
a.MSMIN, 
a.MSWGTAVG, 
a.NEGEAR, 
a.TRIPID, 
a.YEAR
FROM obdbs.obgggh@nova a
WHERE a.YEAR = '&year'
UNION ALL
SELECT DISTINCT(a.HAULNUM), 
a.LINK1, 
a.LINK3, 
a.LINK4, 
a.MSMAX, 
a.MSMIN, 
a.MSWGTAVG, 
a.NEGEAR, 
a.TRIPID, 
a.YEAR
FROM obdbs.asmgggh@nova a
WHERE a.YEAR = '&year'
/
--Add info on mesh liner. If a mesh liner was used, the mesh size supplants
---the mesh size used from the actual net. If no liner is used
---the mesh size defaults to the net, i.e. the smaller of the two mesh sizes is used if a liner is present.
/
DROP TABLE bg_obdbs_tables_4_&year
/

CREATE TABLE bg_obdbs_tables_4_&year
AS SELECT a.*, 
b.CODLINERUSD, 
b.CODMSIZE, 
b.LINERMSIZE
FROM bg_obdbs_tables_3_&year a LEFT OUTER JOIN bg_obdbs_meshsize1_&year b
ON a.link3 = b.link3 


/
DROP TABLE bg_obdbs_tables_5_&year
/

-- get rid of all the update steps... put them in CASE statements for WAY faster processing

CREATE TABLE bg_obdbs_tables_5_&year AS 
select c.*
,  CASE when  (geartype in ('Otter Trawl') AND meshgroup2 = 'xlg' ) then 'lg'
       when meshgroup2 IS NULL then 'na'
      else meshgroup2 end as meshgroup
      from (
Select b.*
, CASE when b.geartype in ('Otter Trawl, Haddock Separator', 'Otter Trawl, Ruhle', 'Otter Trawl, Twin') then 'lg'
       else meshgroup1 end as meshgroup2
    , CASE when geartype NOT LIKE 'Scallop%' then 'all' else accessarea1 end as accessarea
    , CASE when geartype NOT LIKE 'Scallop%' then 'all' else tripcategory1 end as tripcategory
from (
    SELECT a.*
    , (CASE WHEN meshsize < 5.5 AND negear IN ('050','054','057','100','105','116','117') THEN 'sm'
          WHEN meshsize BETWEEN 5.5 AND 7.99 AND negear IN ('050','054','057','100','105','116','117') THEN 'lg'
          WHEN meshsize >= 8 AND negear IN ('050','054','057','100','105','116','117') THEN 'xlg'
          END) as  meshgroup1
--    , CASE when geartype NOT LIKE 'Scallop%' then 'all' else accessarea end as accessarea
--    , CASE when geartype NOT LIKE 'Scallop%' then 'all' else tripcategory end as tripcategory
    from  (
        SELECT a.*, b.MSWGTAVG
        ,  (CASE WHEN (a.month<=06) then 1 
                WHEN (a.month>06) then 2 
                END) as halfofyear
        ,
          (CASE WHEN (a.month<=03) then 1 
                  WHEN (a.month between 04 and 06) then 2 
                  WHEN (a.month between 07 and 09) then 3 
                  WHEN (a.month>09) then 4 
                END) as calendarqtr
        , 
        (CASE WHEN a.linermsize IS NULL AND b.mswgtavg IS NULL THEN codmsize*0.03937--converting millimeters to inches  
              WHEN a.codmsize IS NULL AND b.mswgtavg IS NULL THEN linermsize*0.03937
              WHEN a.codmsize IS NULL AND a.linermsize IS NULL THEN mswgtavg
             WHEN NVL(a.codmsize,0) < NVL(a.linermsize,0) THEN codmsize*0.03937
             WHEN NVL(a.linermsize,0) < NVL(a.codmsize,0) THEN linermsize*0.03937
             ELSE NVL(b.mswgtavg,0)
             END) as meshsize
        , (CASE WHEN a.area < 600 THEN 'N'
                        WHEN a.area >= 600 THEN 'S'
                        ELSE 'Other'
                        END) as region
        ,  (case when a.area in (511, 512, 513, 514, 515, 521, 522, 561) 
                        then 'N' 
                       when a.area  NOT IN (511, 512, 513, 514, 515, 521, 522, 561)
                       then 'S'
                       else 'Unknown' end)	as stockarea  
        
        , (CASE WHEN a.FLEET_TYPE IN ('000', '050', '101', '102') THEN 'all'
                        WHEN a.FLEET_TYPE = '046' THEN 'LIM'
                        WHEN a.FLEET_TYPE = '047' THEN 'GEN'
                        ELSE 'Unknown'
                        END) as tripcategory1
        
        ,	(CASE WHEN a.program IN ('000', '010', '041', '042', '044','045','101', 
                        '102', '103','130','140', '141', '146', '147', '171','230', '231','233', '234','240') THEN 'OPEN'
                        WHEN a.program IN ('201', '202', '203', '204', '205', '206', '207','208','209','210','211','219') THEN 'AA'
                        ELSE 'all'
                        END) as accessarea1
        , (CASE WHEN a.negear IN ('070') THEN 'Beach Seine'
                        WHEN a.negear IN ('020', '021') THEN 'Handline'
                        WHEN a.negear IN ('010') THEN 'Longline'
                        WHEN a.negear IN ('170', '370') THEN 'Mid-water Trawl, Paired and Single'
                        WHEN a.negear IN ('350','050') THEN 'Otter Trawl'
                        WHEN a.negear IN ('057') THEN 'Otter Trawl, Haddock Separator'
                        WHEN a.negear IN ('054') THEN 'Otter Trawl, Ruhle'
                        WHEN a.negear IN ('053') THEN 'Otter Trawl, Twin'
                        WHEN a.negear IN ('181') THEN 'Pots+Traps, Fish'
                        WHEN a.negear IN ('186') THEN 'Pots+Traps, Hagfish'
                        WHEN a.negear IN ('120','121', '123') THEN 'Purse Seine'
                        WHEN a.negear IN ('132') THEN 'Scallop Dredge'
                        WHEN a.negear IN ('052') THEN 'Scallop Trawl'
                        WHEN a.negear IN ('058') THEN 'Shrimp Trawl'
                        WHEN a.negear IN ('100', '105','110', '115','116', '117','500') THEN 'Sink, Anchor, Drift Gillnet'
                        WHEN a.negear NOT IN 
                        ('070','020', '021','010','170','370','350','050','057','054','053','181',
                        '186','120','121', '123','132','052','058','100', '105', '110','115','116', '117','500') THEN 'Other' 
                        WHEN a.negear IS NULL THEN 'Unknown'
                        END) as geartype
              
        FROM bg_obdbs_tables_4_&year a LEFT OUTER JOIN bg_obdbs_meshsize2_&year b
        ON a.link3 = b.link3 
    ) a
  ) b
 ) c 
/

/
-- drop temp columns
ALTER TABLE bg_obdbs_tables_5_&year DROP (tripcategory1, meshgroup1, meshgroup2, accessarea1)
/

CREATE TABLE bg_obdbs_cams_mock&year as select * from bg_obdbs_tables_5_&year
/
drop table bg_obdbs_tables_5_&year
/
drop table bg_obdbs_tables_1_&year
/
drop table bg_obdbs_tables_1a_&year
/
drop table bg_obdbs_tables_2_&year
/
drop table bg_obdbs_tables_3_&year
/
drop table bg_obdbs_tables_4_&year
;

select count(*) 
from bg_obdbs_cams_mock&year

;

