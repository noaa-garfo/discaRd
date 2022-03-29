/*-----------------------------------------------------------------------------------------------------

MERGE CAMS CATCH WITH OBDBS_PRORATE

match on gear (NEGEAR), mesh, link1 and AREA

BG 12-02-21

12/7/21 added gearmapping for OBS abd VTR using a miodified SECGEARFISH column
12/10/21 match CAtch and OBS using a hierarchical match
 Trips with no LINK1 are not observed
 Trips with only one LINK1 are matched on only LINK1
 Trips with >1 LINK1 are matched on LINK1, MESHGROUP, SECGEAR_MAPPED, AREA
12/13/21 changed gearmapping join to use only unique NEGEAR to GEARCODE combinations. Trips were being duped with one to many on this match
12/21/21 changed table nname to MAPS.CAMS_OBS_PRORATE
01/24/22 rebuilt to reflect changes to SECGEAR_MAPPED (clam dredge NEGEAR 400)
02/03/22 make sure tripcategory and accessarea are included
         make sure the multi VTR join is a multi factor join.. AREA, GEAR, MESH, LINK1
02/04/22 added filter for observedtrips coming from CAMS.MATCH_OBS so only trips with TRIP_EXT C or X are included. 
        This is the criteria used in OBS data
02/18/22 changed EFP columns to new EM designation   

03/24/22 joined the process for observer proration and merging of OBS and CATCH. Pro-ration was happening imncorrectly adn is now done
by subtrip. This is designated by VTRSERNO, and happens AFTER the merge between catch and obs. In this manner, each subtrip 
now has the correct OBS_KALL and pro-rated discard by species. 

         
RUN FROM MAPS SCHEMA

------------------------------------------------------------------------------------------------------*/  
/
drop table maps.cams_obs_catch
/
drop table maps.cams_obs_catch_prorate
/


create table maps.cams_obs_catch as 

