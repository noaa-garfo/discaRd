/*

Build a version of CAMS_OBS_CATCH with offwatch haul columns 

retain all offwatch hauls

Ben Galuardi

10/5/22

*/


with trips as (   SELECT
    t.link1
    , h.link3
    , coalesce(d.link3, r.link3, c.link3) as offwatch_haul
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
    , h.catexist
    , case when h.area = '000' then null else h.area end as area
    , SUBSTR(s.nespp4,1,3) nespp3
    , s.nespp4
    , s.negear
    , s.fishdisp
    , s.catdisp
    , s.drflag
    , s.hailwt
    , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_scallop
--        , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_surfclam
--        , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_oceanquahog
--        , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_otherclam
    , coalesce(d.nespp4, r.nespp4) nespp4_off_watch
    , coalesce( case when  d.link3 is not null then '132' else null end  -- scallop dredge
                , case when r.link3 is not null then '052' else null end -- scallop trawl
                , case when c.link3 is not null then '382' else null end -- clam dredge
                , s.negear
                ) as negear_off_watch_coalesce
    , count(case when h.area = '000' then null else h.area end) over (order by t.link1, h.link3) as grp           
   --, EXISTS(select 'x' from em_hauls e where e.vtr_docid = i.docid)
    , 'OBDBS' as source
    
    from
    obdbs.obtrp@nova t 
    LEFT OUTER JOIN
    obdbs.obhau@nova h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obdbs.obspp@nova s ON h.link3 = s.link3
    LEFT OUTER JOIN 
    obdbs.OBSDO@NOVA d ON h.link3 = d.link3
    LEFT OUTER JOIN 
    obdbs.OBSTO@NOVA r ON h.link3 = r.link3
    LEFT OUTER JOIN 
    obdbs.OBCDO@NOVA c ON h.link3 = c.link3
    
   where t.year >= 2017 and t.year < 2022 
--   and t.link1 = '000202101M37001'
   and h.catexist = 1
   )
   
 select *
-- count(distinct(offwatch_haul))
-- , count(distinct(link1))
-- , case when offwatch_haul is null then 
-- , year
-- , area
 from trips 
 where offwatch_haul is not null
-- group by year, area
-- order by year, area

;
/*

 try keeping all link3 for offwatch hauls

*/

with obs1 as (
 select o.link3
            , case when offwatch_haul3 is null then 0 else 1 end as offwatch_haul
            , link1
--            , vtrserno
            , extract(year from dateland) as year
            , o.source
--            , o.month
            , o.obsrflag
            , o.fishdisp
            , o.area as obs_area
            , coalesce(o.negear, o.negear_offwatch) as obs_gear
            , o.geartype
            , round(o.meshsize, 0) as obs_mesh
            , o.meshgroup
            , substr(nespp4, 1, 3) as NESPP3
            , SUM(case when catdisp = 0 then o.livewt else 0 end) as discard
            , SUM(case when catdisp = 1 then o.livewt else 0 end) as obs_haul_kept
            
            from (
							  select o.*
							  , coalesce(d.link3, r.link3, c.link3) as offwatch_haul3
                             , coalesce( case when  d.link3 is not null then '132' else null end  -- scallop dredge
                                , case when r.link3 is not null then '052' else null end -- scallop trawl
                                , case when c.link3 is not null then '382' else null end -- clam dredge
                                , o.negear
                                 ) as negear_offwatch
							  from cams_obdbs_all_years o
							    LEFT OUTER JOIN 
							    obdbs.OBSDO@NOVA d ON o.link3 = d.link3
							    LEFT OUTER JOIN 
							    obdbs.OBSTO@NOVA r ON o.link3 = r.link3
							    LEFT OUTER JOIN 
							    obdbs.OBCDO@NOVA c ON o.link3 = c.link3
                                
                             
            ) o
          group by  o.link3
            , case when offwatch_haul3 is null then 0 else 1 end
            , coalesce(o.negear, o.negear_offwatch)
            , link1
--            , vtrserno
--            , o.month
            , o.obsrflag
            , o.fishdisp
            , o.area 
            , o.geartype
            , o.negear 
            , round(o.meshsize, 0)
            , o.meshgroup
            , substr(nespp4, 1, 3)
            , extract(year from dateland)
            , o.source

)

, owh as (
    select p.*
    , case when offwatch_haul_sum >1 then 1 else 0 end as offwatch_link1
    from (
    select o.*
    , (sum(offwatch_haul) over(partition by link1)) offwatch_haul_sum
    from obs1 o
    ) p
)


