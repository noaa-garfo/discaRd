/*

make observer proration discard 

ben galuardi

1-6-21

*/

drop table obs_cams_prorate 
/

create table obs_cams_prorate as

--WITH dummy AS(
--SELECT
-- 5 num
-- ,0 div
--FROM
-- dual
--)
--
--SELECT
-- num/NULLIF(div,0)
-- ,NVL(num/NULLIF(div,0),0)
--FROM
-- dummy
-- 
-- ;

select b.*
, round(sum(b.discard*b.prorate)) as discard_prorate
from 
(
select a.*
--     , SUM(a.obs_haul_kept) OVER(PARTITION BY a.link3) as obs_haul_kall
--     , SUM(a.discard) OVER(PARTITION BY a.nespp3) as obs_haul_discard_trip_spp
     , SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.link1) as obs_haul_kall_trip
     , SUM(case when a.obsrflag = 0 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.link1) as obs_nohaul_kall_trip
--     , SUM(a.obs_haul_kept) OVER(PARTITION BY a.link1) / SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.link1) as prorate
       , SUM(a.obs_haul_kept) OVER(PARTITION BY a.link1) / NULLIF(SUM(case when a.obsrflag = 1 then a.obs_haul_kept else 0 end) OVER(PARTITION BY a.link1),0) as prorate
    from (
        select o.link3
            , link1
            , o.obsrflag
            , o.area as obs_area
            , o.negear as obs_gear
            , round(o.meshsize, 0) as obs_mesh
            , o.meshgroup
            , substr(nespp4, 1, 3) as NESPP3
            , SUM(case when catdisp = 0 then o.hailwt else 0 end)  as discard
            , SUM(case when catdisp = 1 then o.hailwt else 0 end) as obs_haul_kept
        
            from (
                select * from apsd.bg_obdbs_cams_mock2018
                union all
                select * from apsd.bg_obdbs_cams_mock2019
            )
            o
          group by  o.link3
            , link1
            , o.obsrflag
            , o.area 
            , o.negear 
            , round(o.meshsize, 0)
            , o.meshgroup
            , substr(nespp4, 1, 3)
) a
--where link1 = '230201801N54002'
) b

group by link3
            , link1
            , obsrflag
            , obs_area
            , obs_gear
            , obs_mesh
            , meshgroup
            , NESPP3
            , discard
            , obs_haul_kept
            , obs_haul_kall_trip
            , obs_nohaul_kall_trip
            , prorate