#----------------------------------------------------------------#
# functions for CAMS disacRd
#----------------------------------------------------------------#

require(dplyr)
require(tidyr)

# make_bdat_cams <- function(input_table = bdat, species_nespp3 = '802') {

# this need to sue the obs table explicitly.. 

# 	bdat <- input_table %>% 
# 	# group_by(DMIS_TRIP_ID, NESPP3) %>% 
# 	mutate(SPECIES_DISCARD = case_when(NESPP3 == species_nespp3 ~ DISCARD)) %>% 
# 	mutate(SPECIES_DISCARD = replace_na(SPECIES_DISCARD, 0))
# 
# 
#  bdat$MESHGROUP[bdat$MESHGROUP == 'na'] = NA
# 
#  bdat
#  


#  bdat = input_table %>% 
# 	mutate(SPECIES_DISCARD = case_when(NESPP3 == species_nespp3 ~ DISCARD_PRORATE)) %>% 
# 	mutate(SPECIES_DISCARD = replace_na(SPECIES_DISCARD, 0)) %>% 
# 		mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, sep = '_')) %>% 
#   dplyr::group_by(LINK1
#   								# , NEGEAR
#   								, GEARTYPE
#   								, MESHGROUP
#   								, STRATA
#   								) %>% 
# 	# be careful here... need to take the max values since they are repeated..
#   dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T)*max(PRORATE)), BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 
#  	mutate(KALL = replace_na(KALL, 0), BYCATCH = replace_na(BYCATCH, 0)) %>% 
# 	ungroup()
#  
#  bdat
#  
#  }
# Use this to park discard into subtrips..
get_obs_disc_vals <- function(c_o_tab = c_o_dat2, species_nespp3 = '802', year = 2019){
	
	codat <- c_o_tab %>%
		filter(YEAR == year) %>% 
		# group_by(DMIS_TRIP_ID, NESPP3) %>%
		mutate(SPECIES_DISCARD = case_when(MATCH_NESPP3 == species_nespp3 ~ DISCARD)) %>%
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
	
	
	codat$MESHGROUP[codat$MESHGROUP == 'na'] = NA
	
	obs_discard = codat %>% 
		group_by(YEAR
						 , VTRSERNO
						 # , NEGEAR
						 , GEARTYPE
						 , MESHGROUP
		) %>% 
		dplyr::summarise(KALL = sum(SUBTRIP_KALL), DISCARD = sum(SPECIES_DISCARD), dk = sum(SPECIES_DISCARD, na.rm = T)/sum(SUBTRIP_KALL, na.rm = T))
	
	obs_discard
	
}

# Make an assumed rate by gear/mesh

make_assumed_rate <- function(bdat_focal, year = 2019){
	assumed_discard = bdat_focal %>% 
		dplyr::group_by( GEARTYPE
										 , MESHGROUP
		) %>% 
		# be careful here... max values already represented from bdat_focal. So, take the sum here
		dplyr::summarise(KALL = sum(KALL, na.rm = T), BYCATCH = sum(BYCATCH, na.rm = T)) %>% 
		mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>% 
		ungroup() %>% 
		mutate(dk = BYCATCH/KALL)
	
	assumed_discard
	
}	

# set up bdat for discaRd: rolled up by sub-trip
# bdat is acquired outside of the function snce it's a large table of all species

make_bdat_focal <- function(bdat, year = 2019, species_nespp3 = '802'){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	
	# choose species here
	# bdat_focal = bdat %>% 
	# 	mutate(SPECIES_DISCARD = case_when(NESPP3 == '802' ~ DISCARD_PRORATE)) %>% 
	# 	mutate(SPECIES_DISCARD = replace_na(SPECIES_DISCARD, 0)) %>% 
	# 		mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, sep = '_')) %>% 
	#   dplyr::group_by(LINK1
	#   								# , NEGEAR
	#   								, GEARTYPE
	#   								, MESHGROUP
	#   								, STRATA
	#   								) %>% 
	# 	# be careful here... need to take the max values since they are repeated..
	#   dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T)*max(PRORATE, na.rm = T)), BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 
	# 	mutate(KALL = replace_na(KALL, 0), BYCATCH = replace_na(BYCATCH, 0)) %>% 
	# 	ungroup()
	
	
	
	bdat_focal = bdat %>% 
		filter(YEAR == year) %>% 
		mutate(SPECIES_DISCARD = case_when(MATCH_NESPP3 == species_nespp3 ~ DISCARD_PRORATE)) %>% 
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0)) %>% 
		mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, sep = '_')) %>% 
		dplyr::group_by(LINK1
										# , NEGEAR
										, GEARTYPE
										, MESHGROUP
										, STRATA
		) %>% 
		# be careful here... need to take the max values since they are repeated..
		dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T)*max(PRORATE)), BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 
		mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>% 
		ungroup()
	
	bdat_focal
	
}


