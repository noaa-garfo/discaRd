/*

MERGE CAMS CATCH WITH CAMS_OBDBS_ALL_YEARS

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

04/08/22  since CAMSLANDINGS has so many years, now filter for > 2017 only
   added parts to find and fix obs kall and discard when link3 is duped due to meshgroup similarities across subtrips

07/26/22 rebuilt table following cams_obdbs_all_years builds
08/01/22 added observer source from cams_obdbs_all_years tables/view
         
RUN FROM MAPS SCHEMA

--------------------------------------------------------------------------------

-- August 2022

--------------------------------------------------------------------------------

New version of CAMS_OBS_CATCH that has a differnt join order than the original

When building CAMS_OBS_CATCH, the order of joins between cams_landings and OBDBS information was as follows (simplified):

cams_landings 
left join match_obs  (to get camsid)
left join cams_obdbs_all_years  

the match_obs table has more link1  than cams_obdbs due to filtering trip_ext within that table build. 
This then leads to more link1 records than intended and throws off comparisons between obdbs and cams_obs_catch
Any comparisons made using the match_obs table will show link1 numebrs to be higher than they are in cams_obs_catch

A better approach may be to alter the order of the joins

cams_obdbs_all_years
left join match_obs (to get camsid)
right join cams_landings

This has the effect of maintaining only the link1 records from the obdbs table build


B Galuardi
8/5/22

*/



drop table cams_obs_catch_test
/

create table cams_obs_catch_test as 

with obs1 as (

 select o.link3
            , link1
--            , vtrserno
            , extract(year from dateland) as year
            , o.source
--            , o.month
            , o.obsrflag
            , o.fishdisp
            , o.area as obs_area
            , o.negear as obs_gear
            , o.geartype
            , round(o.meshsize, 0) as obs_mesh
            , o.meshgroup
            , substr(nespp4, 1, 3) as NESPP3
            , SUM(case when catdisp = 0 then o.livewt else 0 end) as discard
            , SUM(case when catdisp = 1 then o.livewt else 0 end) as obs_haul_kept
        
            from (
                select * from cams_obdbs_all_years
            )
            o
          group by  o.link3
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

, ulink as (
       select  permit
    , FIRST_VALUE(obs_link1)
         OVER (partition by camsid) AS min_link1
    , count(distinct(obs_link1)) over(partition by camsid) as N_link1_camsid
    , obs_link1
    , camsid
   from MATCH_OBS a
    where extract(year from a.obs_land) > 2016  
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
--        , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
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
--    , o.link1
    , v.obs_link1
    , v.min_link1
    , v.N_link1_camsid
--    , count(distinct(d.vtrserno)) over(partition by link1) as nvtr_link1 -- count how many vtrs for each link1
     , count(distinct(d.cams_subtrip)) over(partition by obs_link1) as nsubtrip_link1 -- count how many cams_subtrips for each link1
    , count(distinct(d.area)) over(partition by obs_link1) as narea_link1
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
-- left join cams_obdbs_all_years o 
-- on o.link1 = v.obs_link1
 
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
        , NVL(d.mesh_cat, 'na') 
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
    , v.obs_link1
    , v.N_link1_camsid
 
)

-- adds mapped gear for gear matching to trips that have a link1 from above

, trips as (select j.*
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
      )


-- 
/* 
staged matching 

trips with no link1 (unobserved)
*/
, trips_null as (

  select t.*
    , null as link3
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
    , 'none' as obs_meshgroup

     from trips t
--     left join (select * from obs ) o -- no joins here! 
--     on (t.link1 = o.link1)

--    where (t.LINK1 is null)  
    where (t.OBS_LINK1 is null) --maintaining this field as primary field from matching table
)  


/*  not needed now that subtrip is the unit and not VTR
-- trips with no VTR but still observed i.e. clam trips.. 
, trips_0 as (

  select t.*
--    , o.vtrserno as obsvtr
--    , o.link1 as obs_link1
    , o.link3
    , o.source
    , o.obsrflag
    , o.fishdisp
    , o.obs_area as obs_area
    , o.nespp3
    , o.ITIS_TSN
--    , o.ITIS_GROUP1
--    , o.discard_prorate as discard
    , o.discard
    , o.obs_haul_kept
--    , o.obs_haul_kall_trip+o.obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup

     from trips t
     left join (select * from obs ) o
--     on (t.link1 = o.link1)
     on (t.obs_link1 = o.link1)  --maintaining obs_link1 from matching table

      where nsubtrip_link1 = 1
--      and t.link1 is not null
      and t.obs_link1 is not null

)

*/

-- obs trips with exactly one VTR

, trips_1 
 as (  
  select t.*
    , o.link3
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
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 

   ) t
      left join (select * from obs ) o
     on (t.obs_link1 = o.link1)  --maintaining obs_link1 from matching table

      where nsubtrip_link1 = 1
--      and t.link1 is not null
      and t.obs_link1 is not null

)

