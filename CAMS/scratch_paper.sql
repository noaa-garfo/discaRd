select count(distinct(link1))
, count(distinct(link3))
, year
from maps.BG_OBS_KALL_MOCK
group by year
;

with obs as (
select link1
, nespp3
, NVL(sum(discard)/max(kept_all),0) as dk
, max(kept_all) obs_kall
from maps.BG_OBS_KALL_MOCK
where year = 2019
group by link1, nespp3
)

select c.*
, o.nespp3
, o.obs_kall
, o.dk
from apsd.catch_link1_temp c
left join (
 select * from obs where nespp3 = 212 
) o
on o.link1 = c.link1
;

grant all on apsd.stat_areas_def to MAPS;

select * from apsd.stat_areas_def where nespp3 = '212'
;

select a.* 
, extract(year from a.record_land) as year
from apsd.cams_apport a
;

select * from  apsd.cams_apport

;
select * from catch_link1_temp
;

select * from maps.BG_OBS_KALL_MOCK
;

select *
from obdbs.obhau@nova 
;

select * from obdbs.OBMESHSIZE@NOVA
;

select * from obdbs.OBMSZ@nova

select all_tables from NOVA where owner = 'OBDBS'
;

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
