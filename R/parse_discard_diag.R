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
                                 , FY_species = 2018
                                 , date_run = NULL){


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

     outlist <- joined_table %>%
        # lazy_dt() |> # doesn't work with paste in mutate
        dplyr::ungroup() |>
        dplyr::mutate(
          GF_STOCK_DEF = paste0(COMMON_NAME, '-', SPECIES_ESTIMATION_REGION)
          , SUBTRIP = stringr::str_extract(CAMS_SUBTRIP, "[^_]*$")
        ) %>%
        


        dplyr::select(-SPECIES_ITIS, -ITIS_TSN) %>%
        dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
                      , 'CAMS_DISCARD_RATE' = 'COAL_RATE'
                      , 'CAMS_DISCARD' = 'DISCARD'
                      , 'ITIS_TSN' = 'SPECIES_ITIS_EVAL'
                      , 'ACTIVITY_CODE' = 'ACTIVITY_CODE_1'
                      , 'N_OBS_TRIPS_F' = 'n_obs_trips_f'
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
          , SPECIES_ESTIMATION_REGION
          , SECGEAR_MAPPED
          , NEGEAR
          , CAMS_GEAR_GROUP
          , MESH_CAT
          , SCALLOP_AREA
        ) |>
        as.data.frame()

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
