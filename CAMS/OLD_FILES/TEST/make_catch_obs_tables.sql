1/*

    BEN GALUARDI
    
    12/23/20
    
    CREATE MOCKUP OF CATCH TABLE FROM MAPS USING DMIS_TRIP_ID AND JOINING TO LINK3 AND MATCH GEAR AND MESH

*/

drop table bg_cams_catch_mock
/
drop table bg_cams_catch
/


/*-----------------------------------------------------------------------

Now add the trip attributes code
add scallop trips metrics
sector ID
EFP
declaration
-----------------------------------------------------------------------*/

CREATE TABLE bg_cams_catch AS

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
, redfish_exemption
, closed_area_exemption
, sne_smallmesh_exemption
, xlrg_gillnet_exemption
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
				ELSE 'all'
				END) as tripcategory   
, (CASE WHEN activity_code_1 NOT LIKE 'SES%'
                    OR activity_code_1 LIKE 'SES-PWD%' 
                THEN 'all'
			    WHEN activity_code_1 LIKE 'SES-SAA%' 
                 OR activity_code_1 LIKE 'SES%DM%'                  
                  OR activity_code_1 LIKE 'SES%HC%'
                   OR activity_code_1 LIKE   'SES%1S%'
                   OR activity_code_1 LIKE   'SES%2S%'
                    OR activity_code_1 LIKE  'SES%ET%'
                     OR activity_code_1 LIKE 'SES%NS%'
                     OR activity_code_1 LIKE 'SES%MA%'
                     OR activity_code_1 LIKE 'SES%EF%'
                     OR activity_code_1 LIKE 'SES%NH%'
                     OR activity_code_1 LIKE 'SES%NW%'
                     OR activity_code_1 LIKE 'SES%NN%'
--                  OR activity_code_1 LIKE 'SES-RSA-DM%'                  
--                  OR activity_code_1 LIKE 'SES-RSA-HC%'
--                   OR activity_code_1 LIKE   'SES-RSA-1S%'
--                   OR activity_code_1 LIKE   'SES-RSA-2S%'
--                    OR activity_code_1 LIKE  'SES-RSA-ET%'
--                     OR activity_code_1 LIKE 'SES-RSA-NS%'
--                     OR activity_code_1 LIKE 'SES-RSA-MA%'
--                     OR activity_code_1 LIKE 'SES-RSA-EF%'
--                     OR activity_code_1 LIKE 'SES-RSA-NH%'
--                     OR activity_code_1 LIKE 'SES-RSA-NW%'
--                     OR activity_code_1 LIKE 'SES-RSA-NN%'
                     THEN 'AA'
  			   	WHEN activity_code_1 LIKE 'SES-SCA-OP%'
                     OR activity_code_1 LIKE 'SES-RSA-OP%'
                     OR activity_code_1 LIKE 'SES-RSA-XX%'
                     OR activity_code_1 LIKE 'SES-SWE-OP%'
                      OR activity_code_1 LIKE 'SES-SCG-OP%'
                      OR activity_code_1 LIKE 'SES-SCG-SN%'
                      OR activity_code_1 LIKE 'SES-SCG-NG%'
                      THEN 'OPEN'
				ELSE 'all'
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
        , redfish_exemption
        , closed_area_exemption
        , sne_smallmesh_exemption
        , xlrg_gillnet_exemption
        from 
          apsd.cfders_vtr_apportionment a,
          apsd.cams_trip_attribute ta
        WHERE
        a.dmis_trip_id = ta.dmis_trip_id
      ) a
  
--FROM apsd.dmis_all_years  a 
    LEFT OUTER JOIN vtr.vlgear b
    ON a.GEARCODE = b.GEARCODE
--where a.year = 2019

/
UPDATE bg_cams_catch a
SET meshgroup = 'lg'
WHERE a.negear IN ('054', '057') 
/
UPDATE bg_cams_catch a
SET a.geartype = 'Scallop Dredge'
WHERE a.nespp3 = '800' 
AND a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/
UPDATE bg_cams_catch a
SET a.geartype = 'Other'
WHERE a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/
UPDATE bg_cams_catch
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl, Twin'
/                
/*UPDATE bg_cams_catch_mock
SET geartype = 'Otter Trawl'
WHERE geartype = 'Otter Trawl, Twin'*/
/                
UPDATE bg_cams_catch
SET meshgroup = 'lg'
WHERE geartype = 'Sink, Anchor, Drift Gillnet'
AND meshgroup = 'sm'
/   
UPDATE bg_cams_catch_ta_mock
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl'
AND meshgroup = 'xlg'

;


/*-----------------------------------------------------------------------------------------------------

now merge with obdbs

match on gear (NEGEAR), mesh, link1 and AREA

------------------------------------------------------------------------------------------------------*/  

drop table bg_obs_cams_tmp3
/

drop table bg_cams_obs_catch

/


create table bg_cams_obs_catch as 

