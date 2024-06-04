#' Groundfish discards on scallop trips
#' This function oeprates identically to otehr discard modules but is only relevant for scallop trips, and is predicated on what groundfish fishing year is under evaluation.
#' @author Ben Galuardi
#' @Date 6/6/22, updated 9/21/22
#'
#' @param FY Groundfish Fishing year under evaluation. This value determines which scallop fishing years are run
#' @param scal_gf_species data frame, single row, that has species_itis and common name of groundfish under evaluation (e.g. yellowtail and windowpane flounder)
#' @param non_gf_dat data frame containing non-groundfish trips from `CAMS_LANDINGS`. This is loaded from Oracle from a control script.
#' @param scal_trip_dir Directory to save scallop trip results
#' @param con ROracle database connection
#'
#' @return writes a .fst file for disacrd estimates on scallop trips for species under evaluation. This folder and will be referenced within the groundfish module.
#' @export
#'
#' @examples
scallop_subroutine <- function(FY = 2019
                               , con = con_maps
                               , scal_gf_species
                               , non_gf_dat = non_gf_dat
                               , scal_trip_dir = file.path(getOption("maps.discardsPath"), "scallop_groundfish")
){

  if(!dir.exists(scal_trip_dir)) {
    dir.create(scal_trip_dir, recursive = TRUE)
    system(paste("chmod 770 -R", scal_trip_dir))
  }

  species_itis <- scal_gf_species$ITIS_TSN

  # {r estimate discards on scallop trips for each subACL stock, purl = T, eval = T}

  non_gf_dat = non_gf_dat %>%
    mutate(OBS_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE
                                   , TRUE ~ 0))

  scal_trips = non_gf_dat %>%
    filter(substr(ACTIVITY_CODE_1,1,3) == 'SES')

  # stratvars_scalgf = c("SCAL_YEAR"
  #                      , 'SPECIES_STOCK'
  #                      ,'CAMS_GEAR_GROUP'
  #                      , 'MESH_CAT'
  #                      , 'TRIPCATEGORY'
  #                      , 'ACCESSAREA'
  #                      , 'SCALLOP_AREA'
  #                      )

  # scal_gf_species = species[species$SPECIES_ITIS %in% c('172909', '172746'),]

  # NEED TO LOOP OVER TWO YEARS EACH TIME BEACUSE OF MISMATCH IN GROUNDFISH/SCALLOP YEAR.. E.G. GF YEAR 2018 NEEDS SCAL YEAR 2018 AND 2019..
  # THIS NEEDS TO BE DONE HERE BECAUSE THE TABLE SUBSTITUTION IS THE NEXT CHUNK...

  get_scal_range = function(scal_fy){
    y = scal_fy
    smonth = ifelse(y <= 2018, 3, 4)
    emonth = ifelse(y < 2018, 2, 3)
    eday = ifelse(y < 2018, 28, 31)
    sdate = lubridate::as_date(paste(y, smonth, 1, sep = '-'))
    edate = lubridate::as_date(paste(y+1, emonth, eday, sep = '-'))

    c(sdate, edate)

  }


  scal_trips = non_gf_dat %>%
    filter(substr(ACTIVITY_CODE_1,1,3) == 'SES')

# setup scallop strata ----

  stratvars_scalgf = c('FY'
                       , 'FY_TYPE'
                       , 'SPECIES_STOCK'
                       , 'CAMS_GEAR_GROUP'
                       , 'MESH_CAT'
                       , 'TRIPCATEGORY'
                       , 'ACCESSAREA'
                       , 'SCALLOP_AREA'
                       )

  FY_TYPE = 'APRIL'
