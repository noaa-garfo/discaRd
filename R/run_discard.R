#' Run discaRd end to end
#'
#' @param bdat table of observed trips that can include (and should include) multiple years
#' @param ddat_focal table of observed trips for discard year
#' @param c_o_tab matched table of observed and commerical trips
#' @param year year where discard is needed
#' @param species_itis species of interest using SPECIES_ITIS code
#' @param stratvars stratification variables desired
#' @param aidx subset of `stratvars` for a simplified stratification.
#'
#' @return a list of: 
#' 1) Species, 
#' 2) discaRd results (summary table, CV, etc), 
#' 3)Complete table of commercial trips and discard amounts
#' @export
#'
#' @examples
run_discard <- function(bdat
												, ddat_focal
												, c_o_tab = c_o_dat2
												# , year = 2019
												# , species_nespp3 = '802'
												, species_itis = '164712'  # cod
												, stratvars = c('GEARTYPE','meshgroup','region','halfofyear')
												, aidx = c(1,2)
){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	
	stratvars = toupper(stratvars)
	
	ddat_focal = assign_strata(ddat_focal, stratvars = stratvars)
	c_o_tab = assign_strata(c_o_tab, stratvars = stratvars)
	
	# bdat = make_bdat_cams(obstab, species_nespp3 = species_nespp3)
	bdat_focal = make_bdat_focal(bdat
															 # , year = year
															 # , species_nespp3 = species_nespp3
															 , species_itis = species_itis
															 , stratvars = stratvars
	)
	obs_discard = get_obs_disc_vals(c_o_tab
																	# , species_nespp3 = species_nespp3
																	, species_itis = species_itis
																	# , year = year
																	# , stratvars = stratvars
	)
	assumed_discard = make_assumed_rate(bdat
																			# , year = year
																			, stratvars = stratvars[aidx]
	)
	
	# Get complete strata
	strata_complete = unique(c(bdat_focal$STRATA, ddat_focal$STRATA))
	
	allest = get.cochran.ss.by.strat(bydat = bdat_focal
																	 , trips = ddat_focal
																	 , strata_name = 'STRATA'
																	 , targCV = .3
																	 , strata_complete = strata_complete
	)		
	
	# discard rates by strata
	dest_strata = allest$C %>% summarise(STRATA = STRATA
																			 , N = N
																			 , n = n
																			 , orate = round(n/N, 2)
																			 , drate = RE_mean
																			 , KALL = K, disc_est = round(D)
																			 , CV = round(RE_rse, 2)
	)
	
	# plug in estimated rates to the unobserved
	ddat_rate = ddat_focal
	ddat_rate$DISC_RATE = dest_strata$drate[match(ddat_rate$STRATA, dest_strata$STRATA)]	
	ddat_rate$CV = dest_strata$CV[match(ddat_rate$STRATA, dest_strata$STRATA)]	
	
	
	# substitute assumed rate where we can
	# assumed_discard = assumed_discard %>% 
	# 	mutate(STRATA = paste(GEARTYPE, MESHGROUP, sep = '_'))
	# # mutate(STRATA = paste(NEGEAR, MESHGROUP, sep = '_'))
	
	
	
	ddat_rate <- ddat_rate %>% 
		mutate(STRATA_ASSUMED = eval(parse(text = stratvars[aidx[1]])))
	
	if(length(aidx) > 1 ){
		
		for(i in 2:length(aidx)){
			
			ddat_rate <- ddat_rate %>% 
				mutate(STRATA_ASSUMED = paste(STRATA_ASSUMED, eval(parse(text = stratvars[aidx[i]])), sep = '_'))
		}
		
	}
	
	
	ddat_rate = ddat_rate %>% 
		# mutate(STRATA_ASSUMED = paste(GEARTYPE, MESHGROUP, sep = '_')) %>% 
		# mutate(STRATA = paste(NEGEAR, MESHGROUP, sep = '_'))
		mutate(ARATE_IDX = match(STRATA_ASSUMED, assumed_discard$STRATA)) 
	
	# ddat_rate$ARATE_IDX[is.na(ddat_rate$ARATE_IDX)] = 0
	ddat_rate$ARATE = assumed_discard$dk[ddat_rate$ARATE_IDX]
	
	
	# incorporate teh assumed rate into the calculated discard rates
	ddat_rate <- ddat_rate %>% 
		mutate(CRATE = coalesce(DISC_RATE, ARATE)) %>%
		mutate(CRATE = tidyr::replace_na(CRATE, 0)) 
	
	
	# merge observed discards with estimated discards
	# Use the observer tables created, NOT the merged trips/obs table.. 
	# match on VTRSERNO? 
	
	out_tab = obs_discard %>%
		ungroup() %>%
		mutate(OBS_DISCARD = DISCARD) %>%
		dplyr::select(VTRSERNO, CAMSID, OBS_DISCARD) %>%
		right_join(x = ., y = ddat_rate, by = c('VTRSERNO', 'CAMSID')) %>%   # need to drop a column or it gets DISCARD.x
		mutate(OBS_DISCARD = ifelse(is.na(OBS_DISCARD) & !is.na(LINK1), 0,  OBS_DISCARD)) %>%
		mutate(EST_DISCARD = CRATE*LIVE_POUNDS) %>%
		mutate(DISCARD = if_else(!is.na(OBS_DISCARD), OBS_DISCARD, EST_DISCARD)
		)
	
	list(species = species_itis #species_nespp3
			 , allest = allest
			 , res = out_tab
	)
	
}