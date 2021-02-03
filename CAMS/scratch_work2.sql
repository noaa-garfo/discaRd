select *
from fso.t_observer_mortality_ratio
;

select *
from apsd.s_nespp3_match_conv
;

SELECT
  *
FROM
  apsd.cams_apport_20201222 a
  ,apsd.cams_trip_attribute ta
WHERE
  a.dmis_trip_id = ta.dmis_trip_id
AND a.permit = 410458

;
select o.*
, case when c.match_nespp3 is not null then c.match_nespp3 else o.nespp3 end as match_nespp3
from obs_cams_prorate o
left join (select * from apsd.s_nespp3_match_conv) c
on o.nespp3 = c.nespp3

;

with obs_cams as (
   select year
	, month
	, region
	, halfofyear
	, area
	, vtrserno
	, docid
	, dmis_trip_id
	, nespp3
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	, NVL(sum(discard),0) as discard
	, NVL(round(max(subtrip_kall)),0) as subtrip_kall
	, NVL(round(max(obs_kall)),0) as obs_kall
	, NVL(sum(discard)/round(max(obs_kall)), 0) as dk
	from apsd.bg_obs_cams_tmp2
	where nespp3 is not null
	group by year, area, vtrserno, nespp3, docid, NEGEAR, GEARTYPE
	, MESHGROUP, dmis_trip_id, month
	, region
	, halfofyear
	order by vtrserno desc
    ) 
    
 select o.*
, case when c.match_nespp3 is not null then c.match_nespp3 else o.nespp3 end as match_nespp3
from obs_cams o
left join (select * from apsd.s_nespp3_match_conv) c
on o.nespp3 = c.nespp3   

;
with trips as (
SELECT 
--a.dmis_trip_id
 a.docid
, a.vtrserno
, a.AREA
--, a.CAREA
--, a.record_land
--, a.DLR_STATE
--, a.FISHING_YEAR
--, a.LINK1
, a.NESPP3
, a.NESPP4
, a.pounds as POUNDS
, a.MESH
--, a.MONTH
, a.PERMIT 
, extract(year from a.date_trip) as year
, extract(month from a.date_trip) as month
--, a.YEAR||a.ID yearid
, b.gearnm
, b.GEARCODE
, b.NEGEAR
, b.NEGEAR2
,  (CASE WHEN (month IN (1,2,3,4,5,6)) then 1 
          WHEN (month IN (7,8,9,10,11,12)) then 2 
        END) as halfofyear
        , (CASE WHEN area < 600 THEN 'N'
                WHEN area >= 600 THEN 'S'
                ELSE 'Other'
                END) as region
,  (case when area in (511, 512, 513, 514, 515, 521, 522, 561) 
                then 'N' 
                 when area  NOT IN (511, 512, 513, 514, 515, 521, 522, 561)
               then 'S'
                 else 'Unknown' end)  as stockarea 
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
            
--FROM apsd.cams_apport_ntrip_20200106  a 
FROM apsd.dmis_all_years  a 
    LEFT OUTER JOIN vtr.vlgear b
ON a.secgearfish = b.GEARCODE
where a.year = 2019
and docid is not null
)

select count(distinct(VTRSERNO)) as nvtr
, count(distinct(docid)) as ndocid
, gearnm
, meshgroup
, region
, halfofyear
from trips
where NEGEAR in ('350','050')
group by gearnm
, meshgroup
, region
, halfofyear
;
select --count(distinct(VTRSERNO)) as nvtr
 count(distinct(yearid)) as n_id
, gearnm
, meshgroup
, region
, halfofyear
from dh_total_landings_1
where NEGEAR in ('350','050')
group by gearnm
, meshgroup
, region
, halfofyear

