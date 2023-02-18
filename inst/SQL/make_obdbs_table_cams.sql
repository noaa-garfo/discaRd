/*

Create table of discarded species for a calendar year
this follows the steps used in Mid-Atlantic discard estaimtion for year end reports

The eventual goal is to replace the CASE code for gear, mesh and area with tale based joins.

Created by: Ben Galuardi, modified from Jay Hermsen's code

12-23-20

modified
3-18-21
12-2-21 changed mesh_cat defnitions to match CAMS definitons. changed name of final output table
12-21-21 change output names to MAPS.CAMS_OBDBS_YYYY
01-04-22 update mesh categories (mesh_cat): 0-3.99 = sm, >=4 = L, FOR GILLNETS, >=8 = XL
02-03-22 update filter for tripext to include Limited sampling trips (see obdbs.tripext@nova)
04-12-22 changed the date filter in table 3 to match only on year rather than dateland.. this was dropping trips for timestamp reasons

The year variable can be defined, and then the entire script run (F5 in sqldev)

This version ues left joins in the first set of tables which preserves more information than previous versions which used hard matches

we also keep all hauls, not just observed hauls, so prorating can be done

07-11-22 modified script to build everything based on WITH statements.
 added removal of fishdisp
 added OBPRELIM!


08-05-22
put fishdisp 090 back in.

02-17-23 - DJH added MESH_MATCH restriction for landings and discard mesh categories are limited to the same gear

RUN FROM MAPS SCHEMA

*/

--DEF YEAR = 2021

--/

--DROP TABLE MAPS.CAMS_OBDBS_&year

--/
CREATE TABLE CAMS_OBDBS_&year AS

--OBPRELIM DATA

with OP as (
   SELECT
    t.link1
    , h.link3
    , G.OBGEARCAT as GEARCAT
    , t.tripext
    , t.program
    , t.year
    , t.permit1
    , t.hullnum1
    , t.fleet_type
    , t.datesail
    , t.dateland
    , h.obsrflag
    , h.area
    , SUBSTR(s.nespp4,1,3) nespp3
    , s.nespp4
    , h.negear
    , s.fishdisp
    , h.CATEXIST as catdisp
    , s.round as drflag
    , s.hailwt
    , 'OBPRELIM' as source

    from
    obprelim.optrp@NOVA t
    LEFT OUTER JOIN
    obprelim.ophau@NOVA h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obprelim.opcatch@NOVA s ON h.link3 = s.link3
    LEFT OUTER JOIN
    obdbs.obgear@NOVA g ON g.negear = h.negear

    WHERE
    t.year in (&YEAR)
    and h.year in (&YEAR)


)

--OBDBS data

, OB as (
   SELECT
    t.link1
    , h.link3
    , t.GEARCAT
    , t.tripext
    , t.program
    , t.year
    , t.permit1
    , t.hullnum1
    , t.fleet_type
    , t.datesail
    , t.dateland
    , h.obsrflag
    , h.area
    , SUBSTR(s.nespp4,1,3) nespp3
    , s.nespp4
    , s.negear
    , s.fishdisp
    , s.catdisp
    , s.drflag
    , s.hailwt
    , 'OBDBS' as source

    from
    obdbs.obtrp@nova t
    LEFT OUTER JOIN
    obdbs.obhau@nova h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obdbs.obspp@nova s ON h.link3 = s.link3


    WHERE
    t.year in (&YEAR)
    and h.year in (&YEAR)

)

-- ASM data

, ASM as (
SELECT
--a.DEALNUM,
a.LINK1,
b.link3,
a.GEARCAT,
a.TRIPEXT,
a.PROGRAM,
a.YEAR,
a.PERMIT1,
a.HULLNUM1,
a.FLEET_TYPE,
a.DATESAIL,
a.DATELAND,
b.OBSRFLAG,
b.AREA,
SUBSTR(s.nespp4,1,3) nespp3
, s.nespp4
, b.negear
, s.fishdisp
, s.catdisp
, s.drflag
, s.hailwt
, 'ASM' as source

FROM obdbs.asmtrp@nova a
left join (select * from obdbs.asmhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.asmspp@nova) s
on b.LINK3 = s.LINK3
left join (select * from obdbs.obfishdisp@nova) e
on s.FISHDISP = e.FISHDISP
where a.year in (&YEAR)
and b.year in (&YEAR)
)

