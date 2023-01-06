#' discard_generic: Calculate discards for January fishing year species
#'
#' @param con ROracle connection to Oracle (e.g. MAPS)
#' @param species dataframe with species info
#' @param FY Fishing Year
#' @param all_dat Data frame of trips built from CAMS_OBS_CATCH and control script routine
#' @param save_dir Directory to save (and load saved) results
# #' @param FY_TYPE Type of fishing year. This detemrines the time element for the trips used in discard estimation. Herring, Groundifsh, and scallop trips for groundfish are separate functions,
#' @return nothing currently, writes out to fst files (add oracle?)
#' @export
#'
#' @examples
#'
discard_generic <- function(con = con_maps
														 , species = species
														 , FY = fy
														 #, FY_TYPE = c('Calendar','March','April','May','November')
														 , all_dat = all_dat
														 , save_dir = file.path(getOption("maps.discardsPath"), "calendar")
) {


	if(!dir.exists(save_dir)) {
		dir.create(save_dir, recursive = TRUE)
		system(paste("chmod 770 -R", save_dir))
	}


	FY_TYPE = species$RUN_ID[1]

	dr = get_date_range(FY, FY_TYPE)
	end_date = dr[2]
	start_date = dr[1]

	# Stratification variables

	stratvars = c('SPECIES_STOCK'
								,'CAMS_GEAR_GROUP'
								, 'MESHGROUP'
								, 'TRIPCATEGORY'
								, 'ACCESSAREA')


	# Begin loop


	for(i in 1:length(species$ITIS_TSN)){

		t1 = Sys.time()

		print(paste0('Running ', species$ITIS_NAME[i], " for Fishing Year ", FY))

		# species_nespp3 = species$NESPP3[i]
		#species_itis = species$ITIS_TSN[i]

		species_itis <- as.character(species$ITIS_TSN[i])
		species_itis_srce = as.character(as.numeric(species$ITIS_TSN[i]))
		#--------------------------------------------------------------------------#
		# Support table import by species

		# GEAR TABLE
		CAMS_GEAR_STRATA = tbl(con, sql('  select * from CFG_GEARCODE_STRATA')) %>%
			collect() %>%
			dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>%
			filter(ITIS_TSN == species_itis) %>%
			dplyr::select(-NESPP3, -ITIS_TSN)

		# Stat areas table
		# unique stat areas for stock ID if needed
		STOCK_AREAS = tbl(con, sql('select * from CFG_STATAREA_STOCK')) %>%
			filter(ITIS_TSN == species_itis) %>%
			collect() %>%
			group_by(AREA_NAME, ITIS_TSN) %>%
			distinct(AREA) %>%
			mutate(AREA = as.character(AREA)
						 , SPECIES_STOCK = AREA_NAME) %>%
			ungroup()

		# Mortality table
		CAMS_DISCARD_MORTALITY_STOCK = tbl(con, sql("select * from CFG_DISCARD_MORTALITY_STOCK"))  %>%
			collect() %>%
			mutate(SPECIES_STOCK = AREA_NAME
						 , GEARCODE = CAMS_GEAR_GROUP
						 , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
			select(-AREA_NAME) %>%
			filter(ITIS_TSN == species_itis) %>%
			dplyr::select(-ITIS_TSN)

		# Observer codes to be removed
		OBS_REMOVE = tbl(con, sql("select * from CFG_OBSERVER_CODES"))  %>%
			collect() %>%
			filter(ITIS_TSN == species_itis) %>%
			distinct(OBS_CODES)

		#--------------------------------------------------------------------------------#
		# make tables
		ddat_focal <- all_dat %>%
			filter(DATE_TRIP >= start_date & DATE_TRIP < end_date) %>% ## time element is here!!
			filter(AREA %in% STOCK_AREAS$AREA) %>%
			mutate(LIVE_POUNDS = SUBTRIP_KALL
						 ,SEADAYS = 0
						 # , NESPP3 = NESPP3_FINAL
			) %>%
			left_join(., y = STOCK_AREAS, by = 'AREA') %>%
			left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
			left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
								, by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
			) %>%
			dplyr::select(-GEARCODE.y, -NESPP3.y) %>%
			dplyr::rename(COMMON_NAME= 'COMMON_NAME.x',SPECIES_ITIS = 'SPECIES_ITIS', NESPP3 = 'NESPP3.x',
										GEARCODE = 'GEARCODE.x') %>%
			relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')


		# DATE RANGE FOR PREVIOUS YEAR

		dr_prev = get_date_range(FY-1, FY_TYPE)
		end_date_prev = dr_prev[2]
		start_date_prev = dr_prev[1]


		ddat_prev <- all_dat %>%
			filter(DATE_TRIP >= start_date_prev & DATE_TRIP < end_date_prev) %>% ## time element is here!!
			filter(AREA %in% STOCK_AREAS$AREA) %>%
			mutate(LIVE_POUNDS = SUBTRIP_KALL
						 ,SEADAYS = 0
						 # , NESPP3 = NESPP3_FINAL
			) %>%
			left_join(., y = STOCK_AREAS, by = 'AREA') %>%
			left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
			left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
								, by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
			) %>%
			dplyr::select(-NESPP3.y, -GEARCODE.y) %>%
			dplyr::rename(COMMON_NAME= 'COMMON_NAME.x',SPECIES_ITIS = 'SPECIES_ITIS', NESPP3 = 'NESPP3.x',
										GEARCODE = 'GEARCODE.x') %>%
			relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')



		# need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
		ddat_focal_cy = ddat_focal %>%
			filter(!is.na(LINK1)) %>%
			mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
			)) %>%
			mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>%
			group_by(LINK1, CAMS_SUBTRIP) %>%
			arrange(desc(SPECIES_EVAL_DISCARD)) %>%
			slice(1) %>%
			ungroup()

		# and join to the unobserved trips

		ddat_focal_cy = ddat_focal_cy %>%
			union_all(ddat_focal %>%
									filter(is.na(LINK1)))
		#    group_by(VTRSERNO, CAMSID) %>%
		#    slice(1) %>%
		#    ungroup()
		# )


		# if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
		# DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS.

		bdat_cy = ddat_focal %>%
			filter(!is.na(LINK1)) %>%
			filter(FISHDISP != '090') %>%
			filter(LINK3_OBS == 1) %>%
			filter(SOURCE != 'ASM') %>%
			filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES)

		if(nrow(bdat_cy) > 0 ) {
		  bdat_cy <- bdat_cy %>%
		    mutate(DISCARD_PRORATE = DISCARD
		           , OBS_AREA = AREA
		           , OBS_HAUL_KALL_TRIP = OBS_KALL
		           , PRORATE = 1)
		}

		# set up trips table for previous year
		ddat_prev_cy = ddat_prev %>%
			filter(!is.na(LINK1)) %>%
			mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
			)) %>%
			mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>%
			group_by(LINK1, CAMS_SUBTRIP) %>%
			arrange(desc(SPECIES_EVAL_DISCARD)) %>%
			slice(1) %>%
			ungroup()

		ddat_prev_cy = ddat_prev_cy %>%
			union_all(ddat_prev %>%
									filter(is.na(LINK1))) #%>%
		# group_by(VTRSERNO,CAMSID) %>%
		# slice(1) %>%
		# ungroup()

		# previous year observer data needed..
		bdat_prev_cy = ddat_prev %>%
			filter(!is.na(LINK1)) %>%
			filter(FISHDISP != '090') %>%
			filter(LINK3_OBS == 1) %>%
			filter(SOURCE != 'ASM') %>%
			filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
			mutate(DISCARD_PRORATE = DISCARD
						 , OBS_AREA = AREA
						 , OBS_HAUL_KALL_TRIP = OBS_KALL
						 , PRORATE = 1)

		# Run the discaRd functions on previous year
		d_prev = run_discard(bdat = bdat_prev_cy
												 , ddat = ddat_prev_cy
												 , c_o_tab = ddat_prev
												 # , year = 2018
												 # , species_nespp3 = species_nespp3
												 , species_itis = species_itis
												 , stratvars = stratvars
												 , aidx = c(1:length(stratvars))
		)

		# Run the discaRd functions on current year
		if(nrow(bdat_cy) > 0) {
		d_focal = run_discard(bdat = bdat_cy
													, ddat = ddat_focal_cy
													, c_o_tab = ddat_focal
													# , year = 2019
													# , species_nespp3 = '081' # haddock...
													# , species_nespp3 = species_nespp3  #'081' #cod...
													, species_itis = species_itis
													, stratvars = stratvars
													, aidx = c(1:length(stratvars))  # this makes sure this isn't used..
		)

		dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
		                                               , N = N
		                                               , n = n
		                                               , orate = round(n/N, 2)
		                                               , drate = RE_mean
		                                               , KALL = K, disc_est = round(D)
		                                               , CV = round(RE_rse, 2)
		)

		}

		# summarize each result for convenience
		dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
																									, N = N
																									, n = n
																									, orate = round(n/N, 2)
																									, drate = RE_mean
																									, KALL = K, disc_est = round(D)
																									, CV = round(RE_rse, 2)
		)


		# substitute transition rates where needed
		if(exists("dest_strata_f")) {
		  trans_rate_df = dest_strata_f %>%
		    left_join(., dest_strata_p, by = 'STRATA')

		  trans_rate_df <- trans_rate_df %>%
		    mutate(STRATA = STRATA
		           , n_obs_trips_f = n.x
		           , n_obs_trips_p = n.y
		           , in_season_rate = drate.x
		           , previous_season_rate = drate.y
		    ) %>%
		    mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>%
		    mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
		                                       , l_assumed_rate = previous_season_rate
		                                       , l_inseason_rate = in_season_rate
		    )
		    ) %>%
		    dplyr::select(STRATA
		                  , n_obs_trips_f
		                  , n_obs_trips_p
		                  , in_season_rate
		                  , previous_season_rate
		                  , trans_rate
		                  , CV_f = CV.x
		    )
		} else {
		  trans_rate_df = dest_strata_p

		  trans_rate_df <- trans_rate_df %>%
		    mutate(STRATA = STRATA
		           , n_obs_trips_f = 0L
		           , n_obs_trips_p = n
		           , in_season_rate = NA_real_
		           , previous_season_rate = drate
		    ) %>%
		    mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>%
		    mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
		                                       , l_assumed_rate = previous_season_rate
		                                       , l_inseason_rate = in_season_rate
		    ),
		    CV_f = NA_real_
		    ) %>%
		    dplyr::select(STRATA
		                  , n_obs_trips_f
		                  , n_obs_trips_p
		                  , in_season_rate
		                  , previous_season_rate
		                  , trans_rate
		                  , CV_f
		    )
		}

		trans_rate_df = trans_rate_df %>%
			mutate(
			  final_rate = case_when(
			    is.na(in_season_rate) ~ trans_rate,
			    (in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate
			    )
			  )

		trans_rate_df$final_rate = coalesce(trans_rate_df$final_rate, trans_rate_df$in_season_rate)

		trans_rate_df_full = trans_rate_df

		if(exists("d_focal")) {
		full_strata_table = trans_rate_df_full %>%
			right_join(., y = d_focal$res, by = 'STRATA') %>%
			as_tibble() %>%
			mutate(SPECIES_ITIS_EVAL = species_itis
						 , COMNAME_EVAL = species$ITIS_NAME[i]
						 , FISHING_YEAR = FY
						 , FY_TYPE = FY_TYPE) %>%
			dplyr::rename(FULL_STRATA = STRATA)
		} else {
		  full_strata_table = trans_rate_df_full %>%
		    right_join(., y = d_prev$res, by = 'STRATA') %>%
		    as_tibble() %>%
		    mutate(SPECIES_ITIS_EVAL = species_itis
		           , COMNAME_EVAL = species$ITIS_NAME[i]
		           , FISHING_YEAR = FY
		           , FY_TYPE = FY_TYPE) %>%
		    dplyr::rename(FULL_STRATA = STRATA)
		}

		#
		# SECTOR ROLLUP
		#
		# print(paste0("Getting rates across sectors for ", species_itis, " ", FY))

		stratvars_assumed = c("SPECIES_STOCK"
													, "CAMS_GEAR_GROUP"
													, "MESHGROUP")


		### All tables in previous run can be re-used wiht diff stratification

		# Run the discaRd functions on previous year
		d_prev_pass2 = run_discard(bdat = bdat_prev_cy
															 , ddat = ddat_prev_cy
															 , c_o_tab = ddat_prev
															 # , year = 2018
															 # , species_nespp3 = species_nespp3
															 , species_itis = species_itis
															 , stratvars = stratvars_assumed
															 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
															 , aidx = c(1)  # this creates an unstratified broad stock rate
		)


		# Run the discaRd functions on current year
		if(nrow(bdat_cy) > 0) {
		d_focal_pass2 = run_discard(bdat = bdat_cy
																, ddat = ddat_focal_cy
																, c_o_tab = ddat_focal
																# , year = 2019
																# , species_nespp3 = '081' # haddock...
																# , species_nespp3 = species_nespp3  #'081' #cod...
																, species_itis = species_itis
																, stratvars = stratvars_assumed
																# , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
																, aidx = c(1)  # this creates an unstratified broad stock rate
		)

		dest_strata_f_pass2 = d_focal_pass2$allest$C %>% summarise(STRATA = STRATA
		                                                           , N = N
		                                                           , n = n
		                                                           , orate = round(n/N, 2)
		                                                           , drate = RE_mean
		                                                           , KALL = K, disc_est = round(D)
		                                                           , CV = round(RE_rse, 2)
		)

		}

		# summarize each result for convenience
		dest_strata_p_pass2 = d_prev_pass2$allest$C %>% summarise(STRATA = STRATA
																															, N = N
																															, n = n
																															, orate = round(n/N, 2)
																															, drate = RE_mean
																															, KALL = K, disc_est = round(D)
																															, CV = round(RE_rse, 2)
		)



		# substitute transition rates where needed
		if(exists("dest_strata_f_pass2")) {
		trans_rate_df_pass2 = dest_strata_p_pass2 %>%
			left_join(., dest_strata_f_pass2, by = 'STRATA') %>%
			mutate(STRATA = STRATA
						 , n_obs_trips_f = n.x
						 , n_obs_trips_p = n.y
						 , in_season_rate = drate.x
						 , previous_season_rate = drate.y
			) %>%
			mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>%
			mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
																				 , l_assumed_rate = previous_season_rate
																				 , l_inseason_rate = in_season_rate
			)
			) %>%
			dplyr::select(STRATA
										, n_obs_trips_f
										, n_obs_trips_p
										, in_season_rate
										, previous_season_rate
										, trans_rate
										, CV_f = CV.x
			)
		} else {
		  trans_rate_df_pass2 = dest_strata_p_pass2 %>%
		    mutate(STRATA = STRATA
		           , n_obs_trips_f = 0L
		           , n_obs_trips_p = n
		           , in_season_rate = NA_real_
		           , previous_season_rate = drate
		    ) %>%
		    mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>%
		    mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
		                                       , l_assumed_rate = previous_season_rate
		                                       , l_inseason_rate = in_season_rate
		    ),
		    CV_f = NA_real_
		    ) %>%
		    dplyr::select(STRATA
		                  , n_obs_trips_f
		                  , n_obs_trips_p
		                  , in_season_rate
		                  , previous_season_rate
		                  , trans_rate
		                  , CV_f)
		}


		trans_rate_df_pass2 = trans_rate_df_pass2 %>%
		  mutate(
		    final_rate = case_when(
		      is.na(in_season_rate) ~ trans_rate,
		      (in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate
		    )
		  )

		trans_rate_df_pass2$final_rate = coalesce(trans_rate_df_pass2$final_rate, trans_rate_df_pass2$in_season_rate)

		# get a table of broad stock rates using discaRd functions. Previosuly we used sector rollupresults (ARATE in pass2)

		if(nrow(bdat_cy > 0)) {
		bdat_2yrs = bind_rows(bdat_prev_cy, bdat_cy)
		} else {
		  bdat_2yrs = bdat_prev_cy
		}

		ddat_cy_2yr = bind_rows(ddat_prev_cy, ddat_focal_cy)
		ddat_2yr = bind_rows(ddat_prev, ddat_focal)

		mnk = run_discard( bdat = bdat_2yrs
											 , ddat_focal = ddat_cy_2yr
											 , c_o_tab = ddat_2yr
											 , species_itis = species_itis
											 , stratvars = stratvars[1:2]  #"SPECIES_STOCK"   "CAMS_GEAR_GROUP"
		)

		SPECIES_STOCK <-sub("_.*", "", mnk$allest$C$STRATA)

		CAMS_GEAR_GROUP <- sub(".*?_", "", mnk$allest$C$STRATA)

		BROAD_STOCK_RATE <-  mnk$allest$C$RE_mean

		CV_b <- round(mnk$allest$C$RE_rse, 2)

		BROAD_STOCK_RATE_TABLE <- as.data.frame(cbind(SPECIES_STOCK, CAMS_GEAR_GROUP, BROAD_STOCK_RATE, CV_b))

		BROAD_STOCK_RATE_TABLE$BROAD_STOCK_RATE <- as.numeric(BROAD_STOCK_RATE_TABLE$BROAD_STOCK_RATE)
		BROAD_STOCK_RATE_TABLE$CV_b <- as.numeric(BROAD_STOCK_RATE_TABLE$CV_b)


		names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')

		#
		# join full and assumed strata tables
		#
		# print(paste0("Constructing output table for ", species_itis, " ", FY))

		joined_table = assign_strata(full_strata_table, stratvars_assumed) %>%
			dplyr::select(-STRATA_ASSUMED) %>%  # not using this anymore here..
			dplyr::rename(STRATA_ASSUMED = STRATA) %>%
			left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
			left_join(., y = BROAD_STOCK_RATE_TABLE, by = c('SPECIES_STOCK','CAMS_GEAR_GROUP')) %>%
			mutate(COAL_RATE = case_when(n_obs_trips_f >= 5 ~ final_rate  # this is an in season rate
																	 , n_obs_trips_f < 5 &
																	 	n_obs_trips_p >=5 ~ final_rate  # this is a final IN SEASON rate taking transition into account
																	 , n_obs_trips_f < 5 &
																	 	n_obs_trips_p < 5 ~ trans_rate_a  # this is an final assumed rate taking trasnition into account
			)
			) %>%
			mutate(COAL_RATE = coalesce(COAL_RATE, BROAD_STOCK_RATE)) %>%
			mutate(SPECIES_ITIS_EVAL = species_itis
						 , COMNAME_EVAL = species$ITIS_NAME[i]
						 , FISHING_YEAR = FY
						 , FY_TYPE = FY_TYPE)

		#
		# add discard source
		#

		joined_table = joined_table %>%
			mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 0 ~ 'O'  # observed with at least one obs haul and no offwatch hauls on trip
																				, !is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 1 ~ 'I'  # observed with at least one obs haul
																				, !is.na(LINK1) & LINK3_OBS == 0 ~ 'I'  # observed but no obs hauls..
																				, is.na(LINK1) &
																					n_obs_trips_f >= 5 ~ 'I'
																				# , is.na(LINK1) & COAL_RATE == previous_season_rate ~ 'P'
																				, is.na(LINK1) &
																					n_obs_trips_f < 5 &
																					n_obs_trips_p >=5 ~ 'T' # this only applies to in-season full strata
																				, is.na(LINK1) &
																					n_obs_trips_f < 5 &
																					n_obs_trips_p < 5 &
																					n_obs_trips_f_a >= 5 ~ 'GM' # Gear and Mesh, replaces assumed for non-GF
																				, is.na(LINK1) &
																					n_obs_trips_f < 5 &
																					n_obs_trips_p < 5 &
																					n_obs_trips_p_a >= 5 ~ 'G' # Gear only, replaces broad stock for non-GF
																				, is.na(LINK1) &
																					n_obs_trips_f < 5 &
																					n_obs_trips_p < 5 &
																					n_obs_trips_f_a < 5 &
																					n_obs_trips_p_a < 5 ~ 'G')) # Gear only, replaces broad stock for non-GF

		#
		# make sure CV type matches DISCARD SOURCE}
		#

		# obs trips get 0, broad stock rate is NA



		joined_table = joined_table %>%
			mutate(CV = case_when(DISCARD_SOURCE == 'O' ~ 0
														, DISCARD_SOURCE == 'I' ~ CV_f
														, DISCARD_SOURCE == 'T' ~ CV_f
														, DISCARD_SOURCE == 'GM' ~ CV_f_a
														, DISCARD_SOURCE == 'G' ~ CV_b
														#	, DISCARD_SOURCE == 'NA' ~ 'NA'
			)  # , DISCARD_SOURCE == 'B' ~ NA
			)

		# Make note of the stratification variables used according to discard source

		stratvars_gear = c("SPECIES_STOCK"
											 , "CAMS_GEAR_GROUP")

		strata_f = paste(stratvars, collapse = ';')
		strata_a = paste(stratvars_assumed, collapse = ';')
		strata_b = paste(stratvars_gear, collapse = ';')

		joined_table = joined_table %>%
			mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' & LINK3_OBS == 1 ~ ''
																		 , DISCARD_SOURCE == 'O' & LINK3_OBS == 0 ~ 'I'
																		 , DISCARD_SOURCE == 'I' ~ strata_f
																		 , DISCARD_SOURCE == 'T' ~ strata_f
																		 , DISCARD_SOURCE == 'GM' ~ strata_a
																		 , DISCARD_SOURCE == 'G' ~ strata_b
																		 #	, DISCARD_SOURCE == 'NA' ~ 'NA'
			)
			)


		#
		# get the discard for each trip using COAL_RATE}
		#

		# discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio.
		# the KALLs should be small..

		joined_table = joined_table %>%
			mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
			mutate(DISCARD = ifelse(DISCARD_SOURCE == 'O', DISC_MORT_RATIO*OBS_DISCARD # observed with at least one obs haul
															, DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS) # all other cases

			)

		outfile = file.path(save_dir, paste0('discard_est_', species_itis, '_trips', FY,'.fst'))

		fst::write_fst(x = joined_table, path = outfile)
		#
		system(paste("chmod 770", outfile))

		t2 = Sys.time()

		print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

	}

}