, ulink as (
       select  permit   
    , FIRST_VALUE(obs_link1)
         OVER (partition by camsid) AS min_link1
    , count(distinct(obs_link1)) over(partition by camsid) as N_link1_camsid
    , obs_link1 as link1
    , camsid
   from MATCH_OBS a
    where extract(year from a.obs_land) >= 2017
    and obs_link1 in (select distinct link1 from obs1 where link1 is not null)
    group by permit, camsid, obs_link1
    order by permit

 )

-- adds a link1 to cams landings for obs trips
,join_1 as ( 
select d.permit
        , d.camsid
        , d.year
        , d.month
        , d.date_trip
        , d.docid
        , d.vtrserno
        , d.cams_subtrip
        , d.geartype
        , d.negear
        , NVL(d.mesh_cat, 'xxx') as meshgroup
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
--    , o.link1
    , v.link1
    , v.min_link1
    , v.N_link1_camsid
     , count(distinct(d.cams_subtrip)) over(partition by link1) as nsubtrip_link1 -- count how many cams_subtrips for each link1
    , count(distinct(d.area)) over(partition by link1) as narea_link1
from (
        select a.*
        , a.camsid || '_' || a.subtrip as cams_subtrip -- add cams_subtrip here..
        from MAPS.CAMS_LANDINGS a
        where year >= 2017
 ) d
    left join (  --adds observer link field
         select * 
         from ulink
        ) v
       
 on  v.camsid = d.camsid 

 
group by d.permit
        , d.camsid
        , d.year
        , d.month
        , d.date_trip
        , d.docid
        , d.vtrserno
        , d.cams_subtrip 
        , d.geartype
        , d.negear
--        , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
        , NVL(d.mesh_cat, 'xxx') 
        , d.area
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
--    , o.link1
    , v.min_link1 
    , v.link1
    , v.N_link1_camsid
 
)

-- adds mapped gear for gear matching to trips that have a link1 from above
    
, trips as (
    select j.*
    , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
    from join_1 j
    left join (
          select distinct(NEGEAR) as VTR_NEGEAR
           , SECGEAR_MAPPED
          from MAPS.STG_OBS_VTR_GEARMAP
          where NEGEAR is not null
         ) g
     on j.NEGEAR = g.VTR_NEGEAR
)

, obs as (
      select a.*
            , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
            , i.ITIS_TSN
--            , i.ITIS_GROUP1
        from owh a
          left join (
            select distinct(NEGEAR) as OBS_NEGEAR
            , SECGEAR_MAPPED
            from maps.STG_OBS_VTR_GEARMAP
            where NEGEAR is not null          
          ) g
          on a.OBS_GEAR = g.OBS_NEGEAR
          
         left join(select * from maps.CFG_NESPP3_ITIS ) i  --where SRCE_ITIS_STAT = 'valid'
         on a.NESPP3 = i.DLR_NESPP3
      )

--select count(distinct(link1)) as n_link1
--, count(distinct(link3)) as n_link3
----, offwatch_link1
--, obs_area
--from obs
--group by obs_area

-- 
/* 
staged matching 

trips with no link1 (unobserved)
*/
, trips_null as (

  select t.*
    , null as link3
    , null as offwatch_haul
    , null as offwatch_link1
    , null as source
    , null as obsrflag
    , null as fishdisp
    , null as obs_area
    , null as nespp3
    , null as ITIS_TSN
    , null as discard
    , null as obs_haul_kept
    , null as  obs_gear
    , null as obs_mesh
    , 'xxx' as obs_meshgroup

     from trips t
--     left join (select * from obs ) o -- no joins here! 
--     on (t.link1 = o.link1)

--    where (t.LINK1 is null)  
    where (t.link1 is null) --maintaining this field as primary field from matching table
)  

-- trips with 000 area offwatch hauls; other hauls have areas.. gear/mesh may be an issue

, trips_owh as (

select t.*
    , o.link3
        , o.offwatch_haul
        , o.offwatch_link1
    , o.source
    , o.obsrflag
    , o.fishdisp
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
, o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'xxx') as obs_meshgroup
    from ( 
     select t.*
     from trips t 

   ) t
      left join (select * from obs ) o
     on (t.link1 = o.link1)  --maintaining link1 from matching table

      where nsubtrip_link1 = 1
--      and t.link1 is not null
      and t.link1 is not null
      and obs_area = '000'

)
-- obs trips with exactly one VTR

, trips_1 
 as (  
  select t.*
    , o.link3
        , o.offwatch_haul
        , o.offwatch_link1
    , o.source
    , o.obsrflag
    , o.fishdisp
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
, o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'xxx') as obs_meshgroup
    from ( 
     select t.*
     from trips t 

   ) t
      left join (select * from obs ) o
     on (t.link1 = o.link1)  --maintaining link1 from matching table

      where nsubtrip_link1 = 1
