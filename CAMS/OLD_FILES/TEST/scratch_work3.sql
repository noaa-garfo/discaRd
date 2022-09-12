select substr(declaration, 12, 1) as gear
, count(pos_id) as n_polls
from vms_loader.result
where declaration like 'MNK%'
and utc_date >= '01-JAN-18'
group by substr(declaration, 12, 1)

;
select substr(declaration, 12, 1) as gear
, count(pos_id) as n_polls
from vms_loader.result
where declaration like 'NMS%'
and utc_date >= '01-JAN-18'
group by substr(declaration, 12, 1)


;
select *
from vms_loader.result
;

select distinct(vtr_gear_code)
, nespp3
, cams_gear_group
--, species_itis
from APSD.CAMS_GEARCODE_STRATA
where cams_gear_group > 0
--group by --nespp3
-- cams_gear_group
--,species_itis
;

select * from vtr.vlgear

;
-- obs table joined to CAMS GEAR GROUP TABLE
--select max(rownum)
--from obs_cams_prorate o

select o.link3
, o.link1
, o.vtrserno
, o.obs_gear
, o.geartype
, o.nespp3
, b.GEARNM
, b.GEARCODE
--, g.cams_gear_group
--, g.species_itis
from obs_cams_prorate o
LEFT OUTER JOIN (
 select  
 from vtr.vlgear where negear is not null
) b
ON o.OBS_GEAR = b.NEGEAR

left join (
    select *
    from APSD.CAMS_GEARCODE_STRATA
) g
on (o.nespp3 = g.nespp3 AND )

;

-- catch table by itself

select max(rownum)
from (
select a.*
, b.gearnm
, b.NEGEAR
from(
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

LEFT OUTER JOIN vtr.vlgear b
ON a.GEARCODE = b.GEARCODE
)

-- 1,316,056 rows

;



-- catch table joined to CAMS GEAR GROUP TABLE
select max(rownum)
from(
select a.*
, b.gearnm
, b.NEGEAR
, g.cams_gear_group
--, g.species_itis
from(
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
    apsd.cams_apport_20201222 a,
    apsd.cams_trip_attribute ta
    WHERE
    a.dmis_trip_id = ta.dmis_trip_id
) a

LEFT OUTER JOIN vtr.vlgear b
ON a.GEARCODE = b.GEARCODE

left join (
    select distinct(vtr_gear_code)
    --, nespp3
    , cams_gear_group
    --, species_itis
    from APSD.CAMS_GEARCODE_STRATA
    where cams_gear_group > 0   -- this makes the number of rows 1,475,978
) g
on ( a.gearcode = g.vtr_gear_code) --g.nespp3 = a.nespp3 AND
)

-- 2688854

;

select *
from bg_cams_obs_catch a
left join (
  select * 
  from APSD.CAMS_GEARCODE_STRATA
) g

on (a.gearcode = g.vtr_gear_code AND g.nespp3 = a.nespp3)
where a.gearcode is not null



-- 1,017,927 rows... ~ 300,000 too many!
;

--OBS DATA


select o.*
	, case when c.match_nespp3 is not null then c.match_nespp3 else o.nespp3 end as match_nespp3
	from obs_cams_prorate o
	left join (select * from apsd.s_nespp3_match_conv) c
	on o.nespp3 = c.nespp3
    LEFT OUTER JOIN vtr.vlgear b ON o.OBS_GEAR = b.NEGEAR  --1.9 million rows?!?!

--823,131 rows    

;

with obs_cams as (
   select year
	, month
	, region
	, halfofyear
	, carea
	, vtrserno
	, link1
	, docid
	, dmis_trip_id
	, nespp3
    , GEARCODE
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
	group by year, carea, vtrserno, link1, nespp3, docid, GEARCODE, NEGEAR, GEARTYPE
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
	order by vtrserno asc
    ) 

, strata as ( 
     select max(CAMS_GEAR_GROUP_B) CAMS_GEAR_GROUP
     , VTR_GEAR_CODE
    from ( 
     select a.* 
    , a.VTR_GEAR_CODE as GEARCODE
    , case when a.VTR_GEAR_CODE = 'HND' then '0' 
      else a.CAMS_GEAR_GROUP 
      end as CAMS_GEAR_GROUP_B
    from APSD.CAMS_GEARCODE_STRATA a    
    where NESPP3 = '081'
    )
    group by VTR_GEAR_CODE
)
--
--select count(distinct(vtrserno)) n_vtr
--, count(distinct(DMIS_TRIP_ID)) n_dmisid
--, count(distinct(LINK1)) n_link1
--, count(distinct(STRATA)) n_strata
----select distinct(GEARCODE)
--from (

     select case when MONTH in (1,2,3,4) then YEAR-1 else YEAR end as GF_YEAR
  , case when MONTH in (1,2,3) then YEAR-1 else YEAR end as SCAL_YEAR
  , o.*
    , c.match_nespp3
    , coalesce(c.match_nespp3, o.nespp3) as nespp3_final
    , NVL(s.CAMS_GEAR_GROUP, '0')||'-'||o.MESHGROUP||'-'||o.REGION||'-'||o.HALFOFYEAR as STRATA
    , NVL(s.CAMS_GEAR_GROUP, '0') CAMS_GEAR_GROUP
    from obs_cams o
    left join apsd.s_nespp3_match_conv c on o.nespp3 = c.nespp3
    left join (select * from strata) s 
    ON s.VTR_GEAR_CODE = o.GEARCODE
--    order by vtrserno desc
--)


;
select *
from apsd.s_nespp3_match_conv


    