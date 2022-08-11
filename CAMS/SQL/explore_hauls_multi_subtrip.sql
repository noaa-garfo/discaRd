select count(distinct(cams_subtrip)) as subtrip_count
, link3
from cams_link3_subtrip
group by link3
having count(distinct(cams_subtrip)) > 1
order by  subtrip_count desc
;

select count(distinct(cams_subtrip)) as subtrip_count
, link3
from cams_obs_catch_test
group by link3
having count(distinct(cams_subtrip)) > 1
order by  subtrip_count desc
;

select *
 from cams_obs_catch
-- where link3 = '010201804Q040090028'
 where camsid = '320857_20180403133000_5067883'
 ;
 
 select *
 from cams_obdbs_all_years
 where link3 = '010201804Q040090028'
 ;
 
 select vtrserno
 , GEARTYPE
 , NEGEAR
, AREA
, MESH_CAT
, GEAR_SOURCE
, status
 from cams_landings 
 where camsid = '320857_20180403133000_5067883'
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
 