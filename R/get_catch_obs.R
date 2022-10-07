
#' Get Catch OBS data
#'
#' @param con database connection 
#' @param start_year start year (calendar year)
#' @param end_year end year (calendar year)
#'
#' @return a list with the elements needed for discard estimation: 
#' * gf_dat : a data frame of groundfish only trips. This is used only in \link{discard_groundfish.R}
#' * non_gf_dat : data frame of only non groundfish trips 
#' * all_dat : data frame of all trips
#' @export
#'
#' @examples
#' # Main example
#' dat = get_catch_obs(con_maps, 2021, 2022)
#' gf_dat = dat$gf_dat
#' non_gf_dat = dat$non_gf_dat
#' all_dat = dat$all_dat
#' rm(dat)
#' gc()
#' 
#' # Herring example 
#' dat = get_catch_obs_herring(con_maps, 2021, 2022)
#' gf_dat = dat$gf_dat
#' non_gf_dat = dat$non_gf_dat
#' all_dat = dat$all_dat
#' rm(dat)
#' gc()
#' 
get_catch_obs <- function(con = con_maps, start_year = 2017, end_year = 2022){

t1 = Sys.time()

print(paste0("Pulling CAMS_OBS_CATCH data for ", start_year, "-", end_year))	
	
import_query = paste0("  with obs_cams as (
   select year
	, month
	, date_trip
  , PERMIT
  , AREA
	, vtrserno
	, CAMS_SUBTRIP
	, link1 as link1
	, offwatch_link1
	, link3
	, link3_obs
	, offwatch_haul
	, fishdisp
	, docid
	, CAMSID
	, nespp3
  , itis_tsn as SPECIES_ITIS
  , SECGEAR_MAPPED as GEARCODE
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
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
	, NVL(sum(discard),0) as discard
	, NVL(sum(discard_prorate),0) as discard_prorate
	, NVL(round(max(subtrip_kall)),0) as subtrip_kall
	, NVL(round(max(obs_kall)),0) as obs_kall
	from CAMS_OBS_CATCH
	
	where year >=", start_year , "
	and year <= ", end_year , "
	group by year

  , AREA
  , PERMIT
	, vtrserno
	, CAMS_SUBTRIP
	, link1
	, offwatch_link1
	, link3
	, link3_obs
	, offwatch_haul
	, fishdisp
	, docid
	, nespp3
  , itis_tsn
    , SECGEAR_MAPPED
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	, SECTID
  , GF
  , case when activity_code_1 like 'NMS-COM%' then 'COMMON_POOL'
       when activity_code_1 like 'NMS-SEC%' then 'SECTOR'
			 else 'non_GF' end
  , case when PERMIT = '000000' then 'STATE'
       else 'FED' end
  , CAMSID
  , month
  , date_trip
	-- , halfofyear
	, tripcategory
	, accessarea
	, activity_code_1
  , EM
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	order by vtrserno asc
    )

  select case when o.MONTH in (1,2,3,4) then o.YEAR-1 else o.YEAR end as GF_YEAR
  , case when o.MONTH in (1,2,3) then o.YEAR-1 else o.YEAR end as SCAL_YEAR
  , o.*
  from obs_cams o

"
)


c_o_dat2 <- ROracle::dbGetQuery(con, import_query)

c_o_dat2 = c_o_dat2 %>%
	mutate(PROGRAM = substr(ACTIVITY_CODE_1, 9, 10)) %>%
	mutate(SCALLOP_AREA = case_when(substr(ACTIVITY_CODE_1,1,3) == 'SES' & PROGRAM == 'OP' ~ 'OPEN'
																	, PROGRAM == 'NS' ~ 'NLS'
																	, PROGRAM == 'NN' ~ 'NLSN'
																	, PROGRAM == 'NH' ~ 'NLSS'  # includes the NLS south Deep
																	, PROGRAM == 'NW' ~ 'NLSW'
																	, PROGRAM == '1S' ~ 'CAI'
																	, PROGRAM == '2S' ~ 'CAII'
																	, PROGRAM %in% c('MA', 'ET', 'EF', 'HC', 'DM') ~ 'MAA'
	)
	) %>%
	mutate(SCALLOP_AREA = case_when(substr(ACTIVITY_CODE_1,1,3) == 'SES' ~ dplyr::coalesce(SCALLOP_AREA, 'OPEN'))) %>%
	mutate(DOCID_ORIG = DOCID) %>% 
	mutate(DOCID = CAMS_SUBTRIP)

# NOTE: CAMS_SUBTRIP being defined as DOCID so the discaRd functions don't have to change!! DOCID hard coded in the functions..


# 4/13/22
# need to make LINK1 NA when LINK3 is null.. this is due to data mismatches in putting hauls at the subtrip level. If we don't do this step, OBS trips will get values of 0 for any evaluated species. this may or may not be correct.. it's not possible to know without a haul to subtrip match. This is a hotfix that may change in the future

