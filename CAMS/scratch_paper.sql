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
