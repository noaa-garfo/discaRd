/* 
tally loss of hauls during matchign process

ben galuardi

7/15/22

*/
with obs1 as (
select a.*
    from (
 select o.link3
            , link1
--            , vtrserno
            , extract(year from dateland) as year
--            , o.month
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
                union all
                select * from maps.cams_obdbs_2022
            )
            o
            
       where tripext in ('C','X')     
          group by  o.link3
            , link1
--            , vtrserno
--            , o.month
            , o.obsrflag
            , o.area 
            , o.geartype
            , o.negear 
            , round(o.meshsize, 0)
            , o.meshgroup
            , substr(nespp4, 1, 3)
            , extract(year from dateland)
) a

group by link3
            , link1
--            , vtrserno
            , year
--            , month
            , obsrflag
            , obs_area
            , obs_gear
            , geartype
            , obs_mesh
            , meshgroup
            , NESPP3
            , discard
            , obs_haul_kept
)

,obs_ct as (
    select year
    , count(distinct(link1)) nlink1
    , count(distinct(link3)) nlink3
from obs1 
group by year
)

select c.year,
 count(distinct(c.obs_link1)) as obs_catch_nlink1
    , count(distinct(c.link3)) as obs_catch_nlink3
    , o.nlink1
    , o.nlink3
   from cams_obs_catch c 
   left join obs_ct o on c.year = o.year
   
   group by c.year
   , o.nlink1
   , o.nlink3
   