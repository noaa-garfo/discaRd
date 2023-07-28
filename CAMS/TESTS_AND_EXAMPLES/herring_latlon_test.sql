
DEF start_year = 2018
DEF end_year = 2022
/

create table herr_ll_tmp as 

with obs_cams as (
   select year
	, month
  , PERMIT
	, case when month in (5,6,7,8,9,10) then 1
	       when month in (11,12,1,2,3,4) then 2
	       end as halfofyear
  , AREA
	, vtrserno
  , CAMS_SUBTRIP
	, LINK1
	, offwatch_link1
	, link3
	, link3_obs
	, docid
	, CAMSID
	, nespp3
  , itis_tsn as SPECIES_ITIS
  -- , itis_group1
    , SECGEAR_MAPPED as GEARCODE
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	,FISHDISP 
	, SECTID
  , GF
, case when activity_code_1 like 'NMS-COM%' then 'COMMON_POOL'
       when activity_code_1 like 'NMS-SEC%' then 'SECTOR'
			 else 'non_GF' end as SECTOR_TYPE
, case when PERMIT = '000000' then 'STATE'
       else 'FED' end as FED_OR_STATE
	, tripcategory
	, accessarea
	, activity_code_1
  , EM
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	, NVL(sum(discard_prorate),0) as discard
	, NVL(sum(discard_prorate),0) as discard_prorate
	, NVL(round(max(subtrip_kall)),0) as subtrip_kall
	, NVL(round(max(obs_kall)),0) as obs_kall
--	,  NVL(sum(discard)/nullif(round(max(obs_kall)), 0), 0) as dk
	from MAPS.CAMS_OBS_CATCH
 
 WHERE YEAR >= &start_year
  and YEAR <= &end_year

	group by year
  , AREA
  , PERMIT
	, vtrserno
  , CAMS_SUBTRIP
	, LINK1
	, offwatch_link1
	, link3
	, link3_obs
	, docid
	, nespp3	
  , itis_tsn
    , SECGEAR_MAPPED
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	, SECTID
	,FISHDISP
  , GF
  , case when activity_code_1 like 'NMS-COM%' then 'COMMON_POOL'
       when activity_code_1 like 'NMS-SEC%' then 'SECTOR'
			 else 'non_GF' end
  , case when PERMIT = '000000' then 'STATE'
       else 'FED' end
  , CAMSID
  , month
	, case when month in (5,6,7,8,9,10) then 1
	       when month in (11,12,1,2,3,4) then 2
	       end	, tripcategory
	, accessarea
	, activity_code_1
  , EM
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	order by vtrserno asc
    ) , cams_obs_spp as( 

  select case when MONTH in (1,2,3,4) then YEAR-1 else YEAR end as GF_YEAR
  , case when MONTH in (1,2,3) then YEAR-1 else YEAR end as SCAL_YEAR
  , o.*
  , c.match_nespp3
  , coalesce(c.match_nespp3, o.nespp3) as nespp3_final
  from obs_cams o
  left join apsd.s_nespp3_match_conv c on o.nespp3 = c.nespp3)  
  
  , cams_herr as(
  select distinct (cl.camsid||'_'||cl.subtrip) cams_subtrip
  ,case when itis_tsn = '161722' then 'HERR_TRIP' else NULL end herr_targ
  ,cl.lat_dd
  ,cl.lon_dd
  ,(select hs.area_herr from cams_garfo.cfg_fed_area hs where cl.area = hs.area) stat_area_hma
	  from maps.cams_landings cl
	  WHERE YEAR >= &start_year
	  and YEAR <= &end_year
  )
  , vtr_latlon AS(
--VTR LAT/LON
--FISHING LOCATIONS FROM VTR.  REPLACES LAT/LON WITH ESTIMATE LAT/LON FROM LORAN KEY WHEN LORAN GIVEN.
SELECT 
  --vtrserno
  serial_num vtrserno -- AEWA
  ,TO_NUMBER(carea) carea
  ,TO_NUMBER(area) area
  ,COALESCE(-NULLIF((lon_degree + (lon_minute/60) + NVL((lon_second/3600),0)),0)
	,-NULLIF((clondeg + (clonmin/60) + NVL((clonsec/3600),0)),0)) ddlon
  ,COALESCE(NULLIF((lat_degree + (lat_minute/60) + NVL((lat_second/3600),0)),0)
	,NULLIF((clatdeg + (clatmin/60) + NVL((clatsec/3600),0)),0)) ddlat
FROM 
  --dmis.t_vtr_images v --LEFT OUTER JOIN v_loran_key lk ON lk.loran1 = v.loran1 AND lk.loran2 = v.loran2 --remove LORAN_KEY ref on 2020-01-13...causing invalid number...this is a bad patch anyways!
  noaa.images -- AEWA
)
  
  select 
   cos.*
  ,ch.cams_subtrip landings_subt
  ,ch.herr_targ
  , case when ch.herr_targ = 'HERR_TRIP' --or cos.species_itis = '161722' 
  then 'HERR' else 'NON_HERR' end HERR_FLAG
  , ch.lat_dd
  , ch.lon_dd
  , vt.ddlat
  , vt.ddlon
  ,nvl((select hma.area from gis_herring_mgmt_areas hma where sdo_contains(hma.ora_geometry,sdo_geometry(2001,8307,sdo_point_type(NVL(vt.ddlon,0),NVL(vt.ddlat,0),NULL),NULL,NULL)) = 'TRUE'),stat_area_hma) herr_area_vtr
--  ,nvl((select hma.area from gis_herring_mgmt_areas hma where sdo_contains(hma.ora_geometry,sdo_geometry(2001,8307,sdo_point_type(NVL(ch.lon_dd,0),NVL(ch.lat_dd,0),NULL),NULL,NULL)) = 'TRUE'),stat_area_hma) herr_area_cams
  from cams_obs_spp cos
  left join cams_herr ch on cos.cams_subtrip = ch.cams_subtrip
  left join vtr_latlon vt on cos.vtrserno = vt.vtrserno
  ;
  
  
  select * from cams_obs_catch where camsid in ('214165_20051008150000_2359174', '214165_20051006150000_2347197');
select * from cams_landings where camsid in ('214165_20051008150000_2359174', '214165_20051006150000_2347197');
  
