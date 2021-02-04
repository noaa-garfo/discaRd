/*

    BEN GALUARDI
    
    12/23/20
    
    CREATE MOCKUP OF CATCH TABLE FROM MAPS USING DMIS_TRIP_ID AND JOINING TO LINK3 AND MATCH GEAR AND MESH

*/


with obs as (
--        select o.*
select o.link3
    , link1
    , o.obsrflag
    , o.area as obs_area
    , o.negear as obs_gear
    , round(o.meshsize, 0) as obs_mesh
    , o.meshgroup
    , SUM(case when catdisp = 0 then o.hailwt else 0 end) OVER(PARTITION BY o.link3) as discard
        , SUM(case when catdisp = 1 then o.hailwt else 0 end) OVER(PARTITION BY o.link3) as obs_haul_kall
        , substr(nespp4, 1, 3) as NESPP3
    from (
        select * from apsd.bg_obdbs_cams_mock2018
        union all
        select * from apsd.bg_obdbs_cams_mock2019
    )
    o
)
, mgear as (
    select gear_code_fid
    , RIGHT('000' + negear, 3) as negear
    , vtr_gear_code
    from apsd.master_gear
)

    select c.*
    , o.link3
    , o.obs_area
    , o.nespp3
    , o.discard
    , o.obs_haul_kall
    , o.obs_gear 
    , o.obs_mesh
    , o.meshgroup
    , m.GEAR_CODE_FID
from apsd.catch_link1_temp c
    left outer join (
        select * from obs -- where nespp3 = 212 
    ) o
on o.link1 = c.link1 AND c.mesh = o.obs_mesh 
left join (SELECT * from mgear) m
on (c.GEARCODE = m.VTR_GEAR_CODE) --o.obs_gear = m.NEGEAR AND AND c.GEARCODE = m.VTR_GEAR_CODEto_char(o.obs_gear) = to_char(m.NEGEAR) 
;
/*

second try

*/

drop table bg_cams_catch_mock
;

CREATE TABLE bg_cams_catch_mock AS
SELECT a.dmis_trip_id
, a.docid
, a.vtrserno
, a.AREA
, a.CAREA
, a.record_land
--, a.DLR_STATE
--, a.FISHING_YEAR
--, a.LINK1
, a.NESPP3
, a.NESPP4
, a.LIVE as POUNDS
, a.MESH
--, a.MONTH
, a.PERMIT 
, extract(year from a.record_land) as year
, extract(month from a.record_land) as month
--, a.YEAR||a.ID yearid
, b.gearnm
, b.GEARCODE
, b.NEGEAR
, b.NEGEAR2
--,  (CASE WHEN (month IN (1,2,3,4,5,6)) then 1 
--          WHEN (month IN (7,8,9,10,11,12)) then 2 
--        END) as halfofyear
        , (CASE WHEN area < 600 THEN 'N'
                WHEN area >= 600 THEN 'S'
                ELSE 'Other'
                END) as region
,  (case when area in (511, 512, 513, 514, 515, 521, 522, 561) 
                then 'N' 
                 when area  NOT IN (511, 512, 513, 514, 515, 521, 522, 561)
               then 'S'
                 else 'Unknown' end)  as stockarea 
, (CASE WHEN negear IN ('070') THEN 'Beach Seine'
			    WHEN negear IN ('020', '021') THEN 'Handline'
  			   	WHEN negear IN ('010') THEN 'Longline'
				WHEN negear IN ('170', '370') THEN 'Mid-water Trawl, Paired and Single'
				WHEN negear IN ('350','050') THEN 'Otter Trawl'
				WHEN negear IN ('057') THEN 'Otter Trawl, Haddock Separator'
				WHEN negear IN ('054') THEN 'Otter Trawl, Ruhle'
				WHEN negear IN ('053') THEN 'Otter Trawl, Twin'
				WHEN negear IN ('181') THEN 'Pots+Traps, Fish'
				WHEN negear IN ('186') THEN 'Pots+Traps, Hagfish'
				WHEN negear IN ('120','121', '123') THEN 'Purse Seine'
				WHEN negear IN ('132') THEN 'Scallop Dredge'
				WHEN negear IN ('052') THEN 'Scallop Trawl'
				WHEN negear IN ('058') THEN 'Shrimp Trawl'
				WHEN negear IN ('100', '105','110', '115','116', '117','500') THEN 'Sink, Anchor, Drift Gillnet'
				WHEN negear NOT IN 
				('070','020', '021','010','170','370','350','050','057','054','053','181',
				'186','120','121', '123','132','052','058','100', '105', '110','115','116', '117','500') THEN 'Other' 
				WHEN negear IS NULL THEN 'Unknown'
				END) as  geartype
