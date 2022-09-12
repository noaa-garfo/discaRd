select c.*
, case when sum(obsrflag) OVER(PARTITION by LINK1) > 0 then 1 else 0 end as LINK3_OBS
from cams_obs_catch c
--from cams_obdbs_all_years 
--where link1 in ('010201903Q44008','000201908Q44026')
/

select count(distinct(LINK1))
, link3_obs
--, year
, substr(activity_code_1,1,3) as program
from cams_obs_catch
where link3_obs = 0
group by link3_obs, substr(activity_code_1,1,3)
order by link3_obs, program
/

select *
from cams_obs_catch 
where link3_obs = 0
/

-- see what the cams_discards look like for trips with no obs hauls but a link1
with links as (
    select distinct(LINK1) link1
    from cams_obs_catch
    where link3_obs = 0
)

select *
from cams_discard_all_years 
where GF = 1
and species_itis = '172735'
and link1 in (select link1 from links)
