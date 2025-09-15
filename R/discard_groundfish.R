#' discard_groundfish: Calculate groundfish discards
#'
#' @param con ROracle connection to Oracle (e.g. MAPS)
#' @param species dataframe with species info
#' @param FY Fishing Year
#' @param gf_dat Data frame of groundfish trips built from CAMS_OBS_CATCH and control script routine
#' @param non_gf_dat Data frame of non-groundfish trips built from CAMS_OBS_CATCH and control script routine
#' @param gf_trips_only Flag if user only wants to run groundfish trips (e.g. for quota monitoring)
#' @param save_dir Directory to save (and load saved) results
#' @param run_parallel option to run species discard calculations in parallel
#'
#' @return nothing currently, writes out to fst files (add oracle?)
#'@author Benjamin Galuardi
#' @export
#'
#' @examples
#'
discard_groundfish <- function(con
                               , species = species
                               , FY = fy
                               , gf_dat = gf_dat
                               , non_gf_dat = non_gf_dat
                               , gf_trips_only = F
                               , save_dir = file.path(getOption("maps.discardsPath"), "groundfish")
                               , run_parallel = FALSE
) {

  config_run <- configr::read.config(file = here::here("configRun.toml"))
  pw <- as.character(config_run$pw)

  if(!dir.exists(save_dir)) {
    dir.create(save_dir, recursive = TRUE)
    system(paste("chmod 770 -R", save_dir))
  }

  FY_TYPE = species$RUN_ID[1]

  ## ----loop through the sector trips for each stock, eval = T-----------------------------------------------------------------------

  # Stratification variables ----

  stratvars = c('FY'
                , 'FY_TYPE'
                , 'SPECIES_ESTIMATION_REGION'
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

  `%op%` <- if (run_parallel) `%dopar%` else `%do%`

  ncores <- dplyr::case_when(
    config_run$load$type_run == "preprod" ~ min(length(unique(species$ITIS_TSN)), 5, parallel::detectCores() -1),
    TRUE ~ min(length(unique(species$ITIS_TSN)), 13, parallel::detectCores() -1)
  )

  cl <- makeCluster(ncores)
  registerDoParallel(cl, cores = ncores)

  foreach(
    i = 1:length(species$ITIS_TSN),
    .export = c("pw", "database"),
    .noexport = "con",
    .packages = c("discaRd", "dplyr", "MAPS", "DBI", "ROracle", "apsdFuns", "keyring", "fst")
  ) %op% {

    options(keyring_file_lock_timeout = 100000)

    # keyring unlock
    if(!exists("pw")) {
      con_run <- configr::read.config(file = here::here("configRun.toml"))
      pw <- con_run$pw
    }

    keyring::keyring_unlock(keyring = 'apsd', password = pw)

    con <- apsdFuns::roracle_login(key_name = 'apsd', key_service = database, schema = 'maps')

    t1 = Sys.time()

    logr::log_print(paste0('Running ', species$ITIS_NAME[i], ' for Fishing Year ', FY))

    species_itis = species$ITIS_TSN[i]

    # flag allocated vs non-allocated ----
    # Halibut, Ocean Put, Woffish, Winodwpane are unallocated.

    allocated = ifelse(species_itis %in% c(172933, 630979, 171341, 172746), F, T)

    # add OBS_DISCARD column. Previously, this was done within the run_discard() step. 2/2/23 BG ----

    gf_dat = gf_dat %>%
      mutate(OBS_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE
                                     , TRUE ~ 0))

    # Support table import by species ----

    # GEAR TABLE
    CAMS_GEAR_STRATA = ROracle::dbGetQuery(con, 'select * from CFG_GEARCODE_STRATA') %>%
      dplyr::rename(GEARCODE = SECGEAR_MAPPED) %>%
      dplyr::filter(ITIS_TSN == species_itis) %>%
      dplyr::select(-NESPP3, -ITIS_TSN)

    # Stat areas table
    # unique stat areas for stock ID if needed
    STOCK_AREAS = ROracle::dbGetQuery(con, 'select * from CFG_STATAREA_STOCK') %>%
      dplyr::filter(ITIS_TSN == species_itis) %>%
      group_by(SPECIES_ESTIMATION_REGION, ITIS_TSN) %>%
      distinct(AREA) %>%
      mutate(AREA = as.character(AREA)) %>%
      ungroup()


    # Mortality table
    # TODO: This can become MAPS:::cfg_discard_mortality_stock once added to the config load
    CAMS_DISCARD_MORTALITY_STOCK = ROracle::dbGetQuery(con, "select * from CFG_DISCARD_MORTALITY_STOCK")  %>%
      mutate(GEARCODE = CAMS_GEAR_GROUP
             , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
      dplyr::filter(ITIS_TSN == species_itis) %>%
      dplyr::select(-ITIS_TSN)

    # swap underscores for hyphens where compound stocks exist ----
    STOCK_AREAS  = STOCK_AREAS |>
      mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '_', '-')) |>
      mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '_', '-'))

    CAMS_DISCARD_MORTALITY_STOCK = CAMS_DISCARD_MORTALITY_STOCK |>
      mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '_', '-'))


    # Observer codes to be removed
    OBS_REMOVE = ROracle::dbGetQuery(con, "select * from CFG_OBSERVER_CODES")  %>%
      dplyr::filter(ITIS_TSN == species_itis) %>%
      distinct(OBS_CODES)


    # make tables ----
    ddat_focal <- gf_dat %>%
      dplyr::filter(GF_YEAR == FY) %>%   ## time element is here!!
      dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
      mutate(FY_TYPE = FY_TYPE
             , FY = FY) %>%
      mutate(LIVE_POUNDS = SUBTRIP_KALL
             ,SEADAYS = 0
      ) %>%
      left_join(., y = STOCK_AREAS, by = 'AREA') %>%
      left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
      left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
                , by = c('SPECIES_ESTIMATION_REGION', 'CAMS_GEAR_GROUP')
      ) %>%
      dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
      dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x, DOCID = DOCID.x) %>%
      relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_ESTIMATION_REGION','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
      discaRd::assign_strata(., stratvars = stratvars)

    ddat_prev <- gf_dat %>%
      dplyr::filter(GF_YEAR == FY-1) %>%   ## time element is here!!
      dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
      mutate(FY_TYPE = FY_TYPE
             , FY = FY) %>%
      mutate(LIVE_POUNDS = SUBTRIP_KALL
             ,SEADAYS = 0
      ) %>%
      left_join(., y = STOCK_AREAS, by = 'AREA') %>%
      left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
      left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
                , by = c('SPECIES_ESTIMATION_REGION', 'CAMS_GEAR_GROUP')
      ) %>%
      dplyr::select( -GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
      dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
      relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_ESTIMATION_REGION','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
      discaRd::assign_strata(., stratvars = stratvars)

    # need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
    # need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!
    # Observed trips with NO obs hauls can be treated the same here. The assignment of DISCARD source happens at the end and contains the correct filtration criteria.

    ddat_focal_gf <- summarise_single_discard_row(data = ddat_focal, itis_tsn = species_itis)

    # and join to the unobserved trips ----

    ddat_focal_gf = ddat_focal_gf %>%
      union_all(ddat_focal %>%
                  dplyr::filter(is.na(LINK1))
      )


    # if using the combined catch/obs table, which seems necessary for groundfish. need to roll your own table to use with run_discard function
    # DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS.
    # fishdisp_exclude = c(39,90,98) |>
    #   stringr::str_pad(3, side = 'left', pad = 0)

    bdat_gf = ddat_focal %>%
      dplyr::filter(!is.na(LINK1)) %>%
      	dplyr::filter(FISHDISP != '090') %>%
        dplyr::filter(FISHDISP != '039') %>%
        dplyr::filter(FISHDISP != '098') %>%
      #dplyr::filter(FISHDISP %!in% fishdisp_exclude) |>
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
        dplyr::filter(FISHDISP != '039') %>%
        dplyr::filter(FISHDISP != '098') %>%
      # dplyr::filter(FISHDISP %!in% fishdisp_exclude) |>
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
                         , species_itis = species_itis
                         , stratvars = stratvars
                         , aidx = c(1:length(stratvars))
    )


    # Run the discaRd functions on current year ----
    d_focal = run_discard(bdat = bdat_gf
                          , ddat = ddat_focal_gf
                          , c_o_tab = ddat_focal
                          , species_itis = species_itis
                          , stratvars = stratvars
                          , aidx = c(1:length(stratvars))  # this makes sure this isn't used..
    )

    # summarize each result for convenience ----
    dest_strata_p = d_prev$allest$C %>% mutate(STRATA = STRATA
                                                  , N = N
                                                  , n = n
                                                  , orate = round(n/N, 2)
                                                  , drate = RE_mean
                                                  , KALL = K, disc_est = round(D)
                                                  , CV = round(RE_rse, 2)
    )|>
      select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

    dest_strata_f = d_focal$allest$C %>% mutate(STRATA = STRATA
                                                   , N = N
                                                   , n = n
                                                   , orate = round(n/N, 2)
                                                   , drate = RE_mean
                                                   , KALL = K, disc_est = round(D)
                                                   , CV = round(RE_rse, 2)
    )|>
      select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

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
      right_join(., y = ddat_focal_gf, by = 'STRATA') %>% # changed 2/15/23.. wrong table being joined!!
      as_tibble() %>%
      mutate(SPECIES_ITIS_EVAL = species_itis
             , COMNAME_EVAL = species$ITIS_NAME[i]
             , FISHING_YEAR = FY
             , FY_TYPE = FY_TYPE) %>%
      dplyr::rename(FULL_STRATA = STRATA)

    # check one row per species-subtrip-link1
    if(nrow(full_strata_table) !=
       full_strata_table |> dplyr::select(CAMSID, SUBTRIP, ITIS_TSN, LINK1) |> dplyr::distinct() |> nrow()) {
      warning("Duplicate rows in GF full_strata_table")
    }

    #
    # SECTOR ROLLUP: second pass ----

    stratvars_assumed = c("FY"
                          ,"FY_TYPE"
                          ,"SPECIES_ESTIMATION_REGION"
                          , "CAMS_GEAR_GROUP"
                          , "MESH_CAT"
                          , "SECTOR_TYPE")


    ### All tables in previous run can be re-used with diff stratification

    # Run the discaRd functions on previous year
    d_prev_pass2 = run_discard(bdat = bdat_prev_gf
                               , ddat = ddat_prev_gf
                               , c_o_tab = ddat_prev
                               , species_itis = species_itis
                               , stratvars = stratvars_assumed
                               , aidx = c(1)  # this creates an unstratified broad stock rate
    )


    # Run the discaRd functions on current year
    d_focal_pass2 = run_discard(bdat = bdat_gf
                                , ddat = ddat_focal_gf
                                , c_o_tab = ddat_focal
                                , species_itis = species_itis
                                , stratvars = stratvars_assumed
                                , aidx = c(1)  # this creates an unstratified broad stock rate
    )

    # summarize each result for convenience
    dest_strata_p_pass2 = d_prev_pass2$allest$C %>% mutate(STRATA = STRATA
                                                              , N = N
                                                              , n = n
                                                              , orate = round(n/N, 2)
                                                              , drate = RE_mean
                                                              , KALL = K, disc_est = round(D)
                                                              , CV = round(RE_rse, 2)
    )|>
      select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

    dest_strata_f_pass2 = d_focal_pass2$allest$C %>% mutate(STRATA = STRATA
                                                               , N = N
                                                               , n = n
                                                               , orate = round(n/N, 2)
                                                               , drate = RE_mean
                                                               , KALL = K, disc_est = round(D)
                                                               , CV = round(RE_rse, 2)
    )|>
      select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

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


    # broad stock rates using discaRd functions: third pass. ----
    # Previously we used sector rollup results (ARATE in pass2)

    stock_only = run_discard( bdat = bdat_gf
                              , ddat_focal = ddat_focal_gf
                              , c_o_tab = ddat_focal
                              , species_itis = species_itis
                              , stratvars = stratvars[1:3]
    )


    BROAD_STOCK_RATE_TABLE = stock_only$allest$C |>
      dplyr::select(STRATA, N, n, RE_mean, RE_rse) |>
      mutate(FY = as.numeric(sub("_.*", "", STRATA))
             , FY_TYPE = FY_TYPE) |>
      mutate(SPECIES_ESTIMATION_REGION = gsub("^([^_]+)_", "", STRATA)  |>
               gsub(pattern = "^([^_]+)_", replacement = "")  |>
               sub(pattern ="_.*", replacement ="")
             , CV_b = round(RE_rse, 2)
      ) |>
      dplyr::rename(BROAD_STOCK_RATE = RE_mean
                    , n_B = n
                    , N_B = N) |>

      dplyr::select(FY, FY_TYPE, SPECIES_ESTIMATION_REGION
                    , BROAD_STOCK_RATE, CV_b, n_B, N_B)

    # make names specific to the sector rollup pass

    names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')

    # join full and assumed strata tables ----

    joined_table = discaRd::assign_strata(full_strata_table, stratvars_assumed)

    if("STRATA_ASSUMED" %in% names(joined_table)) {
      joined_table = joined_table %>%
        dplyr::select(-STRATA_ASSUMED)   # not using this anymore here..
    }

    joined_table = joined_table %>%
      dplyr::rename(STRATA_ASSUMED = STRATA) %>%
      left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
      left_join(x =., y = BROAD_STOCK_RATE_TABLE, by = c('FY', 'FY_TYPE', 'SPECIES_ESTIMATION_REGION')) %>%
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

    # add discard source ----

    # >5 trips in season gets in season rate
    # < 5 i nseason but >=5 past year gets transition
    # < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
    # <5, <5,  and <5 gets broad stock rate

    joined_table = discaRd::assign_discard_source(joined_table, GF = 1)


    joined_table <- joined_table |>
      ungroup() |>
      as.data.frame() |>
      dplyr::mutate(CV = dplyr::case_when(DISCARD_SOURCE == 'O' ~ 0.0
                                          , DISCARD_SOURCE == 'I' ~ as.numeric(CV_f)
                                          , DISCARD_SOURCE == 'T' ~ as.numeric(CV_f)
                                          , DISCARD_SOURCE == 'A' ~ as.numeric(CV_f_a)
                                          , DISCARD_SOURCE == 'B' ~ as.numeric(CV_b),
                                          TRUE ~ NA_real_
      )
      ) |>
      as.data.frame()

    # Make note of the stratification variables used according to discard source ----

    strata_f = paste(stratvars, collapse = ';')
    strata_a = paste(stratvars_assumed, collapse = ';')
    strata_b = paste(stratvars[1:3], collapse = ';')

    joined_table = joined_table %>%
      mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' & LINK3_OBS == 1 ~ ''
                                     , DISCARD_SOURCE == 'O' & LINK3_OBS == 0 ~ strata_f
                                     , DISCARD_SOURCE == 'I' ~ strata_f
                                     , DISCARD_SOURCE == 'T' ~ strata_f
                                     , DISCARD_SOURCE == 'A' ~ strata_a
                                     , DISCARD_SOURCE == 'B' ~ strata_b
                                     , TRUE ~ NA_character_
      )
      )

    # get the discard for each trip using COAL_RATE ----

    # discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio.
    # the KALLs should be small..

    joined_table = joined_table %>%
      mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
      mutate(DISCARD = ifelse(DISCARD_SOURCE == 'O', DISC_MORT_RATIO*OBS_DISCARD # observed with at least one obs haul
                              , DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS) # all other cases

      )


    # add N, n, and covariance ----
    # now these steps are separate functions
    joined_table <- joined_table |>
      add_nobs() |>
      make_strata_desc() |>
      get_covrow() |>
      mutate(covrow = case_when(DISCARD_SOURCE =='N' ~ NA_real_
                                , TRUE ~ covrow))

    # substitute EM data on EM trips ----

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

    if(allocated == T ){

      mrem_idx = emjoin$EM == 'MREM' & emjoin$DISCARD_SOURCE != 'O'
      emjoin$STRATA_USED[mrem_idx] = 'RULE BASED'
      emjoin$DISCARD_SOURCE[mrem_idx] = 'R'
      emjoin$COAL_RATE[mrem_idx] = 0
      emjoin$DISCARD[mrem_idx] = 0
      emjoin$CV[mrem_idx] = NA
      emjoin$covrow[mrem_idx] = NA

    }

    # save trip by trip info to .fst file ----

    # force remove duplicates
    emjoin <- emjoin |>
      dplyr::distinct() %>%
      mutate(DISCARD_SOURCE = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 'N'
                                        ,TRUE ~ DISCARD_SOURCE)) %>%
      mutate(DISCARD = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 0.0
                                 ,TRUE ~ DISCARD))%>%
      mutate(CV = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ NA_real_
                            ,TRUE ~ CV)) |>
      mutate(covrow = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ NA_real_
                            ,TRUE ~ covrow))



    # replace hyphens with underscores to match the rest of CAMS ----

    emjoin = emjoin |>
      mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '-', '_')) |>
      mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '-', '_')) |>
      mutate(STRATA_USED_DESC = str_replace(STRATA_USED_DESC, '-', '_')) |>
      mutate(STRATA_USED = str_replace(STRATA_USED, '-', '_')) |>
      mutate(STRATA_USED_DESC = str_replace(STRATA_USED_DESC, '-', '_')) |>
      mutate(STRATA_ASSUMED = str_replace(STRATA_ASSUMED, '-', '_')) |>
      mutate(FULL_STRATA = str_replace(FULL_STRATA, '-', '_'))


    # add N, n, and covariance ----

    outfile = file.path(save_dir, paste0('discard_est_', species_itis, '_gftrips_only', FY,'.fst'))

    fst::write_fst(x = emjoin, path = file.path(save_dir, paste0('discard_est_', species_itis, '_gftrips_only', FY,'.fst')))

    system(paste("chmod 770 ", outfile))

    t2 = Sys.time()

    logr::log_print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

    DBI::dbDisconnect(con)

  }

  stopCluster(cl)

  unregister()

  if(gf_trips_only == F){

    # remove old objects so there is no chance of interference..

    rm(list = ls()[grepl(x = ls(), 'ddat*')])
    rm(list = ls()[grepl(x = ls(), 'bdat*')])
    rm(list = ls()[grepl(x = ls(), 'd_f*')])
    rm(list = ls()[grepl(x = ls(), 'b_f*')])
    rm(list = ls()[grepl(x = ls(), 'dest*')])
    rm(list = ls()[grepl(x = ls(), 'trans*')])
    rm(list = ls()[grepl(x = ls(), 'strat*')])
    rm(list = ls()[grepl(x = ls(), 'mnk*')])
    rm(list = ls()[grepl(x = ls(), 'CAMS_GEAR*')])
    rm(list = ls()[grepl(x = ls(), 'BROAD*')])
    rm(list = ls()[grepl(x = ls(), 'STOCK_*')])


    ## ----loop through the non sector trips for each stock ----

    stratvars_nongf = c('FY'
                        , 'FY_TYPE'
                        , 'SPECIES_ESTIMATION_REGION'
                        ,'CAMS_GEAR_GROUP'
                        , 'MESH_CAT'
                        , 'TRIPCATEGORY'
                        , 'ACCESSAREA')

      ncores <- dplyr::case_when(
        config_run$load$type_run == "preprod" ~ min(length(unique(species$ITIS_TSN)), 3, parallel::detectCores() -1),
        TRUE ~ min(length(unique(species$ITIS_TSN)), 13, parallel::detectCores() -1)
      )

      cl2 <- makeCluster(ncores)
      registerDoParallel(cl2, cores = ncores)

      foreach(
        i = 1:length(species$ITIS_TSN),
        .export = c("pw", "database"),
        .noexport = "con",
        .packages = c("discaRd", "dplyr", "MAPS", "DBI", "ROracle", "apsdFuns", "keyring", "fst")
      ) %op% {

        if(!exists("pw")) {
          con_run <- configr::read.config(file = here::here("configRun.toml"))
          pw <- con_run$pw
        }

        options(keyring_file_lock_timeout = 100000)
        keyring::keyring_unlock(keyring = 'apsd', password = pw)
        con <- apsdFuns::roracle_login(key_name = 'apsd', key_service = database, schema = 'maps')

      t1 = Sys.time()

      logr::log_print(paste0('Running non-groundfish trips for ', species$ITIS_NAME[i], ' Fishing Year ', FY))

      # Add OBS_DISCARD for non-GF trips

      species_itis = species$ITIS_TSN[i]

      non_gf_dat = non_gf_dat %>%
        mutate(OBS_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE
                                       , TRUE ~ 0))


      #---#
      # Support table import by species

      # GEAR TABLE
      CAMS_GEAR_STRATA = ROracle::dbGetQuery(con, 'select * from CFG_GEARCODE_STRATA') %>%
        dplyr::rename(GEARCODE = SECGEAR_MAPPED) %>%
        dplyr::filter(ITIS_TSN == species_itis) %>%
        dplyr::select(-NESPP3, -ITIS_TSN)

      # Stat areas table
      # unique stat areas for stock ID if needed
      STOCK_AREAS = ROracle::dbGetQuery(con, 'select * from CFG_STATAREA_STOCK') %>%
        dplyr::filter(ITIS_TSN == species_itis) %>%
        group_by(SPECIES_ESTIMATION_REGION, ITIS_TSN) %>%
        distinct(AREA) %>%
        mutate(AREA = as.character(AREA)
               , SPECIES_ESTIMATION_REGION = SPECIES_ESTIMATION_REGION) %>%
        ungroup()


      # Mortality table
      CAMS_DISCARD_MORTALITY_STOCK = ROracle::dbGetQuery(con, "select * from CFG_DISCARD_MORTALITY_STOCK")  %>%
        mutate(GEARCODE = CAMS_GEAR_GROUP
               , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
        dplyr::filter(ITIS_TSN == species_itis) %>%
        dplyr::select(-ITIS_TSN)

      # swap underscores for hyphens where compound stocks exist ----
      STOCK_AREAS  = STOCK_AREAS |>
        mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '_', '-')) |>
        mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '_', '-'))

      CAMS_DISCARD_MORTALITY_STOCK = CAMS_DISCARD_MORTALITY_STOCK |>
        mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '_', '-'))

         # make tables
      ddat_focal <- non_gf_dat %>%
        dplyr::filter(GF_YEAR == FY) %>%   ## time element is here!!
        dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
        mutate(FY_TYPE = FY_TYPE
               , FY = FY) %>%
        mutate(LIVE_POUNDS = SUBTRIP_KALL
               ,SEADAYS = 0
        ) %>%
        left_join(., y = STOCK_AREAS, by = 'AREA') %>%
        left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
        left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
                  , by = c('SPECIES_ESTIMATION_REGION', 'CAMS_GEAR_GROUP')
        ) %>%
        dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
        dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
        relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_ESTIMATION_REGION','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
        discaRd::assign_strata(., stratvars = stratvars_nongf)

      ddat_prev <- non_gf_dat %>%
        dplyr::filter(GF_YEAR == FY-1) %>%   ## time element is here!!
        dplyr::filter(AREA %in% STOCK_AREAS$AREA) %>%
        mutate(FY_TYPE = FY_TYPE
               , FY = FY) %>%
        mutate(LIVE_POUNDS = SUBTRIP_KALL
               ,SEADAYS = 0
        ) %>%
        left_join(., y = STOCK_AREAS, by = 'AREA') %>%
        left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>%
        left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
                  , by = c('SPECIES_ESTIMATION_REGION', 'CAMS_GEAR_GROUP')
        ) %>%
        dplyr::select(-GEARCODE.y, -COMMON_NAME.y, -NESPP3.y) %>%
        dplyr::rename(GEARCODE = 'GEARCODE.x',COMMON_NAME = COMMON_NAME.x, NESPP3 = NESPP3.x) %>%
        relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_ESTIMATION_REGION','CAMS_GEAR_GROUP','DISC_MORT_RATIO') %>%
        discaRd::assign_strata(., stratvars = stratvars_nongf)


      # need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row..
      # need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!

      ddat_focal_non_gf <- summarise_single_discard_row(data = ddat_focal, itis_tsn = species_itis)

      # and join to the unobserved trips
      ddat_focal_non_gf = ddat_focal_non_gf %>%
        union_all(ddat_focal %>%
                    dplyr::filter(is.na(LINK1))
        )


      # Observer codes to be removed
      OBS_REMOVE = ROracle::dbGetQuery(con, "select * from CFG_OBSERVER_CODES")  %>%
        dplyr::filter(ITIS_TSN == species_itis) %>%
        distinct(OBS_CODES)

      # if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
      # DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS.

      bdat_non_gf = ddat_focal %>%
        dplyr::filter(!is.na(LINK1)) %>%
        	dplyr::filter(FISHDISP != '090') %>%
          dplyr::filter(FISHDISP != '039') %>%
          dplyr::filter(FISHDISP != '098') %>%
        #dplyr::filter(FISHDISP %!in% fishdisp_exclude) |>
        dplyr::filter(LINK3_OBS == 1) %>%
        dplyr::filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
        dplyr::filter(EM != 'MREM' | is.na(EM)) %>%
        mutate(DISCARD_PRORATE = DISCARD
               , OBS_AREA = AREA
               , OBS_HAUL_KALL_TRIP = OBS_KALL
               , PRORATE = 1)


      # set up trips table for previous year
      ddat_prev_non_gf <- summarise_single_discard_row(data = ddat_prev, itis_tsn = species_itis)

      ddat_prev_non_gf = ddat_prev_non_gf %>%
        union_all(ddat_prev %>%
                    dplyr::filter(is.na(LINK1))
        )


      # previous year observer data needed..

      bdat_prev_non_gf = ddat_prev %>%
        dplyr::filter(!is.na(LINK1)) %>%
        	dplyr::filter(FISHDISP != '090') %>%
          dplyr::filter(FISHDISP != '039') %>%
          dplyr::filter(FISHDISP != '098') %>%
        # dplyr::filter(FISHDISP %!in% fishdisp_exclude) |>
        dplyr::filter(LINK3_OBS == 1) %>%
        dplyr::filter(substr(LINK1, 1,3) %!in% OBS_REMOVE$OBS_CODES) %>%
        dplyr::filter(EM != 'MREM' | is.na(EM)) %>%
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
                           , aidx = c(1:2) # uses GEAR as assumed
      )


      # Run the discaRd functions on current year
      d_focal = run_discard(bdat = bdat_non_gf
                            , ddat = ddat_focal_non_gf
                            , c_o_tab = ddat_focal
                            , species_itis = species_itis
                            , stratvars = stratvars_nongf
                            , aidx = c(1:2) # uses GEAR as assumed
      )

      # summarize each result for convenience
      dest_strata_p = d_prev$allest$C %>% mutate(STRATA = STRATA
                                                    , N = N
                                                    , n = n
                                                    , orate = round(n/N, 2)
                                                    , drate = RE_mean
                                                    , KALL = K, disc_est = round(D)
                                                    , CV = round(RE_rse, 2)
      )|>
        select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

      dest_strata_f = d_focal$allest$C %>% mutate(STRATA = STRATA
                                                     , N = N
                                                     , n = n
                                                     , orate = round(n/N, 2)
                                                     , drate = RE_mean
                                                     , KALL = K, disc_est = round(D)
                                                     , CV = round(RE_rse, 2)
      ) |>
        select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

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
        right_join(., y = ddat_focal_non_gf, by = 'STRATA') %>% # changed 2/15/23.. wrong table being joined!!
        as_tibble() %>%
        mutate(SPECIES_ITIS_EVAL = species_itis
               , COMNAME_EVAL = species$ITIS_NAME[i]
               , FISHING_YEAR = FY
               , FY_TYPE = FY_TYPE) %>%
        dplyr::rename(FULL_STRATA = STRATA)

      # GEAR AND MESH_CAT STRATA (2nd pass)

      stratvars_assumed = c("FY"
                            , "FY_TYPE"
                            , "SPECIES_ESTIMATION_REGION"
                            , "CAMS_GEAR_GROUP"
                            , "MESH_CAT")


      ### All tables in previous run can be re-used wiht diff stratification

      # Run the discaRd functions on previous year
      d_prev_pass2 = run_discard(bdat = bdat_prev_non_gf
                                 , ddat = ddat_prev_non_gf
                                 , c_o_tab = ddat_prev
                                 , species_itis = species_itis
                                 , stratvars = stratvars_assumed
                                 , aidx = c(1)  # this creates an unstratified broad stock rate
      )


      # Run the discaRd functions on current year
      d_focal_pass2 = run_discard(bdat = bdat_non_gf
                                  , ddat = ddat_focal_non_gf
                                  , c_o_tab = ddat_focal
                                  , species_itis = species_itis
                                  , stratvars = stratvars_assumed
                                  , aidx = c(1)  # this creates an unstratified broad stock rate
      )

      # summarize each result for convenience
      dest_strata_p_pass2 = d_prev_pass2$allest$C %>% mutate(STRATA = STRATA
                                                                , N = N
                                                                , n = n
                                                                , orate = round(n/N, 2)
                                                                , drate = RE_mean
                                                                , KALL = K, disc_est = round(D)
                                                                , CV = round(RE_rse, 2)
      )|>
        select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

      dest_strata_f_pass2 = d_focal_pass2$allest$C %>% mutate(STRATA = STRATA
                                                                 , N = N
                                                                 , n = n
                                                                 , orate = round(n/N, 2)
                                                                 , drate = RE_mean
                                                                 , KALL = K, disc_est = round(D)
                                                                 , CV = round(RE_rse, 2)
      )|>
        select(STRATA, N, n, orate, drate, KALL, disc_est, CV)

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


      # get a table of broad stock rates using discaRd functions. Previously we used sector rollup results (ARATE in pass2)


      bdat_2yrs = bind_rows(bdat_prev_non_gf, bdat_non_gf)
      ddat_non_gf_2yr = bind_rows(ddat_prev_non_gf, ddat_focal_non_gf)
      ddat_2yr = bind_rows(ddat_prev, ddat_focal)

      gear_only = run_discard( bdat = bdat_2yrs
                               , ddat_focal = ddat_non_gf_2yr
                               , c_o_tab = ddat_2yr
                               , species_itis = species_itis
                              , stratvars = stratvars_nongf[1:4]

      )

      # broad rate table ----

      BROAD_STOCK_RATE_TABLE = gear_only$allest$C |>
        dplyr::select(STRATA, N, n, RE_mean, RE_rse) |>
        mutate(FY = as.numeric(sub("_.*", "", STRATA))
               , FY_TYPE = FY_TYPE) |>
        mutate(SPECIES_ESTIMATION_REGION = gsub("^([^_]+)_", "", STRATA)  |>
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
        dplyr::select(FY, FY_TYPE, SPECIES_ESTIMATION_REGION, CAMS_GEAR_GROUP, BROAD_STOCK_RATE, CV_b, n_B, N_B)


      names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')

      # join full and assumed strata tables
      joined_table = discaRd::assign_strata(full_strata_table, stratvars_assumed)

      if("STRATA_ASSUMED" %in% names(joined_table)) {
        joined_table = joined_table %>%
          dplyr::select(-STRATA_ASSUMED)   # not using this anymore here..
      }

      joined_table = joined_table %>%
        dplyr::rename(STRATA_ASSUMED = STRATA) %>%
        left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>%
        left_join(.,  y = BROAD_STOCK_RATE_TABLE, by = c('FY', 'FY_TYPE', 'SPECIES_ESTIMATION_REGION', 'CAMS_GEAR_GROUP')) %>%
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

      # add discard source

      # >5 trips in season gets in season rate
      # < 5 i nseason but >=5 past year gets transition
      # < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
      # <5, <5,  and <5 gets broad stock rate

      joined_table = discaRd::assign_discard_source(joined_table, GF = 0)

      # make sure CV type matches DISCARD SOURCE}

      # obs trips get 0, broad stock rate is NA



      joined_table = joined_table %>%
        mutate(CV = case_when(DISCARD_SOURCE == 'O' ~ 0
                              , DISCARD_SOURCE == 'I' ~ CV_f
                              , DISCARD_SOURCE == 'T' ~ CV_f
                              , DISCARD_SOURCE == 'GM' ~ CV_f_a
                              , DISCARD_SOURCE == 'G' ~ CV_b
        )
        )

      # Make note of the stratification variables used according to discard source

      stratvars_gear = c("FY"
                         ,"FY_TYPE"
                         ,"SPECIES_ESTIMATION_REGION"
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
                                       , TRUE ~ NA_character_
        )
        )


      # get the discard for each trip using COAL_RATE}

      # discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio.
      # the KALLs should be small..

      joined_table = joined_table %>%
        mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
        mutate(DISCARD = ifelse(DISCARD_SOURCE == 'O', DISC_MORT_RATIO*OBS_DISCARD # observed with at least one obs haul
                                , DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS) # all other cases

        )

      # force remove duplicates
      # add element for non-estimated discard gears
      joined_table <- joined_table |>
        dplyr::distinct()%>%
        mutate(DISCARD_SOURCE = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 'N'
                                          ,TRUE ~ DISCARD_SOURCE)) %>%
        mutate(DISCARD = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ 0.0
                                   ,TRUE ~ DISCARD))%>%
        mutate(CV = case_when(ESTIMATE_DISCARDS == 0 & DISCARD_SOURCE != 'O' ~ NA_real_
                              ,TRUE ~ CV))


      # add N, n, and covariance ----
      # now these steps are spearate functions
      joined_table <- joined_table |>
        add_nobs() |>
        make_strata_desc() |>
        get_covrow() |>
        mutate(covrow = case_when(DISCARD_SOURCE =='N' ~ NA_real_
                                  , TRUE ~ covrow))


      # swap hyphens for underscores to match trhe rest of CAMS..----

      joined_table = joined_table |>
        mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '-', '_')) |>
        mutate(SPECIES_ESTIMATION_REGION = str_replace(SPECIES_ESTIMATION_REGION, '-', '_')) |>
        mutate(STRATA_USED_DESC = str_replace(STRATA_USED_DESC, '-', '_')) |>
        mutate(STRATA_USED = str_replace(STRATA_USED, '-', '_')) |>
        mutate(STRATA_USED_DESC = str_replace(STRATA_USED_DESC, '-', '_')) |>
        mutate(STRATA_ASSUMED = str_replace(STRATA_ASSUMED, '-', '_')) |>
        mutate(FULL_STRATA = str_replace(FULL_STRATA, '-', '_'))


      outfile = file.path(save_dir, paste0('discard_est_', species_itis, '_non_gftrips', FY,'.fst'))

      fst::write_fst(x = joined_table, path = outfile)

      system(paste("chmod 770 ", outfile))

      t2 = Sys.time()

      logr::log_print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

      DBI::dbDisconnect(con)

    }

    parallel::stopCluster(cl2)

    unregister()

    ## ----estimate discards on scallop trips for each subACL stock using subroutine ----

    # do only the yellowtail and windowpane for scallop trips

    scal_gf_species = species %>%
      dplyr::filter(ITIS_TSN %in% c('172909', '172746'))


    con <- apsdFuns::roracle_login(key_name = 'apsd', key_service = database, schema = 'maps')

    for(i in 1:length(scal_gf_species$ITIS_TSN)){

      scallop_subroutine(FY = FY
                         , con = con
                         , scal_gf_species = scal_gf_species[i, ]
                         , non_gf_dat = non_gf_dat
                         , scal_trip_dir = file.path(save_dir, "scallop_groundfish")
      )
    }

    ## ----substitute scallop trips into non-gf trips ----

    for(i in 1:length(scal_gf_species$ITIS_TSN)){
      start_time = Sys.time()

      GF_YEAR_EVAL = FY  # change variable name to avoid self selection..

      logr::log_print(paste0('Adding scallop trip estimates of: ',  scal_gf_species$ITIS_NAME[i], ' for Groundfish Year ', GF_YEAR_EVAL))

      sp_itis = scal_gf_species$ITIS_TSN[i]

      # get only the non-gf trips for each species and fishing year
      gf_files = list.files(save_dir, pattern = paste0('discard_est_', sp_itis), full.names = T)
      gf_files = gf_files[grep(GF_YEAR_EVAL, gf_files)]
      gf_files = gf_files[grep('non_gf', gf_files)]

      # get list all scallop trips bridging fishing years
      scal_files = list.files(file.path(save_dir, "scallop_groundfish"), pattern = paste0('discard_est_', sp_itis, '_scal_trips_SCAL'), full.names = T)

      # read in files
      res_scal = lapply(as.list(scal_files), function(x) fst::read_fst(x))
      res_gf = lapply(as.list(gf_files), function(x) fst::read_fst(x))
      assign(paste0('outlist_df_scal'),  do.call(dplyr::bind_rows, res_scal))
      assign(paste0('outlist_df_',sp_itis,'_',GF_YEAR_EVAL),  do.call(rbind, res_gf))

      t1  = get(paste0('outlist_df_',sp_itis,'_',GF_YEAR_EVAL))

      t2 = get(paste0('outlist_df_scal'))	%>%
        dplyr::filter(GF_YEAR == GF_YEAR_EVAL)

      #### Replace indexing with rbind (7/27/23) -----
      #### NA handling was dropping any trip with no activity code!! need to keep those.. ----

      # drop an CAMS Subtrip in scallop run
      t1 = t1 |>
        filter(CAMSID %!in% t2$CAMSID & SUBTRIP %!in% t2$SUBTRIP)

      # and now replace
      t3 = t1 %>%
        bind_rows(t2)


      # force remove duplicates
      t3 <- t3 |>
        dplyr::distinct()

      # add N, n, and covariance ----

      # --- Overwrite the original non-gf with the new version including scallop replacement ----
      write_fst(x = t3, path = gf_files)

      system(paste("chmod 770 ", gf_files))

      end_time = Sys.time()

      logr::log_print(paste('Scallop subsitution took: ', round(difftime(end_time, start_time, units = "mins"),2), ' MINUTES',  sep = ''))

    }

  }
  system(paste("chmod 770 -R", save_dir))

}


