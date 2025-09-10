/*
back calculation of variance from CV and Discard using variables from cams_discard_all_years

dmr= disacrd_mort_ratio

    CV = se/D
    se = CV*D
    var = se^2 = (CV*D)^2
    var_adj = (CV*(D/dmr))*(CV*(D/dmr))


ben galuardi

6/29/22

*/

select  species_itis
, COMMON_NAME
, round(sum(discard)) as D
, round(sum((CV*discard)*(CV*DISCARD))) as Var
, round(sum((CV*(discard/disc_mort_ratio))*(CV*(DISCARD/disc_mort_ratio)))) as Var_adj
, strata_full
, CAMS_GEAR_GROUP
, MESHGROUP
, SPECIES_ESTIMATION_REGION
, disc_mort_ratio
--, GF
from maps.cams_discard_all_years a
--where disc_mort_ratio <> 1 -- all species with variable mortality --yellowtail flounder --172414 -- mackerel
--and GF = 1
where FY = 2021
and species_itis = 160617
and fed_or_state = 'FED'
group by strata_full, species_itis, COMMON_NAME, CAMS_GEAR_GROUP, disc_mort_ratio
, MESHGROUP
, SPECIES_ESTIMATION_REGION --, GF
order by CAMS_GEAR_GROUP
;


select distinct species_itis
from cams_discard_all_years
where disc_mort_ratio <> 1
