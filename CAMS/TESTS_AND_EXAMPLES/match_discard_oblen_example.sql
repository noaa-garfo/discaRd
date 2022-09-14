/*

match discard_all_years with oblen

witch flounder example

ben galuardi

7/15/22



*/

with dc as (
    select distinct(cams_subtrip)
    from cams_discard_all_years
    where GF = 1
    and Year = 2020
    and species_itis = 172873
)

, mylink3 as (
    select a.* 
    from cams_link3_subtrip a, dc d
    where a.cams_subtrip in d.cams_subtrip

)

, len as (
     select *
     from obdbs.oblen@nova
     where nespp4 = '1220'
     union all 
     select *
     from obdbs.asmlen@nova
     where nespp4 = '1220'
)


select o.*
, m.cams_subtrip
from len o
right join mylink3 m 
on o.link3 = m.link3
--where o.nespp4 = '1220'


--/
--
--select * from maps.CFG_NESPP3_ITIS 
--where itis_tsn = 172873