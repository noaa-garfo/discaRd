
#------------------------
# just a workign area.. delete later


make_bdat_focal <- function(bdat, year = 2019, species_nespp3 = '802', stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	
	require(rlang)
	
	stratvars = toupper(stratvars)
  

	
	bdat_focal = bdat %>% 
		filter(YEAR == year) %>% 
		mutate(SPECIES_DISCARD = case_when(MATCH_NESPP3 == species_nespp3 ~ DISCARD_PRORATE)) %>% 
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
	
	
bdat_focal <- bdat_focal %>% 
	mutate(STRATA = eval(parse(text = stratvars[1])))

if(length(stratvars) >1 ){

	for(i in 2:length(stratvars)){
		
		bdat_focal <- bdat_focal %>% 
			mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
	}
	
}

	bdat_focal <- bdat_focal %>%
		dplyr::group_by(LINK1
										# , NEGEAR
										# , GEARTYPE
										# , MESHGROUP
										, STRATA
		) %>% 
		# be careful here... need to take the max values since they are repeated..
		dplyr::summarise(KALL = sum(max(OBS_HAUL_KALL_TRIP, na.rm = T)*max(PRORATE)), BYCATCH = sum(SPECIES_DISCARD, na.rm = T)) %>% 
		mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>% 
		ungroup()
	
	bdat_focal
	
}

make_assumed_rate <- function(bdat, year = 2019, species_nespp3 = '802', stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){
	require(rlang)
	
	stratvars = toupper(stratvars)
	
	assumed_discard <- make_bdat_focal(bdat, year = 2019, species_nespp3 = species_nespp3 , stratvars = stratvars)
	
 assumed_discard = assumed_discard %>% 
		dplyr::group_by( STRATA) %>% 
	# be careful here... max values already represented from bdat_focal. So, take the sum here
	dplyr::summarise(KALL = sum(KALL, na.rm = T), BYCATCH = sum(BYCATCH, na.rm = T)) %>% 
	mutate(KALL = tidyr::replace_na(KALL, 0), BYCATCH = tidyr::replace_na(BYCATCH, 0)) %>% 
	ungroup() %>% 
	mutate(dk = BYCATCH/KALL)

assumed_discard

}

get_obs_disc_vals <- function(c_o_tab = c_o_dat2, species_nespp3 = '802', year = 2019, stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){
	
	stratvars = toupper(stratvars)
	
	codat <- c_o_tab %>%
		filter(YEAR == year) %>% 
		# group_by(DMIS_TRIP_ID, NESPP3) %>%
		mutate(SPECIES_DISCARD = case_when(MATCH_NESPP3 == species_nespp3 ~ DISCARD)) %>%
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
	
	
	codat$MESHGROUP[codat$MESHGROUP == 'na'] = NA
	
	codat <- codat %>% 
		mutate(STRATA = eval(parse(text = stratvars[1])))
	
	if(length(stratvars) >1 ){
		
		for(i in 2:length(stratvars)){
			
			codat <- codat %>% 
				mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
		}
		
	}
	
	obs_discard = codat %>% 
		group_by(YEAR
						 , VTRSERNO
						 # , NEGEAR
						 , STRATA
		) %>% 
		dplyr::summarise(KALL = sum(SUBTRIP_KALL), DISCARD = sum(SPECIES_DISCARD), dk = sum(SPECIES_DISCARD, na.rm = T)/sum(SUBTRIP_KALL, na.rm = T))
	
	obs_discard
	
}


make_assumed_rate(bdat, year = 2019, species_nespp3 = '802', stratvars = c('geartype', 'meshgroup'))



make_bdat_focal(bdat, year = 2019, species_nespp3 = '802', stratvars = c('GEARTYPE','meshgroup','region','halfofyear')) %>% 
	head()


