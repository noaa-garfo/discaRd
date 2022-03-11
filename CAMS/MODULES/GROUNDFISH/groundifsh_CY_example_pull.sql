/*

example of a calendar year pull of GF discards from two fishign years

joins to AA to get trip attributes of interest

Ben Galuardi

3/11/22

run from MAPS or CAMS_GARFO

*/

with gf as (
    select * from CAMS_GARFO.CAMS_DISCARD_EXAMPLE_GF18
    WHERE year = 2019 
    and month < 5
    
    union all 
    
    select * from CAMS_GARFO.CAMS_DISCARD_EXAMPLE_GF19
    where year = 2019
    and month >= 5
)

select round(sum(discard)) as cams_discard
    , g.common_name
    , s.area_name as species_stock
    , c.negear
from gf g

left join (select * from CAMS_GARFO.cams_statarea_stock) s
on (g.species_itis = s.species_itis and g.area = s.stat_area) -- this gets the stockID strata
left join CAMS_GARFO.CAMS_CFDETT2019AA c
on (c.CAMSID = g.CAMSID AND c.VSERIAL = g.VTRSERNO)  -- this gets many other trip attributes


group by  g.common_name
    , s.area_name
    , c.negear

order by common_name, species_stock
/