,                 
(CASE WHEN mesh < 5.5 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'sm'
	  WHEN mesh BETWEEN 5.5 AND 7.99 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'lg'
	  WHEN mesh >= 8 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'xlg'
	  ELSE NULL
	  END)  as meshgroup
--,  (CASE WHEN activity_code NOT LIKE 'SES%' THEN 'all'
--			    WHEN activity_code LIKE 'SES-SCG%' THEN 'GEN'
--  			   	WHEN activity_code LIKE 'SES-SAA%' THEN 'LIM'
--                WHEN activity_code LIKE 'SES-SCA%' THEN 'LIM'
--                WHEN activity_code LIKE 'SES-RSA%' THEN 'LIM'
--                WHEN activity_code LIKE 'SES-SWE%' THEN 'LIM'
--				ELSE 'Unknown'
--				END) as tripcategory   
--, (CASE WHEN activity_code NOT LIKE 'SES%'
--                    OR activity_code LIKE 'SES-PWD%' 
--                THEN 'all'
--			    WHEN activity_code LIKE 'SES-SAA%' 
--                  OR activity_code LIKE 'SES-RSA-DM%'                  
--                  OR activity_code LIKE 'SES-RSA-HC%'
--                   OR activity_code LIKE   'SES-RSA-1S%'
--                   OR activity_code LIKE   'SES-RSA-2S%'
--                    OR activity_code LIKE  'SES-RSA-ET%'
--                     OR activity_code LIKE 'SES-RSA-NS%'
--                     OR activity_code LIKE 'SES-RSA-MA%'
--                     OR activity_code LIKE 'SES-RSA-EF%'
--                     OR activity_code LIKE 'SES-RSA-NH%'
--                     OR activity_code LIKE 'SES-RSA-NW%'
--                     THEN 'AA'
--  			   	WHEN activity_code LIKE 'SES-SCA-OP%'
--                     OR activity_code LIKE 'SES-RSA-OP%'
--                     OR activity_code LIKE 'SES-RSA-XX%'
--                     OR activity_code LIKE 'SES-SWE-OP%'
--                      THEN 'OPEN'
--				ELSE 'Unknown'
--				END) as accessarea              
FROM apsd.cams_apport_ntrip_20200106  a 
--FROM apsd.dmis_all_years  a 
    LEFT OUTER JOIN vtr.vlgear b
ON a.GEARCODE = b.GEARCODE
--where a.year = 2019

/
UPDATE bg_cams_catch_mock a
SET meshgroup = 'lg'
WHERE a.negear IN ('054', '057') 
/
UPDATE bg_cams_catch_mock a
SET a.geartype = 'Scallop Dredge'
WHERE a.nespp3 = '800' 
AND a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/
UPDATE bg_cams_catch_mock a
SET a.geartype = 'Other'
WHERE a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/
UPDATE bg_cams_catch_mock
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl, Twin'
/                
/*UPDATE bg_cams_catch_mock
SET geartype = 'Otter Trawl'
WHERE geartype = 'Otter Trawl, Twin'*/
/                
UPDATE bg_cams_catch_mock
SET meshgroup = 'lg'
WHERE geartype = 'Sink, Anchor, Drift Gillnet'
AND meshgroup = 'sm'
/   
UPDATE bg_cams_catch_mock
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl'
AND meshgroup = 'xlg'
;

select * from bg_cams_catch_mock
/
select distinct(gearnm) from bg_cams_catch_mock

;

/*

now merge as before with obdbs

*/  

drop table bg_obs_cams_tmp1
/

