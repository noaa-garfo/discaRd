/*

Check the extent of dropped hauls/trips

check mismatches for 

area
gear
mesh 


7/20/22

Ben Galuardi


*/

-- from schema maps:

grant select on maps.cams_obdbs_2017 to cams_garfo;
grant select on maps.cams_obdbs_2018 to cams_garfo;
grant select on maps.cams_obdbs_2019 to cams_garfo;
grant select on maps.cams_obdbs_2020 to cams_garfo;
grant select on maps.cams_obdbs_2021 to cams_garfo;
grant select on maps.cams_obdbs_2022 to cams_garfo;


/

/*  Example of dropped hauls where there was no link1 match  */

-- from schema cams_garfo: 

with obs1 as (
select a.*
    from (
 select o.link3
            , link1
--            , vtrserno
            , extract(year from dateland) as year
--            , o.month
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
                union all
                select * from maps.cams_obdbs_2022
            )
            o
            
       where tripext in ('C','X')     
          group by  o.link3
            , link1
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
--            , vtrserno
            , year
--            , month
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
, cams as (
    select distinct(camsid), subtrip, negear, vtr_mesh, mesh_cat, area, area_source, gear_source, activity_code_1, secgear_mapped--, year
    from cams_garfo.cams_landings c
     left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on c.NEGEAR = g.VTR_NEGEAR
)

select a.*
, case when secgear_obs = secgear_mapped then 'match' else 'no match' end as gear_match
, case when meshgroup = mesh_cat then 'match' else 'no match' end as mesh_match
, case when obs_area = area then 'match' else 'no match' end as area_match
from (
    select o.*, c.* , g.secgear_mapped as secgear_obs
    from obs1 o
    
    left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on o.OBS_GEAR = g.VTR_NEGEAR
     
    
    left join cams_garfo.match_obs m on o.link1 = m.obs_link1
    left join cams c on c.camsid = m.camsid 
    where o.link1 not in (select distinct link1 from cams_obs_catch where link1 is not null) -- and year = 2020)

) a

;

/*  Example of dropped hauls where there was a link1 match but dropped link3 */

-- from schema cams_garfo: 

with obs1 as (
select a.*
    from (
 select o.link3
            , link1
--            , vtrserno
            , extract(year from dateland) as year
--            , o.month
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
                union all
                select * from maps.cams_obdbs_2022
            )
            o
            
       where tripext in ('C','X')     
          group by  o.link3
            , link1
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
--            , vtrserno
            , year
--            , month
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
, cams as (
    select distinct(camsid), subtrip, negear, vtr_mesh, mesh_cat, area, area_source, gear_source, activity_code_1, secgear_mapped--, year
    from cams_garfo.cams_landings c
     left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on c.NEGEAR = g.VTR_NEGEAR
)

select a.*
, case when secgear_obs = secgear_mapped then 'match' else 'no match' end as gear_match
, case when meshgroup = mesh_cat then 'match' else 'no match' end as mesh_match
, case when obs_area = area then 'match' else 'no match' end as area_match
from (
    select o.*, c.* , g.secgear_mapped as secgear_obs
    from obs1 o
    
    left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on o.OBS_GEAR = g.VTR_NEGEAR
     
    
    left join cams_garfo.match_obs m on o.link1 = m.obs_link1
    left join cams c on c.camsid = m.camsid 
    where o.link1 in (select distinct link1 from cams_obs_catch where link1 is not null) -- and year = 2020)
    AND o.link3 not in (select distinct link3 from cams_obs_catch where link3 is not null) -- and year = 2020)
) a