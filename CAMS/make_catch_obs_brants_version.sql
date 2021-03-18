--select *
--from obs_cams_prorate
--
--/

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

--SELECT c_meshgroup, obs_meshgroup, COUNT(*) FROM(
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
   , NVL(c.meshgroup, 'none') as c_meshgroup
   , NVL(o.meshgroup, 'none') as obs_meshgroup
--    , m.GEAR_CODE_FID
from trips c
   left join (
       select * from obs
   ) o
--on (o.link1 = c.link1 AND c.meshgroup = o.meshgroup AND c.negear = o.obs_gear AND c.CAREA = o.OBS_AREA)
on (o.link1 = c.link1 AND c.negear = o.obs_gear AND NVL(c.meshgroup, 'none') = NVL(o.meshgroup, 'none') AND c.CAREA = o.OBS_AREA)
--on (o.link1 = c.link1 AND o.vtrserno = c.vtrserno)
--)

/

SELECT c_meshgroup, obs_meshgroup, COUNT(distinct(VTRSERNO)) nvtrs 
FROM BG_CAMS_OBS_CATCH
WHERE
 c_meshgroup <> obs_meshgroup
AND LINK1 is not null 
GROUP BY
 c_meshgroup
 ,obs_meshgroup
 
/

select meshgroup||'-'||obs_meshgroup as vtr_obs_meshes
, vtrserno
, link1
, subtrip_kall
from apsd.bg_cams_obs_catch
where link1 is not null
and negear = 50
--group by  meshgroup||'-'||obs_meshgroup
 
 
 /
 
 select carea||'-'||obs_area
, count(*)
, round(sum(subtrip_KALL)) as subtrip_kall_sum
--, distinct(obsmeshgroup)
from bg_cams_obs_catch
where link1 is not null
and negear = 50
--group by  meshgroup||'-'||obs_meshgroup

group by carea||'-'||obs_area

/

select count(distinct(link1))
from bg_obdbs_meshsize2_2019
where MSWGTAVG is null
and MSMIN is not null
and MSMAX is not null
/

select count(distinct(link1))
from bg_obdbs_tables_4_2019
where codmsize is null 
and linermsize is null
/

select count(distinct(link1))
from bg_obdbs_tables_5_2019
where meshgroup is null 
/

-- look at link1 in OBS that are NOT in Catch

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


select count(distinct(link1))
from obs_cams_prorate
where year = 2019
and link1 not in (
 select distinct(link1) 
 from trips
 where year = 2019 
 )