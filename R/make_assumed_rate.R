#' Make an assumed rate
#'
#'This function is meant to return fallback rates that are more general than a more specific stratification used in `make_bdat_focal`. The discard rates are generated directly to be subsequently substituted where needed. 
#'
#' @param bdat table of observed trips that can include (and should include) multiple years
#' @param year Year where discard estimate is needed
#' @param species_itis species of interest using SPECIES_ITIS code
#' @param stratvars Stratification variables. These must be columns available in `bdat`. Not case sensitive. Thiws should be a subset of those used in `make_bdat_focal`. 
#' 
#'
#' @return a tibbleS with STRATA, KALL (Kept All), BYCATCH (discard of species), dk (discard rate)
#' @export
#'
#' @examples
make_assumed_rate <- function(bdat
															# , year = 2019
															# , species_nespp3 = '802'
															, species_itis = '164712' # cod
															, stratvars = c('GEARTYPE','meshgroup')){
	require(rlang)
	
	stratvars = toupper(stratvars)
	
	assumed_discard <- make_bdat_focal(bdat
																		 # , year = 2019
																		 # , species_nespp3 = species_nespp3 
																		 , species_itis = species_itis
																		 , stratvars = stratvars
	)
	
	assumed_discard = assumed_discard %>% 
		dplyr::group_by( STRATA) %>% 
		# be careful here... max values already represented from bdat_focal. So, take the sum here
		dplyr::summarise(KALL = sum(KALL, na.rm = T), BYCATCH = sum(BYCATCH, na.rm = T)) %>% 
		mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>% 
		ungroup() %>% 
		mutate(dk = BYCATCH/KALL)
	
	assumed_discard
	
}