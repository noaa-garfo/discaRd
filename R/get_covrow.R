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
#' 	dplyr::select(starts_with('N_') | starts_with('n_') | DISCARD_SOURCE |  CAMS_GEAR_GROUP | SPECIES_STOCK | MESH_CAT | TRIPCATEGORY | ACCESSAREA) %>% 
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
 	
 	# Go through each STRATA_USED and split out the columns used 
 	sidx = joined_table %>% 
 		filter(DISCARD_SOURCE != 'O') %>% 
 		dplyr::select(STRATA_USED, DISCARD_SOURCE) %>% 
 		distinct()
 	
 	
 	# Use the individual columns to group and tally N
 	
 	for(iloop in 1:nrow(sidx)){
 		svars = str_split(sidx$STRATA_USED[iloop], ';')	%>% unlist()
 		cidx = sapply(1:length(svars), function(x) which(colnames(joined_table) == svars[x]))
 		
 		dtype = sidx$DISCARD_SOURCE[iloop]
 		
 		N_name = paste('N', dtype, sep = '_')
 		n_name = paste('n', dtype, sep = '_')
 		
 		# STRATA_USED_DESC = c(joined_table[1,cidx])
 		
 		ntable = joined_table %>% 
 			group_by_at(vars(all_of(cidx))) %>% 
 			dplyr::summarize(N = n_distinct(CAMS_SUBTRIP)
 											 , n = n_distinct(LINK1)) %>% 
 			dplyr::rename({{N_name}} := N
 										, {{n_name}} := n)
 		
 		joined_table = joined_table %>% 
 			left_join(., ntable, by = svars ) 
 		
 	}
 	
 	# add columns so case_when doesn't crash
 	
 	cols <- c(N_I = NA_integer_
 						, N_GM = NA_integer_
 						, N_G = NA_integer_
 						, N_B = NA_integer_
 						, N_A = NA_integer_
 						, N_DELTA = NA_integer_
 						, N_EM = NA_integer_
 						, n_I = NA_integer_
 						, n_GM = NA_integer_
 						, n_G = NA_integer_
 						, n_B =  NA_integer_
 						, n_A = NA_integer_
 						, n_DELTA = NA_integer_
 						, n_EM = NA_integer_
 	)
 	
 	joined_table = tibble::add_column(joined_table, !!!cols[setdiff(names(cols), names(joined_table))])
 	
 	# join back to original table using STRATA_USED or DISCARD SOURCE
 	
 	joined_table = joined_table %>% 
 		mutate(N_USED = dplyr::case_when(DISCARD_SOURCE == 'I' ~ N_I
 															, DISCARD_SOURCE == 'T' ~ N_I
 															, DISCARD_SOURCE == 'GM' ~ N_GM
 															, DISCARD_SOURCE == 'G' ~ N_G
 															, DISCARD_SOURCE == 'B' ~ N_B
 															, DISCARD_SOURCE == 'A' ~ N_A
 															, DISCARD_SOURCE == 'DELTA' ~ NA_integer_
 															, DISCARD_SOURCE == 'EM' ~ NA_integer_
 															, TRUE ~ NA_integer_
 		)
 		, n_USED = dplyr::case_when(DISCARD_SOURCE == 'I' ~ n_I
 												 , DISCARD_SOURCE == 'T' ~ n_I
 												 , DISCARD_SOURCE == 'GM' ~ n_GM
 												 , DISCARD_SOURCE == 'G' ~ n_G
 												 , DISCARD_SOURCE == 'B' ~ n_B
 												 , DISCARD_SOURCE == 'A' ~ n_A
 												 , DISCARD_SOURCE == 'DELTA' ~ NA_integer_ # n_DELTA
 												 , DISCARD_SOURCE == 'EM' ~ NA_integer_
 												 , TRUE ~ NA_integer_
 												 ) #n_EM
 		) 
 	
 	
 	# add Legaults covrow ---- 
 	joined_table = joined_table %>% 
 		tidyr::unite(., col = 'STRATA_USED_DESC', unlist(strsplit(joined_table$STRATA_USED, ';')), remove = F)
 	
 	# Legaults covrow ----
 	joined_table = joined_table %>% 
 		mutate(var = (DISCARD * CV)^2)
 	#    mutate(var = kall_pro^2 * (dk * cv)^2)
 	
 	mysdsum <- joined_table %>% 
 		group_by(STRATA_USED_DESC) %>% 
 		dplyr::summarise(sdsum = sum(sqrt(var), na.rm = T))
 	
 	joined_table <- joined_table %>%
 		left_join(., mysdsum, by = 'STRATA_USED_DESC') %>% 
 		mutate(covrow = sqrt(var) * sdsum)	
 	
 	joined_table
 	
 }

 