# 8/17/22 this may not be needed anymore..

link3_na = c_o_dat2 %>%
	filter(!is.na(LINK1) & is.na(LINK3))


# make these values 0 or NA or 'none' depending on the default for that field

link3_na = link3_na %>%
	mutate(LINK1 = NA
				 , DISCARD = NA
				 , DISCARD_PRORATE = NA
				 , OBSRFLAG = NA
				 , OBSVTR = NA
				 , OBS_AREA = NA
				 , OBS_GEAR = NA
				 , OBS_HAUL_KALL_TRIP = 0
				 , OBS_HAUL_KEPT = 0
				 , OBS_KALL = 0
				 , OBS_LINK1 = NA
				 , OBSVTR = NA
				 , OBS_MESHGROUP = 'none'
				 , PRORATE = NA)

# this was dropping full trips...
# tidx = c_o_dat2$CAMSID %in% link3_na$CAMSID


# 8/17/22 Changing the method to remove only the records where link1 has no link3.. previously, this removed the entire trip which is probelmatic for multiple subtrip LINK1 trips

tidx = which(!is.na(c_o_dat2$LINK1) & is.na(c_o_dat2$LINK3))

c_o_dat2 = c_o_dat2[-tidx,]

# c_o_dat2 = c_o_dat2[tidx == F,]

c_o_dat2 = c_o_dat2 %>%
	bind_rows(link3_na)

# continue the data import


state_trips = c_o_dat2 %>% filter(FED_OR_STATE == 'STATE')
fed_trips = c_o_dat2 %>% filter(FED_OR_STATE == 'FED')

fed_trips = fed_trips %>%
	mutate(ROWID = 1:nrow(fed_trips)) %>%
	relocate(ROWID)

# filter out link1 that are doubled on VTR

multilink = fed_trips %>%
	filter(!is.na(LINK1)) %>%
	group_by(VTRSERNO) %>%
	dplyr::summarise(nlink1 = n_distinct(LINK1)) %>%
	arrange(desc(nlink1)) %>%
	filter(nlink1>1)

remove_links = fed_trips %>%
	filter(is.na(SPECIES_ITIS) & !is.na(LINK1) & VTRSERNO %in% multilink$VTRSERNO) %>%
	dplyr::select(LINK1) %>%
	distinct()

remove_id = fed_trips %>%
	filter(is.na(SPECIES_ITIS) & !is.na(LINK1) & VTRSERNO %in% multilink$VTRSERNO) %>%
	distinct(ROWID)

fed_trips =
	fed_trips %>%
	filter(ROWID %!in% remove_id$ROWID)

non_gf_dat = fed_trips %>%
	filter(GF == 0) %>%
	bind_rows(., state_trips) %>%
	mutate(GF = "0")

gf_dat = fed_trips%>%
	filter(GF == 1)

# need this for anything not in the groundfish loop...
all_dat = non_gf_dat %>%
	bind_rows(., gf_dat)

rm(c_o_dat2, fed_trips, state_trips)

gc()
t2 = Sys.time()

print(paste0("Took ", round(difftime(t2, t1, units = 'mins'), 2) , ' minutes'))

return(list(gf_dat = gf_dat, non_gf_dat = non_gf_dat, all_dat = all_dat))

}