with obs1 as (
select a.*
    from (
 select o.link3
            , link1
            , vtrserno
            , extract(year from datesail) as year
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
            , extract(year from datesail)
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

, ulink as (
    select count(distinct(obs_link1)) nlink1
    , obs_vtr
    from maps.match_obs
    where obs_link1 is not null
    AND obs_link1 in (
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
, obstrp_ext as (
 select distinct(link1) link1 
 from obdbs.obtrp@NOVA
 where tripext in ('C','X')
 
  union all
 
 select distinct(link1) link1 
 from obdbs.asmtrp@NOVA
 where tripext in ('C','X')
 
-- and year >= 2018
)
 
, vtr_link as (
     select obs_vtr
    , permit
    , min(obs_link1) as link1  -- this is the minimum link1 for the vtr
    , camsid
    from (
        select a.*
        from MAPS.MATCH_OBS a, ulink l, obstrp_ext o
        where a.obs_vtr in (l.obs_vtr)
        and l.obs_vtr is not null        
        AND OBS_LINK1 in o.link1       
    )
    group by obs_vtr, permit, camsid
    order by permit, obs_vtr
)
,trips as (  
       select d.permit
        , d.camsid
        , d.year
        , d.month
--        , case when d.carea < 600 then 'N'
--               else 'S' end as region
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end as halfofyear
        , d.docid
--        , substr(d.vtrserno, 1, 13) vtrserno
        , d.vtrserno
        , d.camsid || '_' || d.subtrip as cams_subtrip
--        , d.gearcode
        , d.geartype
        , d.negear
        , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
--        , d.meshsize
        , NVL(d.mesh_cat, 'na') as meshgroup
        , d.area
--        , d.carea
        , round(sum(d.LIVLB)) as subtrip_kall
        , d.sectid
        , d.GF
        , d.activity_code_1
        , d.activity_code_2
--        , d.activity_code_3
--        , d.permit_EFP_1
--        , d.permit_EFP_2
--        , d.permit_EFP_3
--        , d.permit_EFP_4
        , d.EM
        , redfish_exemption
        , closed_area_exemption
        , sne_smallmesh_exemption
        , xlrg_gillnet_exemption
        , d.tripcategory
        , d.accessarea
    , o.link1
    , count(distinct(vtrserno)) over(partition by link1) as nvtr_link1 -- count how many vtrs for each link1
    from MAPS.CAMS_LANDINGS d
    left join (  --adds observer link field
         select * 
         from vtr_link
        ) o
       
    on  o.camsid = d.camsid 
    
    left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g
     on d.NEGEAR = g.VTR_NEGEAR
    
    
    group by 
        d.permit
        , d.year
        , d.month
--        , case when d.carea < 600 then 'N'
--               else 'S' end 
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end 
        , d.camsid
        , d.docid
        , d.vtrserno
        , d.camsid || '_' || d.subtrip
--        , d.gearcode
        , d.geartype
        , d.negear
        , NVL(g.SECGEAR_MAPPED, 'OTH')
--        , d.meshsize
        , NVL(d.mesh_cat, 'na')
        , d.area
--        , d.carea
        , d.sectid
        , d.GF
        , d.activity_code_1
        , d.activity_code_2
--        , d.activity_code_3
        , d.EM
--        , d.permit_EFP_1
--        , d.permit_EFP_2
--        , d.permit_EFP_3
--        , d.permit_EFP_4
        , d.redfish_exemption
        , d.closed_area_exemption
        , d.sne_smallmesh_exemption
        , d.xlrg_gillnet_exemption
        , d.tripcategory
        , d.accessarea
        , o.link1
)

-- get observer data
-- join to gearmapping for match

, obs as (
      select a.*
            , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
            , i.ITIS_TSN
            , i.ITIS_GROUP1
        from OBS1 a
          left join (
            select distinct(NEGEAR) as OBS_NEGEAR
            , SECGEAR_MAPPED
            from maps.STG_OBS_VTR_GEARMAP
            where NEGEAR is not null          
          ) g
          on a.OBS_GEAR = g.OBS_NEGEAR
          
         left join(select * from maps.CFG_ITIS where SRCE_ITIS_STAT = 'valid') i
         on a.NESPP3 = i.DLR_NESPP3
      )


-- 
/* 
staged matching 

trips with no link1 (unobserved)
*/
, trips_0 as (

  select t.*
    , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obsrflag
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
    , o.ITIS_GROUP1
--    , o.discard_prorate as discard
, o.discard
    , o.obs_haul_kept
--    , o.obs_haul_kall_trip+o.obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup

     from trips t
     left join (select * from obs ) o
     on (t.link1 = o.link1)
 
    where (t.LINK1 is null or t.nvtr_link1 = 0)   

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
    , o.ITIS_GROUP1
--    , o.discard_prorate as discard
, o.discard
    , o.obs_haul_kept
--    , o.obs_haul_kall_trip+o.obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 

   ) t
      left join (select * from obs ) o
        on (t.link1 = o.link1)
  where nvtr_link1 = 1
  and t.link1 is not null
  and t.vtrserno is not null
--  and t.year = 2019

)

-- trips with >1 link1
, trips_2 as ( 

   select t.*
  , o.vtrserno as obsvtr
    , o.link1 as obs_link1
    , o.link3
    , o.obsrflag
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
    , o.ITIS_GROUP1
--    , o.discard_prorate as discard
, o.discard
    , o.obs_haul_kept
--    , o.obs_haul_kall_trip+o.obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
--        on (t.link1 = o.link1)
        on (o.link1 = t.link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND o.meshgroup = t.meshgroup AND o.OBS_AREA = t.AREA)
  where (nvtr_link1 > 1 AND nvtr_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and t.link1 is not null
  and t.cams_subtrip is not null
--  and t.year = 2019
)

, obs_catch as 
( 
    select * from trips_0
    union all
    select * from trips_1
    union all
    select * from trips_2
)

select a.*
, round(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip)) as obs_haul_kall_trip
, round(SUM(case when a.obsrflag = 0 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip)) as obs_nohaul_kall_trip
, round(SUM(a.obs_haul_kept)  OVER(PARTITION BY a.cams_subtrip)) as OBS_KALL
, SUM(a.obs_haul_kept) OVER(PARTITION BY a.cams_subtrip) / 
   NULLIF(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip),0) as prorate
, round((SUM(a.obs_haul_kept) OVER(PARTITION BY a.cams_subtrip) / 
 NULLIF(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.cams_subtrip),0)*a.discard), 2) as discard_prorate
from obs_catch a


--
--PARTITION BY LIST (year) AUTOMATIC
--(
--  PARTITION year2017 VALUES (2017),
--  PARTITION year2018 VALUES (2018),
--  PARTITION year2019 VALUES (2019),
--  PARTITION year2020 VALUES (2020)
----  PARTITION year2021 VALUES ('2021')
--)
;


--where a.link1 is not null
--and a.link1 = '000201908R35027'

