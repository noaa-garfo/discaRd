#----------------------------------------------------------------------------------------------#
## Test using merged table of observer and catch records to perform the discard calculations
# 2/10/21
# ben galuardi
#----------------------------------------------------------------------------------------------#

# Step 1. run chunks from discard_steps_for_CAMS.RMD to get ddat_focal, bdat and c_o_dat tables
# c_o_dat is a combiend observer/catch table used to park observed discards on a subtrip. 
# bdat is obs rcecords only 
# ddat_focal is catch records only with KALL rolled up to the subtrip level (VTR)

source('cams_discard_functions.R')

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
