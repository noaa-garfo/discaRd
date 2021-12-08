/*-----------------------------------------------------------------------------------------------------

merge CAMS catchg with obdbs_prorate

match on gear (NEGEAR), mesh, link1 and AREA

BG 12-02-21

12/7/21 added gearmapping for OBS abd VTR using a miodified SECGEARFISH column

------------------------------------------------------------------------------------------------------*/  

drop table bg_cams_obs_catch
/

drop table cams_obs_catch
/


create or replace view cams_obs_catch as 


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
        , d.gearcode
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
    from maps.cams_catch d
    left join (  --adds observer link field
         select * 
         from vtr_link
        ) o
       
    on  o.camsid = d.camsid 
    
    left join (select * from maps.STG_OBS_VTR_GEARMAP) g
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
        , d.gearcode
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

-- this part gets observer data

, obs as (
      select a.*
            , NVL(g.SECGEAR_MAPPED, 'OTH') as SECGEAR_MAPPED
        from apsd.obs_cams_prorate a
          left join (select * from maps.STG_OBS_VTR_GEARMAP) g
          on a.OBS_GEAR = g.OBS_NEGEAR
      )

--, mgear as (
--    select gear_code_fid
--    , RIGHT('000' + negear, 3) as negear
--    , vtr_gear_code
--    from apsd.master_gear
--)

--, gearmap as (select * from maps.STG_OBS_VTR_GEARMAP)

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
    
on (o.link1 = c.link1 AND c.SECGEAR_MAPPED = o.SECGEAR_MAPPED AND c.meshgroup = o.meshgroup AND c.AREA = o.OBS_AREA)
--on (o.link1 = c.link1 AND c.meshgroup = o.meshgroup AND c.negear = o.obs_gear AND c.CAREA = o.OBS_AREA)
--on (o.link1 = c.link1 AND substr(to_char(c.negear), 1, 1) = substr(to_char(o.obs_gear), 1, 1) AND c.meshgroup = o.meshgroup AND c.AREA = o.OBS_AREA)
--on (o.vtrserno = c.vtrserno)
--on (o.link1 = c.link1)

--left outer join (SELECT * from mgear) m
--on (c.GEARCODE = m.VTR_GEAR_CODE) 

/

;

select count(distinct(link1)) as nlink1
, meshgroup
, geartype
, negear
from cams_obs_catch
--where meshgroup not in 'na'
where year = 2019
and link1 is not null
group by negear, meshgroup, geartype
order by negear, meshgroup
/

/ 
------- Look at what gear is on the VTR for the obs link1 where we see  116 ,117 gillnets
-- get link1 from obs prorate table where negear is 116 117
--- get CAMSID for those obs link1
-- get catch info for those CMASIDs

select count(distinct(camsid))
, negear
, gearnm
, mesh_cat
from
maps.cams_catch
    where camsid in (
    select distinct(camsid) camsid
    from maps.match_obs
        where obs_link1 in(
            select distinct(link1) as link1
            from apsd.obs_cams_prorate
            where obs_gear in (115, 116, 117)
            and year = 2019
        )
)
group by gearnm
, mesh_cat
, negear

/

-- look at number of link1 and vtr per gear and mesh combination

select count(distinct(link1)) as nlink1
,  count(distinct(CAMSID)) as n_vtr
, meshgroup
, geartype
, negear
, secgear_mapped
from cams_obs_catch
--where meshgroup not in 'na'
where year = 2019
--and link1 is not null
group by negear, meshgroup, geartype, secgear_mapped
order by negear, meshgroup