with ulink as (
    select count(distinct(link1)) nlink1
    , obs_vtr
    from dmis.d_match_obs_link
    where link1 is not null
    AND link1 in (
                 select distinct(link1) link1
                 from
                 obdbs.obhau@NOVA
                 where link3 is not null
                 union all
                 select distinct(link1) link1
                 from
                 obdbs.asmhau@NOVA
                 where link3 is not null
             )    
    
    group by obs_vtr
    order by nlink1 desc
)
, vtr_link as (
     select obs_vtr
    , permit
    , min(link1) as link1  -- this is the minimum link1 for the vtr
    , dmis_trip_id
    from (
        select a.*
        from dmis.d_match_obs_link a, ulink l
        where a.obs_vtr in (l.obs_vtr)
        and l.obs_vtr is not null        
    )
    --where permit = 410126
    group by obs_vtr, permit, dmis_trip_id
    order by permit, obs_vtr
)
,trips as (  
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
        , substr(d.vtrserno, 1, 13) vtrserno
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
        , redfish_exemption
        , closed_area_exemption
        , sne_smallmesh_exemption
        , xlrg_gillnet_exemption
        , d.tripcategory
        , d.accessarea
    , o.link1
--    from apsd.bg_cams_catch_ta_mock d
    from apsd.bg_cams_catch d
--    from apsd.cams_apport d
    left join (  --adds observer link field
    
         select * 
         from vtr_link
        
        /* this code still     */    
--             select *
--        --     from dmis.d_match_obs_link
--             from dmis.d_match_obs_link
--             where link1 in (
--                 select distinct(link1) link1
--                 from
--                 obdbs.obhau@NOVA
--        --         where year >=2018
--                 union all
--                 select distinct(link1) link1
--                 from
--                 obdbs.asmhau@NOVA
--        --         where year >=2018
--             )
    ) o
--    on ( o.obs_vtr = substr(d.vtrserno, 1, 13))
--    on o.obs_vtr = d.vtrserno --substr(d.vtrserno, 1, 13)
    on  o.dmis_trip_id = d.dmis_trip_id 
    
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
        , d.redfish_exemption
        , d.closed_area_exemption
        , d.sne_smallmesh_exemption
        , d.xlrg_gillnet_exemption
        , d.tripcategory
        , d.accessarea
        , o.link1
)

-- this part gets observer data

, obs as (select * from obs_cams_prorate)

--, mgear as (
--    select gear_code_fid
--    , RIGHT('000' + negear, 3) as negear
--    , vtr_gear_code
--    from apsd.master_gear
--)

    select c.*
    , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obs_area as obs_area
    , o.nespp3
    , o.discard_prorate as discard
    , o.obs_haul_kept
    , o.obs_haul_kall_trip+obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
--    , m.GEAR_CODE_FID
from trips c
    left join (
        select * from obs 
    ) o
--on (o.link1 = c.link1 AND c.meshgroup = o.meshgroup AND c.negear = o.obs_gear AND c.CAREA = o.OBS_AREA)
on (o.link1 = c.link1 AND c.negear = o.obs_gear AND c.meshgroup = o.meshgroup AND c.CAREA = o.OBS_AREA)
--on (o.vtrserno = c.vtrserno)
--on (o.link1 = c.link1)

--left outer join (SELECT * from mgear) m
--on (c.GEARCODE = m.VTR_GEAR_CODE) 

/

;

select *
from bg_cams_obs_catch
/


/*-------------------------------------------------------------------------------------------------------------
-- this is the SQL call in R.. 
-------------------------------------------------------------------------------------------------------------*/


with obs_cams as (
   select year
	, month
	, region
	, halfofyear
	, area
	, vtrserno
	, link1
	, docid
	, dmis_trip_id
	, nespp3
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	, SECTOR_ID
	, tripcategory
	, accessarea
	, activity_code_1
    , permit_EFP_1
  , permit_EFP_2
  , permit_EFP_3
  , permit_EFP_4
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	, NVL(sum(discard),0) as discard
	, NVL(round(max(subtrip_kall)),0) as subtrip_kall
	, NVL(round(max(obs_kall)),0) as obs_kall
	, NVL(sum(discard)/round(max(obs_kall)), 0) as dk
	from apsd.bg_cams_obs_catch
--	where nespp3 is not null
	group by year, area, vtrserno, link1, nespp3, docid, NEGEAR, GEARTYPE
	, MESHGROUP, dmis_trip_id, month
	, region
	, halfofyear
	, sector_id
	, tripcategory
	, accessarea
	, activity_code_1
    , permit_EFP_1
  , permit_EFP_2
  , permit_EFP_3
  , permit_EFP_4
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	order by vtrserno desc
    ) 
    
-- select o.*
--, case when c.match_nespp3 is not null then c.match_nespp3 else o.nespp3 end as match_nespp3
--from obs_cams o
--left join (select * from apsd.s_nespp3_match_conv) c
--on o.nespp3 = c.nespp3
     select o.*
    , case when c.match_nespp3 is not null then c.match_nespp3 else o.nespp3 end as match_nespp3
    from obs_cams o, apsd.s_nespp3_match_conv c

;