run_discard <- function(bdat, ddat_focal, c_o_tab = c_o_dat2, year = 2019, species_nespp3 = '802'){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	# bdat = make_bdat_cams(obstab, species_nespp3 = species_nespp3)
	bdat_focal = make_bdat_focal(bdat, year = year, species_nespp3 = species_nespp3)
	obs_discard = get_obs_disc_vals(c_o_tab, species_nespp3 = species_nespp3, year = year)
	assumed_discard = make_assumed_rate(bdat_focal, year = year)
	
	# Get complete strata
	strata_complete = unique(c(bdat_focal$STRATA, ddat_focal$STRATA))
	
	allest = get.cochran.ss.by.strat(bydat = bdat_focal, trips = ddat_focal, strata_name = 'STRATA', targCV = .3, strata_complete = strata_complete)		
	
	# discard rates by strata
	dest_strata = allest$C %>% summarise(STRATA = STRATA
																			 , N = N
																			 , n = n
																			 , orate = round(n/N, 2)
																			 , drate = RE_mean
																			 , KALL = K, disc_est = round(D)
																			 , CV = round(RE_rse, 2)
	)
	
	# plug in estimated rates to the unobserved
	ddat_rate = ddat_focal
	ddat_rate$DISC_RATE = dest_strata$drate[match(ddat_rate$STRATA, dest_strata$STRATA)]	
	ddat_rate$CV = dest_strata$CV[match(ddat_rate$STRATA, dest_strata$STRATA)]	
	
	
	# substitute assumed rate where we can
	assumed_discard = assumed_discard %>% 
		mutate(STRATA = paste(GEARTYPE, MESHGROUP, sep = '_'))
	# mutate(STRATA = paste(NEGEAR, MESHGROUP, sep = '_'))
	
	ddat_rate = ddat_rate %>% 
		mutate(STRATA_ASSUMED = paste(GEARTYPE, MESHGROUP, sep = '_')) %>% 
		# mutate(STRATA = paste(NEGEAR, MESHGROUP, sep = '_'))
		mutate(ARATE_IDX = match(STRATA_ASSUMED, assumed_discard$STRATA)) 
	
	# ddat_rate$ARATE_IDX[is.na(ddat_rate$ARATE_IDX)] = 0
	ddat_rate$ARATE = assumed_discard$dk[ddat_rate$ARATE_IDX]
	
	
	# incorporate teh assumed rate into the calculated discard rates
	ddat_rate <- ddat_rate %>% 
		mutate(CRATE = coalesce(DISC_RATE, ARATE)) %>%
		mutate(CRATE = tidyr::replace_na(CRATE, 0)) 
	
	
	# merge observed discards with estimated discards
	# Use the observer tables created, NOT the merged trips/obs table.. 
	# match on VTRSERNO? 
	
	out_tab = obs_discard %>% 
		ungroup() %>% 
		dplyr::select(VTRSERNO, DISCARD) %>% 
		right_join(x = ., y = ddat_rate, by = 'VTRSERNO') %>% 
		mutate(EST_DISCARD = CRATE*LIVE_POUNDS) %>% 
		mutate(DISCARD = if_else(!is.na(DISCARD), DISCARD, EST_DISCARD)
		) 
	
	list(species = species_nespp3
			 , allest = allest
			 , res = out_tab
	)
	
}


#-----------------------------------------------------------------------------#
## Test it 
#-----------------------------------------------------------------------------#

