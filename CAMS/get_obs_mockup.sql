/*

ben Galuardi
2020-12-17
OBS data grab

script lifted from butterfish cacth cap monitoring and generalized for all species
idea is to get d, k, and kall by link 1 (obs trip)... maybe by link 3 (haul)

*/


create table maps.BG_OBS_KALL_MOCK as 

select a.*
, SUM(hailwt) OVER(PARTITION BY link1) as kept_all
from (
select 
        permit1 as permit
      , link1
      , link3
      , min(dateland) as date_trip
      , min(extract(month from dateland)) as month
      , min(year) as year
      , nespp3
      , hailwt
      , sum(case when catdisp = 1 then hailwt else 0 end) as kept
      , sum(case when  catdisp = 0 then hailwt else 0 end) as discard
--      , SUM(hailwt) OVER(PARTITION BY link1) as kept_all
from 

(
SELECT
  t.link1
  , s.link3
  ,t.year
  ,t.permit1
  ,t.hullnum1
  ,t.datesail
  ,t.dateland
--  ,s.obsrflag
  ,SUBSTR(s.nespp4,1,3) nespp3
  ,s.nespp4
  ,s.fishdisp
  ,s.catdisp
--  ,s.drflag
--  ,s.wgttype
  ,s.hailwt
  
  from
  (
    select link1, year, datesail, dateland, permit1, hullnum1
    from obdbs.obtrp@nova
    union all
    select link1, year, datesail, dateland, permit1, hullnum1
    from obprelim.optrp@nova
  ) t 
  LEFT OUTER JOIN
  (
    select  link1, year, link3 , obsrflag
      from obdbs.obhau@nova 
    union all 
    select link1, year, link3, obsrflag
      from obprelim.ophau@nova 
    ) h ON t.link1 = h.link1
  LEFT OUTER JOIN
  ( 
  select link1, link3, year, nespp4, hailwt, fishdisp, to_number(catdisp) as catdisp
  from obdbs.obspp@nova 
  union all 
  select link1, link3, year, nespp4, hailwt, fishdisp
    , to_number(case when fishdisp like '0%'  then 0  
           when fishdisp like '1%' then 1 end) as  catdisp
  from obprelim.opcatch@nova 
  ) s ON h.link3 = s.link3

WHERE
  t.year BETWEEN 2018 AND 2019 --= 2011
--AND t.fleet_type in (46, 47)
and h.obsrflag = 1
and s.fishdisp <> 039
--and s.nespp4 in ('8010','8020','0510', '2120')
order by dateland desc
)

group by link1, permit1, nespp3, hailwt, link3
--having sum(case when nespp3 = 801 then hailwt else 0 end) >= 2501
order by date_trip
) a
;

grant all on maps.BG_OBS_KALL_MOCK to apsd;
grant all on maps.BG_OBS_KALL_MOCK to dmis;
grant all on maps.BG_OBS_KALL_MOCK to bgaluardi;

