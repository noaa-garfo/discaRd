#' Parse Discard Table for Diagnostics
#' Parses discard results, cleans the table (e.g. infinite).
#'
#'
#' @param FY Fishing Year run
#' @param joined_table data framesourced from diagnostic discard run. This table is an intermediary table that must be processed before uploadeing to `CAMS_DISCARD_ALL_YEARS`
#' @param gf_only logical
#' @param date_run either NULL or a specific date object. If `NULL`, it defaults to the date the function was run
#'
#' @return a data frame with columns corresponding to `CAMS_DISCARD_ALL_YEARS`
#' @export
#'
#' @examples

parse_discard_diag <- function(joined_table
                                 # , filepath = getOption("maps.discardsPath")
                                 , FY_species = 2018
                                 # , gf_only = F
                                 , date_run = NULL){

  # require(ROracle)

  if(is.null(date_run)) {
    date_run <- Sys.Date()
  }
  if(class(date_run) != "Date") {
    date_run <- as.Date(date_run)
  }
  if(class(date_run) != "Date") {
    date_run <- Sys.Date()
  }

  t1 = Sys.time()


  # assign('resfiles', list.files(path = filepath, pattern = paste0(FY,'.fst'), full.names = T))

  # drop ones containing scal_trips_SCAL because they are already added into non_gftrips for those species. Maybe move to their own folder.

  # species = lapply(stringr::str_split(resfiles, pattern = '_'), function(x) x[3]) %>%
  #   unlist %>%
  #   unique


    # # setDTthreads(threads = 5)
    # options(keyring_file_lock_timeout = 100000)
    # keyring::keyring_unlock(keyring = 'apsd', password = pw)
    # con <- apsdFuns::roracle_login(key_name = 'apsd', key_service = database, schema = 'maps')
    #



    # spfiles = resfiles[grep(pattern = kk, x = resfiles)]

    # if(gf_only ==T){
    #
    #   spfiles = spfiles[grep(pattern = 'gftrips_only', x = spfiles)]
    #
    # }

    # vectorize over mulitple files for a year for the same species
    # res = lapply(as.list(spfiles), function(x) fst::read_fst(x))


     outlist <- joined_table %>%
        # lazy_dt() |> # doesn't work with paste in mutate
        dplyr::ungroup() |>
        dplyr::mutate(
          GF_STOCK_DEF = paste0(COMMON_NAME, '-', SPECIES_STOCK)
          , SUBTRIP = stringr::str_extract(CAMS_SUBTRIP, "[^_]*$")
        ) %>%
        # dplyr::select(COMMON_NAME, SPECIES_STOCK, GF_STOCK_DEF, SUBTRIP)
        dplyr::select(-SPECIES_ITIS, -ITIS_TSN) %>%
        # dplyr::select(-COMMON_NAME, -SPECIES_ITIS) %>%
        dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
                      , 'CAMS_DISCARD_RATE' = 'COAL_RATE'
                      , 'CAMS_DISCARD' = 'DISCARD'
                      # , 'COMMON_NAME' = 'COMNAME_EVAL'
                      , 'ITIS_TSN' = 'SPECIES_ITIS_EVAL'
                      , 'ACTIVITY_CODE' = 'ACTIVITY_CODE_1'
                      , 'N_OBS_TRIPS_F' = 'n_obs_trips_f'
                      # , 'CV_I_T' ='CV_f'
                      , 'CV_S_GM' ='CV_f_a'
                      , 'CV_G' ='CV_b'
                      , 'DISCARD_RATE_S_GM' = 'trans_rate_a'
                      , 'DISCARD_RATE_G' = 'BROAD_STOCK_RATE'
                      , 'CAMS_CV' = 'CV'
                      , 'SECGEAR_MAPPED' = 'GEARCODE'
        ) %>%
        mutate(DATE_RUN = date_run
               , FY = as.integer(FY_species)
               , CAMS_DISCARD_VARIANCE = round(covrow, 4) #
               , N_UNOBSERVED = N_USED - n_USED
               , N_OBSERVED = n_USED
               , STRATA_USED = dplyr::case_when(
                 DISCARD_SOURCE %in% c('N', 'R', 'EM', 'DELTA', 'O') ~ NA_character_,
                 STRATA_USED == "NA" ~ NA_character_,
                 TRUE ~ STRATA_USED
               )
               , STRATA_USED_DESC = dplyr::case_when(
                 DISCARD_SOURCE %in% c('N', 'R', 'EM', 'DELTA', 'O') ~ NA_character_,
                 STRATA_USED_DESC == "NA" ~ NA_character_,
                 TRUE ~ STRATA_USED_DESC
               )
               , N_OBSERVED = dplyr::case_when(
                 DISCARD_SOURCE %in% c('N', 'R', 'EM', 'DELTA', 'O') ~ NA_integer_,
                 TRUE ~ N_OBSERVED
               )
               , N_UNOBSERVED = dplyr::case_when(
                 DISCARD_SOURCE %in% c('N', 'R', 'EM', 'DELTA', 'O') ~ NA_integer_,
                 TRUE ~ N_UNOBSERVED
               )
        ) %>%
        #     dplyr::rename_all(.funs = toupper)
        #
        # |>
        dplyr::select(
          DATE_RUN
          , FY
          , DATE_TRIP
          , YEAR
          , ITIS_TSN
          , COMMON_NAME
          , FY_TYPE
          , CAMSID
          , SUBTRIP
          , GF
          , AREA
          , LINK1
          , OFFWATCH_LINK1
          , LINK3_OBS
          # , N_OBS_TRIPS_F
          , STRATA_USED
          , STRATA_USED_DESC
          , STRATA_FULL
          , STRATA_ASSUMED
          , DISCARD_SOURCE
          , OBS_DISCARD
          , OBS_KALL
          , SUBTRIP_KALL
          , CAMS_DISCARD_RATE
          , DISCARD_RATE_S_GM
          , DISCARD_RATE_G
          , CAMS_CV
          , CV_S_GM
          , CV_G
          , DISC_MORT_RATIO
          , CAMS_DISCARD
          , CAMS_DISCARD_VARIANCE
          , N_UNOBSERVED
          , N_OBSERVED
          , SPECIES_STOCK
          , SECGEAR_MAPPED
          , NEGEAR
          , CAMS_GEAR_GROUP
          , MESH_CAT
          , SCALLOP_AREA
          # eval(strata_unique)
        ) |>
        as.data.frame()
      # add left join run_id

      # if(i == 1) {
        # outlist <- tmp
      # } else {
      #   outlist <- outlist |>
      #     # lazy_dt() |>  # causes error in loop
      #     dplyr::bind_rows(tmp) |>
      #     as.data.frame()
      # }
    # }

    # convert list to data frame
    # outlist = do.call(rbind, outlist)

    # adjust for DISACRD_SOURCE = N, nan and infinite values

    outlist <- outlist %>%
      dplyr::mutate(
        DISCARD_SOURCE = case_when(
          is.na(CAMS_DISCARD) ~ 'N'
          , TRUE ~ DISCARD_SOURCE
        )
      ) %>%
      dplyr::mutate(
        STRATA_USED = case_when(
          is.na(CAMS_DISCARD) ~ NA_character_
          , DISCARD_SOURCE == 'N' ~ NA_character_
          , STRATA_USED == 'NA' ~ NA_character_
          , TRUE ~ STRATA_USED
        )
      ) %>%
      dplyr::mutate(
        STRATA_USED_DESC = case_when(
          is.na(CAMS_DISCARD) ~ NA_character_
          , DISCARD_SOURCE == 'N' ~ NA_character_
          , STRATA_USED_DESC == 'NA' ~ NA_character_
          , TRUE ~ STRATA_USED_DESC
        )
      )

    outlist$CAMS_CV[is.nan(outlist$CAMS_CV)] <- NA_real_
    outlist$CAMS_CV[is.infinite(outlist$CAMS_CV)] <- NA_real_

    # outlist$CV_I_T[is.nan(outlist$CV_I_T)]<-NA
    # outlist$CV_I_T[is.infinite(outlist$CV_I_T)] <- NA

    outlist$CV_S_GM[is.nan(outlist$CV_S_GM)]<-NA_real_
    outlist$CV_S_GM[is.infinite(outlist$CV_S_GM)] <- NA_real_

    outlist$CV_G[is.nan(outlist$CV_G)]<-NA_real_
    outlist$CV_G[is.infinite(outlist$CV_G)] <- NA_real_

    outlist$CAMS_DISCARD_RATE[is.nan(outlist$CAMS_DISCARD_RATE)] <- NA_real_
    outlist$CAMS_DISCARD_RATE[is.infinite(outlist$CAMS_DISCARD_RATE)] <- NA_real_

    outlist$DISCARD_RATE_G[is.nan(outlist$DISCARD_RATE_G)]<-NA_real_
    outlist$DISCARD_RATE_G[is.infinite(outlist$DISCARD_RATE_G)] <- NA_real_

    outlist$DISCARD_RATE_S_GM[is.nan(outlist$DISCARD_RATE_S_GM)] <- NA_real_
    outlist$DISCARD_RATE_S_GM[is.infinite(outlist$DISCARD_RATE_S_GM)] <- NA_real_

    outlist$CAMS_DISCARD[is.nan(outlist$CAMS_DISCARD)] <- NA_real_
    outlist$CAMS_DISCARD[is.infinite(outlist$CAMS_DISCARD)] <- NA_real_

    outlist$CAMS_DISCARD_VARIANCE[is.nan(outlist$CAMS_DISCARD_VARIANCE)] <- NA_real_
    outlist$CAMS_DISCARD_VARIANCE[is.infinite(outlist$CAMS_DISCARD_VARIANCE)] <- NA_real_

    outlist$N_UNOBSERVED[is.nan(outlist$CAMS_DISCARD_VARIANCE)] <- NA
    outlist$N_UNOBSERVED[is.infinite(outlist$CAMS_DISCARD_VARIANCE)] <- NA

    outlist$N_OBSERVED[is.nan(outlist$N_OBSERVED)] <- NA
    outlist$N_OBSERVED[is.infinite(outlist$N_OBSERVED)] <- NA

    dplyr::as_tibble(outlist)

}