create table bg_obs_cams_tmp1 as 
-- this part selects trips with more than one subtrip

with mtrips as (
select dmis_trip_id
    from (
        select
         count(distinct(vtrserno)) nvtr
        , count(distinct(docid)) ndocid
        , dmis_trip_id
        from apsd.bg_cams_catch_mock
        group by dmis_trip_id
    ) a
    where a.nvtr > 1
)

-- this part grabs the catch/trip info from the apportionment table, but only for trips with >1 subtrip

, trips as (  
       select d.permit
        , d.dmis_trip_id
        , extract(year from d.record_land) as year
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.negear
        , d.mesh
        , d.meshgroup
        , d.area
        , d.carea
        , round(sum(d.pounds)) as subtrip_kall
    , o.link1
    from mtrips m
    left join apsd.bg_cams_catch_mock d on m.dmis_trip_id = d.dmis_trip_id
--    from apsd.cams_apport d
    left join (  --adds observer link field
     select *
     from dmis.d_match_obs_link
    ) o
    on o.dmis_trip_id = d.dmis_trip_id
    
    group by 
        d.permit
        , extract(year from d.record_land)
        , d.dmis_trip_id
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.negear
        , d.mesh
        , d.meshgroup
        , d.area
        , d.carea
        , o.link1
)

-- this part gets observer data

, obs as (select * from obs_cams_prorate)
--, obs as (
----        select o.*
--select o.link3
--    , link1
--    , o.area as obs_area
--    , o.negear as obs_gear
--    , round(o.meshsize, 0) as obs_mesh
--    , o.meshgroup
--    , substr(nespp4, 1, 3) as NESPP3
--    , o.hailwt
--    , o.catdisp
--    , SUM(case when catdisp = 1 then o.hailwt else 0 end) OVER(PARTITION BY o.link3) as obs_haul_kall
--    , case when catdisp = 0 then o.hailwt else 0 end  as discard
--
--    from (
--        select * from apsd.BG_OBDBS_TABLES_5_2018
--        union all
--        select * from apsd.BG_OBDBS_TABLES_5_2019
--    ) o
--    
--
--)

-- this would link to the master gear table

, mgear as (
    select gear_code_fid
    , RIGHT('000' + negear, 3) as negear
    , vtr_gear_code
    from apsd.master_gear
)

    select c.*
    , o.link3
    , o.obs_area as obs_area
    , o.nespp3
    , o.discard_prorate as discard
    , o.obs_haul_kept
    , o.obs_haul_kall_trip+obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , o.meshgroup as obs_meshgroup
    , m.GEAR_CODE_FID
from trips c
    left outer join (
        select * from obs -- where nespp3 = 212 
    ) o
on (o.link1 = c.link1 AND c.meshgroup = o.meshgroup AND c.negear = o.obs_gear AND c.CAREA = o.OBS_AREA)
left join (SELECT * from mgear) m
on (c.GEARCODE = m.VTR_GEAR_CODE) 

/

select *
from bg_obs_cams_tmp1

--/
--select listagg(GEARCODE, ',') within group (order by dmis_trip_id) multi_gears
--, dmis_trip_id--* --count(distinct(dmis_trip_id))
---- , count(distinct(vtrserno))
--from (select dmis_trip_id, distinct(GEARCODE) from bg_obs_cams_tmp1 group by dmis_trip_id)
--group by dmis_trip_id
;

-- now make a bigger table that has all trips.. not just ones with multpile subtrips
drop table bg_obs_cams_tmp2
/

create table bg_obs_cams_tmp2 as 
-- this part selects trips with more than one subtrip
--
--with mtrips as (
--select dmis_trip_id
--    from (
--        select
--         count(distinct(vtrserno)) nvtr
--        , count(distinct(docid)) ndocid
--        , dmis_trip_id
--        from apsd.bg_cams_catch_mock
--        group by dmis_trip_id
--    ) a
--    where a.nvtr > 1
--)

-- this part grabs the catch/trip info from the apportionment table, but only for trips with >1 subtrip

