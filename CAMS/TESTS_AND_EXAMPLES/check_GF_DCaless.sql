
/* for a calendar year.. */

with gf as (
    select * from MAPS.CAMS_DISCARD_EXAMPLE_GF18
    WHERE year = 2019 
    and month < 5
    
    union all 
    
    select * from MAPS.CAMS_DISCARD_EXAMPLE_GF19
    where year = 2019
    and month >= 5
)
/


/* for a fishing year.. */

with gf as (
    select round(sum(discard)) as cams_discard
    from MAPS.CAMS_DISCARD_EXAMPLE_GF19
    where GF = 1
    AND TRIP_TYPE = 'FED'
    AND common_name = 'OCEAN POUT'
)
/

with gf as (
    select *
    from MAPS.CAMS_DISCARD_EXAMPLE_GF19
     where GF = 1
    AND TRIP_TYPE = 'FED'
)

select round(sum(discard)) as cams_discard
    , g.common_name
    , max(s.area_name) as species_stock
    , c.negear
    , c.mesh_cat
    , c.SECTID
from gf g

left join (select * from MAPS.cams_statarea_stock) s
on (g.species_itis = s.species_itis and g.area = s.stat_area) -- this gets the stockID strata

left join (
    select  negear
    ,  mesh_cat
    , sectid
    , camsid
    , vtrserno
    from  MAPS.CAMS_CATCH 
    group by negear
    ,  mesh_cat
    , sectid
    , camsid
    , vtrserno
) c
on (c.CAMSID = g.CAMSID AND c.VTRSERNO = g.VTRSERNO)  -- this gets many other trip attributes

WHERE g.common_name = 'OCEAN POUT'

group by  g.common_name
    , s.area_name
    , c.negear
    , c.mesh_cat
    , c.SECTID

order by common_name , species_stock
/

grant select on cams_catch to apsd
/
grant select on CAMS_DISCARD_EXAMPLE_GF19 to APSD
/
grant select on CAMS_DISCARD_EXAMPLE_GF18 to APSD
/

grant select on MAPS.cams_statarea_stock to apsd