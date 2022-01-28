-- DMIS

select round(sum(HADGBE_DISCARD)) as HADGBE_discard
, count(distinct(VTRSERNO)) as nsubtrips
--, DOCID
--, VTRSERNO
, SECGEARFISH
, mesh_cat
from apsd.dmis_all_years
where fishing_year = 2019
and sector_id = 3
and area in (561, 562)
and fishery_group in ('GROUND', 'OTHER')
group by secgearfish, mesh_cat--, DOCID--, VTRSERNO
/


-- CAMS OBS CATCH
select count(distinct(vtrserno)) as ntrips
, SECGEAR_MAPPED
, NEGEAR
, meshgroup
, case when MONTH in (1,2,3,4) then YEAR-1 else YEAR end as GF_YEAR
from maps.CAMS_OBS_CATCH
where sectid = 3
and area in (561, 562)
and activity_code_1 like 'NMS%'
group by NEGEAR, SECGEAR_MAPPED, meshgroup, case when MONTH in (1,2,3,4) then YEAR-1 else YEAR end

/

--CAMS_CATCH
select count(distinct(vtrserno)) as ntrips
, GEARTYPE
, NEGEAR
, mesh_cat
, case when MONTH in (1,2,3,4) then YEAR-1 else YEAR end as GF_YEAR
from maps.CAMS_CATCH
where sectid = 3
and area in (561, 562)
and activity_code_1 like 'NMS%'
group by NEGEAR, GEARTYPE, mesh_cat, case when MONTH in (1,2,3,4) then YEAR-1 else YEAR end

/

-- DLR_VTR
select
    count(distinct camsid) as n_trips
    , count(distinct docid) as n_docid
    , area
    , area_source
    , negear
    , gear_source
    , mesh_cat
from 
    maps.dlr_vtr
where
    docid IN (
'5190951',
'5215630',
'5215634',
'5183832',
'5217872',
'5184935',
'5217880',
'5190937',
'5209282',
'5195952'
)
group by
    area
    , area_source
    , negear
    , gear_source
    , mesh_cat


