#' Get Observed trips for discard year
#' This function utilizes the DISCARD field in CAMS_OBS_CATCH. This value must be used for d/k calculations since it represents the observed part of a trip.
#' @param bdat table of observed trips that can include (and should include) multiple years
#' @param year Year where discard estimate is needed
#' @param species_itis species of interest using SPECIES ITIS code
#' @param stratvars Stratification variables. These must be columns available in `bdat`. Not case sensitive.
#'
#' @return a tibble with LINK1, CAMS_SUBTRIP, STRATA, KALL, BYCATCH. Kept all (KALL) is rolled up by CAMS_SUBTRIP (subtrip). BYCATCH is the observed discard of the species of interest.
#'
#' This table is used in `discaRd`
#'
#' the source table (bdat) is created outside of this function in SQL. It can be quite large so it is not done functionally here. See vignette (when it's available..)
#' @export
#'
#' @examples
make_bdat_focal <- function(bdat
														, species_itis = '164712' #cod
														, stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){

	require(rlang)

	stratvars = toupper(stratvars)



	bdat_focal = bdat %>%
		mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD)) %>%
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))


	bdat_focal = assign_strata(bdat_focal, stratvars = stratvars)


	bdat_focal <- bdat_focal %>%
		dplyr::group_by(LINK1
										, CAMSID
										, SUBTRIP
										, STRATA
		) %>%
		# be careful here... need to take the max values since they are repeated..
		dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T))# *max(PRORATE) take this part out! 4/27/22
										 , BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>%
		mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>%
		ungroup()

	bdat_focal

}
