-- how many rows

select max(rownum)
from bg_cams_obs_catch

-- 866,258 rows

;

-- count VTRS within LINK1
select count(distinct(vtrserno)) nvtr
, link1
from bg_cams_obs_catch
where link1 is not null
group by link1
order by nvtr desc
--group by dmis_trip_id

/

-- count link1 within vtrserno
with link as (
    select count(distinct(link1)) nlink1
    , vtrserno
    from bg_cams_obs_catch
    where link1 is not null
    group by vtrserno
    order by nlink1 desc
)
select *
from link 
where nlink1 > 1
and vtrserno is not null
--group by dmis_trip_id
/

--check one of the many to 1 link1 on VTRSERNO
select *
from bg_cams_obs_catch
where vtrserno = 12771795
/

select * 
from dmis.d_match_obs_link
where dmis_trip_id = '410126_180222_121500'
/

select *
from dmis_all_years
where vtrserno = '3305491807281'
/
-- grab all dmis records where nlink1 > 1

with link as (
    select count(distinct(link1)) nlink1
    , vtrserno
    from bg_cams_obs_catch
    where link1 is not null
    group by vtrserno
    order by nlink1 desc
)

select a.*
from dmis.d_match_obs_link a, link l 
where a.obs_vtr is not null 
AND a.obs_vtr in (l.vtrserno)
AND l.nlink1 > 1
order by a.dmis_trip_id desc

/
-- this one shows 3 link1 

select *
--from obdbs.obtrp@nova
from obdbs.asmtrp@nova
where link1 in (
 select link1
 from dmis.d_match_obs_link
 where dmis_trip_id = '250164_180523_142000'
)
/
-- look at the hauls for all link1's in the above secion. Are there hauls on each link1 ?? NO! 
select *
--from obdbs.obtrp@nova
from obdbs.asmhau@nova
where link1 in (
 select link1
 from dmis.d_match_obs_link
 where dmis_trip_id = '250164_180523_142000'
)

/

select distinct(link1)
--from obdbs.obtrp@nova
from (
    select * from obdbs.obhau@nova
    union all
    select * from obdbs.asmhau@nova
)
where link1 in (
 select * --distinct(link1) link1
 , vtrserno
 from dmis.d_match_obs_link
 where vtrserno is not null
-- where dmis_trip_id = '250164_180523_142000'
)


/
select  * 
from obdbs.asmhau@nova
--from obdbs.obhau@nova
where link1 = '230201801P78001'

/

select *
from obdbs.asmotgh@nova
--from obdbs.obdbs.obotgh@nova
where link1 = '230201801P78001'
--where link3 = '230201801P780010006'


/

--check obdbs and asm directly for many to many vtr to link1
-- no multiple vtr per link1 here.. 
select count(distinct(vtrserno)) nvtr
, link1
--from obdbs.obtrp@nova
from obdbs.asmtrp@nova
where link1 is not null
and year = 2018
group by link1
order by nvtr desc
/

select count(distinct(link1)) as nlink1
, vtrserno
from obdbs.obtrp@nova
--from obdbs.asmtrp@nova
where link1 is not null
and year = 2018
group by vtrserno
order by nlink1 desc

-- asm 2018 only has 2 trips like this
-- asm 2019 only has 5 trips like this
-- obtrp 2018 has 28 trips like this
-- obtrp 2019 has 19 trips like this


-- check KALL sums

select sum(subtrip_kall)
, sum(discard)
--, nespp3
, geartype
--, obs_gear
--, meshgroup
--, Sector_id
--, accessarea
--, tripcategory
--, carea
from bg_cams_obs_catch
--where nespp3 is not null
where year = 2019
group by geartype
--, obs_gear, meshgroup, Sector_id
--, accessarea
--, tripcategory
--, carea

;