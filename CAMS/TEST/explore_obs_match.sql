with docid as (
    select dmis_docid
    from apsd.bg_obsvtr_status_la
)

select count(distinct(vtrserno))
, docid
from apsd.dmis_all_years, docid d
where docid in d.dmis_docid
and get_scal_fy(date_trip) = 2019
group by docid
;

select *
from apsd.dmis_all_years
where docid = 5241807
;


select *
from dmis.d_match_obs_link

;

select count(obs_vtr) ct
, dmis_trip_id
from dmis.d_match_obs_link
group by dmis_trip_id
order by ct desc

;

-- Brant's obs matching

SELECT
  NVL(av.docid, av.das_id) trip_id
  ,av.permit
  ,CASE WHEN av.docid IS NOT NULL THEN 'DOCID' WHEN av.docid IS NULL AND av.das_id IS NOT NULL THEN 'DAS_ID' END trip_id_type
  , MIN(link1) link1
  ,'HUMAN' observer_mode
  ,0 monitoring_program_id
FROM
  apsd.mv_dmis_match_ams_vtr av
  , apsd.mv_dmis_match_obs_link o 
WHERE 
  av.dmis_trip_id = o.dmis_trip_id 
GROUP BY
  NVL(av.docid,av.das_id)
  , av.permit
  ,CASE WHEN av.docid IS NOT NULL THEN 'DOCID' WHEN av.docid IS NULL AND av.das_id IS NOT NULL THEN 'DAS_ID' END
--  , observer_mode
--  , monitoring_program_id
