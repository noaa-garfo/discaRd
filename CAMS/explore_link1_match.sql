select *
from apsd.dmis_all_years
;

select count(distinct(vtrserno))
, count(distinct(docid))
, dmis_trip_id
from apsd.cams_apport
group by dmis_trip_id
;

with obs_cams as ( 
     select d.*
    , o.link1
    from apsd.cams_apport d
    left join (
     select *
     from dmis.d_match_obs_link
    ) o
    on o.dmis_trip_id = d.dmis_trip_id
    
)
, mtrips as (
select dmis_trip_id
    from (
        select
         count(distinct(vtrserno)) nvtr
        , count(distinct(docid)) ndocid
        , dmis_trip_id
        from apsd.cams_apport
        group by dmis_trip_id
    ) a
    where a.nvtr > 1
)


select d.permit
, d.dmis_trip_id
, d.docid
--, d.nespp3
--, d.nespp4
, d.vtrserno
, d.gearcode
, d.mesh
, d.area
, d.carea
--, round(sum(d.landed)) as landed
, round(sum(d.live)) as cams_kall
, T.GEARCAT
,t.program
,t.year
,t.sector_id
,t.fleet_type
,t.datesail obs_sail
,t.dateland obs_land
--,s.obsrflag
--    ,s.area obs_area -- this will be at at a species level.. 
--    ,SUBSTR(s.nespp4,1,3) nespp3
--    ,s.nespp4
, max(s.negear) as  obs_negear
--    ,s.fishdisp
--    ,s.catdisp
--    ,s.drflag
--    ,s.wgttype
, sum(s.hailwt) as obs_kall
    from (
     select o.* 
     from obs_cams o , mtrips  m
     where o.DMIS_TRIP_ID in m.dmis_trip_id
    ) d

    LEFT OUTER JOIN 
    obdbs.obtrp@nova t on d.link1 = t.link1
    LEFT OUTER JOIN
    obdbs.obhau@nova h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obdbs.obspp@nova s ON h.link3 = s.link3

    where h.obsrflag = 1
    group by 
    d.permit
, d.dmis_trip_id
, d.docid
, d.nespp3
, d.nespp4
, d.vtrserno
, d.gearcode
, d.mesh
, d.area
, d.carea
--, d.landed
--, d.live
, T.GEARCAT
,t.program
,t.year
,t.sector_id
,t.fleet_type
,t.datesail 
,t.dateland 
--,s.obsrflag
--,s.negear

    ;
    
    select *
--    from obdbs.obspp@nova
    from obdbs.obtrp@nova