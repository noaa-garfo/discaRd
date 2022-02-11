select a.*
, b.vtr_gear_code
from maps.cams_discard_mortality_stock a
left join (select * from maps.CAMS_GEARCODE_STRATA) b
on (a.cams_gear_group = b.cams_gear_group and a.species_itis = b.species_itis)
where  a.common_name like '%WIN%'
/
-- check pound source in DMIS for 2019

select 
kept_source
, round(sum(live_pounds)) live_pounds
, round(sum(hail_weight)) hail_weight
, round(sum(pounds)) final_pounds
from apsd.dmis_all_years
where year = 2019
group by kept_source

/

-- look at livepounds from MAPS table sources

select sum(LIVLB) as LIVLB
, 'CAMS_CATCH' as source
from maps.CAMS_CATCH
where year = 2019

union all

select sum(subtrip_kall) as LIVLB
, 'CAMS_OBS_CATCH' as source
from ( 
    select camsid, vtrserno, sum(subtrip_kall) subtrip_kall
    from maps.CAMS_OBS_CATCH
    where year = 2019
    and vtrserno is null
    group by camsid, vtrserno
)
/
-- look at distinct CAMSID in STG_TRIP_ATTR and CAMS_CATCH

select count(distinct(CAMSID))
, 'dlr_vtr' as source
from maps.DLR_VTR
where year = 2019

union all

select count(distinct(CAMSID))
, 'trip_attr' as source
from maps.STG_TRIP_ATTR
where extract(year from RECORD_LAND) = 2019

union all 

select count(distinct(CAMSID))
, 'cams_catch' as source
from maps.cams_catch
where year = 2019

union all 

select count(distinct(CAMSID))
, 'merged' as source
from maps.CAMS_OBS_CATCH
where year = 2019

union all 

select count(distinct(CAMSID))
, 'match_tripid' as source
from maps.MATCH_TRIPID
where extract(year from record_land) = 2019

union all 

select count(distinct(CAMSID))
, 'vtr_rec' as source
from maps.VTR_REC
where year = 2019

/

-- are state trips in our estaimtes? 

select distinct(gear_source)
from DLR_VTR_ZERO
--
--where permit = '000000'
--and year = 2019

/
-- check pounds by area and gear for CAMS CATCH and CAMS OBS CATCH

with tab1 as (
    select NEGEAR
--    , area
    ,   count(distinct(camsid)) as n_camsid
     , sum(livlb) as livlb
     , 'CAMS_CATCH' as source
     from CAMS_CATCH a
     where year = 2019
    group by negear
--    , area
)
, tab2 as ( 
    select NEGEAR
--    , area
    ,   count(distinct(camsid)) as n_camsid
    , sum(subtrip_kall) as subtrip_kall
    , 'CAMS_OBS_CATCH' as source
    from (
        select year
        , camsid
        , vtrserno
        , subtrip_kall
        , negear
--        , area 
        from CAMS_OBS_CATCH
        where link1 is null
        
        union all
        
        (
            select year
            , camsid
            , vtrserno
            , max(subtrip_kall) as subtrip_kall
            , negear
--            , area 
            from CAMS_OBS_CATCH
            where link1 is not null
            group by year, camsid, vtrserno, negear
--            , area
        )
        
        )
    where year = 2019
    group by negear
--    , area
   
) 

select a.*, b.*
, a.livlb - b.subtrip_kall as pounds_diff
from tab1 a
full join (select * from tab2) b
on (a.negear = b.negear) -- and a.area = b.area)

 order by pounds_diff desc

/
-- look at CAMSID in CAMS_CATCH and not in CAMS_OBS_CATCH

select area
, ITIS_GROUP1
, MESH_CAT
, NEGEAR
, round(sum(livlb)) as livlb
from CAMS_CATCH a
where a.CAMSID not in (select distinct(CAMSID) from CAMS_OBS_CATCH)
and year = 2019
group by 
area
, ITIS_GROUP1
, MESH_CAT
, NEGEAR
order by livlb desc

/
-- look at NEGEAR 400
select *
from CAMS_CATCH a
where a.CAMSID not in (select distinct(CAMSID) from CAMS_OBS_CATCH)
and year = 2019
and negear = 400

/
-- look at the DLR_VTR_ZERO total pounds

with state as (
SELECT a.CAMSID
, a.docid
, a.vtrserno
, a.AREA
, a.CAREA
, a.record_land
--, a.DLR_STATE
--, a.FISHING_YEAR
--, a.LINK1
, a.NESPP3
, a.ITIS_TSN
, a.ITIS_GROUP1
--, a.NESPP4
, a.LIVLB
, a.MESH_CAT
--, a.MONTH
, a.PERMIT 
, null as sectid
, null as activity_code_1
, null as activity_code_2
, null as activity_code_3
, null as permit_EFP_1
, null as permit_EFP_2
, null as permit_EFP_3
, null as permit_EFP_4
, null as redfish_exemption
, null as closed_area_exemption
, null as sne_smallmesh_exemption
, null as xlrg_gillnet_exemption
, extract(year from a.date_trip) as year
, extract(month from a.date_trip) as month
, a.NEGEAR as negear

        , (CASE WHEN area < 600 THEN 'N'
                WHEN area >= 600 THEN 'S'
                ELSE 'Other'
                END) as region
,  (case when area in (511, 512, 513, 514, 515, 521, 522, 561) 
                then 'N' 
                 when area  NOT IN (511, 512, 513, 514, 515, 521, 522, 561)
               then 'S'
                 else 'Unknown' end)  as stockarea 
, (CASE WHEN a.negear IN ('070') THEN 'Beach Seine'
			    WHEN a.negear IN ('020', '021') THEN 'Handline'
  			   	WHEN a.negear IN ('010') THEN 'Longline'
				WHEN a.negear IN ('170', '370') THEN 'Mid-water Trawl, Paired and Single'
				WHEN a.negear IN ('350','050') THEN 'Otter Trawl'
				WHEN a.negear IN ('057') THEN 'Otter Trawl, Haddock Separator'
				WHEN a.negear IN ('054') THEN 'Otter Trawl, Ruhle'
				WHEN a.negear IN ('053') THEN 'Otter Trawl, Twin'
				WHEN a.negear IN ('181') THEN 'Pots+Traps, Fish'
				WHEN a.negear IN ('186') THEN 'Pots+Traps, Hagfish'
				WHEN a.negear IN ('120','121', '123') THEN 'Purse Seine'
				WHEN a.negear IN ('132') THEN 'Scallop Dredge'
				WHEN a.negear IN ('052') THEN 'Scallop Trawl'
				WHEN a.negear IN ('058') THEN 'Shrimp Trawl'
				WHEN a.negear IN ('100', '105','110', '115','116', '117','500') THEN 'Sink, Anchor, Drift Gillnet'
				WHEN a.negear NOT IN 
				('070','020', '021','010','170','370','350','050','057','054','053','181',
				'186','120','121', '123','132','052','058','100', '105', '110','115','116', '117','500') THEN 'Other' 
				WHEN a.negear IS NULL THEN 'Unknown'
				END) as  geartype


,  'all' as tripcategory   
,  'all' as accessarea              

 from  MAPS.DLR_VTR_ZERO a
 )
 
 select GEARTYPE, area
,   count(distinct(camsid)) as n_camsid
 , sum(livlb) as livlb
 from state 
 where year = 2019
group by geartype, area

