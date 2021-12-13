/*-----------------------------------------------------------------------------------------------------

merge CAMS catchg with obdbs_prorate

match on gear (NEGEAR), mesh, link1 and AREA

BG 12-02-21

12/7/21 added gearmapping for OBS abd VTR using a miodified SECGEARFISH column
12/10/21 match CAtch and OBS using a hierarchical match
 Trips with no LINK1 are not observed
 Trips with only one LINK1 are matched on only LINK1
 Trips with >1 LINK1 are matched on LINK1, MESHGROUP, SECGEAR_MAPPED, AREA
12/13/21 changed gearmapping join to use only unique NEGEAR to GEARCODE combinations. Trips were being duped with one to many on this match


------------------------------------------------------------------------------------------------------*/  

drop table bg_cams_obs_catch
/

drop table cams_obs_catch
/

drop View cams_obs_catch

/
drop materialized view cams_obs_catch
/

create materialized view cams_obs_catch as 

with ulink as (
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
, vtr_link as (
     select obs_vtr
    , permit
    , min(obs_link1) as link1  -- this is the minimum link1 for the vtr
    , camsid
    from (
        select a.*
        from maps.match_obs a, ulink l
        where a.obs_vtr in (l.obs_vtr)
        and l.obs_vtr is not null        
    )
    group by obs_vtr, permit, camsid
    order by permit, obs_vtr
)
,trips as (  
       select d.permit
        , d.camsid
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end as region
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end as halfofyear
        , d.docid
        , substr(d.vtrserno, 1, 13) vtrserno
--        , d.gearcode
        , d.geartype
        , d.negear
        , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
--        , d.meshsize
        , NVL(d.mesh_cat, 'na') as meshgroup
        , d.area
        , d.carea
        , round(sum(d.LIVLB)) as subtrip_kall
        , d.sectid
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
    , count(distinct(vtrserno)) over(partition by link1) as nvtr_link1 -- count how many vtrs for each link1
    from maps.cams_catch d
    left join (  --adds observer link field
         select * 
         from vtr_link
        ) o
       
    on  o.camsid = d.camsid 
    
    left join (
      select distinct(VTR_NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from maps.STG_OBS_VTR_GEARMAP
      where VTR_NEGEAR is not null
     ) g
     on d.NEGEAR = g.VTR_NEGEAR
    
    
    group by 
        d.permit
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end 
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end 
        , d.camsid
        , d.docid
        , d.vtrserno
--        , d.gearcode
        , d.geartype
        , d.negear
        , NVL(g.SECGEAR_MAPPED, 'OTH')
--        , d.meshsize
        , NVL(d.mesh_cat, 'na')
        , d.area
        , d.carea
        , d.sectid
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

-- get observer data
-- join to gearmapping for match

, obs as (
      select a.*
            , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
        from apsd.obs_cams_prorate a
          left join (
            select distinct(OBS_NEGEAR) as OBS_NEGEAR
            , SECGEAR_MAPPED
            from maps.STG_OBS_VTR_GEARMAP
            where OBS_NEGEAR is not null          
          ) g
          on a.OBS_GEAR = g.OBS_NEGEAR
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
    , o.obs_area as obs_area
    , o.nespp3
    , o.discard_prorate as discard
    , o.obs_haul_kept
    , o.obs_haul_kall_trip+obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup

     from trips t
     left join (select * from obs ) o
     on (t.link1 = o.link1)
 
    where t.LINK1 is null   

)

-- trips with single link1 (one subtrip)
, trips_1 
 as (  
  select t.*
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
    , o.obs_area as obs_area
    , o.nespp3
    , o.discard_prorate as discard
    , o.obs_haul_kept
    , o.obs_haul_kall_trip+obs_nohaul_kall_trip as obs_kall
    , o.obs_gear as obs_gear
    , o.obs_mesh as obs_mesh
    , NVL(o.meshgroup, 'none') as obs_meshgroup
    from ( 
     select t.*
     from trips t 
   ) t
      left join (select * from obs ) o
        on (t.link1 = o.link1)
  where (nvtr_link1 > 1 AND nvtr_link1 < 20) -- there should never be more than a few subtrips.. zeros add up to lots, so we dont' want those here
  and t.link1 is not null
  and t.vtrserno is not null
--  and t.year = 2019
)

select * from trips_0
union all
select * from trips_1
union all
select * from trips_2

/*       Old matching criteria, no table split as above      */
--on (o.link1 = c.link1 AND c.SECGEAR_MAPPED = o.SECGEAR_MAPPED AND c.meshgroup = o.meshgroup AND c.AREA = o.OBS_AREA)

/

;   
--
--select count(distinct(link1)) as nlink1
--, meshgroup
--, geartype
--, negear
--from cams_obs_catch
----where meshgroup not in 'na'
--where year = 2019
--and link1 is not null
--group by negear, meshgroup, geartype
--order by negear, meshgroup
/

/ 
