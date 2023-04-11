#' discard_groundfish_diagnostic: Calculate groundfish discards: Calculate discards for May groundfish fishing year
#'
#' Support tables in this version ar function variables. This allows them to be modified and run for diagnostic testing. This function can output a summary of discard information by strata, including number of trips used, variance, CV, discard amount, and KALL. It can also output a table, by subtrip, with all information. This table can be summarized afterward as well. If testing several scenarios, it is recommended to only output the summary rather than the full subtrip table as each output is 1-2GB.
#' 
#' The original function pushed .fst files directly to the Wind server at GARFO. This version does not do that and only produces local results.
#' When running windowpane or yellowtail flounders, this function will save .fst files of scallop trips locally. These will be auto-saved in your working directory.
#'
#' @param con Oracle connection
#' @param species data frame of species for evaluation. Can be a dataframe of multiple species or single row (preferred for testing)
#' @param FY fishing year for evaluation
#' @param gf_dat Data frame of groundfish trips built from CAMS_OBS_CATCH and control script routine. sourced from CAMS_OBS_CATCH
#' @param non_gf_dat Data frame of non-groundfish trips built from CAMS_OBS_CATCH and control script routine. sourced from CAMS_OBS_CATCH
#' @param return_table logical, should a table (very large!) of trip level info be returned?
#' @param return_summary  logical, should a summary (very not large) be returned?
#' @param CAMS_GEAR_STRATA  support table sourced from Oracle
#' @param STOCK_AREAS support table sourced from Oracle
#' @param CAMS_DISCARD_MORTALITY_STOCK support table sourced from Oracle
#'
#' @return nothing currently, writes out to fst files (add oracle?)
#' @export
#'
#' @examples
#' see vignette
#'
discard_groundfish_diagnostic <- function(con = con_maps
															 , species = species
															 , FY = fy
															 , gf_dat = gf_dat
															 , non_gf_dat = non_gf_dat
															 , return_table = T
															 , return_summary = F
															 , CAMS_GEAR_STRATA = CAMS_GEAR_STRATA
															 , STOCK_AREAS = STOCK_AREAS
															 , CAMS_DISCARD_MORTALITY_STOCK = CAMS_DISCARD_MORTALITY_STOCK
															 ) {

  # if(!dir.exists(save_dir)) {
  #   dir.create(save_dir, recursive = TRUE)
  #   system(paste("chmod 770 -R", save_dir))
  # }

  FY_TYPE = species$RUN_ID[1]

  ## ----loop through the sector trips for each stock, eval = T-----------------------------------------------------------------------

  # Stratification variables ----

  stratvars = c( 'SPECIES_STOCK'
  							# , 'GEARCODE'  # this is the SECGEAR_MAPPED variable
                , 'CAMS_GEAR_GROUP'
                , 'MESH_CAT'
                , 'SECTID'
                , 'EM'
                , "REDFISH_EXEMPTION"
                , "SNE_SMALLMESH_EXEMPTION"
                , "XLRG_GILLNET_EXEMPTION"
  							, "EXEMPT_7130"
                )

  # add a second SECTORID for Common pool/all others



  for(i in 1:length(species$ITIS_TSN)){

  t1 = Sys.time()

  logr::log_print(paste0('Running ', species$ITIS_NAME[i], ' for Fishing Year ', FY))

  # species_nespp3 = species$NESPP3[i]
  species_itis = species$ITIS_TSN[i]

  # flag allocated vs non-allocated ----
  # Halibut, Ocean Put, Woffish, Winodwpane are unallocated.

  allocated = ifelse(species_itis %in% c(172933, 630979, 171341, 172746), F, T)


  #---#


  # add OBS_DISCARD column. Previously, this was done within the run_discard() step. 2/2/23 BG ----

  gf_dat = gf_dat %>%
  	mutate(OBS_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE
  																 , TRUE ~ 0))


  # Support table import by species ----

  # # GEAR TABLE
  # CAMS_GEAR_STRATA = ROracle::dbGetQuery(con, 'select * from CFG_GEARCODE_STRATA') %>%
  #   dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>%
  #   # dplyr::filter(NESPP3 == species_nespp3) %>%
  # 	dplyr::filter(ITIS_TSN == species_itis) %>%
  #   dplyr::select(-NESPP3, -ITIS_TSN)
  # 
  # # Stat areas table
  # # unique stat areas for stock ID if needed
  # STOCK_AREAS = ROracle::dbGetQuery(con, 'select * from CFG_STATAREA_STOCK') %>%
  #   # dplyr::filter(NESPP3 == species_nespp3) %>%  # removed  & AREA_NAME == species_stock
  # 	dplyr::filter(ITIS_TSN == species_itis) %>%
  #   group_by(AREA_NAME, ITIS_TSN) %>%
  #   distinct(AREA) %>%
  #   mutate(AREA = as.character(AREA)
  #          , SPECIES_STOCK = AREA_NAME) %>%
  #   ungroup()
  # # %>%
  # #   dplyr::select(SPECIES_STOCK, AREA)
  # 
  # # Mortality table
  # # TODO: This can become MAPS:::cfg_discard_mortality_stock once added to the config load
  # CAMS_DISCARD_MORTALITY_STOCK = ROracle::dbGetQuery(con, "select * from CFG_DISCARD_MORTALITY_STOCK")  %>%
  #   mutate(SPECIES_STOCK = AREA_NAME
  #          , GEARCODE = CAMS_GEAR_GROUP
  #   			 , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  #   dplyr::select(-AREA_NAME) %>%
  #   # mutate(CAREA = as.character(STAT_AREA)) %>%
  #   # dplyr::filter(NESPP3 == species_nespp3) %>%
  # 	dplyr::filter(ITIS_TSN == species_itis) %>%
  #   dplyr::select(-ITIS_TSN)


  # Observer codes to be removed
  OBS_REMOVE = ROracle::dbGetQuery(con, "select * from CFG_OBSERVER_CODES")  %>%
  	dplyr::filter(ITIS_TSN == species_itis) %>%
  	distinct(OBS_CODES)


  # logr::log_print(paste0("Getting in-season rates for ", species_itis, " ", FY))

  # make tables ----
  ddat_focal <- gf_dat %>%
    dplyr::filter(GF_YEAR == FY) %>%   ## time element is here!!
    dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
    mutate(LIVE_POUNDS = SUBTRIP_KALL
           ,SEADAYS = 0
  	  		 ) %>%
     left_join(., y = STOCK_AREAS, by = 'AREA') %>%
     left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
     left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
              , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
              ) %>%
  	dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
  	dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
  	relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
  	assign_strata(., stratvars = stratvars)
  # 	dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
  # 	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
  #   relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')


  ddat_prev <- gf_dat %>%
    dplyr::filter(GF_YEAR == FY-1) %>%   ## time element is here!!
    dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
    mutate(LIVE_POUNDS = SUBTRIP_KALL
           ,SEADAYS = 0
  	  		 ) %>%
     left_join(., y = STOCK_AREAS, by = 'AREA') %>%
     left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
     left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
              , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
              ) %>%
  	dplyr::select( -GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
  	dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
  	relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
  	assign_strata(., stratvars = stratvars)

  # 	dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
  # 	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
  #   relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')



  # need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
  # need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!
  # Observed trips with NO obs hauls can be treated the same here. The assignment of DISCARD source happens at the end and contains the correct filtration criteria.

  ddat_focal_gf <- summarise_single_discard_row(data = ddat_focal, itis_tsn = species_itis)

    # and join to the unobserved trips ----

  ddat_focal_gf = ddat_focal_gf %>%
    union_all(ddat_focal %>%
                dplyr::filter(is.na(LINK1))
    # 					%>%
    #              group_by(VTRSERNO) %>%
    #              slice(1) %>%
    #              ungroup()
              )


  # if using the combined catch/obs table, which seems necessary for groundfish. need to roll your own table to use with run_discard function
  # DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS.

  bdat_gf = ddat_focal %>%
    dplyr::filter(!is.na(LINK1)) %>%
  	dplyr::filter(FISHDISP != '090') %>%
  	dplyr::filter(LINK3_OBS == 1) %>%
  	dplyr::filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
  	dplyr::filter(EM != 'MREM' | is.na(EM)) %>%
    mutate(DISCARD_PRORATE = DISCARD
           , OBS_AREA = AREA
           , OBS_HAUL_KALL_TRIP = OBS_KALL
           , PRORATE = 1)


  # set up trips table for previous year ----
  ddat_prev_gf <- summarise_single_discard_row(data = ddat_prev, itis_tsn = species_itis)

# previous year observer data needed..
  bdat_prev_gf = ddat_prev %>%
    dplyr::filter(!is.na(LINK1)) %>%
  	dplyr::filter(FISHDISP != '090') %>%
  	dplyr::filter(LINK3_OBS == 1) %>%
  	dplyr::filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
  	dplyr::filter(EM != 'MREM' | is.na(EM)) %>%
    mutate(DISCARD_PRORATE = DISCARD
           , OBS_AREA = AREA
           , OBS_HAUL_KALL_TRIP = OBS_KALL
           , PRORATE = 1)

  # Run the discaRd functions on previous year ----
  d_prev = run_discard(bdat = bdat_prev_gf
  											 , ddat = ddat_prev_gf
  											 , c_o_tab = ddat_prev
  											 # , year = 2018
  											 # , species_nespp3 = species_nespp3
  										   , species_itis = species_itis
  											 , stratvars = stratvars
  											 , aidx = c(1:length(stratvars))
  											 )


  # Run the discaRd functions on current year ----
  d_focal = run_discard(bdat = bdat_gf
  											 , ddat = ddat_focal_gf
  											 , c_o_tab = ddat_focal
  											 # , year = 2019
  											 # , species_nespp3 = '081' # haddock...
  											 # , species_nespp3 = species_nespp3  #'081' #cod...
  											 , species_itis = species_itis
  											 , stratvars = stratvars
  											 , aidx = c(1:length(stratvars))  # this makes sure this isn't used..
  											 )

  # summarize each result for convenience ----
  dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  # substitute transition rates where needed ----

  trans_rate_df = dest_strata_f %>%
    left_join(., dest_strata_p, by = 'STRATA') %>%
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


  trans_rate_df = trans_rate_df %>%
    mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate))

   trans_rate_df$final_rate = coalesce(trans_rate_df$final_rate, trans_rate_df$in_season_rate)


   trans_rate_df_full = trans_rate_df

   full_strata_table = trans_rate_df_full %>%
     # right_join(., y = d_focal$res, by = 'STRATA') %>%
   	# right_join(., y = ddat_focal, by = 'STRATA') %>%
   	right_join(., y = ddat_focal_gf, by = 'STRATA') %>% # changed 2/15/23.. wrong table being joined!!
     as_tibble() %>%
   	 	mutate(SPECIES_ITIS_EVAL = species_itis
   				 , COMNAME_EVAL = species$ITIS_NAME[i]
   				 , FISHING_YEAR = FY
   				 , FY_TYPE = FY_TYPE) %>%
   	   dplyr::rename(FULL_STRATA = STRATA)

   # check one row per species-subtrip-link1
   if(nrow(full_strata_table) !=
     full_strata_table |> dplyr::select(CAMS_SUBTRIP, ITIS_TSN, LINK1) |> dplyr::distinct() |> nrow()) {
     warning("Duplicate rows in GF full_strata_table")
   }

  #
  # SECTOR ROLLUP: second pass ----
  #
  # logr::log_print(paste0("Getting rates across sectors for ", species_itis, " ", FY))

  stratvars_assumed = c("SPECIES_STOCK"
  											, "CAMS_GEAR_GROUP"
  											# , "GEARCODE"
  											, "MESH_CAT"
  											, "SECTOR_TYPE")


  ### All tables in previous run can be re-used with diff stratification

  # Run the discaRd functions on previous year
  d_prev_pass2 = run_discard(bdat = bdat_prev_gf
  											 , ddat = ddat_prev_gf
  											 , c_o_tab = ddat_prev
  											 # , year = 2018
  											 # , species_nespp3 = species_nespp3
  										   , species_itis = species_itis
  											 , stratvars = stratvars_assumed
  											 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
  											, aidx = c(1)  # this creates an unstratified broad stock rate
  											 )


  # Run the discaRd functions on current year
  d_focal_pass2 = run_discard(bdat = bdat_gf
  											 , ddat = ddat_focal_gf
  											 , c_o_tab = ddat_focal
  											 # , year = 2019
  											 # , species_nespp3 = '081' # haddock...
  											 # , species_nespp3 = species_nespp3  #'081' #cod...
  											 , species_itis = species_itis
  											 , stratvars = stratvars_assumed
  											 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
  											, aidx = c(1)  # this creates an unstratified broad stock rate
  											 )

  # summarize each result for convenience
  dest_strata_p_pass2 = d_prev_pass2$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  dest_strata_f_pass2 = d_focal_pass2$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  # substitute transition rates where needed

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


  trans_rate_df_pass2 = trans_rate_df_pass2 %>%
    mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate))

   trans_rate_df_pass2$final_rate = coalesce(trans_rate_df_pass2$final_rate, trans_rate_df_pass2$in_season_rate)


   # get a table of broad stock rates using discaRd functions: third pass. ----
   # Previously we used sector rollup results (ARATE in pass2)


  BROAD_STOCK_RATE_TABLE = list()

  kk = 1

  ustocks = bdat_gf$SPECIES_STOCK %>% unique()

  for(k in ustocks){
  	BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_rate(bdat = bdat_gf
  											 , ddat_focal_sp = ddat_focal_gf
  											 , ddat_focal = ddat_focal
  											 , species_itis = species_itis
  											 , stratvars = stratvars[1]
  											 # , aidx = 1
  											 , stock = k
  											 )
  	kk = kk + 1
  }

  BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

  rm(kk, k)

  #
  # BROAD_STOCK_RATE_TABLE = d_focal_pass2$res %>%
  #  	group_by(SPECIES_STOCK) %>%
  #  	dplyr::summarise(BROAD_STOCK_RATE = mean(ARATE)) # mean rate is max rate.. they are all the same within STOCK, as they should be

  # make names specific to the sector rollup pass

  names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')

  #
  # join full and assumed strata tables ----
  #
  joined_table = assign_strata(full_strata_table, stratvars_assumed)

  if("STRATA_ASSUMED" %in% names(joined_table)) {
  	joined_table = joined_table %>%
  		dplyr::select(-STRATA_ASSUMED)   # not using this anymore here..
  }

  joined_table = joined_table %>%
  	# dplyr::select(-STRATA_ASSUMED) %>%  # not using this anymore here..
  	dplyr::rename(STRATA_ASSUMED = STRATA) %>%
  	left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
  	left_join(x =., y = BROAD_STOCK_RATE_TABLE, by = 'SPECIES_STOCK') %>%
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


  # >5 trips in season gets in season rate
  # < 5 i nseason but >=5 past year gets transition
  # < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
  # <5, <5,  and <5 gets broad stock rate

  joined_table = joined_table %>%
  	mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 0 ~ 'O'  # observed with at least one obs haul and no offwatch hauls on trip
  																		, !is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 1 ~ 'I'  # observed with at least one obs haul
  																		, !is.na(LINK1) & LINK3_OBS == 0 ~ 'I'  # observed but no obs hauls..
  																		, is.na(LINK1) &
  																			n_obs_trips_f >= 5 ~ 'I'
  																		# , is.na(LINK1) & COAL_RATE == previous_season_rate ~ 'P'
  																		, is.na(LINK1) &
  																			n_obs_trips_f < 5 &
  																			n_obs_trips_p >=5 ~ 'T' # T only applies to full in-season strata
  																		, is.na(LINK1) &
  																			n_obs_trips_f < 5 &
  																			n_obs_trips_p < 5 &
  																			n_obs_trips_f_a >= 5 ~ 'A' # Assumed means Sector, Gear, Mesh
  																		, is.na(LINK1) &
  																			n_obs_trips_f < 5 &
  																			n_obs_trips_p < 5 &
  																			n_obs_trips_f_a < 5 &
  																			n_obs_trips_p_a >= 5 ~ 'B' # Broad stock is only for GF now
  																		, is.na(LINK1) &
  																			n_obs_trips_f < 5 &
  																			n_obs_trips_p < 5 &
  																			n_obs_trips_f_a < 5 &
  																			n_obs_trips_p_a < 5 ~ 'B'
  				)
  	)



  #
  # make sure CV type matches DISCARD SOURCE ----
  #

  # obs trips get 0, broad stock rate is NA


  joined_table <- joined_table |>
    ungroup() |>
    as.data.frame() |>
    # rowwise() |>
  	dplyr::mutate(CV = dplyr::case_when(DISCARD_SOURCE == 'O' ~ 0.0
  												, DISCARD_SOURCE == 'I' ~ as.numeric(CV_f)
  												, DISCARD_SOURCE == 'T' ~ as.numeric(CV_f)
  												, DISCARD_SOURCE == 'A' ~ as.numeric(CV_f_a)
  												, DISCARD_SOURCE == 'B' ~ as.numeric(CV_b),
  												TRUE ~ NA_real_
  												# , DISCARD_SOURCE == 'AT' ~ CV_f_a
  												)  # , DISCARD_SOURCE == 'B' ~ NA
  				 ) |>
    as.data.frame()

  # Make note of the stratification variables used according to discard source ----

  strata_f = paste(stratvars, collapse = ';')
  strata_a = paste(stratvars_assumed, collapse = ';')
  strata_b = stratvars[1]

  joined_table = joined_table %>%
  	mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' & LINK3_OBS == 1 ~ ''
  												, DISCARD_SOURCE == 'O' & LINK3_OBS == 0 ~ strata_f
  												, DISCARD_SOURCE == 'I' ~ strata_f
  												, DISCARD_SOURCE == 'T' ~ strata_f
  												, DISCARD_SOURCE == 'A' ~ strata_a
  												, DISCARD_SOURCE == 'B' ~ strata_b
  												)
  				 )

  #
  # get the discard for each trip using COAL_RATE ----
  #

  # discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio.
  # the KALLs should be small..

  joined_table = joined_table %>%
  	mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
  	mutate(DISCARD = ifelse(DISCARD_SOURCE == 'O', DISC_MORT_RATIO*OBS_DISCARD # observed with at least one obs haul
  													, DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS) # all other cases

  	)

  # if(FALSE) { # run this if looking manually
  # joined_table %>%
  # 	group_by(SPECIES_STOCK, DISCARD_SOURCE) %>%
  # 	dplyr::summarise(DISCARD_EST = sum(DISCARD)) %>%
  # 	pivot_wider(names_from = 'SPECIES_STOCK', values_from = 'DISCARD_EST') %>%
  # 	dplyr::select(-1) %>%
  # 	colSums(na.rm = T) %>%
  # 	round()
  # }


  #-------------------------------#
  # substitute EM data on EM trips ----
  #-------------------------------#

  # TODO: Convert these logr::log_print() statements to logr file write outs
  logr::log_print(paste0('Adding EM values for ', species$ITIS_NAME[i], ' Groundfish Trips ', FY))


  em_tab = ROracle::dbGetQuery(conn = con, statement = "
  			 select  ITIS_TSN as SPECIES_ITIS_EVAL
  			 , EM_COMPARISON
  			 , VTR_DISCARD
  			 , EM_DISCARD
  			 , DELTA_DISCARD
  			 , NMFS_DISCARD
  			 , NMFS_DISCARD_SOURCE
  			 , VTRSERNO
  			 from
  			 -- CAMS_GF_EM_DELTA_VTR_DISCARD_20_22
  			 CAMS_GF_EM_DELTA_VTR_DISCARD
  			 ") %>%
  	      as_tibble()

  emjoin = joined_table %>%
  	left_join(., em_tab, by = c('VTRSERNO', 'SPECIES_ITIS_EVAL')) %>%
  	mutate(DISCARD = case_when(is.na(NMFS_DISCARD_SOURCE) ~ DISCARD
  														 , DISCARD_SOURCE == 'O' ~ DISCARD
  														 , !is.na(NMFS_DISCARD_SOURCE) & DISCARD_SOURCE != 'O' ~ NMFS_DISCARD*DISC_MORT_RATIO)
  	) %>%
  		mutate(DISCARD_SOURCE = case_when(is.na(NMFS_DISCARD_SOURCE) ~ DISCARD_SOURCE
  														 , DISCARD_SOURCE == 'O' ~ DISCARD_SOURCE
  														 ,  !is.na(NMFS_DISCARD_SOURCE) & DISCARD_SOURCE != 'O' ~ NMFS_DISCARD_SOURCE)
  	) %>%
  	dplyr::select(names(joined_table))


  # change discard_source, strata_used, discard_rate, and discard for allocated groundfish stocks ----

  if(allocated == T){

  	mrem_idx = emjoin$EM == 'MREM'
  	emjoin$STRATA_USED[mrem_idx] = 'RULE BASED'
  	emjoin$DISCARD_SOURCE[mrem_idx] = 'R'
  	emjoin$COAL_RATE[mrem_idx] = 0
  	emjoin$DISCARD[mrem_idx] = 0
  	emjoin$CV[mrem_idx] = NA

  }


  #-------------------------------#
  # save trip by trip info to .fst file ----
  #-------------------------------#

  # force remove duplicates
  emjoin <- emjoin |>
    dplyr::distinct()


  # outfile = file.path(save_dir, paste0('discard_est_', species_itis, '_gftrips_only', FY,'.fst'))
  # 
  # fst::write_fst(x = emjoin, path = file.path(save_dir, paste0('discard_est_', species_itis, '_gftrips_only', FY,'.fst')))
  # 
  # system(paste("chmod 770 ", outfile))

   t2 = Sys.time()

  logr::log_print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

  }


  # if(gf_trips_only == F){

  # remove old objects so there is no chance of interference..

  	rm(list = ls()[grepl(x = ls(), 'ddat*')])
  	rm(list = ls()[grepl(x = ls(), 'bdat*')])
  	rm(list = ls()[grepl(x = ls(), 'd_f*')])
  	rm(list = ls()[grepl(x = ls(), 'b_f*')])
  	rm(list = ls()[grepl(x = ls(), 'dest*')])
  	rm(list = ls()[grepl(x = ls(), 'trans*')])
  	rm(list = ls()[grepl(x = ls(), 'strat*')])
  	rm(list = ls()[grepl(x = ls(), 'mnk*')])
  	# rm(list = ls()[grepl(x = ls(), 'CAMS_GEAR*')])
  	# rm(list = ls()[grepl(x = ls(), 'BROAD*')])
  	# rm(list = ls()[grepl(x = ls(), 'STOCK_*')])


  # Add OBS_DISCARD for non-GF trips

  #'
  ## ----loop through the non sector trips for each stock ----
  # -------------------------------------------------------------------#
  stratvars_nongf = c('SPECIES_STOCK'
                ,'CAMS_GEAR_GROUP'
  							, 'MESH_CAT'
  						  , 'TRIPCATEGORY'
  						  , 'ACCESSAREA')


  for(i in 1:length(species$ITIS_TSN)){

  t1 = Sys.time()

  logr::log_print(paste0('Running non-groundfish trips for ', species$ITIS_NAME[i], ' Fishing Year ', FY))

  species_itis = species$ITIS_TSN[i]
  
  non_gf_dat = non_gf_dat %>%
  	mutate(OBS_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE
  																 , TRUE ~ 0))
  
  #---#
  # Support table import by species

  # GEAR TABLE
  # CAMS_GEAR_STRATA = ROracle::dbGetQuery(con, 'select * from CFG_GEARCODE_STRATA') %>%
  #   dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>%
  #   # dplyr::filter(NESPP3 == species_nespp3) %>%
  # 	dplyr::filter(ITIS_TSN == species_itis) %>%
  #   dplyr::select(-NESPP3, -ITIS_TSN)
  # 
  # # Stat areas table
  # # unique stat areas for stock ID if needed
  # STOCK_AREAS = ROracle::dbGetQuery(con, 'select * from CFG_STATAREA_STOCK') %>%
  #   # dplyr::filter(NESPP3 == species_nespp3) %>%  # removed  & AREA_NAME == species_stock
  # 	dplyr::filter(ITIS_TSN == species_itis) %>%
  #   group_by(AREA_NAME, ITIS_TSN) %>%
  #   distinct(AREA) %>%
  #   mutate(AREA = as.character(AREA)
  #          , SPECIES_STOCK = AREA_NAME) %>%
  #   ungroup()
  # # %>%
  # #   dplyr::select(SPECIES_STOCK, AREA)
  # 
  # # Mortality table
  # CAMS_DISCARD_MORTALITY_STOCK = ROracle::dbGetQuery(con, "select * from CFG_DISCARD_MORTALITY_STOCK")  %>%
  #   mutate(SPECIES_STOCK = AREA_NAME
  #          , GEARCODE = CAMS_GEAR_GROUP
  #   			 , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  #   dplyr::select(-AREA_NAME) %>%
  #   # mutate(CAREA = as.character(STAT_AREA)) %>%
  #   # dplyr::filter(NESPP3 == species_nespp3) %>%
  # 	dplyr::filter(ITIS_TSN == species_itis) %>%
  #   dplyr::select(-ITIS_TSN)
  # %>%
  #   dplyr::rename(DISC_MORT_RATIO = Discard_Mortality_Ratio)

  #---------#
  # haddock example trips with full strata either in year_t or year _t-1
  #---------#

  # logr::log_print(paste0("Getting in-season rates for ", species_itis, " ", FY))

  # make tables
  ddat_focal <- non_gf_dat %>%
    dplyr::filter(GF_YEAR == FY) %>%   ## time element is here!!
    dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
    mutate(LIVE_POUNDS = SUBTRIP_KALL
           ,SEADAYS = 0
  	  		 ) %>%
     left_join(., y = STOCK_AREAS, by = 'AREA') %>%
     left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
     left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
              , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
              ) %>%
  	dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
  	dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
    relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
  	assign_strata(., stratvars = stratvars_nongf)

  ddat_prev <- non_gf_dat %>%
    dplyr::filter(GF_YEAR == FY-1) %>%   ## time element is here!!
    dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
    mutate(LIVE_POUNDS = SUBTRIP_KALL
           ,SEADAYS = 0
  	  		 ) %>%
     left_join(., y = STOCK_AREAS, by = 'AREA') %>%
     left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
     left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
              , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
              ) %>%
  		dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
  	dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
    relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
  	assign_strata(., stratvars = stratvars_nongf)


  # need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
  # need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!

  ddat_focal_non_gf <- summarise_single_discard_row(data = ddat_focal, itis_tsn = species_itis)

  # and join to the unobserved trips
  ddat_focal_non_gf = ddat_focal_non_gf %>%
    union_all(ddat_focal %>%
                dplyr::filter(is.na(LINK1))
    					# %>%
                 # group_by(VTRSERNO, CAMSID) %>%
                 # slice(1) %>%
                 # ungroup()
              )


  # if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
  # DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS.

  bdat_non_gf = ddat_focal %>%
    dplyr::filter(!is.na(LINK1)) %>%
  	dplyr::filter(FISHDISP != '090') %>%
  	dplyr::filter(LINK3_OBS == 1) %>%
  	dplyr::filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
    mutate(DISCARD_PRORATE = DISCARD
           , OBS_AREA = AREA
           , OBS_HAUL_KALL_TRIP = OBS_KALL
           , PRORATE = 1)


  # set up trips table for previous year
  ddat_prev_non_gf <- summarise_single_discard_row(data = ddat_prev, itis_tsn = species_itis)

  ddat_prev_non_gf = ddat_prev_non_gf %>%
    union_all(ddat_prev %>%
    						 dplyr::filter(is.na(LINK1))
    					# %>%
                 # group_by(VTRSERNO, CAMSID) %>%
                 # slice(1) %>%
                 # ungroup()
    					)


  # previous year observer data needed..
  bdat_prev_non_gf = ddat_prev %>%
    dplyr::filter(!is.na(LINK1)) %>%
  	dplyr::filter(FISHDISP != '090') %>%
  	dplyr::filter(LINK3_OBS == 1) %>%
  	dplyr::filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
    mutate(DISCARD_PRORATE = DISCARD
           , OBS_AREA = AREA
           , OBS_HAUL_KALL_TRIP = OBS_KALL
           , PRORATE = 1)

  # Run the discaRd functions on previous year
  d_prev = run_discard(bdat = bdat_prev_non_gf
  											 , ddat = ddat_prev_non_gf
  											 , c_o_tab = ddat_prev
  										   , species_itis = species_itis
  											 , stratvars = stratvars_nongf
  											 # , aidx = c(1:length(stratvars))
  										   , aidx = c(1:2) # uses GEAR as assumed
  											 )


  # Run the discaRd functions on current year
  d_focal = run_discard(bdat = bdat_non_gf
  											 , ddat = ddat_focal_non_gf
  											 , c_o_tab = ddat_focal
  											 , species_itis = species_itis
  											 , stratvars = stratvars_nongf
  											 # , aidx = c(1:length(stratvars))  # this makes sure this isn't used..
  											 , aidx = c(1:2) # uses GEAR as assumed
  											 )

  # summarize each result for convenience
  dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  # substitute transition rates where needed

  trans_rate_df = dest_strata_f %>%
    left_join(., dest_strata_p, by = 'STRATA') %>%
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


  trans_rate_df = trans_rate_df %>%
    mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate))

   trans_rate_df$final_rate = coalesce(trans_rate_df$final_rate, trans_rate_df$in_season_rate)


   trans_rate_df_full = trans_rate_df

   full_strata_table = trans_rate_df_full %>%
     # right_join(., y = d_focal$res, by = 'STRATA') %>%
   	# right_join(., y = ddat_focal, by = 'STRATA') %>%
   	right_join(., y = ddat_focal_non_gf, by = 'STRATA') %>% # changed 2/15/23.. wrong table being joined!!
     as_tibble() %>%
   	 	mutate(SPECIES_ITIS_EVAL = species_itis
   				 , COMNAME_EVAL = species$ITIS_NAME[i]
   				 , FISHING_YEAR = FY
   				 , FY_TYPE = FY_TYPE) %>%
   	   dplyr::rename(FULL_STRATA = STRATA)

  # GEAR AND MESH_CAT STRATA (2nd pass)

  # logr::log_print(paste0("Getting rates across sectors for ", species_itis, " ", FY))

  stratvars_assumed = c("SPECIES_STOCK"
  											, "CAMS_GEAR_GROUP"
  											, "MESH_CAT")


  ### All tables in previous run can be re-used wiht diff stratification

  # Run the discaRd functions on previous year
  d_prev_pass2 = run_discard(bdat = bdat_prev_non_gf
  											 , ddat = ddat_prev_non_gf
  											 , c_o_tab = ddat_prev
  											 # , year = 2018
  											 # , species_nespp3 = species_nespp3
  										   , species_itis = species_itis
  											 , stratvars = stratvars_assumed
  											 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
  											, aidx = c(1)  # this creates an unstratified broad stock rate
  											 )


  # Run the discaRd functions on current year
  d_focal_pass2 = run_discard(bdat = bdat_non_gf
  											 , ddat = ddat_focal_non_gf
  											 , c_o_tab = ddat_focal
  											 # , year = 2019
  											 # , species_nespp3 = '081' # haddock...
  											 # , species_nespp3 = species_nespp3  #'081' #cod...
  											 , species_itis = species_itis
  											 , stratvars = stratvars_assumed
  											 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
  											, aidx = c(1)  # this creates an unstratified broad stock rate
  											 )

  # summarize each result for convenience
  dest_strata_p_pass2 = d_prev_pass2$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  dest_strata_f_pass2 = d_focal_pass2$allest$C %>% summarise(STRATA = STRATA
                         , N = N
                         , n = n
                         , orate = round(n/N, 2)
                         , drate = RE_mean
                         , KALL = K, disc_est = round(D)
                         , CV = round(RE_rse, 2)
  										)

  # substitute transition rates where needed

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


  trans_rate_df_pass2 = trans_rate_df_pass2 %>%
    mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate))

   trans_rate_df_pass2$final_rate = coalesce(trans_rate_df_pass2$final_rate, trans_rate_df_pass2$in_season_rate)


   # get a table of broad stock rates using discaRd functions. Previosuly we used sector rollupresults (ARATE in pass2)


  bdat_2yrs = bind_rows(bdat_prev_non_gf, bdat_non_gf)
  ddat_non_gf_2yr = bind_rows(ddat_prev_non_gf, ddat_focal_non_gf)
  ddat_2yr = bind_rows(ddat_prev, ddat_focal) # TODO: double check correct reuse of ddat_focal

  mnk = run_discard( bdat = bdat_2yrs
  			, ddat_focal = ddat_non_gf_2yr
  			, c_o_tab = ddat_2yr
  			, species_itis = species_itis
  			, stratvars = stratvars_nongf[1:2]  #"SPECIES_STOCK"   "CAMS_GEAR_GROUP"
  			)

  # rate table
  mnk$allest$C

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
  joined_table = assign_strata(full_strata_table, stratvars_assumed)

  if("STRATA_ASSUMED" %in% names(joined_table)) {
  	joined_table = joined_table %>%
  		dplyr::select(-STRATA_ASSUMED)   # not using this anymore here..
  }

  joined_table = joined_table %>%
  	# dplyr::select(-STRATA_ASSUMED) %>%  # not using this anymore here..
  	dplyr::rename(STRATA_ASSUMED = STRATA) %>%
  	left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
  	left_join(., y = BROAD_STOCK_RATE_TABLE, by = c('SPECIES_STOCK','CAMS_GEAR_GROUP')) %>%
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
  # add discard source
  #


  # >5 trips in season gets in season rate
  # < 5 i nseason but >=5 past year gets transition
  # < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
  # <5, <5,  and <5 gets broad stock rate

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

  strata_f = paste(stratvars_nongf, collapse = ';')
  strata_a = paste(stratvars_assumed, collapse = ';')
  strata_b = paste(stratvars_gear, collapse = ';')

  joined_table = joined_table %>%
  	mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' & LINK3_OBS == 1 ~ ''
  												, DISCARD_SOURCE == 'O' & LINK3_OBS == 0 ~ strata_f
  												, DISCARD_SOURCE == 'I' ~ strata_f
  												, DISCARD_SOURCE == 'T' ~ strata_f
  												, DISCARD_SOURCE == 'GM' ~ strata_a
  												, DISCARD_SOURCE == 'G' ~ strata_b
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

  # force remove duplicates
  joined_table <- joined_table |>
    dplyr::distinct()

   # saveRDS(joined_table, file = paste0(here::here('CAMS/MODULES/GROUNDFISH/OUTPUT/discard_est_', species_itis, '_non_gftrips.RDS'))
  # Sys.umask('660')
  # Sys.umask('775')

  # outfile = file.path(save_dir, paste0('discard_est_', species_itis, '_non_gftrips', FY,'.fst'))
  # 
  # fst::write_fst(x = joined_table, path = outfile)

  # system(paste("chmod 770 ", outfile))

  t2 = Sys.time()

  logr::log_print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

  }

  ## ----estimate discards on scallop trips for each subACL stock using subroutine ----

  # do only the yellowtail and windowpane for scallop trips

  scal_gf_species = species %>%
  	dplyr::filter(ITIS_TSN %in% c('172909', '172746'))

  # for(species_itis %in% c('172909', '172746')){

 if(nrow(scal_gf_species) > 0){ 	
  	
  for(i in 1:length(scal_gf_species$ITIS_TSN)){

  save_dir = getwd()	
  	
    scallop_subroutine(FY = FY
    									 , con = con
                       , scal_gf_species = scal_gf_species[i, ]
                       , non_gf_dat = non_gf_dat
                       , scal_trip_dir = file.path(save_dir, "scallop_groundfish")
    )
  }

  ## ----substitute scallop trips into non-gf trips ----
  # if(species_itis %in% c('172909', '172746')){

  for(i in 1:length(scal_gf_species$ITIS_TSN)){
  # for(j in 2018:2019){
  start_time = Sys.time()

  	GF_YEAR = FY

  	# for(i in 1:length(scal_gf_species$ITIS_TSN)){

  		logr::log_print(paste0('Adding scallop trip estimates of: ',  scal_gf_species$ITIS_NAME[i], ' for Groundfish Year ', GF_YEAR))

  		sp_itis = scal_gf_species$ITIS_TSN[i]

  		# get only the non-gf trips for each species and fishing year

  		# gf_files = list.files(save_dir, pattern = paste0('discard_est_', sp_itis), full.names = T) # don't need for the diagnostic function 
  		# gf_files = gf_files[grep(GF_YEAR, gf_files)]
  		# gf_files = gf_files[grep('non_gf', gf_files)]

  		# get list all scallop trips bridging fishing years
  		# scal_file_dir = here::here('CAMS/MODULES/APRIL/OUTPUT/')
  		scal_files = list.files(file.path(save_dir, "scallop_groundfish"), pattern = paste0('discard_est_', sp_itis, '_scal_trips_SCAL'), full.names = T)

  		# read in files
  		res_scal = lapply(as.list(scal_files), function(x) fst::read_fst(x))
  		# res_gf = lapply(as.list(gf_files), function(x) fst::read_fst(x))  # don't need for the diagnostic function 

  		# assign(paste0('outlist_df_scal'),  do.call(rbind, outlist))
  		assign(paste0('outlist_df_scal'),  do.call(dplyr::bind_rows, res_scal))



  		# assign(paste0('outlist_df_',sp_itis,'_',GF_YEAR),  do.call(rbind, outlist))  # don't need for the diagnostic function 
  				# assign(paste0('outlist_df_',sp_itis,'_',GF_YEAR),  do.call(rbind, res_gf))

  		# t1  = get(paste0('outlist_df_',sp_itis,'_',GF_YEAR))
  		
  		t1 = joined_table
  		# %>%
  		# 	dplyr::select(-DATE_TRIP.1)
  		t2 = get(paste0('outlist_df_scal'))	%>%
  			dplyr::filter(GF_YEAR == GF_YEAR)

  		# index scallop records present in groundfish year table
  		t2idx = t2$CAMS_SUBTRIP %in% t1$CAMS_SUBTRIP # & t2$CAMSID %in% t1$CAMSID

  		# index records in groundfish table to be removed
  		t1idx = t1$CAMS_SUBTRIP %in% t2$CAMS_SUBTRIP # & t1$CAMSID %in% t2$CAMSID


  		# make sure columns match
  		didx  = match(names(t1), names(t2))

  		# swap the scallop estimated trips into the groundfish records ----


  		t1[t1idx, ] = t2[t2idx, didx]

  		# force remove duplicates
  		t1 <- t1 |>
  		  dplyr::distinct()

# --- Overwrite the original non-gf with the new version including scallop replacement ----
  		# write_fst(x = t1, path = gf_files)
  		# 
  		# system(paste("chmod 770 ", gf_files))

  		end_time = Sys.time()

  		logr::log_print(paste('Scallop subsitution took: ', round(difftime(end_time, start_time, units = "mins"),2), ' MINUTES',  sep = ''))


 # rename the t1 object with subbed in scallop trips to joined table. this will overwrite the object created outside the scallop loop ---- 
  		
  		joined_table = t1 
  		
  }
 	
 } # end if statement