# test for groundfish ----
# run wolffish_example.Rmd steps 
 
 # 
 # joined_table_gf = discard_wolf$trips_discard %>% 
 # 	filter(GF == 1) %>% 
 # 	get_covrow()
 # 
 # joined_table_nongf = discard_wolf$trips_discard %>% 
 # 	filter(GF == 0) %>% 
 # 	get_covrow()
 
 
 # Ntable = get_N_trips(joined_table) 
 
 # Take a look 
 # joined_table_gf %>% 
 # 	ungroup() %>% 
 # 	dplyr::select(starts_with('N_') | DISCARD_SOURCE |  CAMS_GEAR_GROUP | SPECIES_STOCK | MESH_CAT | TRIPCATEGORY | ACCESSAREA) %>% 
 # 	distinct() %>% 
 # 	View()
 
 # check sums  ---- 
 # joined_table_nongf %>% 
 # 	filter(DISCARD_SOURCE == 'I') %>% 
 # 	group_by(STRATA_USED_DESC) %>% 
 # 	dplyr::summarise(trip_var_total = sum(var, na.rm = T)
 # 									 # , strata_var = max(VAR_RATE_STRATA, na.rm = T)
 # 									 , CV_STRATA = max(CV, na.rm = T)
 # 									 , N_USED = max(N_USED, na.rm = T)
 # 									 , n_used = max(n_USED, na.rm = T)
 # 									 ) %>%
 # 	View()
 
 
 # GF trips 
 # joined_table_gf %>% 
 # 	# filter(GF == 1) %>% 
 # 	mutate( VAR_RATE_STRATA = (CV*COAL_RATE)^2
 # 					, VAR_RATE_TRIP = ((CV*COAL_RATE)^2)/N_USED) %>% 
 # 	filter(DISCARD_SOURCE == 'I') %>% 
 # 	group_by( SPECIES_STOCK
 # 						, CAMS_GEAR_GROUP
 # 						, MESH_CAT
 # 						, SECTID
 # 						, EM
 # 						, REDFISH_EXEMPTION
 # 						, SNE_SMALLMESH_EXEMPTION
 # 						, XLRG_GILLNET_EXEMPTION
 # 						, EXEMPT_7130
 # 	) %>% 
 # 	dplyr::summarise(trip_var_total = sum(VAR_RATE_TRIP, na.rm = T)
 # 									 , strata_var = max(VAR_RATE_STRATA)
 # 									 , CV_STRATA = max(CV)
 # 									 , max(N_USED)) %>% 
 # 	View()


 
 # check sums  
# joined_table %>% 
# 	group_by()
#  dplyr::summarise(check_dk <- OBS_DISCARD / OBS_HAUL_KEPT
#  leftp <- n$unobsn / (n$obsn * n$totaln)
#  middlep <- 1 / (obssum$sumk / n$obsn)^2
#  rightp <- (obssum$sumd2 + check_dk^2 * obssum$sumk2 - 2 * check_dk * obssum$sumdk) / (n$obsn - 1)
#  vardk <- leftp * middlep * rightp
#  check_cv <- sqrt(vardk) / check_dk
 
 
 # add discard used desc ---- 
 # joined_table = mydiscard$trips_discard
 # 
 # joined_table = joined_table %>% 
 # 	tidyr::unite(., col = 'STRATA_USED_DESC', unlist(strsplit(joined_table$STRATA_USED, ';')), remove = F)
 # 	
 # 	# Legaults covrow ----
 # joined_table = joined_table %>% 
 # 	mutate(var = (DISCARD * CV)^2)
 # #    mutate(var = kall_pro^2 * (dk * cv)^2)
 # 
 # mysdsum <- joined_table %>% 
 # 	group_by(STRATA_USED_DESC) %>% 
 # 	dplyr::summarise(sdsum = sum(sqrt(var), na.rm = T))
 # 
 # joined_table <- joined_table %>%
 # 	left_join(., mysdsum, by = 'STRATA_USED_DESC') %>% 
 # 	mutate(covrow = sqrt(var) * sdsum)	
 # 	
 # 	joined_table %>% 
 # 		filter(DISCARD_SOURCE == 'I') %>% 
 # 	dplyr::select(YEAR, FISHING_YEAR, STRATA_USED_DESC, COAL_RATE, DISCARD, var, sdsum, covrow)
 # 
 # 
 # 
 # 