#----------------------------------------------------------------#
# functions for CAMS disacRd
#----------------------------------------------------------------#

require(dplyr)
require(tidyr)


#' Assign Strata
#' uses text input to coalesce variables to a STRATA column
#' @param dat catch or observation input
#' @param stratvars variables in `dat` to coalesce
#'
#' @return a data frame (dat) with a `STRATA` column
#' @export
#'
#' @examples
assign_strata <- function(dat, stratvars){
  stratvars = toupper(stratvars)
  
  dat <- dat %>% 
    mutate(STRATA = eval(parse(text = stratvars[1])))
  
  if(length(stratvars) >1 ){
    
    for(i in 2:length(stratvars)){
      
      dat <- dat %>% 
        mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
    }
    
  }
  dat
}

#' Get Observed Discards
#'
#' This function is used to get observed discard values on observed trips. These values are used in place of estimated values for those trips that were observed. This is done at the the sub-trip level. 
#' This function does not need startification. Only VTR serial number and an observed discard for desired species
#' @param c_o_tab table of matched observer and commerical trips
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
    mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD))
  
  obs_discard = codat %>% 
    group_by(VTRSERNO
             # , NEGEAR
             # , STRATA
    ) %>% 
    dplyr::summarise(DISCARD = sum(SPECIES_DISCARD, na.rm = T))
  
  obs_discard
  
}

# get_obs_disc_vals <- function(c_o_tab = c_o_dat2
#                               , species_nespp3 = '802'
#                               # , year = 2019
#                               , stratvars = c('GEARTYPE','meshgroup','region','halfofyear')
#                               ){
# 	
# 	stratvars = toupper(stratvars)
# 	
# 	codat <- c_o_tab %>%
# 		# filter(YEAR == year) %>% 
# 		# group_by(DMIS_TRIP_ID, NESPP3) %>%
# 		mutate(SPECIES_DISCARD = case_when(NESPP3 == species_nespp3 ~ DISCARD)) 
# 	# %>%
# 	# 	mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
# 	# 
# 	
# 	codat$MESHGROUP[codat$MESHGROUP == 'na'] = NA
# 	
# 	codat <- codat %>% 
# 		mutate(STRATA = eval(parse(text = stratvars[1])))
# 	
# 	if(length(stratvars) >1 ){
# 		
# 		for(i in 2:length(stratvars)){
# 			
# 			codat <- codat %>% 
# 				mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
# 		}
# 		
# 	}
# 	
# 	obs_discard = codat %>% 
# 		group_by(YEAR
# 						 , VTRSERNO
# 						 # , NEGEAR
# 						 , STRATA
# 		) %>% 
# 		dplyr::summarise(KALL = sum(SUBTRIP_KALL), DISCARD = sum(SPECIES_DISCARD, na.rm = T), dk = sum(SPECIES_DISCARD, na.rm = T)/sum(SUBTRIP_KALL, na.rm = T))
# 	
# 	obs_discard
# 	
# }

#' Get Observed trips for discard year
#'
#' @param bdat table of observed trips that can include (and should include) multiple years
#' @param year Year where discard estimate is needed
#' @param species_itis species of interest using SPECIES ITIS code
#' @param stratvars Stratification variables. These must be columns available in `bdat`. Not case sensitive. 
#'
#' @return a tibble with LINK1, STRATA, KALL, BYCATCH. Kept all (KALL) is rolled up by LINK1 (subtrip). BYCATCH is the observed discard of the species of interest.
#' 
#' This table is used in `discaRd`
#' 
#' the source table (bdat) is created outside of this function in SQL. It can be quite large so it is not done functionally here. See vignette (when it'savailable..)
#' @export
#'
#' @examples
make_bdat_focal <- function(bdat
                            # , year = 2019
                            # , species_nespp3 = '802'
														, species_itis = '164712' #cod
                            , stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	
	require(rlang)
	
	stratvars = toupper(stratvars)
	
	
	
	bdat_focal = bdat %>% 
		# filter(YEAR == year) %>% 
		# mutate(SPECIES_DISCARD = case_when(NESPP3 == species_nespp3 ~ DISCARD_PRORATE)) %>% 
		mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE)) %>%
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
	
	
	bdat_focal = assign_strata(bdat_focal, stratvars = stratvars)
	
	# 
	# bdat_focal <- bdat_focal %>% 
	# 	mutate(STRATA = eval(parse(text = stratvars[1])))
	# 
	# if(length(stratvars) >1 ){
	# 	
	# 	for(i in 2:length(stratvars)){
	# 		
	# 		bdat_focal <- bdat_focal %>% 
	# 			mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
	# 	}
	# 	
	# }
	
	bdat_focal <- bdat_focal %>%
		dplyr::group_by(LINK1
										# , NEGEAR
										# , GEARTYPE
										# , MESHGROUP
										, STRATA
		) %>% 
		# be careful here... need to take the max values since they are repeated..
		dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T)*max(PRORATE))
										 , BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 
		mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>% 
		ungroup()
	
	bdat_focal
	
}


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
		dplyr::select(VTRSERNO, OBS_DISCARD) %>% 
		right_join(x = ., y = ddat_rate, by = 'VTRSERNO') %>%   # need to drop a column or it gets DISCARD.x
		mutate(OBS_DISCARD = ifelse(is.na(OBS_DISCARD) & !is.na(LINK1), 0,  OBS_DISCARD)) %>% 
		mutate(EST_DISCARD = CRATE*LIVE_POUNDS) %>% 
		mutate(DISCARD = if_else(!is.na(OBS_DISCARD), OBS_DISCARD, EST_DISCARD)
		) 
	
	list(species = species_itis #species_nespp3
			 , allest = allest
			 , res = out_tab
	)
	
}