# join GF and non-gf trip results ----  	
  	
  	joined_table = joined_table %>% 
  		bind_rows(., emjoin)
  	
  	dest_obj = joined_table %>% 
  		group_by(FISHING_YEAR, GF, STRATA_USED, DISCARD_SOURCE, SPECIES_STOCK, CAMS_GEAR_GROUP, MESH_CAT, TRIPCATEGORY, ACCESSAREA, FED_OR_STATE) %>%
  		dplyr::summarise(rate = max(COAL_RATE, na.rm = T)
  										 , n_f = max(n_obs_trips_f)
  										 , n_p = max(n_obs_trips_p)
  										 , N = n_distinct(CAMS_SUBTRIP)
  										 # , rate_min = min(COAL_RATE, na.rm = T)
  										 , KALL = round(sum(LIVE_POUNDS, na.rm = T))
  										 , D = round(sum(DISCARD, na.rm = T), 2)
  										 , CV = max(CV, na.rm = T)
  		)
  	
  	if(return_table == T & return_summary == F){return(joined_table)}
  	if (return_table == F & return_summary == T) {return(dest_obj)}
  	if (return_table == T & return_summary == T) {return(list(trips_discard = joined_table, discard_summary = dest_obj))}
  	if(return_table == F & return_summary == F) {(print("What did you do all that work for?"))} 	
  

  }


