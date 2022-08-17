/*

Check the extent of dropped hauls/trips
7/20/22

Ben Galuardi

check mismatches for 

area
gear
mesh 


8/1/2022

at least, that's how it was intended... turns out there were other issues. 

When building CAMS_OBS_CATCH, the order of joins between cams_landings and OBDBS information was as follows (simplified):

cams_landings 
left join match_obs  (to get camsid)
left join cams_obdbs_all_years  

the match_obs table has more link1  than cams_obdbs due to filtering trip_ext within that table build. 
This then leads to more link1 records than intended and throws off comparisons between obdbs and cams_obs_catch
Any comparisons made using the match_obs table will show link1 numebrs to be higher than they are in cams_obs_catch

A better approach may be to alter the order of the joins

cams_obdbs_all_years
left join match_obs (to get camsid)
right join cams_landings

This has the effect of maintaining only the link1 records from the obdbs table build

The script to build the new version is

merge_cams_catch_obs_test.sql

The original version is merge_cams_catch_obs



*/

-- from schema maps:

grant select on maps.cams_obdbs_2017 to cams_garfo;
grant select on maps.cams_obdbs_2018 to cams_garfo;
grant select on maps.cams_obdbs_2019 to cams_garfo;
grant select on maps.cams_obdbs_2020 to cams_garfo;
grant select on maps.cams_obdbs_2021 to cams_garfo;
grant select on maps.cams_obdbs_2022 to cams_garfo;


/

-- see how many link1 match between obdbs table build, STG_obs_linktrp and MTACH_OBS
select year
, count(*)
from(
    select distinct(c.link1) as obdbs_link1
    , c.year
    --, b.obs_link1 as stg_link1 
    , m.obs_link1 as match_link1
    from cams_obdbs_all_years c
    --full join (select obs_link1 from stg_obs_linktrp where extract(year from obs_land) between 2017 and 2022) b 
    --on c.link1 = b.obs_link1
    full join (select obs_link1 from match_obs where extract(year from obs_land) between 2017 and 2022) m
    on c.link1 = m.obs_link1
    where c.year >= 2017
    and c.year < 2022
)
where match_link1 is null
group by year
order by year desc
/

--look for link1 in obdbs that are not in matching table

 select distinct(c.link1) as obdbs_link1
    , c.year
    , c.link1
    from cams_obdbs_all_years c
  where c.link1 not in (
   select obs_link1 from match_obs where extract(year from obs_land) between 2017 and 2022
  )
  and c.year >= 2017
    and c.year < 2022

/
-- compare staging and matching tables for dropped link1

select year
, count(*)
from(
    select  extract(year from obs_land) as year
    , b.obs_link1 as stg_link1 
    , m.obs_link1 as match_link1
    from  stg_obs_linktrp b 
    full join (select obs_link1 from match_obs where extract(year from obs_land) between 2017 and 2022) m
    on b.obs_link1 = m.obs_link1
    where extract(year from obs_land) between 2017 and 2022 
    and obs_tripext in ('C','X')
)
where match_link1 is null
group by year
order by year desc


/

 select distinct(c.link1) as obdbs_link1
    , c.year
    , c.link1
    from cams_obdbs_all_years c
  where c.link1 not in (
   select obs_link1 from match_obs where extract(year from obs_land) between 2017 and 2022
  )
  and c.year >= 2017
    and c.year < 2022



/


/*------------------------------------------------------------------------------ 

This section compares cams_obdbs_all_years, cams_obs_catch, cams_obs_catch_test

------------------------------------------------------------------------------*/

/
-- now test link1 drops in cams_obs_catch_test
select count(distinct link1)
from cams_obdbs_all_years
where link1 not in (select distinct link1 from cams_obs_catch_test where link1 is not null and year < 2022)

/
-- trips with info
select *
from cams_obdbs_all_years
where link1 not in (select distinct link1 from cams_obs_catch_test where link1 is not null and year < 2022)

/

-- test link3 drops in cams_obs_catch_test
select count(distinct(link3))
from cams_obdbs_all_years
where link3 not in (select distinct(link3) from cams_obs_catch_test where link3 is not null and year < 2022)

/

-- test link1 in cams_obs_catch_test from match_obs
select count(distinct(obs_link1))
from match_obs
where obs_link1 not in (select distinct(link1) from cams_obs_catch_test where link1 is not null and year < 2022)
and extract(year from obs_land) between 2017 and 2021

/

-- test link1 from stg_obs_linktrp
select count(distinct(obs_link1))
from stg_obs_linktrp
where obs_link1 not in (select distinct(link1) from cams_obs_catch_test where link1 is not null and year < 2022)
and extract(year from obs_land) between 2017 and 2021
/


