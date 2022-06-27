select  species_itis
, COMMON_NAME
, round(sum(discard)) as D
, round(sum((CV*discard)*(CV*DISCARD))) as Var
, round(sum((CV*(discard/disc_mort_ratio))*(CV*(DISCARD/disc_mort_ratio)))) as Var_adj
, strata_used
from maps.cams_discard_all_years a
where disc_mort_ratio <> 1 -- all species with variable mortality --yellowtail flounder --172414 -- mackerel
and GF = 1
and FY = 2021
group by strata_used, species_itis, COMMON_NAME
;


select distinct species_itis
from cams_discard_all_years
where disc_mort_ratio <> 1