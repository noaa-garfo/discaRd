#' Get covrow
#' Get total number of trips (N) and observed trips (n) in a strata
#' Get the row-based covariance based on Chris Legault's equations/markdown
#' @author Benjamin Galuardi, Chris Legault, Daniel Hocking
#' @param joined_table table produced during run_discard or from discard_diagnostic
#'
#' @return data frame of trips and discards
#' @export
#'
#' @examples
#'
#' # all discard_sources

#' R no
#' I yes
#' EM yes
#' N no
#' O no
#' B yes
#' A yes
#' DELTA yes
#' T yes
#' GM yes
#' G yes
#'  # example
#'
#' # first, run discard_diagnostic for any species
#' joined_table = mydiscard$trips_discard
#'
#' Ntable = get_covrow(joined_table)
#'
#' # Take a look
#' joined_table %>%
#' 	dplyr::select(starts_with('N_') | starts_with('n_') | DISCARD_SOURCE |  CAMS_GEAR_GROUP | SPECIES_ESTIMATION_REGION | MESH_CAT | TRIPCATEGORY | ACCESSAREA) %>%
#' 	distinct() %>%
#' 	View()
#'
#' # check sums
#' joined_table %>%
#' 	filter(DISCARD_SOURCE == 'I') %>%
#' 	group_by(STRATA_USED_DESC) %>%
#' 	dplyr::summarise(trip_var_total = sum(var, na.rm = T)
#' 									 # , strata_var = max(VAR_RATE_STRATA, na.rm = T)
#' 									 , CV_STRATA = max(CV, na.rm = T)
#' 									 , N_USED = max(N_USED, na.rm = T)
#' 									 , n_used = max(n_USED, na.rm = T)
#' 	) %>%
#' 	View()
#'
#'
get_covrow <- function(joined_table){

  options(dplyr.summarise.inform = FALSE)

  # Legaults covrow ----
  joined_table = joined_table %>%
    mutate(var = (DISCARD * CV)^2)

  mysdsum <- joined_table %>%
    group_by(STRATA_USED_DESC) %>%
    dplyr::summarise(sdsum = sum(sqrt(var), na.rm = T))

  joined_table <- joined_table %>%
    left_join(., mysdsum, by = 'STRATA_USED_DESC') %>%
    mutate(covrow = sqrt(var) * sdsum)

  joined_table

}