--      and t.link1 is not null
      and t.link1 is not null
      and obs_area <> '000'

)

-- multiple subtrips but only one area
, trips_2_area_1 as ( 

   select t.*
    , o.link3
        , o.offwatch_haul
        , o.offwatch_link1
    , o.source
    , o.obsrflag
    , o.fishdisp
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
    , o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'xxx') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
  on (o.link1 = t.link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND NVL(o.meshgroup, 'xxx') = NVL(t.meshgroup, 'xxx'))  -- don't use area when narea = 1
  where (nsubtrip_link1 > 1 AND nsubtrip_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and narea_link1 = 1
  and t.link1 is not null  --maintin naming from matching table
  and t.cams_subtrip is not null
  and obs_area <> '000'

)
-- trips with >1 subtrip and multiple areas on link1s
, trips_2_area_2 as ( 

   select t.*
    , o.link3
    , o.offwatch_haul
    , o.offwatch_link1
    , o.source
    , o.obsrflag
    , o.fishdisp    
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
    , o.discard
    , o.obs_haul_kept
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'xxx') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
        on (o.link1 = t.link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND NVL(o.meshgroup, 'xxx') = NVL(t.meshgroup, 'xxx') AND o.OBS_AREA = t.AREA) -- use area when narea >1
  where (nsubtrip_link1 > 1 AND nsubtrip_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and narea_link1 > 1
  and t.link1 is not null --maintain naming from matching table
  and t.cams_subtrip is not null
  and obs_area <> '000'

)

-- change the 'xxx' back to nulls for meshgroups

, obs_catch as 
( 
    select e.* 
    , nullif(e.meshgroup, 'xxx') meshgroup_pre
    , nullif(e.obs_meshgroup, 'xxx') obs_meshgroup_pre
    from trips_null e
    
    union all
    
    select a.* 
    , nullif(a.meshgroup, 'xxx') meshgroup_pre
    , nullif(a.obs_meshgroup, 'xxx') obs_meshgroup_pre
    from trips_owh a
    
    union all
    
--    select * from trips_0 -- not needed now that subtrip is the unit and not vtr
--    union all
    select b.* 
    , nullif(b.meshgroup, 'xxx') meshgroup_pre
    , nullif(b.obs_meshgroup, 'xxx') obs_meshgroup_pre
    from trips_1 b
    
    union all
    
    select c.* 
    , nullif(c.meshgroup, 'xxx') meshgroup_pre
    , nullif(c.obs_meshgroup, 'xxx') obs_meshgroup_pre 
    from trips_2_area_1 c
    
    union all
    
    select d.* 
    , nullif(d.meshgroup, 'xxx') meshgroup_pre
    , nullif(d.obs_meshgroup, 'xxx') obs_meshgroup_pre
    from trips_2_area_2 d
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

, obs_catch3 as (
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
--,HALFOFYEAR
,ITIS_TSN
--,LINK1
,link1
,LINK3
, offwatch_haul
, offwatch_link1
,MESHGROUP_PRE as MESHGROUP
,MONTH
,NEGEAR
,NESPP3
,nsubtrip_link1
,n_subtrips_link3
,OBSRFLAG
, case when sum(obsrflag) OVER(PARTITION by LINK1) > 0 then 1 else 0 end as LINK3_OBS -- added 9/8/22 
,FISHDISP
--,OBSVTR
,OBS_AREA
,OBS_GEAR
, case when n_subtrips_link3 > 1 THEN OBS_HAUL_KALL_TRIP/n_subtrips_link3 ELSE OBS_HAUL_KALL_TRIP end as OBS_HAUL_KALL_TRIP
, case when n_subtrips_link3 > 1 THEN OBS_HAUL_KEPT/n_subtrips_link3 ELSE OBS_HAUL_KEPT end as OBS_HAUL_KEPT 
, case when n_subtrips_link3 > 1 THEN OBS_NOHAUL_KALL_TRIP/n_subtrips_link3 ELSE OBS_NOHAUL_KALL_TRIP end as OBS_NOHAUL_KALL_TRIP  
, case when n_subtrips_link3 > 1 THEN OBS_KALL/n_subtrips_link3 ELSE OBS_KALL end as OBS_KALL  
,OBS_MESH
,OBS_MESHGROUP_PRE as OBS_MESHGROUP
, SOURCE
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
)

select count(distinct(link1))
, count(distinct(link3))
, year
, offwatch_link1
from obs_catch3
where offwatch_link1 is not null
--where obs_area = '000'
--and obs_gear is null
group by year, offwatch_link1
order by year





