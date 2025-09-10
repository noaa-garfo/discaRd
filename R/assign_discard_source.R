#' Assign Discard Source
#' this is an internal function that assigns DISCARD_SOURCE. IT is explcitly designed to account for situations where there is an observed trip with no observed hauls.
#'
#' @param jtable joined table created during the discard run
#' @param GF 0/1 denoting groundfish trips or not. Groundfish trips have a different set of DISCARD_SOURCE
#'
#' @return data frame (joined_table in discard run)
#' @export
#'
#' @examples
assign_discard_source <- function(jtable, GF = 1){
if(GF ==1){
jtable = jtable %>%
  mutate(CAMSID_SUBTRIP = paste(CAMSID,SUBTRIP,sep = "_")) |>
  mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 0 ~ 'O'  # observed with at least one obs haul and no offwatch hauls on trip
                                    , !is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 1 ~ 'O'  # observed with at least one obs haul
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
                                      n_obs_trips_p_a >= 5 ~ 'A' # Assumed means Sector, Gear, Mesh, transition rate
                                    , is.na(LINK1) &
                                      n_obs_trips_f < 5 &
                                      n_obs_trips_p < 5 &
                                      n_obs_trips_f_a < 5 &
                                      n_obs_trips_p_a < 5 ~ 'B'  # Broad stock is only for GF now
  )
  )

tab1 = jtable %>%
  filter(!is.na(LINK1) & LINK3_OBS == 0 & DISCARD_SOURCE == 'I')

tab1_cams_subtrip = unique(tab1$CAMSID_SUBTRIP)

tab1 = tab1 %>%
  mutate(DISCARD_SOURCE = case_when(  n_obs_trips_f >= 5 ~ 'I'
                                    , n_obs_trips_f < 5 &
                                      n_obs_trips_p >=5 ~ 'T' # T only applies to full in-season strata
                                    , n_obs_trips_f < 5 &
                                      n_obs_trips_p < 5 &
                                      n_obs_trips_f_a >= 5 ~ 'A' # Assumed means Sector, Gear, Mesh
                                    , n_obs_trips_f < 5 &
                                      n_obs_trips_p < 5 &
                                      n_obs_trips_f_a < 5 &
                                      n_obs_trips_p_a >= 5 ~ 'A' # Assumed means Sector, Gear, Mesh, transition rate
                                    , n_obs_trips_f < 5 &
                                      n_obs_trips_p < 5 &
                                      n_obs_trips_f_a < 5 &
                                      n_obs_trips_p_a < 5 ~ 'B'  # Broad stock is only for GF now
  )
  )

tab2 = jtable %>%
  filter(CAMSID_SUBTRIP %!in% tab1_cams_subtrip)

tab2 = tab2 %>%
  bind_rows(., tab1)
}

if(GF == 0) {
  jtable = jtable %>%
    mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 0 ~ 'O'  # observed with at least one obs haul and no offwatch hauls on trip
                                      , !is.na(LINK1) & LINK3_OBS == 1 & OFFWATCH_LINK1 == 1 ~ 'O'  # observed with at least one obs haul
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
                                        n_obs_trips_f_a < 5 &
                                        n_obs_trips_p_a >= 5 ~ 'GM' # Gear and Mesh transition
                                      , is.na(LINK1) &
                                        n_obs_trips_f < 5 &
                                        n_obs_trips_p < 5 &
                                        n_obs_trips_f_a < 5 &
                                        n_obs_trips_p_a < 5 ~ 'G') # Gear only replaces broad stock for non-GF
           ) # Gear only, replaces broad stock for non-GF

  tab1 = jtable %>%
    filter(!is.na(LINK1) & LINK3_OBS == 0 & DISCARD_SOURCE == 'I')

  tab1_cams_subtrip = unique(tab1$CAMSID_SUBTRIP)

  tab1 = tab1 %>%
  mutate(DISCARD_SOURCE = case_when(  n_obs_trips_f >= 5 ~ 'I'
                                     , n_obs_trips_f < 5 &
                                       n_obs_trips_p >=5 ~ 'T' # this only applies to in-season full strata
                                     , n_obs_trips_f < 5 &
                                       n_obs_trips_p < 5 &
                                       n_obs_trips_f_a >= 5 ~ 'GM' # Gear and Mesh, replaces assumed for non-GF
                                     , n_obs_trips_f < 5 &
                                       n_obs_trips_p < 5 &
                                       n_obs_trips_f_a < 5 &
                                       n_obs_trips_p_a >= 5 ~ 'GM' # Gear and Mesh transition
                                     , n_obs_trips_f < 5 &
                                       n_obs_trips_p < 5 &
                                       n_obs_trips_f_a < 5 &
                                       n_obs_trips_p_a < 5 ~ 'G')  # Gear only replaces broad stock for non-GF
    )

  tab2 = jtable %>%
    filter(CAMSID_SUBTRIP %!in% tab1_cams_subtrip)

  tab2 = tab2 %>%
    bind_rows(., tab1)

}

tab2

}
