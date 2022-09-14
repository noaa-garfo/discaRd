 /*
 
 cams obs catch table that preserves ALL LINK1
 aims to solve the issue of dropped link1 when there are multiple LINK1/VTR
 
 old method was to use min(link1)
 
 new method creates a new matchign table that has 
 link1
 link3
 camsid
 min_link1
 
 min_link1 is a reference for matching in later steps. doing it this way preserves ALL link1 and link3 designations. 
 the most important part is preseveing link3 which are then matched to subtrips.
 
 min_link1 is carried through
 
 ben galuardi
 6/22/22
 
 */
 
 
drop table cams_obs_catch_test
/ 
 create table cams_obs_catch_test as 
 
 with obs1 as (
select a.*
    from (
 select o.link3
            , link1
            , vtrserno
            , extract(year from dateland) as year
            , o.month
            , o.obsrflag
            , o.area as obs_area
            , o.negear as obs_gear
            , o.geartype
            , round(o.meshsize, 0) as obs_mesh
            , o.meshgroup
            , substr(nespp4, 1, 3) as NESPP3
            , SUM(case when catdisp = 0 then o.livewt else 0 end) as discard
            , SUM(case when catdisp = 1 then o.livewt else 0 end) as obs_haul_kept
        
            from (
			    select * from maps.cams_obdbs_2017
                union all
                select * from maps.cams_obdbs_2018
                union all
                select * from maps.cams_obdbs_2019
				union all
                select * from maps.cams_obdbs_2020
                union all
                select * from maps.cams_obdbs_2021
            )
            o
            
         
          group by  o.link3
            , link1
            , vtrserno
            , o.month
            , o.obsrflag
            , o.area 
            , o.geartype
            , o.negear 
            , round(o.meshsize, 0)
            , o.meshgroup
            , substr(nespp4, 1, 3)
            , extract(year from dateland)
) a

group by link3
            , link1
            , vtrserno
            , year
            , month
            , obsrflag
            , obs_area
            , obs_gear
            , geartype
            , obs_mesh
            , meshgroup
            , NESPP3
            , discard
            , obs_haul_kept
)
, link3_match as ( 
   select m.camsid
    , min(obs_link1) as min_link1
    , count(distinct(obs_link1)) OVER(PARTITION BY CAMSID) as n_obslink1
    , m.obs_link1
    , o.link1
    , o.link3
    , m.obs_vtr
    from maps.match_obs m
  left join  (
                 select link1, link3
                 from
                 obdbs.obhau@NOVA
                 where link3 is not null
                 union all
                 select link1, link3
                 from
                 obdbs.asmhau@NOVA
                 where link3 is not null
             )  o 
    on m.obs_link1 = o.link1
     group by m.camsid
    , m.obs_link1
    , o.link1
    , o.link3
    , m.obs_vtr
    
    order by n_obslink1 desc
)
, obstrp_ext as (
 select distinct(link1) link1 
 from obdbs.obtrp@NOVA
 where tripext in ('C','X')
 
  union all
 
 select distinct(link1) link1 
 from obdbs.asmtrp@NOVA
 where tripext in ('C','X')

)
,trips as (  
       select d.permit
        , d.camsid
        , d.year
        , d.month
        , d.date_trip
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end as halfofyear
        , d.docid
        , d.vtrserno
        , d.camsid || '_' || d.subtrip as cams_subtrip
        , d.geartype
        , d.negear
        , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
        , NVL(d.mesh_cat, 'na') as meshgroup
        , d.area
        , round(sum(d.LIVLB)) as subtrip_kall
        , d.sectid
        , d.GF
        , d.activity_code_1
        , d.activity_code_2
        , d.EM
        , redfish_exemption
        , closed_area_exemption
        , sne_smallmesh_exemption
        , xlrg_gillnet_exemption
        , d.tripcategory
        , d.accessarea
    , o.min_link1
    , count(distinct(vtrserno)) over(partition by min_link1) as nvtr_link1 -- count how many vtrs for each link1
    , count(distinct(area)) over(partition by min_link1) as narea_link1 -- count how many VTR areas for each link1
    from MAPS.CAMS_LANDINGS d
    left join (  --adds observer link field
         select * 
         from link3_match
        ) o
       
    on  o.camsid = d.camsid 
    
    left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g
     on d.NEGEAR = g.VTR_NEGEAR
    
    WHERE d.year >= 2017 -- reduces the table size.. we aren't going back in time too far for discards
    
    group by 
        d.permit
        , d.year
        , d.month
        , d.date_trip
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end 
        , d.camsid
        , d.docid
        , d.vtrserno
        , d.camsid || '_' || d.subtrip
        , d.geartype
        , d.negear
        , NVL(g.SECGEAR_MAPPED, 'OTH')
        , NVL(d.mesh_cat, 'na')
        , d.area
        , d.sectid
        , d.GF
        , d.activity_code_1
        , d.activity_code_2
        , d.EM
        , d.redfish_exemption
        , d.closed_area_exemption
        , d.sne_smallmesh_exemption
        , d.xlrg_gillnet_exemption
        , d.tripcategory
        , d.accessarea
        , o.min_link1
)

