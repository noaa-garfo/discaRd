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
#' This function does not need stratification. Only VTR serial number and an observed discard for desired species
#' This function utilizes the DISCARD_PRORATE field in CAMS_OBS_CATCH. This value must be used for assigning observed discrd to trips. It is NOT used for d/k calculations since it is pro-rated by unobserved KALL. 
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
    mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE)) 
  
  obs_discard = codat %>% 
    group_by(VTRSERNO, CAMSID
             # , NEGEAR
             # , STRATA
    ) %>% 
    dplyr::summarise(DISCARD = sum(SPECIES_DISCARD, na.rm = T))
  
  obs_discard
  
}


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
														# , year = 2019
														# , species_nespp3 = '802'
														, species_itis = '164712' #cod
														, stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	
	require(rlang)
	
	stratvars = toupper(stratvars)
	
	
	
	bdat_focal = bdat %>% 
		# filter(YEAR == year) %>% 
		# mutate(SPECIES_DISCARD = case_when(NESPP3 == species_nespp3 ~ DISCARD_PRORATE)) %>% 
		mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD)) %>%
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
	
	
	bdat_focal = assign_strata(bdat_focal, stratvars = stratvars)
	
	
	bdat_focal <- bdat_focal %>%
		dplyr::group_by(LINK1
										, CAMS_SUBTRIP # new field that catenates CAMSID and CAMS SUBTRIP
										# , NEGEAR
										# , GEARTYPE
										# , MESHGROUP
										, STRATA
		) %>% 
		# be careful here... need to take the max values since they are repeated..
		dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T))# *max(PRORATE) take this part out! 4/27/22
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


#' Get Broad Stock Rate
#' This function is a special case of \link{run_discard}. When sotck is used as a startification variable, it is not starightforward to get a broad stock rate, with a CV. This function simply subsets a larger dataset by stock component before running run_discard.
#' The advantage of having this as a function is it may easily be run in a loop.
#' @param bdat table of observed trips that can include (and should include) multiple years
#' @param ddat_focal_sp table of observed trips for discard year
#' @param ddat_focal matched table of observed and commerical trips
#' @param species_itis species of interest using SPECIES_ITIS code
#' @param stratvars stratification variables desired: should only be SPECIES_STOCK; ususally the first of a strinf of stratification variables
#' @param stock specific stock (name) to run
#'
#' @return a list of: 
#' 1) Species stock 
#' 2) discaRd rate 
#' 3) CV
#' @export
#'
#' @examples
#' stratvars_scalgf = c("SPECIES_STOCK"
#' , "CAMS_GEAR_GROUP" 
#' , "MESHGROUP"     
#' , "TRIPCATEGORY" 
#' , "ACCESSAREA"  
#' , "SCALLOP_AREA"
#' )
#' 
#' BROAD_STOCK_RATE_TABLE = list()

#' kk = 1

#' ustocks = bdat_scal$SPECIES_STOCK %>% unique()

#' for(k in ustocks){
#'	BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_rate(bdat = bdat_scal
#'																											, ddat_focal_sp = ddat_focal_scal
#'																											, ddat_focal = ddat_focal
#'																											, species_itis = species_itis
#'																											, stratvars = stratvars_scalgf[1]																	
#'																											, stock = k 
#'	)
#'	kk = kk+1
#'}

#' BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

#' rm(kk, k)
#' 
get_broad_stock_rate = function(bdat, ddat_focal_sp, ddat_focal, species_itis, stratvars, stock = 'GOM'){ 	
  
  btmp = 	bdat %>%
    filter(SPECIES_STOCK == stock)
  dstmp = ddat_focal_sp %>%
    filter(SPECIES_STOCK == stock)
  dtmp = 	ddat_focal %>%
    filter(SPECIES_STOCK == stock)
  
  d_broad_stock = run_discard(bdat = btmp
                              , ddat = dstmp
                              , c_o_tab = dtmp
                              , species_itis = species_itis
                              , stratvars = stratvars
                              , aidx = 1  # this makes sure this isn't used..
  )
  
  data.frame(SPECIES_STOCK = stock, BROAD_STOCK_RATE = d_broad_stock$allest$rTOT
             , CV_b = d_broad_stock$allest$CVTOT
  )
  
} 



get_broad_stock_gear_rate = function(bdat, ddat_focal_sp, ddat_focal, species_itis, stratvars, stock = 'GOM'){ 	
  
  btmp = 	bdat %>%
    filter(SPECIES_STOCK == ustocks[k] & CAMS_GEAR_GROUP == CAMS_GEAR_GROUP[i])
  dstmp = ddat_focal_sp %>%
    filter(SPECIES_STOCK == ustocks[k] & CAMS_GEAR_GROUP == CAMS_GEAR_GROUP[i])
  dtmp = 	ddat_focal %>%
    filter(SPECIES_STOCK == ustocks[k] & CAMS_GEAR_GROUP == CAMS_GEAR_GROUP[i])
  
  d_broad_stock = run_discard(bdat = btmp
                              , ddat = dstmp
                              , c_o_tab = dtmp
                              , species_itis = species_itis
                              , stratvars = stratvars
                              , aidx = 1  # this makes sure this isn't used..
  )
  
  data.frame(SPECIES_STOCK = ustocks[k], CAMS_GEAR_GROUP=CAMS_GEAR_GROUP[i], BROAD_STOCK_RATE = d_broad_stock$allest$rTOT
             , CV_b = d_broad_stock$allest$CVTOT
  )
  
}
