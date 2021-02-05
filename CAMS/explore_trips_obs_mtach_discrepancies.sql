 /*
 
 Problem statement: the numebr of observed trips in a strata seems low when joingin a catch table to obs records and then tallying the n of obs  trips.. 
 
 When using OBS tables ONLY, the number of obs trips is ~2x higher.. This makes no sense. 
 
 Good example is otter trawl small mesh. 
 
 copmare any result in this script to number of OBS trips in this file:
 
 H:\Hocking\smb\smb_acl_accounting\smb_acl_2019\SMB_FY2019_discRd.xlsx
 
 Disregard inconsistencies with Commerical trips/strata.. obs trips is the issue. 
 
 Ben Galuardi
 
 2/5/21
 
 
 */
 
 
 -- look at unique records for dmis trip is vtr and link1. 
 
 select count(distinct(LINK1)) as nlink1
-- , count(distinct(obs_vtr)) as nvtr
 , count(distinct(dmis_trip_id)) as dmis_tid
-- , dmis_trip_id
, obs_vtr
 from dmis.d_match_obs_link
 where link1 is not null
 and obs_vtr is not null
group by obs_vtr --dmis_trip_id
 order by nlink1 desc


;

-- join on dmis_trip_id or VTR?? 

with trips as (
       select d.permit
        , d.dmis_trip_id
        , d.year
        , d.month
        , case when d.carea < 600 then 'N'
               else 'S' end as region
        , case when d.month in (1,2,3,4,5,6) then 1
             when d.month in (7,8,9,10,11,12) then 2
             end as halfofyear
        , d.docid
        , d.vtrserno as trip_vtr
        , d.gearcode
        , d.geartype
        , d.negear
        , d.mesh
        , NVL(d.meshgroup, 'na') as meshgroup
        , d.area
        , d.carea
--        , round(sum(d.pounds)) as subtrip_kall
        , pounds
        , d.sector_id
        , d.activity_code_1
        , d.activity_code_2
        , d.activity_code_3
        , d.permit_EFP_1
        , d.permit_EFP_2
        , d.permit_EFP_3
        , d.permit_EFP_4
        , d.tripcategory
        , d.accessarea
        , o.link1
        , o.obs_vtr as obs_vtr
    from apsd.bg_cams_catch_ta_mock d
--    from apsd.cams_apport d
    full join (  --adds observer link field
     select *
      from dmis.d_match_obs_link
--      from obs_cams_prorate
    ) o
--    on o.vtrserno = d.vtrserno
--      on o.obs_vtr = d.vtrserno
on o.dmis_trip_id = d.dmis_trip_id
    )

select count(distinct(trip_vtr)  )
, count(distinct(obs_vtr) )
 , GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, YEAR
 from trips
 where year = 2019
 group by 
 GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, YEAR
 order by YEAR, GEARTYPE, MESHGROUP, REGION, HALFOFYEAR
 ;
 
 -- try using total landings from 2019 ACL accoutning
 with trips as(

select   YEAR
, vtrserno as trip_vtr
,  (CASE WHEN (month IN (1,2,3,4,5,6)) then 1 
          WHEN (month IN (7,8,9,10,11,12)) then 2 
        END) as halfofyear
        , (CASE WHEN area < 600 THEN 'N'
                WHEN area >= 600 THEN 'S'
                ELSE 'Other'
                END) as region
, (CASE WHEN negear IN ('070') THEN 'Beach Seine'
			    WHEN negear IN ('020', '021') THEN 'Handline'
  			   	WHEN negear IN ('010') THEN 'Longline'
				WHEN negear IN ('170', '370') THEN 'Mid-water Trawl, Paired and Single'
				WHEN negear IN ('350','050') THEN 'Otter Trawl'
				WHEN negear IN ('057') THEN 'Otter Trawl, Haddock Separator'
				WHEN negear IN ('054') THEN 'Otter Trawl, Ruhle'
				WHEN negear IN ('053') THEN 'Otter Trawl, Twin'
				WHEN negear IN ('181') THEN 'Pots+Traps, Fish'
				WHEN negear IN ('186') THEN 'Pots+Traps, Hagfish'
				WHEN negear IN ('120','121', '123') THEN 'Purse Seine'
				WHEN negear IN ('132') THEN 'Scallop Dredge'
				WHEN negear IN ('052') THEN 'Scallop Trawl'
				WHEN negear IN ('058') THEN 'Shrimp Trawl'
				WHEN negear IN ('100', '105','110', '115','116', '117','500') THEN 'Sink, Anchor, Drift Gillnet'
				WHEN negear NOT IN 
				('070','020', '021','010','170','370','350','050','057','054','053','181',
				'186','120','121', '123','132','052','058','100', '105', '110','115','116', '117','500') THEN 'Other' 
				WHEN negear IS NULL THEN 'Unknown'
				END) as  geartype
,                 
(CASE WHEN mesh < 5.5 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'sm'
	  WHEN mesh BETWEEN 5.5 AND 7.99 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'lg'
	  WHEN mesh >= 8 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'xlg'
	  ELSE NULL
	  END)  as meshgroup
      
, o.link1
, o.obs_vtr as obs_vtr

from apsd.dmis_all_years a 
LEFT OUTER JOIN vtr.vlgear b
ON a.secgearfish = b.GEARCODE
 full join (  --adds observer link field
     select *
      from dmis.d_match_obs_link
--      from obs_cams_prorate
    ) o
--    on o.vtrserno = d.vtrserno
      on o.obs_vtr = a.vtrserno
--on o.dmis_trip_id = d.dmis_trip_id
)
 
select count(distinct(trip_vtr)  )
, count(distinct(obs_vtr) )
 , GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, YEAR
 from trips
 where year = 2019
 group by 
 GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, YEAR
 order by YEAR, GEARTYPE, MESHGROUP, REGION, HALFOFYEAR 
 
; 
-- look at number of obs trips from obs data... 
 
select count(distinct(LINK1)  )
 , GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, YEAR
from obs_cams_prorate
 where year = 2019
  group by 
 GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, YEAR
 order by YEAR, GEARTYPE, MESHGROUP, REGION, HALFOFYEAR
 