# get date ranges for current and previous fishing year ----
  # Can't run discard for a future year.. this prevents that
  end_fy = ifelse(year(Sys.Date()) == FY, 0, 1)

  for(yy in FY:(FY+end_fy)){

    if (yy == year(Sys.Date())){
      scal_end_date = as_date(paste(year(Sys.Date()), month(Sys.Date()), 1, sep = '-'))
      scal_start_date = scal_end_date-365
    } else{
      dr = get_scal_range(yy)
      scal_end_date = dr[2]
      scal_start_date = dr[1]
    }

    # for(i in 1:length(scal_gf_species$SPECIES_ITIS)){
    #
    t1 = Sys.time()

    logr::log_print(paste0('ESTIMATING SCALLOP TRIP DISCARDS FOR SCALLOP YEAR', yy," ", scal_gf_species$ITIS_NAME))

    # species_itis = scal_gf_species$SPECIES_ITIS
    #---#
    # Support table import by species ----

    # GEAR TABLE
    CAMS_GEAR_STRATA = tbl(con, sql('  select * from CFG_GEARCODE_STRATA')) %>%
      collect() %>%
      dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>%
      filter(ITIS_TSN == species_itis) %>%  # use strata for the species. It should only be DRS and OTB for scallop trips
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

    # make trip and obs tables ----
    ddat_focal <- scal_trips %>%
      mutate(FY_TYPE = FY_TYPE
             , FY = SCAL_YEAR) %>%
      # filter(SCAL_YEAR == yy) %>%   ## time element is here!! NOTE THE SCAL YEAR>>>
      filter(DATE_TRIP >= scal_start_date & DATE_TRIP <= scal_end_date) %>%
      filter(AREA %in% STOCK_AREAS$AREA) %>%
      mutate(LIVE_POUNDS = SUBTRIP_KALL
             ,SEADAYS = 0
      ) %>%
      left_join(., y = STOCK_AREAS, by = 'AREA') %>%
      left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
      left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
                , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
      ) %>%
      dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
      dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS', GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
      relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
      assign_strata(., stratvars = stratvars_scalgf)

    ddat_prev <- scal_trips %>%
      mutate(FY_TYPE = FY_TYPE
             , FY = SCAL_YEAR) %>%
      # filter(SCAL_YEAR == yy-1) %>%   ## time element is here!! NOTE THE SCAL YEAR>>>
      filter(DATE_TRIP >= scal_start_date-365 & DATE_TRIP <= scal_end_date-365) %>%
      filter(AREA %in% STOCK_AREAS$AREA) %>%
      mutate(LIVE_POUNDS = SUBTRIP_KALL
             ,SEADAYS = 0
      ) %>%
      left_join(., y = STOCK_AREAS, by = 'AREA') %>%
      left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
      left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
                , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
      ) %>%
      dplyr::select( -GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
      dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS', GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
      relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')



    # need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
    # need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!

    ddat_focal_scal <- summarise_single_discard_row(data = ddat_focal, itis_tsn = species_itis)

    # and join to the unobserved trips

    ddat_focal_scal = ddat_focal_scal %>%
      union_all(ddat_focal %>%
                  filter(is.na(LINK1))
                # %>%
                # group_by(VTRSERNO, CAMSID) %>%
                # slice(1) %>%
                # ungroup()
      )


    # if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
    # DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS.

    bdat_scal = ddat_focal %>%
      filter(!is.na(LINK1)) %>%
      filter(FISHDISP != '090') %>%
      filter(LINK3_OBS == 1) %>%
      filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
      mutate(OBS_AREA = AREA
             , OBS_HAUL_KALL_TRIP = OBS_KALL
             , PRORATE = 1)


    # set up trips table for previous year ----
    ddat_prev_scal <- summarise_single_discard_row(data = ddat_prev, itis_tsn = species_itis)

    ddat_prev_scal = ddat_prev_scal %>%
      union_all(ddat_prev %>%
                  filter(is.na(LINK1))
                # %>%
                # group_by(VTRSERNO, CAMSID) %>%
                # slice(1) %>%
                # ungroup()
      )


    # previous year observer data needed..
    bdat_prev_scal = ddat_prev %>%
      filter(!is.na(LINK1)) %>%
      filter(FISHDISP != '090') %>%
      filter(LINK3_OBS == 1) %>%
      filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
      mutate( OBS_AREA = AREA
              , OBS_HAUL_KALL_TRIP = OBS_KALL
              , PRORATE = 1)

    # Run the discaRd functions on previous year ----
    d_prev = run_discard(bdat = bdat_prev_scal
                         , ddat = ddat_prev_scal
                         , c_o_tab = ddat_prev
                         , species_itis = species_itis
                         , stratvars = stratvars_scalgf
                         # , aidx = c(1:length(stratvars))
                         , aidx = c(1:3) # uses GEAR as assumed
    )


    # Run the discaRd functions on current year ----
    d_focal = run_discard(bdat = bdat_scal
                          , ddat = ddat_focal_scal
                          , c_o_tab = ddat_focal
                          , species_itis = species_itis
                          , stratvars = stratvars_scalgf
                          # , aidx = c(1:length(stratvars))  # this makes sure this isn't used..
                          , aidx = c(1:3) # uses GEAR as assumed
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
      right_join(., y = ddat_focal_scal, by = 'STRATA') %>%
      as_tibble() %>%
      mutate(SPECIES_ITIS_EVAL = species_itis
             , COMNAME_EVAL = scal_gf_species$ITIS_NAME
             , FISHING_YEAR = yy
             , FY_TYPE = FY_TYPE) %>%
      dplyr::rename(FULL_STRATA = STRATA)

    # GEAR and MESh rollup (2nd pass for scallop trips)

    # Make 'assumed' strata ----
    # join full and assumed strata tables
    stratvars_assumed = c('FY'
                          , 'FY_TYPE'
                          ,"SPECIES_STOCK"
                          , "CAMS_GEAR_GROUP"
                          , "MESH_CAT")


    ### All tables in previous run can be re-used with diff stratification

    ### Run the discaRd functions on previous year ----
    d_prev_pass2 = run_discard(bdat = bdat_prev_scal
                               , ddat = ddat_prev_scal
                               , c_o_tab = ddat_prev
                               , species_itis = species_itis
                               , stratvars = stratvars_assumed
                               # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
                               , aidx = c(1:2)  # this creates an unstratified broad stock rate
    )


    ### Run the discaRd functions on current year ----
    d_focal_pass2 = run_discard(bdat = bdat_scal
                                , ddat = ddat_focal_scal
                                , c_o_tab = ddat_focal
                                , species_itis = species_itis
                                , stratvars = stratvars_assumed
                                # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used..
                                , aidx = c(1:2)  # this creates an unstratified broad stock rate
    )

    ### summarize each result for convenience ----
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

    ### substitute transition rates where needed ----

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



    # Gear only Rollup: this replaces a broad stock rate. and, this is only scallop trips so it may be redundant with previous pass ----

    bdat_2yrs = bind_rows(bdat_prev_scal, bdat_scal)
    ddat_non_gf_2yr = bind_rows(ddat_prev_scal, ddat_focal_scal)
    ddat_2yr = bind_rows(ddat_prev, ddat_focal)

    gear_only = run_discard( bdat = bdat_2yrs
                             , ddat_focal = ddat_non_gf_2yr
                             , c_o_tab = ddat_2yr
                             , species_itis = species_itis
                             , stratvars = stratvars_scalgf[1:4]  #FY, FY_TYPE "SPECIES_STOCK"   "CAMS_GEAR_GROUP"
    )

    # broad rate table ----

    BROAD_STOCK_RATE_TABLE = gear_only$allest$C |>
      dplyr::select(STRATA, N, n, RE_mean, RE_rse) |>
      mutate(FY = as.numeric(sub("_.*", "", STRATA))
             , FY_TYPE = FY_TYPE) |>
      mutate(SPECIES_STOCK = gsub("^([^_]+)_", "", STRATA)  |>
               gsub(pattern = "^([^_]+)_", replacement = "")  |>
               sub(pattern ="_.*", replacement ="")
             , CAMS_GEAR_GROUP = gsub("^([^_]+)_", "", STRATA) |>
               gsub(pattern = "^([^_]+)_", replacement = "")  |>
               gsub(pattern = "^([^_]+)_", replacement = "")
             , CV_b = round(RE_rse, 2)
      ) |>
      dplyr::rename(BROAD_STOCK_RATE = RE_mean
                    , n_B = n
                    , N_B = N) |>
      dplyr::select(FY, FY_TYPE, SPECIES_STOCK, CAMS_GEAR_GROUP, BROAD_STOCK_RATE, CV_b, n_B, N_B)

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
    #
    # BROAD_STOCK_RATE_TABLE <- data.frame(FY = FY_BST, FY_TYPE = FY_TYPE, cbind(SPECIES_STOCK, CAMS_GEAR_GROUP, BROAD_STOCK_RATE, CV_b))
    #
    # BROAD_STOCK_RATE_TABLE$BROAD_STOCK_RATE <- as.numeric(BROAD_STOCK_RATE_TABLE$BROAD_STOCK_RATE)
    # BROAD_STOCK_RATE_TABLE$CV_b <- as.numeric(BROAD_STOCK_RATE_TABLE$CV_b)


    names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')

    #
    # join full and assumed strata tables
    #
    # logr::log_print(paste0("Constructing output table for ", species_itis, " ", FY))

    joined_table = assign_strata(full_strata_table, stratvars_assumed)

    if("STRATA_ASSUMED" %in% names(joined_table)) {
      joined_table = joined_table %>%
        dplyr::select(-STRATA_ASSUMED)   # not using this anymore here..
    }

    joined_table <- joined_table %>%
      # dplyr::select(-STRATA_ASSUMED) %>%  # not using this anymore here..
      dplyr::rename(STRATA_ASSUMED = STRATA) %>%
      left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
      left_join(., y = BROAD_STOCK_RATE_TABLE, by = c('FY', 'FY_TYPE', 'SPECIES_STOCK','CAMS_GEAR_GROUP')) %>%
      mutate(COAL_RATE = case_when(n_obs_trips_f >= 5 ~ final_rate  # this is an in season rate
                                   , n_obs_trips_f < 5 &
                                     n_obs_trips_p >=5 ~ final_rate  # this is a final IN SEASON rate taking transition into account
                                   , n_obs_trips_f < 5 &
                                     n_obs_trips_p < 5 ~ trans_rate_a  # this is an final assumed rate taking transition into account
      )
      ) %>%
      mutate(COAL_RATE = coalesce(COAL_RATE, BROAD_STOCK_RATE)) %>%
      mutate(SPECIES_ITIS_EVAL = species_itis
             , COMNAME_EVAL = scal_gf_species$ITIS_NAME
             , FISHING_YEAR = yy
             , FY_TYPE = FY_TYPE)

    #
    # add discard source
    #

    joined_table = assign_discard_source(joined_table, GF = 0)

    # >5 trips in season gets in season rate
    # < 5 i nseason but >=5 past year gets transition
    # < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
    # <5, <5,  and <5 gets broad stock rate

    # joined_table = joined_table %>%
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

    stratvars_gear = c("FY"
                       , "FY_TYPE"
                       , "SPECIES_STOCK"
                       , "CAMS_GEAR_GROUP")

    strata_f = paste(stratvars_scalgf, collapse = ';')
    strata_a = paste(stratvars_assumed, collapse = ';')
    strata_b = paste(stratvars_gear, collapse = ';')

    joined_table = joined_table %>%
      mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' ~ ''
                                     , DISCARD_SOURCE == 'I' ~ strata_f
                                     , DISCARD_SOURCE == 'T' ~ strata_f
                                     , DISCARD_SOURCE == 'GM' ~ strata_a
                                     , DISCARD_SOURCE == 'G' ~ strata_b
                                     , TRUE ~ NA_character_
      )
      )


    #
    # get the discard for each trip using COAL_RATE}
    #

    # discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio.
    # the KALLs should be small..

    joined_table = joined_table %>%
      mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) # %>%
    # mutate(DISCARD = ifelse(DISCARD_SOURCE == 'O', DISC_MORT_RATIO*OBS_DISCARD # observed with at least one obs haul
    # 												, DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS) # all other cases
    # )
    # Sys.umask('775')

    joined_table <- joined_table |>
      dplyr::distinct()%>%
      mutate(DISCARD_SOURCE = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 'N'
                                        ,TRUE ~ DISCARD_SOURCE)) %>%
      mutate(DISCARD = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 0.0,
                                 DISCARD_SOURCE == 'O' ~ DISC_MORT_RATIO*OBS_DISCARD,
                                 DISCARD_SOURCE != 'O' ~ DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS,
                                 TRUE ~ NA_real_))%>%
      mutate(CV = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ NA_real_
                            ,TRUE ~ CV))

    # add covrow ----

    # joined_table = get_covrow(joined_table)

    joined_table = joined_table |>
      add_nobs() |>
      make_strata_desc() |>
      get_covrow() |>
      mutate(covrow = case_when(DISCARD_SOURCE =='N' ~ NA_real_
                                , TRUE ~ covrow))


    # make sure the fishing year file contains ONLY trips in that scallop fishing year ----

    joined_table = joined_table %>%
      filter(SCAL_YEAR == yy)


    # force remove duplicates ----
    joined_table <- joined_table |>
      dplyr::distinct()

    outfile = file.path(scal_trip_dir, paste0('discard_est_', species_itis, '_scal_trips_SCAL', yy,'.fst'))

    fst::write_fst(x = joined_table, path = outfile)

    system(paste("chmod 770 ", outfile))

    t2 = Sys.time()

    logr::log_print(paste(species_itis, ' SCALLOP DISCARDS RAN IN ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

  }

  # end function

}