-- get observer data
-- join to gearmapping for match

, obs as (
      select a.*
            , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
            , i.ITIS_TSN
            , m.min_link1
--            , i.ITIS_GROUP1
        from OBS1 a
          left join (
            select distinct(NEGEAR) as OBS_NEGEAR
            , SECGEAR_MAPPED
            from maps.STG_OBS_VTR_GEARMAP
            where NEGEAR is not null          
          ) g
          on a.OBS_GEAR = g.OBS_NEGEAR
          
         left join(select * from maps.CFG_NESPP3_ITIS ) i  --where SRCE_ITIS_STAT = 'valid'
         on a.NESPP3 = i.DLR_NESPP3
         
         left join (select * from link3_match) m
         on a.link1 = m.link1
         
      )

, trips_0 as (

  select t.*
    , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obsrflag
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
, o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup

     from trips t
     left join (select * from obs ) o
     on (t.min_link1 = o.min_link1)
 
    where (t.min_LINK1 is null or t.nvtr_link1 = 0)   -- this will capture clam trips with no vtr

)

-- trips with single link1 (one subtrip)
, trips_1 
 as (  
  select t.*
  , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obsrflag
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
d
, o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 

   ) t
      left join (select * from obs ) o
        on (t.min_link1 = o.min_link1)
  where nvtr_link1 = 1
  and t.min_link1 is not null
  and t.vtrserno is not null

)
, trips_2_area_1 as ( 

   select t.*
  , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obsrflag
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
    , o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
  on (o.min_link1 = t.min_link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND o.meshgroup = t.meshgroup)  -- don't use area when narea = 1
  where (nvtr_link1 > 1 AND nvtr_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and narea_link1 = 1
  and t.min_link1 is not null
  and t.cams_subtrip is not null

)

, trips_2_area_2 as ( 

   select t.*
  , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obsrflag
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
    , o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
        on (o.min_link1 = t.min_link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND o.meshgroup = t.meshgroup AND o.OBS_AREA = t.AREA) -- use area when narea >1
  where (nvtr_link1 > 1 AND nvtr_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and narea_link1 > 1
  and t.min_link1 is not null
  and t.cams_subtrip is not null

)

, obs_catch as 
( 
    select * from trips_0
    union all
    select * from trips_1
    union all
    select * from trips_2_area_1
    union all
    select * from trips_2_area_2
)

, obs_catch_2 as 
( 

/* add OBS KALL amounts, prorated discard and find duped subtrips */

     select a.*
    , count(distinct(a.cams_subtrip)) OVER(PARTITION BY a.link3) as n_subtrips_link3  -- finds duped link3.. 
    , round(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip)) as obs_haul_kall_trip
    , round(SUM(case when a.obsrflag = 0 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip)) as obs_nohaul_kall_trip
    --, round(SUM(a.obs_haul_kept)  OVER(PARTITION BY a.cams_subtrip)) 
    , round(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip)) as OBS_KALL  -- will be the same as obs_haul_kall_trip
    , SUM(a.obs_haul_kept) OVER(PARTITION BY a.cams_subtrip) / 
       NULLIF(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip),0) as prorate
    , round((SUM(a.obs_haul_kept) OVER(PARTITION BY a.cams_subtrip) / 
     NULLIF(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip),0)*a.discard), 2) as discard_prorate
    from obs_catch a
)

