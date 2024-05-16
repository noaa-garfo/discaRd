#' discard_generic: Calculate discards for January fishing year species
#'
#' @param con ROracle connection to Oracle (e.g. MAPS)
#' @param species dataframe with species info
#' @param FY Fishing Year
#' @param all_dat Data frame of trips built from CAMS_OBS_CATCH and control script routine
#' @param save_dir Directory to save (and load saved) results
#' @param run_parallel option to run species discard calculations in parallel
#'
# #' @param FY_TYPE Type of fishing year. This determines the time element for the trips used in discard estimation. Herring, Groundfish, and scallop trips for groundfish are separate functions,
#' @return nothing currently, writes out to fst files (add oracle?)
#' @author Benjamin Galuardi
#' @export
#'
#' @examples
#'
#'
discard_generic <- function(con = con_maps
														 , species = species
														 , FY = fy
														 #, FY_TYPE = c('Calendar','March','April','May','November')
														 , all_dat = all_dat
														 , save_dir = file.path(getOption("maps.discardsPath"), "calendar")
														 , run_parallel = FALSE
) {

  config_run <- configr::read.config(file = here::here("configRun.toml"))
  pw <- as.character(config_run$pw)

	if(!dir.exists(save_dir)) {
		dir.create(save_dir, recursive = TRUE)
		system(paste("chmod 770 -R", save_dir))
	}


	FY_TYPE = species$RUN_ID[1]

	if(FY >= 2022 & FY_TYPE == 'NOVEMEBER'){
		FY_TYPE = 'CALENDAR'
	}

	dr = get_date_range(FY, FY_TYPE)
	end_date = dr[2]
	start_date = dr[1]

	# Stratification variables

	stratvars = c('FY'
              	, 'FY_TYPE'
              	,'SPECIES_STOCK'
								,'CAMS_GEAR_GROUP'
								, 'MESH_CAT'
								, 'TRIPCATEGORY'
								, 'ACCESSAREA')


	# Begin loop

	# for(i in 1:length(species$ITIS_TSN)){

	  `%op%` <- if (run_parallel) `%dopar%` else `%do%`

	  ncores <- min(length(unique(species$ITIS_TSN)), 8)
	  cl3 <- makeCluster(ncores, outfile = "")
	  registerDoParallel(cl3, cores = ncores)

	  foreach(
	    i = 1:length(species$ITIS_TSN),
	    .export = c("pw", "database"),
	    .noexport = "con",
	    .packages = c("discaRd", "dplyr", "MAPS", "DBI", "ROracle", "apsdFuns", "keyring", "fst")
	  ) %op% {

		t1 = Sys.time()

		# print(paste0('Running ', species$ITIS_NAME[i], " for Fishing Year ", FY))

		# setDTthreads(threads = 5)
		options(keyring_file_lock_timeout = 100000)

		# keyring unlock
		if(!exists("pw")) {
		  con_run <- configr::read.config(file = here::here("configRun.toml"))
		  pw <- con_run$pw
		}

		keyring::keyring_unlock(keyring = 'apsd', password = pw)
		con <- apsdFuns::roracle_login(key_name = 'apsd', key_service = database, schema = 'maps')

		# species_nespp3 = species$NESPP3[i]
		#species_itis = species$ITIS_TSN[i]

		species_itis <- as.character(species$ITIS_TSN[i])
		species_itis_srce = as.character(as.numeric(species$ITIS_TSN[i]))

		# add OBS_DISCARD column. Previously, this was done within the run_discard() step. 2/2/23 BG ----

		all_dat = all_dat %>%
			mutate(OBS_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE
																		 , TRUE ~ 0))

		#--------------------------------------------------------------------------#
		#-  Support table import by species ------

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
		# make tables ----

		ddat_focal <- all_dat %>%
			filter(DATE_TRIP >= start_date & DATE_TRIP < end_date) %>% ## time element is here!!
			filter(AREA %in% STOCK_AREAS$AREA) %>%
		  mutate(FY_TYPE = FY_TYPE
		         , FY = FY) %>%
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
			relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
			assign_strata(., stratvars)


		# DATE RANGE FOR PREVIOUS YEAR ----

		dr_prev = get_date_range(FY-1, FY_TYPE)
		end_date_prev = dr_prev[2]
		start_date_prev = dr_prev[1]


		ddat_prev <- all_dat %>%
			filter(DATE_TRIP >= start_date_prev & DATE_TRIP < end_date_prev) %>% ## time element is here!!
			filter(AREA %in% STOCK_AREAS$AREA) %>%
		  mutate(FY_TYPE = FY_TYPE
		         , FY = FY) %>%
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
			relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')%>%
			assign_strata(., stratvars)



		# need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
		ddat_focal_cy <- summarise_single_discard_row(data = ddat_focal, itis_tsn = species_itis)

		# and join to the unobserved trips ----

		ddat_focal_cy = ddat_focal_cy %>%
			union_all(ddat_focal %>%
									filter(is.na(LINK1)))


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

		# set up trips table for previous year ----
		ddat_prev_cy <- summarise_single_discard_row(data = ddat_prev, itis_tsn = species_itis)

		ddat_prev_cy = ddat_prev_cy %>%
			union_all(ddat_prev %>%
									filter(is.na(LINK1))) #%>%

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

		# Run the discaRd functions on previous year ----
		d_prev = run_discard(bdat = bdat_prev_cy
												 , ddat = ddat_prev_cy
												 , c_o_tab = ddat_prev
												 # , year = 2018
												 # , species_nespp3 = species_nespp3
												 , species_itis = species_itis
												 , stratvars = stratvars
												 , aidx = c(1:length(stratvars))
		)

		# Run the discaRd functions on current year----
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

		# summarize each result for convenience ----
		dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
																									, N = N
																									, n = n
																									, orate = round(n/N, 2)
																									, drate = RE_mean
																									, KALL = K, disc_est = round(D)
																									, CV = round(RE_rse, 2)
		)


		# substitute transition rates where needed ----
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
			# right_join(., y = d_focal$res, by = 'STRATA') %>%
			right_join(., y = ddat_focal_cy, by = 'STRATA') %>%
			as_tibble() %>%
			mutate(SPECIES_ITIS_EVAL = species_itis
						 , COMNAME_EVAL = species$ITIS_NAME[i]
						 , FISHING_YEAR = FY
						 , FY_TYPE = FY_TYPE) %>%
			dplyr::rename(FULL_STRATA = STRATA)
		} else {
		  full_strata_table = trans_rate_df_full %>%
		    # right_join(., y = d_prev$res, by = 'STRATA') %>%
		  	right_join(., y = ddat_focal_cy, by = 'STRATA') %>%
		    as_tibble() %>%
		    mutate(SPECIES_ITIS_EVAL = species_itis
		           , COMNAME_EVAL = species$ITIS_NAME[i]
		           , FISHING_YEAR = FY
		           , FY_TYPE = FY_TYPE) %>%
		    dplyr::rename(FULL_STRATA = STRATA)
		}

		# Second Pass: Stock, Gear, and Mesh only ----

		stratvars_assumed = c("FY"
		                      ,"FY_TYPE"
		                      ,"SPECIES_STOCK"
													, "CAMS_GEAR_GROUP"
													, "MESH_CAT")


		### All tables in previous run can be re-used wiht diff stratification

		# Run the discaRd functions on previous year: pass 2 ----
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


		# Run the discaRd functions on current year: pass 2 ----
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

		# summarize each result for convenience : pass 2 ----
		dest_strata_p_pass2 = d_prev_pass2$allest$C %>% summarise(STRATA = STRATA
																															, N = N
																															, n = n
																															, orate = round(n/N, 2)
																															, drate = RE_mean
																															, KALL = K, disc_est = round(D)
																															, CV = round(RE_rse, 2)
		)



		# substitute transition rates where needed: pass 2 ----
		if(exists("dest_strata_f_pass2")) {
		trans_rate_df_pass2 = dest_strata_f_pass2 %>%
			left_join(., dest_strata_p_pass2, by = 'STRATA') %>%
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

		# get a table of broad stock rates using discaRd functions. ----
		# Previosuly we used sector rollupresults (ARATE in pass2)

		if(nrow(bdat_cy > 0)) {
		bdat_2yrs = bind_rows(bdat_prev_cy, bdat_cy)
		} else {
		  bdat_2yrs = bdat_prev_cy
		}

		ddat_cy_2yr = bind_rows(ddat_prev_cy, ddat_focal_cy)
		ddat_2yr = bind_rows(ddat_prev, ddat_focal)

		gear_only = run_discard( bdat = bdat_2yrs
											 , ddat_focal = ddat_cy_2yr
											 , c_o_tab = ddat_2yr
											 , species_itis = species_itis
											 , stratvars = stratvars[1:4]  #"FY","FY_TYPE", "SPECIES_STOCK", "CAMS_GEAR_GROUP"
		)

		# broad rate table ----

		BROAD_STOCK_RATE_TABLE = gear_only$allest$C |>
		  dplyr::select(STRATA, N, n, RE_mean, RE_rse) |>
		  mutate(FY = as.numeric(sub("_.*", "", STRATA))
		         , FY_TYPE = FY_TYPE) |>
		  mutate(SPECIES_STOCK = gsub("^([^_]+)_", "", STRATA)  |>
		           gsub(pattern = "^([^_]+)_", replacement = "")  |>
		           sub(pattern ="_.*", replacement ="")
		         , CAMS_GEAR_GROUP = gsub("^([^_]+)_", "", STRATA)  |>
		           gsub(pattern = "^([^_]+)_", replacement = "")  |>
		           gsub(pattern = "^([^_]+)_", replacement = "")
		         , CV_b = round(RE_rse, 2)
		         ) |>
		  dplyr::rename(BROAD_STOCK_RATE = RE_mean
		                , n_B = n
		                , N_B = N) |>
		  dplyr::select(FY, FY_TYPE, SPECIES_STOCK, CAMS_GEAR_GROUP, BROAD_STOCK_RATE, CV_b, n_B, N_B)

		#
		# FY_BST = as.numeric(sub("_.*", "", gear_only$allest$C$STRATA))
		#
		# SPECIES_STOCK <- gsub("^([^_]+)_", "", gear_only$allest$C$STRATA) %>%
		#   gsub("^([^_]+)_", "", .) %>% sub("_.*", "",.)  # sub("_.*", "", gear_only$allest$C$STRATA)
		#
		# CAMS_GEAR_GROUP <- gsub("^([^_]+)_", "", gear_only$allest$C$STRATA) %>%
		#   gsub("^([^_]+)_", "", .)%>%
		#   gsub("^([^_]+)_", "", .) #sub(".*?_", "", gear_only$allest$C$STRATA)
		#
		# BROAD_STOCK_RATE <-  gear_only$allest$C$RE_mean
		#
		# CV_b <- round(gear_only$allest$C$RE_rse, 2)

		# BROAD_STOCK_RATE_TABLE <- data.frame(FY = FY_BST, FY_TYPE = FY_TYPE, cbind(SPECIES_STOCK, CAMS_GEAR_GROUP, BROAD_STOCK_RATE, CV_b))
		#
		# BROAD_STOCK_RATE_TABLE$BROAD_STOCK_RATE <- as.numeric(BROAD_STOCK_RATE_TABLE$BROAD_STOCK_RATE)
		# BROAD_STOCK_RATE_TABLE$CV_b <- as.numeric(BROAD_STOCK_RATE_TABLE$CV_b)
		#

		names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')

		#--------------------------------------------------------------------------#
		# join full and assumed strata tables ----


		joined_table = assign_strata(full_strata_table, stratvars_assumed)

		if("STRATA_ASSUMED" %in% names(joined_table)) {
			joined_table = joined_table %>%
				dplyr::select(-STRATA_ASSUMED)   # not using this anymore here..
		}

		joined_table = joined_table %>%
			dplyr::rename(STRATA_ASSUMED = STRATA) %>%
			left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
			left_join(., y = BROAD_STOCK_RATE_TABLE, by = c('FY', 'FY_TYPE', 'SPECIES_STOCK','CAMS_GEAR_GROUP')) %>%
			mutate(COAL_RATE = case_when(n_obs_trips_f >= 5 ~ final_rate  # this is an in season rate
																	 , n_obs_trips_f < 5 &
																	 	n_obs_trips_p >=5 ~ final_rate  # this is a final IN SEASON rate taking transition into account
																	 , n_obs_trips_f < 5 &
																	 	n_obs_trips_p < 5  &
																	 	n_obs_trips_f_a >= 5 ~ trans_rate_a  # this is an final assumed rate taking transition into account
																	 , n_obs_trips_f < 5 &
																	 	n_obs_trips_p < 5  &
																	 	n_obs_trips_f_a < 5 &
																	 	n_obs_trips_p_a >= 5 ~ trans_rate_a  # this is an final assumed rate taking transition into account
			)
			) %>%
			mutate(COAL_RATE = coalesce(COAL_RATE, BROAD_STOCK_RATE)) %>%
			mutate(SPECIES_ITIS_EVAL = species_itis
						 , COMNAME_EVAL = species$ITIS_NAME[i]
						 , FISHING_YEAR = FY
						 , FY_TYPE = FY_TYPE)

		#
		# add discard source ----
		#

		joined_table = assign_discard_source(joined_table, GF = 0)
		#
		# %>%
		# 	mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 0 ~ 'O'  # observed with at least one obs haul and no offwatch hauls on trip
		# 																		, !is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 1 ~ 'I'  # observed with at least one obs haul
		# 																		, !is.na(LINK1) & LINK3_OBS == 0 ~ 'I'  # observed but no obs hauls..
		# 																		, is.na(LINK1) &
		# 																			n_obs_trips_f >= 5 ~ 'I'
		# 																		# , is.na(LINK1) & COAL_RATE == previous_season_rate ~ 'P'
		# 																		, is.na(LINK1) &
		# 																			n_obs_trips_f < 5 &
		# 																			n_obs_trips_p >=5 ~ 'T' # this only applies to in-season full strata
		# 																		, is.na(LINK1) &
		# 																			n_obs_trips_f < 5 &
		# 																			n_obs_trips_p < 5 &
		# 																			n_obs_trips_f_a >= 5 ~ 'GM' # Gear and Mesh, replaces assumed for non-GF
		# 																		, is.na(LINK1) &
		# 																			n_obs_trips_f < 5 &
		# 																			n_obs_trips_p < 5 &
		# 																			n_obs_trips_p_a >= 5 ~ 'G' # Gear only, replaces broad stock for non-GF
		# 																		, is.na(LINK1) &
		# 																			n_obs_trips_f < 5 &
		# 																			n_obs_trips_p < 5 &
		# 																			n_obs_trips_f_a < 5 &
		# 																			n_obs_trips_p_a < 5 ~ 'G')) # Gear only, replaces broad stock for non-GF

		#
		# Make sure CV type matches DISCARD SOURCE ----
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

		# Make note of the stratification variables used according to discard source ----

		stratvars_gear = c("FY"
		                   , "FY_TYPE"
		                   , "SPECIES_STOCK"
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
																		 , TRUE ~ NA_character_
																		 #	, DISCARD_SOURCE == 'NA' ~ 'NA'
			)
			)


		#------------------------------------------------------------------------#
		# get the discard for each trip using COAL_RATE and discard mortality ----
		#

		# discard mort ratio that are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio.
		# the KALLs should be small..

		joined_table = joined_table %>%
			mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
			mutate(DISCARD = ifelse(DISCARD_SOURCE == 'O', DISC_MORT_RATIO*OBS_DISCARD # observed with at least one obs haul
															, DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS) # all other cases

			)
	# add element for non-estimated gear types

  	joined_table = joined_table %>%
  		mutate(DISCARD_SOURCE = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 'N'
  																			,TRUE ~ DISCARD_SOURCE)) %>%
  		mutate(DISCARD = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 0.0
  															 ,TRUE ~ DISCARD))%>%
  		mutate(CV = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ NA_real_
  															 ,TRUE ~ CV))

		# force remove duplicates
		joined_table <- joined_table |>
		  dplyr::distinct()

		# add N, n, and covariance ----

		# add N, n, and covariance ----
		joined_table <- joined_table |>
		  add_nobs() |>
		  make_strata_desc() |>
		  get_covrow()

		# joined_table = get_covrow(joined_table)

		outfile = file.path(save_dir, paste0('discard_est_', species_itis, '_trips', FY,'.fst'))

		fst::write_fst(x = joined_table, path = outfile)
		#
		# system(paste("chmod 770", outfile))

		t2 = Sys.time()

		# print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

		DBI::dbDisconnect(con)

	}

	  stopCluster(cl3)
	  unregister()

}