get_catch_obs_herring <- function(con = con_maps, start_year = 2017, end_year = 2022){

	t1 = Sys.time()
	
	print(paste0("Pulling CAMS_OBS_CATCH Herring data for ", start_year, "-", end_year))
	
	import_query = paste0(" with obs_cams as (
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
 
 WHERE YEAR >= ", start_year, " 
  and YEAR <= ", end_year, "

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
	  WHERE YEAR >= ", start_year," 
	  and YEAR <= ", end_year,"
  )
  
  select 
   cos.*
  ,ch.cams_subtrip landings_subt
  ,ch.herr_targ
  , case when ch.herr_targ = 'HERR_TRIP' --or cos.species_itis = '161722' 
  then 'HERR' else 'NON_HERR' end HERR_FLAG
  , ch.lat_dd
  , ch.lon_dd
  ,nvl((select hma.area from gis_herring_mgmt_areas hma where sdo_contains(hma.ora_geometry,sdo_geometry(2001,8307,sdo_point_type(NVL(ch.lon_dd,0),NVL(ch.lat_dd,0),NULL),NULL,NULL)) = 'TRUE'),stat_area_hma) herr_area
  from cams_obs_spp cos
  left join cams_herr ch
  on cos.cams_subtrip = ch.cams_subtrip
      
"
	)
	
	
	c_o_dat2 <- ROracle::dbGetQuery(con, import_query)
	
	c_o_dat2 = c_o_dat2 %>% 
		mutate(PROGRAM = substr(ACTIVITY_CODE_1, 9, 10)) %>% 
		mutate(SCALLOP_AREA = case_when(substr(ACTIVITY_CODE_1,1,3) == 'SES' & PROGRAM == 'OP' ~ 'OPEN' 
																		, PROGRAM == 'NS' ~ 'NLS'
																		, PROGRAM == 'NN' ~ 'NLSN'
																		, PROGRAM == 'NH' ~ 'NLSS'  # includes the NLS south Deep
																		, PROGRAM == 'NW' ~ 'NLSW'
																		, PROGRAM == '1S' ~ 'CAI'
																		, PROGRAM == '2S' ~ 'CAII'
																		, PROGRAM %in% c('MA', 'ET', 'EF', 'HC', 'DM') ~ 'MAA'
		)
		) %>% 
		mutate(SCALLOP_AREA = case_when(substr(ACTIVITY_CODE_1,1,3) == 'SES' ~ dplyr::coalesce(SCALLOP_AREA, 'OPEN'))) %>% 
		mutate(DOCID = CAMS_SUBTRIP)
	
	# NOTE: CAMS_SUBTRIP being defined as DOCID so the discaRd functions don't have to change!! DOCID hard coded in the functions..
	
	
	# 4/13/22
	# need to make LINK1 NA when LINK3 is null.. this is due to data mismatches in putting hauls at the subtrip level. If we don't do this step, OBS trips will get values of 0 for any evaluated species. this may or may not be correct.. it's not possible to know without a haul to subtrip match. This is a hotfix that may change in the future 
	
	link3_na = c_o_dat2 %>% 
		filter(!is.na(LINK1) & is.na(LINK3))
	
	
	# make these values 0 or NA or 'none' depending on the default for that field
	link3_na = link3_na %>% 
		mutate(LINK1 = NA
					 , DISCARD = NA
					 , DISCARD_PRORATE = NA
					 , OBSRFLAG = NA
					 , OBSVTR = NA
					 , OBS_AREA = NA
					 , OBS_GEAR = NA
					 , OBS_HAUL_KALL_TRIP = 0
					 , OBS_HAUL_KEPT = 0
					 , OBS_KALL = 0
					 , LINK1 = NA
					 , OBSVTR = NA
					 , OBS_MESHGROUP = 'none'
					 , PRORATE = NA)
	
	
	tidx = c_o_dat2$CAMSID %in% link3_na$CAMSID
	
	c_o_dat2 = c_o_dat2[tidx == F,]
	
	c_o_dat2 = c_o_dat2 %>% 
		bind_rows(link3_na)
	
	# continue the data import
	
	
	state_trips = c_o_dat2 %>% filter(FED_OR_STATE == 'STATE')
	fed_trips = c_o_dat2 %>% filter(FED_OR_STATE == 'FED')
	
	fed_trips = fed_trips %>% 
		mutate(ROWID = 1:nrow(fed_trips)) %>% 
		relocate(ROWID)
	
	# filter out link1 that are doubled on VTR
	
	multilink = fed_trips %>% 
		filter(!is.na(LINK1)) %>% 
		group_by(VTRSERNO) %>% 
		dplyr::summarise(nlink1 = n_distinct(LINK1)) %>% 
		arrange(desc(nlink1)) %>% 
		filter(nlink1>1)
	
	remove_links = fed_trips %>% 
		filter(is.na(SPECIES_ITIS) & !is.na(LINK1) & VTRSERNO %in% multilink$VTRSERNO) %>% 
		dplyr::select(LINK1) %>% 
		distinct()
	
	remove_id = fed_trips %>% 
		filter(is.na(SPECIES_ITIS) & !is.na(LINK1) & VTRSERNO %in% multilink$VTRSERNO) %>% 
		distinct(ROWID)
	
	fed_trips =
		fed_trips %>% 
		filter(ROWID %!in% remove_id$ROWID)
	
	c_o_dat2 = fed_trips %>% 
		#	filter(GF == 0) %>% 
		bind_rows(., state_trips) %>% 
		mutate(GF = "0")
	
	# gf_dat = fed_trips%>% 
	# 	filter(GF == 1)
	
	rm(fed_trips, state_trips)	
	
	gc()
	t2 = Sys.time()
	
	print(paste0("Took ", round(difftime(t2, t1, units = 'mins'), 2) , ' minutes'))
	
	return(all_dat = c_o_dat2)
	
}

# dat = get_catch_obs_herring(con_maps, 2021, 2022)

# Error in .oci.GetQuery(conn, statement, data = data, prefetch = prefetch,  : 
# 											 	Error in try({ : ORA-12801: error signaled in parallel query server P017
# 											 		ORA-01427: single-row subquery returns more than one row