-- multiple subtrips but only one area
, trips_2_area_1 as ( 

   select t.*
    , o.link3
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
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
  on (o.link1 = t.obs_link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND o.meshgroup = t.meshgroup)  -- don't use area when narea = 1
  where (nsubtrip_link1 > 1 AND nsubtrip_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and narea_link1 = 1
  and t.obs_link1 is not null  --maintin naming from matching table
  and t.cams_subtrip is not null

)
-- trips with >1 subtrip and multiple areas on link1s
, trips_2_area_2 as ( 

   select t.*
    , o.link3
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
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
        on (o.link1 = t.obs_link1 AND o.SECGEAR_MAPPED = t.SECGEAR_MAPPED AND o.meshgroup = t.meshgroup AND o.OBS_AREA = t.AREA) -- use area when narea >1
  where (nsubtrip_link1 > 1 AND nsubtrip_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and narea_link1 > 1
  and t.obs_link1 is not null --maintain naming from matching table
  and t.cams_subtrip is not null

)

, obs_catch as 
( 
    select * from trips_null
    union all
--    select * from trips_0 -- not needed now that subtrip is the unit and not vtr
--    union all
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
--,HALFOFYEAR
,ITIS_TSN
--,LINK1
,OBS_LINK1
,LINK3
,MESHGROUP
,MONTH
,NEGEAR
,NESPP3
,nsubtrip_link1
,n_subtrips_link3
,OBSRFLAG
,FISHDISP
--,OBSVTR
,OBS_AREA
,OBS_GEAR
, case when n_subtrips_link3 > 1 THEN OBS_HAUL_KALL_TRIP/n_subtrips_link3 ELSE OBS_HAUL_KALL_TRIP end as OBS_HAUL_KALL_TRIP
, case when n_subtrips_link3 > 1 THEN OBS_HAUL_KEPT/n_subtrips_link3 ELSE OBS_HAUL_KEPT end as OBS_HAUL_KEPT 
, case when n_subtrips_link3 > 1 THEN OBS_NOHAUL_KALL_TRIP/n_subtrips_link3 ELSE OBS_NOHAUL_KALL_TRIP end as OBS_NOHAUL_KALL_TRIP  
, case when n_subtrips_link3 > 1 THEN OBS_KALL/n_subtrips_link3 ELSE OBS_KALL end as OBS_KALL  
,OBS_MESH
,OBS_MESHGROUP
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

/

--select max ( length ( link3 ) ) mx_char_length,
--       max ( lengthb ( link3 ) ) mx_byte_length
--from   cams_obs_catch_test
/

-- shorten the character length to allow an index to be built

alter table cams_obs_catch_test
  modify obs_link1 varchar2(100 char)
/

CREATE INDEX yearidx_test ON CAMS_OBS_CATCH_TEST(YEAR, ITIS_TSN, OBS_LINK1, LINK3)




