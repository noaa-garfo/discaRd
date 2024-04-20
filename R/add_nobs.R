
#' add_nobs
#' add number of observed subtrips according to the `DISCARD_SOURCE` used
#' `n` is number of obsereved subtrips used. This may cross fishing years in the case of Assumed (A) or transition rates (T). Gear only rates use two years of information so `n` for those is across two years (\year_{t} and \year_{t-1})
#' @param joined_table
#'
#' @return dataframe from input with additional columns for n_USED and N_USED
#' @author Benjamin Galuardi
#' @export
#'
#' @examples
#'
add_nobs <- function(joined_table){

# Go through each STRATA_USED and split out the columns used
sidx = joined_table %>%
  dplyr::filter(!(DISCARD_SOURCE %in% c('O', 'R', 'N'))) %>%
  dplyr::select(STRATA_USED, DISCARD_SOURCE) %>%
  dplyr::filter(!is.na(STRATA_USED)) |>
  distinct()


# addone = function(x,y){x+y}

joined_table =  joined_table |>
  mutate(n_obs_trips_p  = as.integer(n_obs_trips_p )
         , n_obs_trips_p_a  = as.integer(n_obs_trips_p_a)
  ) |>

  mutate(n_A2 = as.integer(n_obs_trips_f_a+n_obs_trips_p_a)
         , n_T = as.integer(n_obs_trips_f + n_obs_trips_p)
         , n_GM2 = as.integer(n_obs_trips_f_a + n_obs_trips_p_a)) |>

  mutate(n_USED = case_when(DISCARD_SOURCE == 'I' ~ as.integer(n_obs_trips_f)
                            , DISCARD_SOURCE == 'T' ~ n_T
                            , DISCARD_SOURCE == 'A'  ~ as.integer(n_obs_trips_f_a) # assumed (groundfish, second pass) &  n_obs_trips_f_a >= 5
                            , DISCARD_SOURCE == 'A' & n_obs_trips_f_a < 5  ~ n_A2 # assumed with transition (groundfish, second pass)  & n_obs_trips_p_a >= 5
                            , DISCARD_SOURCE == 'GM' & n_obs_trips_f_a >= 5 ~ as.integer(n_obs_trips_f_a) # Gear Mesh (non-groundfish, second pass)
                            , DISCARD_SOURCE == 'GM' & n_obs_trips_f_a < 5  ~ n_GM2 # Gear Mesh with transition (non-groundfish, second pass) &  n_obs_trips_p_a >= 5
                            , DISCARD_SOURCE == 'B' ~ as.integer(n_B)
                            , DISCARD_SOURCE == 'G' ~ as.integer(n_B)
                            , DISCARD_SOURCE == 'DELTA' ~ NA_integer_ # n_DELTA
                            , DISCARD_SOURCE == 'EM' ~ NA_integer_
                            , TRUE ~ NA_integer_

  ), .after = FULL_STRATA
  )


    # joined_table |>
    # assign_discard_source(GF = 0) |>
  # group_by(DISCARD_SOURCE,FED_OR_STATE)  |>
  #   filter(DISCARD_SOURCE == 'GM' & n_obs_trips_f_a  >= 5) |>
  #   # filter(n_obs_trips_f_a < 5 ) |>
  #   # filter(is.na(n_USED)) |>
  #   dplyr::select(n_obs_trips_f_a, n_obs_trips_p_a, CAMS_GEAR_GROUP, MESH_CAT, n_USED, n_GM2) |>   #
  #   distinct()
  #
  # # dplyr::summarise(max(n_USED, na.rm = T))
  #
  #
  # filter(DISCARD_SOURCE == 'GM') |>
  #   # filter(n_obs_trips_f_a < 5 ) |>
  #   filter(is.na(n_USED)) |>
  #   group_by(FED_OR_STATE) |>
  #   dplyr::select(n_obs_trips_f_a, n_obs_trips_p_a, CAMS_GEAR_GROUP, MESH_CAT, n_USED, n_GM2) |>  distinct()
  # #
  #
  #
  #   dplyr::select(n_USED, CAMS_GEAR_GROUP, MESH_CAT) |>
  #   distinct()



# Use the individual columns to group and tally unobs suntrips (N)

for(iloop in 1:nrow(sidx)){
  svars = str_split(sidx$STRATA_USED[iloop], ';')	%>% unlist()
  cidx = sapply(1:length(svars), function(x) which(colnames(joined_table) == svars[x]))

  dtype = sidx$DISCARD_SOURCE[iloop]

  N_name = paste('N', dtype, sep = '_')
  # n_name = paste('n', dtype, sep = '_')

  # STRATA_USED_DESC = c(joined_table[1,cidx])

  # N = number of total subtrips in strata
  # n = total observed subtrips in strata
  ntable = joined_table %>%
    dplyr::group_by_at(vars(all_of(cidx))) %>%
    dplyr::summarize(N = n_distinct(CAMS_SUBTRIP[is.na(LINK1)])  # This is number of unobs subtrips in strata in year_t
                     # , n = n_distinct(CAMS_SUBTRIP[!is.na(LINK1) & LINK3_OBS > 0])
                     ) %>%
    dplyr::rename({{N_name}} := N
                  # , {{n_name}} := n
                  )

  joined_table = joined_table %>%
    left_join(., ntable, by = svars )

}

# add columns so case_when doesn't crash

cols <- c(N_I = NA_integer_
          , N_GM = NA_integer_
          , N_G = NA_integer_
          , N_B = NA_integer_
          , N_A = NA_integer_
          , N_DELTA = NA_integer_
          , N_EM = NA_integer_
          , n_I = NA_integer_
          , n_GM = NA_integer_
          , n_G = NA_integer_
          , n_B =  NA_integer_
          , n_A = NA_integer_
          , n_DELTA = NA_integer_
          , n_EM = NA_integer_
)

joined_table = tibble::add_column(joined_table, !!!cols[setdiff(names(cols), names(joined_table))])

# join back to original table using STRATA_USED or DISCARD SOURCE

joined_table = joined_table %>%
  mutate(N_USED = dplyr::case_when(DISCARD_SOURCE == 'I' ~ N_I
                                   , DISCARD_SOURCE == 'T' ~ N_I
                                   , DISCARD_SOURCE == 'GM' ~ N_GM
                                   , DISCARD_SOURCE == 'G' ~ N_G
                                   , DISCARD_SOURCE == 'B' ~ N_B
                                   , DISCARD_SOURCE == 'A' ~ N_A
                                   , DISCARD_SOURCE == 'DELTA' ~ NA_integer_
                                   , DISCARD_SOURCE == 'EM' ~ NA_integer_
                                   , TRUE ~ NA_integer_
  )
  # , n_USED = dplyr::case_when(DISCARD_SOURCE == 'I' ~ n_I
  #                             , DISCARD_SOURCE == 'T' ~ n_I
  #                             , DISCARD_SOURCE == 'GM' ~ n_GM
  #                             , DISCARD_SOURCE == 'G' ~ n_G
  #                             , DISCARD_SOURCE == 'B' ~ n_B
  #                             , DISCARD_SOURCE == 'A' ~ n_A
  #                             , DISCARD_SOURCE == 'DELTA' ~ NA_integer_ # n_DELTA
  #                             , DISCARD_SOURCE == 'EM' ~ NA_integer_
  #                             , TRUE ~ NA_integer_
  # ) #n_EM
  )


# add Legaults covrow ----
# joined_table <- make_strata_desc(joined_table) # put this in the discard_generic, groundfish and herring functions and in diganostics


joined_table

}