with trips as (  
       select d.permit
        , d.dmis_trip_id
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end as region
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end as halfofyear
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.geartype
        , d.negear
        , d.mesh
        , NVL(d.meshgroup, 'na') as meshgroup
        , d.area
        , d.carea
        , round(sum(d.pounds)) as subtrip_kall
    , o.link1
    from apsd.bg_cams_catch_mock d
--    from apsd.cams_apport d
    left join (  --adds observer link field
     select *
     from dmis.d_match_obs_link
    ) o
    on o.dmis_trip_id = d.dmis_trip_id
    
    group by 
        d.permit
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end 
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end 
        , d.dmis_trip_id
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.geartype
        , d.negear
        , d.mesh
        , NVL(d.meshgroup, 'na')
        , d.area
        , d.carea
        , o.link1
)

-- this part gets observer data

, obs as (select * from obs_cams_prorate)

, mgear as (
    select gear_code_fid
    , RIGHT('000' + negear, 3) as negear
    , vtr_gear_code
    from apsd.master_gear
)

    select c.*
    , o.link3
    , o.obs_area as obs_area
    , o.nespp3
    , o.discard_prorate as discard
    , o.obs_haul_kept
    , o.obs_haul_kall_trip+obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    , m.GEAR_CODE_FID
from trips c
    left outer join (
        select * from obs 
    ) o
--on (o.link1 = c.link1 AND c.meshgroup = o.meshgroup AND c.negear = o.obs_gear AND c.CAREA = o.OBS_AREA)
on (o.link1 = c.link1 AND c.negear = o.obs_gear AND c.meshgroup = o.meshgroup AND c.CAREA = o.OBS_AREA)

left outer join (SELECT * from mgear) m
on (c.GEARCODE = m.VTR_GEAR_CODE) 

/
/*

select *
from bg_obs_cams_tmp2

/

select distinct(nespp3)
from bg_obs_cams_tmp2

/

select distinct(geartype)
from bg_obs_cams_tmp2
where discard > 0

/

select obs_gear --geartype
--, count(distinct(dmis_trip_id)) n_trips
, count(distinct(link1)) n_obs
--from bg_obs_cams_tmp2
from obs_cams_prorate
where year = 2019
group by obs_gear --geartype
*/
/
/*-----------------------------------------------------------------------

Now add the trip attributes code
add scallop trips metrics
sector ID
EFP
declaration
-----------------------------------------------------------------------*/
drop table bg_cams_catch_ta_mock
/

CREATE TABLE bg_cams_catch_ta_mock AS
SELECT a.dmis_trip_id
, a.docid
, a.vtrserno
, a.AREA
, a.CAREA
, a.record_land
--, a.DLR_STATE
--, a.FISHING_YEAR
--, a.LINK1
, a.NESPP3
, a.NESPP4
, a.LIVE as POUNDS
, a.MESH
--, a.MONTH
, a.PERMIT 
, a.sector_id
, a.activity_code_1
, a.activity_code_2
, a.activity_code_3
, permit_EFP_1
, permit_EFP_2
, permit_EFP_3
, permit_EFP_4
, extract(year from a.record_land) as year
, extract(month from a.record_land) as month
--, a.YEAR||a.ID yearid
, b.gearnm
, b.GEARCODE
, b.NEGEAR
, b.NEGEAR2
--,  (CASE WHEN (month IN (1,2,3,4,5,6)) then 1 
--          WHEN (month IN (7,8,9,10,11,12)) then 2 
--        END) as halfofyear
        , (CASE WHEN area < 600 THEN 'N'
                WHEN area >= 600 THEN 'S'
                ELSE 'Other'
                END) as region
,  (case when area in (511, 512, 513, 514, 515, 521, 522, 561) 
                then 'N' 
                 when area  NOT IN (511, 512, 513, 514, 515, 521, 522, 561)
               then 'S'
                 else 'Unknown' end)  as stockarea 