/* now deal with link3 dupes  */

select ACCESSAREA
,ACTIVITY_CODE_1
,AREA
,CAMSID
,CAMS_SUBTRIP
,CLOSED_AREA_EXEMPTION
, case when n_subtrips_link3 > 1 THEN DISCARD/n_subtrips_link3 ELSE DISCARD end as DISCARD
, case when n_subtrips_link3 > 1 THEN DISCARD_PRORATE/n_subtrips_link3 ELSE DISCARD_PRORATE end as DISCARD_PRORATE
,DATE_TRIP
,DOCID
,EM
,GEARTYPE
,GF
,HALFOFYEAR
,ITIS_TSN
,min_LINK1
,LINK3
,MESHGROUP
,MONTH
,NEGEAR
,NESPP3
,NVTR_LINK1
,OBSRFLAG
,OBSVTR
,OBS_AREA
,OBS_GEAR
, case when n_subtrips_link3 > 1 THEN OBS_HAUL_KALL_TRIP/n_subtrips_link3 ELSE OBS_HAUL_KALL_TRIP end as OBS_HAUL_KALL_TRIP
, case when n_subtrips_link3 > 1 THEN OBS_HAUL_KEPT/n_subtrips_link3 ELSE OBS_HAUL_KEPT end as OBS_HAUL_KEPT 
, case when n_subtrips_link3 > 1 THEN OBS_NOHAUL_KALL_TRIP/n_subtrips_link3 ELSE OBS_NOHAUL_KALL_TRIP end as OBS_NOHAUL_KALL_TRIP  
, case when n_subtrips_link3 > 1 THEN OBS_KALL/n_subtrips_link3 ELSE OBS_KALL end as OBS_KALL  
,OBS_LINK1
,OBS_MESH
,OBS_MESHGROUP
,PERMIT
,PRORATE
,REDFISH_EXEMPTION
,SECGEAR_MAPPED
,SECTID
,SNE_SMALLMESH_EXEMPTION
,SUBTRIP_KALL
,TRIPCATEGORY
,VTRSERNO
,XLRG_GILLNET_EXEMPTION
,YEAR

from obs_catch_2

/
CREATE INDEX yearidx ON CAMS_OBS_CATCH_TEST(YEAR, MONTH)
/
CREATE INDEX itisidx ON CAMS_OBS_CATCH_TEST(ITIS_TSN)
;
commit

/
 
 
 -- test new/old cams_obs_catch with susan  snoops 

select sum(OBS_HAUL_KEPT) OBS_HAUL_KEPT
, link3
, 'cams_obs_catch' as source
from cams_obs_catch
where camsid = '330920_20170717170000_5001206'
and year = 2017
group by link3


union all

select sum(OBS_HAUL_KEPT) OBS_HAUL_KEPT
, link3
, 'cams_obs_catch_test' as source
from cams_obs_catch_test
where camsid = '330920_20170717170000_5001206'
and year = 2017
group by link3


/
-- and l.camsid = '330920_20170717170000_5001206' -- one of susans examples
--    and camsid = '330489_20170314030000_4970264'   -- camsid with 3 link3 and tons of hauls


-- 
-- select obs_vtr
----, permit
--, obs_link1
--, count(distinct(link3)) over(partition by obs_link1) as n_link3_obs
--, count(distinct(obs_link1)) OVER(PARTITION BY CAMSID) as n_obslink1
----, min(obs_link1) as min_link1  -- this is the minimum link1 for the vtr
--, camsid
--from (
--    select l.*
--    from link3_match l, obstrp_ext o
--    where l.obs_vtr is not null        
--    AND l.OBS_LINK1 in o.link1       
----    and l.camsid = '330920_20170717170000_5001206' -- one of susans examples
--    and camsid = '330489_20170314030000_4970264'  -- camsid with 3 link3 and tons of hauls
--)
--
--where obs_link1 = '010201707Q01003'  --susans example
--
--group by obs_vtr, permit, camsid --, obs_link1
order by n_obslink1 desc, camsid, obs_link1
/

select *
from maps.cams_obs_catch
--where camsid = '330920_20170717170000_5001206'
where  camsid = '330489_20170314030000_4970264'  -- camsid with 3 link3 and tons of hauls
and year = 2017
--group by link1