# test using trips only vs merged obs/trips
ddat_focal %>% group_by(GEARTYPE) %>% dplyr::summarise(KALL = sum(LIVE_POUNDS, na.rm = T)) %>% 
	left_join(., 
c_o_dat2 %>% 
	# filter(!is.na(LINK1) & YEAR == 2019) %>%
	filter(YEAR == 2019) %>%  # KEEP ALL TRIPS IN FOR COMPARISON
	mutate(MESHGROUP = ifelse(MESHGROUP == 'na', NA, MESHGROUP)) %>% 
	mutate(SPECIES_DISCARD = case_when(NESPP3 == '802' ~ DISCARD)) %>% 
	mutate(SPECIES_DISCARD = replace_na(SPECIES_DISCARD, 0)) %>% 
	# mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, sep = '_')) %>% 
	# mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, ACCESSAREA, TRIPCATEGORY, sep = '_')) %>% 
	# mutate(STRATA = paste(GEARTYPE, MESHGROUP, AREA, SECTOR_ID, sep = '_')) %>% 
	
	dplyr::group_by(VTRSERNO
									, SUBTRIP_KALL
									, OBS_KALL
									# , NEGEAR
									, GEARTYPE
									# , MESHGROUP
									# , STRATA
	) %>% 
	# be careful here... need nested groupings to first roll up by VTR, then by gear.. 
	dplyr::summarise(#KALL_OBS = max(OBS_KALL, na.rm = T)
									 # , SUBTRIP_KALL = max(SUBTRIP_KALL, na.rm = T)
									  BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 

		dplyr::group_by(GEARTYPE) %>% 
	dplyr::summarise(OBS_KALL = sum(OBS_KALL, na.rm = T)
									 , BYCATCH = sum(BYCATCH, na.rm = T)
									 ,  SUBTRIP_KALL = sum(SUBTRIP_KALL, na.rm = T)) %>% 
	ungroup()	
, by = 'GEARTYPE')


# Now make the bdat object from the combined table

bdat_focal <- c_o_dat2 %>% 
	# filter(!is.na(LINK1) & YEAR == 2019) %>%
	filter(YEAR == 2019) %>%  # KEEP ALL TRIPS IN FOR COMPARISON
	mutate(MESHGROUP = ifelse(MESHGROUP == 'na', NA, MESHGROUP)) %>% 
	mutate(SPECIES_DISCARD = case_when(NESPP3 == '802' ~ DISCARD)) %>% 
	mutate(SPECIES_DISCARD = replace_na(SPECIES_DISCARD, 0)) %>% 
	# mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, sep = '_')) %>% 
	mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, ACCESSAREA, TRIPCATEGORY, sep = '_')) %>%
	# mutate(STRATA = paste(GEARTYPE, MESHGROUP, AREA, SECTOR_ID, sep = '_')) %>% 
	
	dplyr::group_by(#VTRSERNO
									LINK1
									# , SUBTRIP_KALL
									, OBS_KALL   # NOTE!! MUST group by OBS_KALL because this is repeated for all species discarded on that trip
									# , NEGEAR
									# , GEARTYPE
									# , MESHGROUP
									, STRATA
	) %>% 
	# be careful here... need nested groupings to first roll up by VTR, then by gear.. 
	dplyr::summarise(#KALL_OBS = max(OBS_KALL, na.rm = T)
		# , SUBTRIP_KALL = max(SUBTRIP_KALL, na.rm = T)
		BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 
	ungroup()	%>% 
	dplyr::rename(KALL = OBS_KALL) %>% 
	arrange(LINK1)


# now make the ddat object from the TRIPS ONLY object.. combined table has ssues with subtrip KALL
# this is just KALL, VTRSERNO (tripid), and STRATA
ddat_focal <- ddat_focal %>% 
	filter(YEAR == 2019) %>%  # KEEP ALL TRIPS IN FOR COMPARISON
	mutate(MESHGROUP = ifelse(MESHGROUP == 'na', NA, MESHGROUP)) %>% 
	# mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, sep = '_')) %>% 
	mutate(STRATA = paste(GEARTYPE, MESHGROUP, REGION, HALFOFYEAR, ACCESSAREA, TRIPCATEGORY, sep = '_')) %>% 
	dplyr::group_by(
		 VTRSERNO
		, STRATA
	) %>% 
	dplyr::summarise(LIVE_POUNDS = sum(LIVE_POUNDS, na.rm = T)) %>% 
  ungroup() %>% 
	mutate( SEADAYS = 0
				 , DOCID = VTRSERNO)



# Get complete strata
strata_complete = unique(c(bdat_focal$STRATA, ddat_focal$STRATA))

allest = get.cochran.ss.by.strat(bydat = bdat_focal, trips = ddat_focal, strata_name = 'STRATA', targCV = .3, strata_complete = strata_complete)		

# discard rates by strata
dest_strata = allest$C %>% summarise(STRATA = STRATA
																		 , N = N
																		 , n = n
																		 , orate = round(n/N, 2)
																		 , drate = RE_mean
																		 , KALL = K, disc_est = round(D)
																		 , CV = round(RE_rse, 2)
)


# squid_ex = run_discard(obstab = c_o_dat2, ddat = ddat_focal, year = 2019, species_nespp3 = '802')
squid_ex = run_discard(bdat = bdat, ddat = ddat_focal, c_o_tab = c_o_dat2, year = 2019, species_nespp3 = '802')


squid_ex$res$DISCARD %>% sum(na.rm = T)

# discard rates by strata
dest_strata = squid_ex$allest$C %>% summarise(STRATA = STRATA
																							, N = N
																							, n = n
																							, orate = round(n/N, 2)
																							, drate = RE_mean
																							, KALL = K, disc_est = round(D)
																							, CV = round(RE_rse, 2)
)

dest_strata %>% slice(grep('Otter Trawl_sm*', dest_strata$STRATA))