#' Get Date Range
#' get date range for particular type of fishing year
#' @param FY Fishing Year (e.g. 2020)
#' @param FY_TYPE  Type of fishing year (e.g. CALENDAR). This is case sensitive as it calls `CFG_DISCARD_RUNID`
#'
#' @return a start and end date
#' @export
#'
#' @examples
get_date_range = function(FY, FY_TYPE){
	y = FY
	if(FY_TYPE == 'APRIL'){
		smonth = ifelse(y <= 2018, 3, 4)
		emonth = ifelse(y <= 2018, 3, 4)
		eday = ifelse(y <= 2018, 31, 30)
		sdate = lubridate::as_date(paste(y, smonth, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, emonth, eday, sep = '-'))
	}
	if(FY_TYPE == 'MARCH'){
		sdate = lubridate::as_date(paste(y, 3, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 3, 1, sep = '-'))
	}
	if(FY_TYPE == 'MAY'){
		sdate = lubridate::as_date(paste(y, 5, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 5, 1, sep = '-'))
	}
	if(FY_TYPE == 'NOVEMBER'){
		sdate = lubridate::as_date(paste(y, 11, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 11, 1, sep = '-'))
	}
	if(FY_TYPE == 'CALENDAR'){
		sdate = lubridate::as_date(paste(y, 1, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 1, 1, sep = '-'))
	}

	if(FY_TYPE == 'HERRING'){
		sdate = lubridate::as_date(paste(y, 1, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 1, 1, sep = '-'))
	}
	sdate = lubridate::floor_date(sdate, unit = 'day')
	c(sdate, edate)

}
