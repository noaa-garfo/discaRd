/* susans example*/

select link1
, link3
, obsrflag
, oneffort
, catexist
, area
, negear
, haucomments							
from obdbs.obhau@NOVA 
where link1 = '000202101M37001' 
order by link3
;  ---27 hauls before the engine failed  NOTE: catexit =0 (no) for hauls 1-4  							


select *
from obdbs.OBSDO@NOVA
--where year = 2021

/

select *
from obdbs.OBCDO@NOVA

/
select *
from obdbs.OBSTO@NOVA


/
/* our check */
select obsrflag
, negear
, meshgroup
, accessarea
, year
, fleet_type
, source
, count(distinct(link3)) nlink3
, count(distinct(link1)) nlink1
, substr(link1, 1, 3) obprogram
from CAMS_OBDBS_all_years
where area is null
group by obsrflag
, negear
, meshgroup
, accessarea
, year
, fleet_type
, substr(link1, 1, 3)
, source

order by year desc, obprogram, negear

/

/* possible solution */

with newtable as (
   SELECT
    t.link1
    , h.link3
    , t.GEARCAT
    , t.tripext
    , t.program
    , t.year
    , t.permit1
    , t.hullnum1
    , t.fleet_type
    , t.datesail
    , t.dateland
    , h.obsrflag
    , h.catexist
    , case when h.area = '000' then null else h.area end as area
    , SUBSTR(s.nespp4,1,3) nespp3
    , s.nespp4
    , s.negear
    , s.fishdisp
    , s.catdisp
    , s.drflag
    , s.hailwt
    , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_scallop
--        , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_surfclam
--        , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_oceanquahog
--        , coalesce(d.nbushkep*8*8.333, r.nbushkep*8*8.333) as off_watch_hailwt_otherclam
    , coalesce(d.nespp4, r.nespp4) nespp4_off_watch
    , coalesce( case when  d.link3 is not null then '132' else null end  -- scallop dredge
                , case when r.link3 is not null then '052' else null end -- scallop trawl
                , case when c.link3 is not null then '382' else null end -- clam dredge
                , s.negear
                ) as negear_off_watch_coalesce
    , count(case when h.area = '000' then null else h.area end) over (order by t.link1, h.link3) as grp           
   --, EXISTS(select 'x' from em_hauls e where e.vtr_docid = i.docid)
    , 'OBDBS' as source
    
    from
    obdbs.obtrp@nova t 
    LEFT OUTER JOIN
    obdbs.obhau@nova h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obdbs.obspp@nova s ON h.link3 = s.link3
    LEFT OUTER JOIN 
    obdbs.OBSDO@NOVA d ON h.link3 = d.link3
    LEFT OUTER JOIN 
    obdbs.OBSTO@NOVA r ON h.link3 = r.link3
    LEFT OUTER JOIN 
    obdbs.OBCDO@NOVA c ON h.link3 = c.link3
    
   where t.year >= 2017 and t.year < 2022 
   and t.link1 = '000202101M37001'
   and h.catexist = 1
)


select n.*
, first_value(area) over (partition by n.grp order by link1, link3) filled_area
from newtable n

