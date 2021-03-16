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

-- look at dmis obs match with mulit link1 for vtr
with link as (
    select count(distinct(link1)) nlink1
    , dmis_trip_id
    from bg_cams_obs_catch
    where link1 is not null
    group by dmis_trip_id
    order by nlink1 desc
)

select * 
from dmis.d_match_obs_link
where dmis_trip_id in (
    select dmis_trip_id
    from link 
    where nlink1 > 1
--    and vtrserno is not null
)
--group by dmis_trip_id





/
-- build an intermediary tablewith 1-1 vtr to link1 from DMIS_MATCH_OBS_LINK
with link as (
    select count(distinct(link1)) nlink1
    , vtrserno
    from bg_cams_obs_catch
    where link1 is not null
    group by vtrserno
    order by nlink1 desc
)
select obs_vtr
, permit
, min(link1) as minlink1
, dmis_trip_id
from (
    select a.*
    from dmis.d_match_obs_link a, link l
    where obs_vtr in (l.vtrserno)
    and l.vtrserno is not null
)
--where permit = 410126
group by obs_vtr, permit, dmis_trip_id
order by permit, obs_vtr

/
-- count of obsvtr that are not null

select sum(case when obs_vtr is null then 1 else 0 end) as null_ct
, sum(case when obs_vtr is null then 0 else 1 end) as vtr_good_ct
, extract(year from obs_sail) year
, a.obs_link_match
from dmis.d_match_obs_link a
group by  extract(year from obs_sail), a.obs_link_match
order by year

/
--check one of the many to 1 link1 on VTRSERNO
select *
from bg_cams_obs_catch
where vtrserno = 12844034
/

select * 
from dmis.d_match_obs_link
--where dmis_trip_id = '410126_180222_121500'
--where link1 = '000201907P99026' -- first link1...
where link1 = '000201907R53022' -- second link1... 
--where obs_vtr = '12844034'
/

-- CAMS appt table
 select * from
 apsd.bg_cams_catch
 where vtrserno in ('12844034','12844035')


/

select vtrserno
, docid
, date_trip
, area
, secgearfish
, permit
from dmis_all_years
--where vtrserno = '12844034'
where permit = 240206
and date_trip >= '01-JUL-19'
and date_trip < '01-AUG-19'
order by date_trip

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

-- check a bad example

with hauls as (
    select link1, link3, datehbeg
    from obdbs.obhau@nova
--    where year = 2018
    union all
    select link1, link3, datehbeg
    from obdbs.asmhau@nova
--    year = 2018
)
/

with otrips as (
    select hullnum1, link1
    from obdbs.obtrp@nova
    union all
    select hullnum1, link1
    from obdbs.asmtrp@nova
)
select *
from otrips
where link1 in (
     select unique(link1) as link1
    from dmis.d_match_obs_link
    where dmis_trip_id = '410126_180222_121500'
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