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


9/7/22 made meshgroup where is no mesh consistently named between trips and obs
9/8/22 added a column (LINK3_OBS) indicating whether the observed trip has at least one observed haul or not (1,0)
10/2/22 fixed meshgroup null matching issue
        added offwatch hauls column    
10/7/22 changed where offwatch hauls are added. added an addional column to make trips with offwatch hauls        
*/



--drop table cams_obs_catch
--/

create table cams_obs_catch as 

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
            , NESPP4
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
            , NESPP4
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
            , i.SPECIES_ITIS as ITIS_TSN
--            , i.ITIS_GROUP1
        from owh a
          left join (
            select distinct(NEGEAR) as OBS_NEGEAR
            , SECGEAR_MAPPED
            from maps.STG_OBS_VTR_GEARMAP
            where NEGEAR is not null          
          ) g
          on a.OBS_GEAR = g.OBS_NEGEAR
          
--         left join(select * from maps.CFG_NESPP3_ITIS ) i  --where SRCE_ITIS_STAT = 'valid'
--         on a.NESPP3 = i.DLR_NESPP3
         left join(select * from obdbs.obspec@NOVA ) i  --use obdbs table since dlr nespp3 has some quirtks from nefsc nespp3 version..
         on a.NESPP4 = i.NESPP4
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
  where (nsubtrip_link1 > 1 AND nsubtrip_link1 < 40) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
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
  where (nsubtrip_link1 > 1 AND nsubtrip_link1 < 40) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
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





