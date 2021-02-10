
#' Title
#'
#' @param bdat 
#' @param year 
#' @param species_nespp3 
#'
#' @return
#' @export
#'
#' @examples
make_bdat_focal <- function(bdat, year = 2019, species_nespp3 = '802', stratvars = c('GEARTYPE','meshgroup','region','halfofyear')){ #, strata = paste(GEARTYPE, MESHGROUP, AREA, sep = '_')
	
	require(rlang)
	
	stratvars = toupper(stratvars)
  

	
	bdat_focal = bdat %>% 
		filter(YEAR == year) %>% 
		mutate(SPECIES_DISCARD = case_when(MATCH_NESPP3 == species_nespp3 ~ DISCARD_PRORATE)) %>% 
		mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))
	
	
bdat_focal <- bdat_focal %>% 
	mutate(STRATA = eval(parse(text = stratvars[1])))

for(i in 2:length(stratvars)){
	
	bdat_focal <- bdat_focal %>% 
		mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
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


make_bdat_focal(bdat, year = 2019, species_nespp3 = '802', stratvars = c('GEARTYPE','meshgroup','region','halfofyear')) %>% 
	head()

make_bdat_focal(bdat, year = 2019, species_nespp3 = '802', stratvars = c('GEARTYPE','meshgroup')) %>% 
	head()


test <- test %>% 
	mutate(new = eval(parse(text = stratvars[1])))

for(i in 2:length(stratvars)){

	test<- test %>% 
		mutate(new = paste(new, eval(parse(text = stratvars[i])), sep = '_'))
		
}
