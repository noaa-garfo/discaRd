select *
from fso.t_observer_mortality_ratio
;

select *
from apsd.s_nespp3_match_conv
;

SELECT
  *
FROM
  apsd.cams_apport_20201222 a
  ,apsd.cams_trip_attribute ta
WHERE
  a.dmis_trip_id = ta.dmis_trip_id
AND a.permit = 410458

;
select o.*
, case when c.match_nespp3 is not null then c.match_nespp3 else o.nespp3 end as match_nespp3
from obs_cams_prorate o
left join (select * from apsd.s_nespp3_match_conv) c
on o.nespp3 = c.nespp3

;
/*  

test how to grab info from combined observer and trip table.. 
need one kept all per subtrip
only pull one species of discard

dont use DMIS_TRIP_ID!! it's a TRIP, not a subtrip... 

*/

with cotrips as(

        select distinct(subtrip_kall) 
    --    , case when nespp3 = 802 then (NVL(sum(discard) over(partition by vtrserno),0)) else 0 end as discard
        ,NVL(sum(discard) over(partition by vtrserno, geartype, nespp3),0)  as discard
        --, dmis_trip_id
        , vtrserno
        , geartype
        , nespp3
        from apsd.bg_obs_cams_tmp3
        where year = 2019

)

select geartype
, sum(subtrip_kall)
, sum(discard) as discard
from (
    select max(subtrip_kall) subtrip_kall
    , vtrserno
    , sum(case when nespp3 = 802 then discard else 0 end) as discard
    , geartype
    from cotrips
    group by vtrserno, geartype
)
group by geartype

;
;