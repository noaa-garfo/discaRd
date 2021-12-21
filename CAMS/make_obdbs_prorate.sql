/*

make observer proration discard 

ben galuardi

1-6-21

modified
12-02-21 changed table references to match new OBS CAMS table names

12-21-21 Changed names to MAPS.CAMS_OBS_PRORATE 
         Changed table references to MAPS.CAMS_OBS_YYYY

*/

drop table CAMS_OBS_prorate 
/

create table MAPS.CAMS_OBS_PRORATE as

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
 , case when month in (1,2,3,4,5,6) then 1
		   when month in (7,8,9,10,11,12) then 2
		   end as HALFOFYEAR
,  case when obs_area < 600 then 'N'
               else 'S' end as region           
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
            , vtrserno
            , extract(year from datesail) as year
            , o.month
            , o.obsrflag
            , o.area as obs_area
            , o.negear as obs_gear
            , o.geartype
            , round(o.meshsize, 0) as obs_mesh
            , o.meshgroup
            , substr(nespp4, 1, 3) as NESPP3
            , SUM(case when catdisp = 0 then o.livewt else 0 end) as discard
            , SUM(case when catdisp = 1 then o.livewt else 0 end) as obs_haul_kept
        
            from (
			    select * from maps.cams_obdbs_2017
                union all
                select * from maps.cams_obdbs_2018
                union all
                select * from maps.cams_obdbs_2019
				union all
                select * from maps.cams_obdbs_2020
                union all
                select * from maps.cams_obdbs_2021
            )
            o
          group by  o.link3
            , link1
            , vtrserno
            , o.month
            , o.obsrflag
            , o.area 
            , o.geartype
            , o.negear 
            , round(o.meshsize, 0)
            , o.meshgroup
            , substr(nespp4, 1, 3)
            , extract(year from datesail)
) a
--where link1 = '230201801N54002'
) b

group by link3
            , link1
            , vtrserno
            , year
            , month
            , obsrflag
            , obs_area
            , obs_gear
            , geartype
            , obs_mesh
            , meshgroup
            , NESPP3
            , discard
            , obs_haul_kept
            , obs_haul_kall_trip
            , obs_nohaul_kall_trip
            , prorate
            , case when month in (1,2,3,4,5,6) then 1
		      when month in (7,8,9,10,11,12) then 2
		      end
,  case when obs_area < 600 then 'N'
               else 'S' end
;

--select * from obs_cams_prorate
/

grant select on cams_obs_prorate to apsd
/



            
            