-- test link1 from all years
select count(distinct(link1))
from cams_obdbs_all_years
where link1 not in (select distinct(link1) from cams_obs_catch_test where link1 is not null and year < 2022 and year >= 2017)
and year < 2022 and year >= 2017

/

-- now look at counts of link1 and link3 vs original cams_obs_catch and cams_obs_catch_test and obdbs 

select count(distinct(a.link1)) as link1_test
, count(distinct(a.obs_link1)) as obs_link1_test
, count(distinct(a.link3)) as link3_test
, b.link1_cams
, b.link3_cams
, c.link1_obdbs
, c.link3_obdbs
, a.year
--, 'test' as source
from maps.cams_obs_catch_test a

left join ( 
    select count(distinct(link1)) as link1_cams
    , count(distinct(link3)) as link3_cams
    , year
    from maps.cams_obs_catch
    group by year
) b
on a.year = b.year

left join ( 
    select count(distinct(link1)) as link1_obdbs
    , count(distinct(link3)) as link3_obdbs
    , year
    from maps.cams_obdbs_all_years
    group by year
) c
on a.year = c.year

group by a.year, b.link1_cams, b.link3_cams, c.link1_obdbs, c.link3_obdbs
order by year
/

-- look at which link1 are not in new version.. 
-- ther seem to be 
select * from (
select a.link1 as link1_test
, b.link1 as link1_cams
from cams_obs_catch_test a
--full join cams_obs_catch b
full join cams_obdbs_all_years b
on a.link1 = b.link1
where a.year < 2022
and b.year < 2022
and a.link1 is not null
and b.link1 is not null
)
--where LINK1_TEST is null  -- zero records
where LINK1_CAMS is null  -- zero records?!?!
/
/* 


This section was used to discover that the order of joins mattered.. 
The join logic here was emulated in the cams_obs_catch_test table

this section does not need to be looked at directly. 

*/


/*  Example of dropped hauls where there was no link1 match  */

-- from schema cams_garfo: 

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
            
            cams_obdbs_all_years
--			    select * from maps.cams_obdbs_2017
--                union all
--                select * from maps.cams_obdbs_2018
--                union all
--                select * from maps.cams_obdbs_2019
--				union all
--                select * from maps.cams_obdbs_2020
--                union all
--                select * from maps.cams_obdbs_2021
--                union all
--                select * from maps.cams_obdbs_2022
            )
            o
            
       where tripext in ('C','X')     
          group by  o.link3
            , link1
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
, cams as (
    select distinct(camsid), subtrip, negear, vtr_mesh, mesh_cat, area, area_source, gear_source, activity_code_1, secgear_mapped--, year
    from cams_garfo.cams_landings c
     left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on c.NEGEAR = g.VTR_NEGEAR
)

select a.*
, case when secgear_obs = secgear_mapped then 'match' else 'no match' end as gear_match
, case when meshgroup = mesh_cat then 'match' else 'no match' end as mesh_match
, case when obs_area = area then 'match' else 'no match' end as area_match
from (
    select o.*, c.* , g.secgear_mapped as secgear_obs
    from obs1 o
    
    left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on o.OBS_GEAR = g.VTR_NEGEAR
     
    
    left join cams_garfo.match_obs m on o.link1 = m.obs_link1
    left join cams c on c.camsid = m.camsid 
    where o.link1 not in (select distinct link1 from cams_obs_catch where link1 is not null) -- and year = 2020)

) a

;

/*  Example of dropped hauls where there was a link1 match but dropped link3 */

-- from schema cams_garfo: 

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
, cams as (
    select distinct(camsid), subtrip, vtrserno, negear, vtr_mesh, mesh_cat, area, area_source, gear_source, activity_code_1, secgear_mapped--, year
    from cams_garfo.cams_landings c
     left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP 
      where NEGEAR is not null
     ) g on c.NEGEAR = g.VTR_NEGEAR
)

select a.*
, case when secgear_obs = secgear_mapped then 'match' else 'no match' end as gear_match
, case when meshgroup = mesh_cat then 'match' else 'no match' end as mesh_match
, case when obs_area = area then 'match' else 'no match' end as area_match
from (
    select o.*, c.* , g.secgear_mapped as secgear_obs
    from obs1 o
    
    left join (
      select distinct(NEGEAR) as VTR_NEGEAR
       , SECGEAR_MAPPED
      from MAPS.STG_OBS_VTR_GEARMAP
      where NEGEAR is not null
     ) g on o.OBS_GEAR = g.VTR_NEGEAR
     
    
    left join cams_garfo.match_obs m on o.link1 = m.obs_link1
    left join cams c on c.camsid = m.camsid 
    where o.link1 in (select distinct link1 from cams_obs_catch where link1 is not null) -- and year = 2020)
    AND o.link3 not in (select distinct link3 from cams_obs_catch where link3 is not null) -- and year   = 2020)
) a