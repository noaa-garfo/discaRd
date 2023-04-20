/*
BEN GALUARDI

12/16/20

CREATE MOCKUP OF CATCH TABLE FROM MAPS USING DMIS_TRIP_ID AND JOINING TO LINK1

*/


--select *
--from apsd.dmis_all_years
--;
--
--select count(distinct(vtrserno))
--, count(distinct(docid))
--, dmis_trip_id
--from apsd.cams_apport
--group by dmis_trip_id
--;

DROP TABLE catch_link1_temp ;

CREATE TABLE catch_link1_temp as 
with mtrips as (
select dmis_trip_id
    from (
        select
         count(distinct(vtrserno)) nvtr
        , count(distinct(docid)) ndocid
        , dmis_trip_id
        from apsd.cams_apport_20201222
        group by dmis_trip_id
    ) a
    where a.nvtr > 1
)
--, obs_cams as ( 
     select d.permit
        , d.dmis_trip_id
        , extract(year from d.record_land) as year
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.mesh
        , d.area
        , d.carea
        , round(sum(d.live)) as cams_kall
    , o.link1
    from mtrips m
    left join apsd.cams_apport_20201222 d on m.dmis_trip_id = d.dmis_trip_id
--    from apsd.cams_apport d
    left join (
     select *
     from dmis.d_match_obs_link
    ) o
    on o.dmis_trip_id = d.dmis_trip_id
    
    group by 
        d.permit
        , extract(year from d.record_land)
        , d.dmis_trip_id
        , d.docid
        , d.vtrserno
        , d.gearcode
        , d.mesh
        , d.area
        , d.carea
        , o.link1
    
;

grant all on catch_link1_temp to maps

;

grant all on stat_areas_def to MAPS

;

/*
select  T.GEARCAT
    ,t.program
    ,t.year
    ,t.sector_id
    ,t.fleet_type
    ,t.datesail obs_sail
    ,t.dateland obs_land
    ,s.obsrflag
    ,s.area obs_area -- this will be at at a species level.. 
    ,SUBSTR(s.nespp4,1,3) nespp3
    ,s.nespp4
    , s.negear
    ,s.fishdisp
    ,s.catdisp
    ,s.drflag
    ,s.wgttype
    , s.hailwt

    from apsd.catch_link1_temp d

    LEFT OUTER JOIN 
    obdbs.obtrp@nova t on d.link1 = t.link1
    LEFT OUTER JOIN
    obdbs.obhau@nova h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obdbs.obspp@nova s ON h.link3 = s.link3

    where h.obsrflag = 1
--    group by 
--        T.GEARCAT
--        ,t.program
--        ,t.year
--        ,t.sector_id
--        ,t.fleet_type
--        ,t.datesail 
--        ,t.dateland 
--        ,s.obsrflag
--        ,s.negear

    ;
    
    select *
--    from obdbs.obspp@nova
    from obdbs.obtrp@nova
    
    */