, (CASE WHEN negear IN ('070') THEN 'Beach Seine'
			    WHEN negear IN ('020', '021') THEN 'Handline'
  			   	WHEN negear IN ('010') THEN 'Longline'
				WHEN negear IN ('170', '370') THEN 'Mid-water Trawl, Paired and Single'
				WHEN negear IN ('350','050') THEN 'Otter Trawl'
				WHEN negear IN ('057') THEN 'Otter Trawl, Haddock Separator'
				WHEN negear IN ('054') THEN 'Otter Trawl, Ruhle'
				WHEN negear IN ('053') THEN 'Otter Trawl, Twin'
				WHEN negear IN ('181') THEN 'Pots+Traps, Fish'
				WHEN negear IN ('186') THEN 'Pots+Traps, Hagfish'
				WHEN negear IN ('120','121', '123') THEN 'Purse Seine'
				WHEN negear IN ('132') THEN 'Scallop Dredge'
				WHEN negear IN ('052') THEN 'Scallop Trawl'
				WHEN negear IN ('058') THEN 'Shrimp Trawl'
				WHEN negear IN ('100', '105','110', '115','116', '117','500') THEN 'Sink, Anchor, Drift Gillnet'
				WHEN negear NOT IN 
				('070','020', '021','010','170','370','350','050','057','054','053','181',
				'186','120','121', '123','132','052','058','100', '105', '110','115','116', '117','500') THEN 'Other' 
				WHEN negear IS NULL THEN 'Unknown'
				END) as  geartype
,                 
(CASE WHEN mesh < 5.5 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'sm'
	  WHEN mesh BETWEEN 5.5 AND 7.99 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'lg'
	  WHEN mesh >= 8 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'xlg'
	  ELSE NULL
	  END)  as meshgroup
,  (CASE WHEN activity_code_1 NOT LIKE 'SES%' THEN 'all'
			    WHEN activity_code_1 LIKE 'SES-SCG%' THEN 'GEN'
  			   	WHEN activity_code_1 LIKE 'SES-SAA%' THEN 'LIM'
                WHEN activity_code_1 LIKE 'SES-SCA%' THEN 'LIM'
                WHEN activity_code_1 LIKE 'SES-RSA%' THEN 'LIM'
                WHEN activity_code_1 LIKE 'SES-SWE%' THEN 'LIM'
				ELSE 'Unknown'
				END) as tripcategory   
, (CASE WHEN activity_code_1 NOT LIKE 'SES%'
                    OR activity_code_1 LIKE 'SES-PWD%' 
                THEN 'all'
			    WHEN activity_code_1 LIKE 'SES-SAA%' 
                  OR activity_code_1 LIKE 'SES-RSA-DM%'                  
                  OR activity_code_1 LIKE 'SES-RSA-HC%'
                   OR activity_code_1 LIKE   'SES-RSA-1S%'
                   OR activity_code_1 LIKE   'SES-RSA-2S%'
                    OR activity_code_1 LIKE  'SES-RSA-ET%'
                     OR activity_code_1 LIKE 'SES-RSA-NS%'
                     OR activity_code_1 LIKE 'SES-RSA-MA%'
                     OR activity_code_1 LIKE 'SES-RSA-EF%'
                     OR activity_code_1 LIKE 'SES-RSA-NH%'
                     OR activity_code_1 LIKE 'SES-RSA-NW%'
                     OR activity_code_1 LIKE 'SES-RSA-NN%'
                     THEN 'AA'
  			   	WHEN activity_code_1 LIKE 'SES-SCA-OP%'
                     OR activity_code_1 LIKE 'SES-RSA-OP%'
                     OR activity_code_1 LIKE 'SES-RSA-XX%'
                     OR activity_code_1 LIKE 'SES-SWE-OP%'
                      OR activity_code_1 LIKE 'SES-SCG-OP%'
                      THEN 'OPEN'
				ELSE 'Unknown'
				END) as accessarea              
    FROM (
        select a.*
        , ta.sector_id
        , ta.activity_code_1
        , ta.activity_code_2
        , ta.activity_code_3
        , permit_EFP_1
        , permit_EFP_2
        , permit_EFP_3
        , permit_EFP_4
        from 
        apsd.cams_apport_20201222 a,
        apsd.cams_trip_attribute ta
        WHERE
        a.dmis_trip_id = ta.dmis_trip_id
      ) a
  
--FROM apsd.dmis_all_years  a 
    LEFT OUTER JOIN vtr.vlgear b