-- put all obs sources together and add livewt calculation

, all_obs as (
select s.*
, s.hailwt*c.cf_rptqty_lndlb*c.cf_lndlb_livlb livewt
--, sum(s.hailwt*c.cf_rptqty_lndlb*c.cf_lndlb_livlb) OVER(PARTITION BY LINK1) as keptall
    from (
        select *
         from ob

         union all

         select *
         from op

          union all

         select *
         from asm
     ) s
LEFT OUTER JOIN obdbs.obspecconv@nova c
ON (s.nespp4 = c.nespp4_obs AND s.catdisp = c.catdisp_code AND s.drflag = c.drflag_code)

)

-- add kept all for LINK1

, kall as (
    SELECT link1
    , sum(livewt) keptall
    FROM all_obs
    GROUP BY link1
)

-- mesh info from trawls

, mesh1 as (
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
WHERE a.YEAR = &YEAR
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
WHERE a.YEAR = &YEAR
)

-- mesh info from gillnets

,mesh2 as (

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
WHERE a.YEAR = &YEAR
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
WHERE a.YEAR = &YEAR

)

-- add trawl mesh info and kall to table
, tab1 as (
    select o.*
    , k.keptall
    , b.CODLINERUSD
    , b.CODMSIZE
    , b.LINERMSIZE
    from all_obs o
    left join (select * from kall) k
    on o.link1 = k.link1

    LEFT OUTER JOIN mesh1 b
    ON o.link3 = b.link3

    WHERE o.program <> '127'
    AND o.tripext IN ('C', 'X')
--    AND o.FISHDISP <> '090' -- keep this in.. deal with it in R
)

select b.*
        , CASE WHEN (meshsize >= 8 AND negear in ('100','105','117', '116','115')) then 'XL'
             else mesh_cat_pre
             END as mesh_cat
from(
    SELECT a.*
        , CASE WHEN (meshsize < 4 AND mesh_match = 1) then 'SM' --
             WHEN (meshsize >= 4 AND mesh_match = 1) then 'LM'
             else null
             END as mesh_cat_pre


        , CASE when geartype NOT LIKE 'Scallop%' then 'ALL' else accessarea1 end as accessarea
        , CASE when geartype NOT LIKE 'Scallop%' then 'ALL' else tripcategory1 end as tripcategory

    from  (
        SELECT a.*
        , b.MSWGTAVG
        , g.mesh_match
--        ,  (CASE WHEN (a.month<=06) then 1
--                WHEN (a.month>06) then 2
--                END) as halfofyear
--        ,
--          (CASE WHEN (a.month<=03) then 1
--                  WHEN (a.month between 04 and 06) then 2
--                  WHEN (a.month between 07 and 09) then 3
--                  WHEN (a.month>09) then 4
--                END) as calendarqtr
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

        , (CASE WHEN a.FLEET_TYPE IN ('000', '050', '101', '102') THEN 'ALL'
                        WHEN a.FLEET_TYPE = '046' THEN 'LIM'
                        WHEN a.FLEET_TYPE = '047' THEN 'GEN'
                        ELSE 'Unknown'
                        END) as tripcategory1

        ,	(CASE WHEN a.program IN ('000', '010', '041', '042', '044','045','101',
                        '102', '103','130','140', '141', '146', '147', '171','230', '231','233', '234','240') THEN 'OPEN'
                        WHEN a.program IN ('201', '202', '203', '204', '205', '206', '207','208','209','210','211', '212','213','219') THEN 'AA'
                        ELSE 'ALL'
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

        FROM tab1 a
        LEFT OUTER JOIN mesh2 b
        ON a.link3 = b.link3
        LEFT OUTER JOIN cfg_negear g
        ON a.negear = g.negear
    ) a
  ) b
--/

--ALTER TABLE MAPS.CAMS_OBDBS_&year DROP (mesh_cat_pre, tripcategory1, accessarea1)
