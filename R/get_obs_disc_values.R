#' Get Observed Discards
#'
#' This function is used to get observed discard values on observed trips. These values are used in place of estimated values for those trips that were observed. This is done at the the sub-trip level. 
#' This function does not need stratification. Only VTR serial number and an observed discard for desired species
#' This function utilizes the DISCARD_PRORATE field in CAMS_OBS_CATCH. This value must be used for assigning observed discard to trips. It is NOT used for d/k calculations since it is pro-rated by unobserved KALL. 
#' @param c_o_tab table of matched observer and commercial trips
#' @param species_itis species of interest using SPECIES_ITIS code
#' @return a tibble with: YEAR, VTRSERNO, GEARTYPE, MESHGROUP,KALL, DISCARD, dk
#' The stratification variables don't matter so much as the assignment of discard is done using VTR Serial Number.  
#' @export
#'
#' @examples
#' 
get_obs_disc_vals <- function(c_o_tab = c_o_dat2
															# , species_nespp3 = '802'
															, species_itis = '164712'){
	
	codat = c_o_tab %>% 
		# filter(NESPP3 == species_nespp3) %>%
		filter(SPECIES_ITIS == species_itis) %>% 
		# mutate(SPECIES_DISCARD = case_when(NESPP3 == species_nespp3 ~ DISCARD))
		mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE)) 
	
	obs_discard = codat %>% 
		group_by(CAMS_SUBTRIP #VTRSERNO, CAMSID  # changed 10/3/22 BG
						 # , NEGEAR
						 # , STRATA
		) %>% 
		dplyr::summarise(DISCARD = sum(SPECIES_DISCARD, na.rm = T))
	
	obs_discard
	
}