ON a.GEARCODE = b.GEARCODE
--where a.year = 2019

/
UPDATE bg_cams_catch_ta_mock a
SET meshgroup = 'lg'
WHERE a.negear IN ('054', '057') 
/
UPDATE bg_cams_catch_ta_mock a
SET a.geartype = 'Scallop Dredge'
WHERE a.nespp3 = '800' 
AND a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/
UPDATE bg_cams_catch_ta_mock a
SET a.geartype = 'Other'
WHERE a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/
UPDATE bg_cams_catch_mock
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl, Twin'
/                
/*UPDATE bg_cams_catch_mock
SET geartype = 'Otter Trawl'
WHERE geartype = 'Otter Trawl, Twin'*/
/                
UPDATE bg_cams_catch_ta_mock
SET meshgroup = 'lg'
WHERE geartype = 'Sink, Anchor, Drift Gillnet'
AND meshgroup = 'sm'
/   
UPDATE bg_cams_catch_ta_mock
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl'
AND meshgroup = 'xlg'




/

drop table bg_obs_cams_tmp3
/

create table bg_obs_cams_tmp3 as 

with trips as (  
       select d.permit
        , d.dmis_trip_id
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end as region
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end as halfofyear
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.geartype
        , d.negear
        , d.mesh
        , NVL(d.meshgroup, 'na') as meshgroup
        , d.area
        , d.carea
        , round(sum(d.pounds)) as subtrip_kall
        , d.sector_id
        , d.activity_code_1
        , d.activity_code_2
        , d.activity_code_3
        , d.permit_EFP_1
        , d.permit_EFP_2
        , d.permit_EFP_3
        , d.permit_EFP_4
        , d.tripcategory
        , d.accessarea
    , o.link1
    from apsd.bg_cams_catch_ta_mock d
--    from apsd.cams_apport d
    left join (  --adds observer link field
     select *
     from dmis.d_match_obs_link
    ) o
    on o.dmis_trip_id = d.dmis_trip_id
    
    group by 
        d.permit
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end 
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end 
        , d.dmis_trip_id
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.geartype
        , d.negear
        , d.mesh
        , NVL(d.meshgroup, 'na')
        , d.area
        , d.carea
        , d.sector_id
        , d.activity_code_1
        , d.activity_code_2
        , d.activity_code_3
        , d.permit_EFP_1
        , d.permit_EFP_2
        , d.permit_EFP_3
        , d.permit_EFP_4
        , d.tripcategory
        , d.accessarea
        , o.link1
)

-- this part gets observer data

, obs as (select * from obs_cams_prorate)

, mgear as (
    select gear_code_fid
    , RIGHT('000' + negear, 3) as negear
    , vtr_gear_code
    from apsd.master_gear
)

    select c.*
    , o.link3
    , o.obs_area as obs_area
    , o.nespp3
    , o.discard_prorate as discard
    , o.obs_haul_kept
    , o.obs_haul_kall_trip+obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    , m.GEAR_CODE_FID
from trips c
    left outer join (
        select * from obs 
    ) o
--on (o.link1 = c.link1 AND c.meshgroup = o.meshgroup AND c.negear = o.obs_gear AND c.CAREA = o.OBS_AREA)
on (o.link1 = c.link1 AND c.negear = o.obs_gear AND c.meshgroup = o.meshgroup AND c.CAREA = o.OBS_AREA)

left outer join (SELECT * from mgear) m
on (c.GEARCODE = m.VTR_GEAR_CODE) 

/

/

select sum(subtrip_kall)
, sum(discard)
--, nespp3
, geartype
--, obs_gear
--, meshgroup
--, Sector_id
--, accessarea
--, tripcategory
--, carea
from bg_obs_cams_tmp3
where nespp3 is not null
and year = 2019
group by geartype
--, obs_gear, meshgroup, Sector_id
--, accessarea
--, tripcategory
--, carea

;




select dmis_trip_id
, count(distinct(GEARCODE))
, count(distinct(MESHGROUP))
, count(distinct(AREA))
from bg_obs_cams_tmp2
group by dmis_trip_id

/



