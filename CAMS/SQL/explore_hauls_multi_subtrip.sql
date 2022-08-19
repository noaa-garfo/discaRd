select count(distinct(cams_subtrip)) as subtrip_count
, link3
from cams_link3_subtrip
group by link3
having count(distinct(cams_subtrip)) > 1
order by  subtrip_count desc
;

-- look for multiple gears/mesh/area on link3s .. this would indicate duping across fleets

select count(distinct(cams_subtrip)) as subtrip_count
, link3
, listagg(distinct(negear), ';') u_gears
, listagg(distinct(meshgroup), ';') u_mesh
, listagg(distinct(area), ';') u_areas
from cams_obs_catch_test
where link3 is not null
group by link3
having count(distinct(cams_subtrip)) > 1
order by  subtrip_count desc
;

select *
 from cams_obs_catch_test
 where link3 = '000201901Q530030015'
-- where camsid = '320857_20180403133000_5067883'
 ;
 
 select *
 from cams_obdbs_all_years
 where link3 = '000201901Q530030015'
 ;
 
 select vtrserno
 , GEARTYPE
 , NEGEAR
, AREA
, MESH_CAT
, vtr_mesh
, GEAR_SOURCE
, status
 from cams_landings 
 where camsid = '330303_20190119203000_5160125'
 ;
 
 select *
 from match_obs
 where obs_link1 = '010201804Q04009'
 
 ;
 
 select distinct status
 from cams_landings
 ;
 
 select distinct count(distinct(gear_source)) as n_gear_source
 , link1
 from cams_obs_catch
 where link1 is not null
 group by link1
 having count(distinct(gear_source)) >1
 order by n_gear_source desc
 ;
 
 -- obsvtr = 12751406
 