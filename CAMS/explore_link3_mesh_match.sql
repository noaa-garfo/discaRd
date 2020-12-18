/*
BEN GALUARDI

12/18/20

CREATE MOCKUP OF CATCH TABLE FROM MAPS USING DMIS_TRIP_ID AND JOINING TO LINK3 AND MATCH GEAR AND MESH

*/


with obs as (
--        select o.*
select o.link3
    , link1
    , o.area as obs_area
    , o.negear as obs_gear
    , round(o.meshsize, 0) as obs_mesh
    , o.meshgroup
        , SUM(case when catdisp = 0 then o.hailwt else 0 end) OVER(PARTITION BY o.link3) as discard
        , SUM(case when catdisp = 1 then o.hailwt else 0 end) OVER(PARTITION BY o.link3) as obs_haul_kall
        , substr(nespp4, 1, 3) as NESPP3
    from (
        select * from apsd.BG_OBDBS_TABLES_5_2018
        union all
        select * from apsd.BG_OBDBS_TABLES_5_2019
    )
    o
)
    select c.*
    , o.link3
    , o.obs_area
    , o.nespp3
    , o.discard
    , o.obs_haul_kall
    , o.obs_gear 
    , o.obs_mesh
    , o.meshgroup
from apsd.catch_link1_temp c
    left outer join (
        select * from obs -- where nespp3 = 212 
    ) o
on o.link1 = c.link1 AND c.mesh = o.obs_mesh