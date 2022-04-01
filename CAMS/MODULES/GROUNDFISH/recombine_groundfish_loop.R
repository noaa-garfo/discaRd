knitr::opts_chunk$set(echo=FALSE
											, warning = FALSE
											, message = FALSE
											, cache = FALSE
											, progress = TRUE
											, verbose = FALSE
											, comment = F
											, error = FALSE
											, dev = 'png'
											, dpi = 200
											, prompt = F
											, results='hide')

options(dplyr.summarise.inform = FALSE)









# Stratification variables

stratvars = c( 'SPECIES_STOCK'
							# , 'GEARCODE'  # this is the SECGEAR_MAPPED variable
              , 'CAMS_GEAR_GROUP'
              , 'MESHGROUP'
              , 'SECTID'
              , 'EM'
              , "REDFISH_EXEMPTION"
              , "SNE_SMALLMESH_EXEMPTION"
              , "XLRG_GILLNET_EXEMPTION"
              )

# add a second SECTORID for Common pool/all others



for(i in 1:length(species$SPECIES_ITIS)){

t1 = Sys.time()
	
print(paste0('Running ', species$COMNAME[i]))	
	
# species_nespp3 = species$NESPP3[i]  
species_itis = species$SPECIES_ITIS[i] 
#---#
# Support table import by species

# GEAR TABLE
CAMS_GEAR_STRATA = tbl(bcon, sql('  select * from MAPS.CAMS_GEARCODE_STRATA')) %>% 
    collect() %>% 
  dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>% 
  # filter(NESPP3 == species_nespp3) %>% 
	filter(SPECIES_ITIS == species_itis) %>%
  dplyr::select(-NESPP3, -SPECIES_ITIS)

# Stat areas table  
# unique stat areas for stock ID if needed
STOCK_AREAS = tbl(bcon, sql('select * from MAPS.CAMS_STATAREA_STOCK')) %>%
  # filter(NESPP3 == species_nespp3) %>%  # removed  & AREA_NAME == species_stock
	filter(SPECIES_ITIS == species_itis) %>%
    collect() %>% 
  group_by(AREA_NAME, SPECIES_ITIS) %>% 
  distinct(STAT_AREA) %>%
  mutate(AREA = as.character(STAT_AREA)
         , SPECIES_STOCK = AREA_NAME) %>% 
  ungroup() 
# %>% 
#   dplyr::select(SPECIES_STOCK, AREA)

# Mortality table
CAMS_DISCARD_MORTALITY_STOCK = tbl(bcon, sql("select * from MAPS.CAMS_DISCARD_MORTALITY_STOCK"))  %>%
  collect() %>%
  mutate(SPECIES_STOCK = AREA_NAME
         , GEARCODE = CAMS_GEAR_GROUP
  			 , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  select(-AREA_NAME) %>%
  # mutate(CAREA = as.character(STAT_AREA)) %>% 
  # filter(NESPP3 == species_nespp3) %>% 
	filter(SPECIES_ITIS == species_itis) %>%
  dplyr::select(-SPECIES_ITIS) %>% 
  dplyr::rename(DISC_MORT_RATIO = Discard_Mortality_Ratio)

#---------#
# haddock example trips with full strata either in year_t or year _t-1
#---------#

# print(paste0("Getting in-season rates for ", species_itis, " ", FY))

# make tables
ddat_focal <- gf_dat %>% 
  filter(GF_YEAR == FY) %>%   ## time element is here!!
  filter(AREA %in% STOCK_AREAS$AREA) %>% 
  mutate(LIVE_POUNDS = SUBTRIP_KALL
         ,SEADAYS = 0
	  		 , NESPP3 = NESPP3_FINAL) %>% 
   left_join(., y = STOCK_AREAS, by = 'AREA') %>% 
   left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>% 
   left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
            , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
            ) %>% 
	dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y) %>% 
	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x') %>% 
  relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')


ddat_prev <- gf_dat %>% 
  filter(GF_YEAR == FY-1) %>%   ## time element is here!!
  filter(AREA %in% STOCK_AREAS$AREA) %>% 
  mutate(LIVE_POUNDS = SUBTRIP_KALL
         ,SEADAYS = 0
	  		 , NESPP3 = NESPP3_FINAL) %>% 
   left_join(., y = STOCK_AREAS, by = 'AREA') %>% 
   left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>% 
   left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
            , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
            ) %>%  
		dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y) %>% 
	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x') %>% 
  relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')



# need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row.. 
# need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!

ddat_focal_gf = ddat_focal %>% 
  filter(!is.na(LINK1)) %>% 
	mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
																					)) %>% 
	mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>% 
  group_by(LINK1, VTRSERNO) %>% 
	arrange(desc(SPECIES_EVAL_DISCARD)) %>% 
	slice(1) %>% 
  ungroup()

# and join to the unobserved trips

ddat_focal_gf = ddat_focal_gf %>% 
  union_all(ddat_focal %>% 
              filter(is.na(LINK1)) %>% 
               group_by(VTRSERNO) %>% 
               slice(1) %>% 
               ungroup()
            )


# if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
# DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS. 

bdat_gf = ddat_focal %>% 
  filter(!is.na(LINK1)) %>% 
  mutate(DISCARD_PRORATE = DISCARD
         , OBS_AREA = AREA
         , OBS_HAUL_KALL_TRIP = OBS_KALL
         , PRORATE = 1)


# set up trips table for previous year
ddat_prev_gf = ddat_prev %>% 
  filter(!is.na(LINK1)) %>% 
	mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
																					)) %>% 
	mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>% 
  group_by(LINK1, VTRSERNO) %>% 
	arrange(desc(SPECIES_EVAL_DISCARD)) %>% 
	slice(1) %>% 
  ungroup()

ddat_prev_gf = ddat_prev_gf %>% 
  union_all(ddat_prev %>% 
  						 filter(is.na(LINK1)) %>% 
               group_by(VTRSERNO) %>% 
               slice(1) %>% 
               ungroup()
  					)


# previous year observer data needed.. 
bdat_prev_gf = ddat_prev %>% 
  filter(!is.na(LINK1)) %>% 
  mutate(DISCARD_PRORATE = DISCARD
         , OBS_AREA = AREA
         , OBS_HAUL_KALL_TRIP = OBS_KALL
         , PRORATE = 1)

# Run the discaRd functions on previous year
d_prev = run_discard(bdat = bdat_prev_gf
											 , ddat = ddat_prev_gf
											 , c_o_tab = ddat_prev
											 # , year = 2018
											 # , species_nespp3 = species_nespp3
										   , species_itis = species_itis
											 , stratvars = stratvars
											 , aidx = c(1:length(stratvars))
											 )


# Run the discaRd functions on current year
d_focal = run_discard(bdat = bdat_gf
											 , ddat = ddat_focal_gf
											 , c_o_tab = ddat_focal
											 # , year = 2019
											 # , species_nespp3 = '081' # haddock...
											 # , species_nespp3 = species_nespp3  #'081' #cod...
											 , species_itis = species_itis
											 , stratvars = stratvars
											 , aidx = c(1:length(stratvars))  # this makes sure this isn't used.. 
											 )

# summarize each result for convenience
dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

# substitute transition rates where needed

trans_rate_df = dest_strata_f %>% 
  left_join(., dest_strata_p, by = 'STRATA') %>% 
  mutate(STRATA = STRATA
         , n_obs_trips_f = n.x
  			 , n_obs_trips_p = n.y
         , in_season_rate = drate.x
         , previous_season_rate = drate.y
  ) %>% 
	mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>% 
  mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
                                         , l_assumed_rate = previous_season_rate
                                         , l_inseason_rate = in_season_rate
                                         )
         ) %>% 
  dplyr::select(STRATA
         , n_obs_trips_f
         , n_obs_trips_p
         , in_season_rate 
         , previous_season_rate 
         , trans_rate
         , CV_f = CV.x
         )


trans_rate_df = trans_rate_df %>% 
  mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate)) 
  
 trans_rate_df$final_rate = coalesce(trans_rate_df$final_rate, trans_rate_df$in_season_rate)

 
 trans_rate_df_full = trans_rate_df
 
 full_strata_table = trans_rate_df_full %>% 
   right_join(., y = d_focal$res, by = 'STRATA') %>% 
   as_tibble() %>% 
 	 	mutate(SPECIES_ITIS_EVAL = species_itis
 				 , COMNAME_EVAL = species$COMNAME[i]
 				 , FISHING_YEAR = FY
 				 , FY_TYPE = FY_TYPE) %>% 
 	   dplyr::rename(FULL_STRATA = STRATA) 
 
#
# SECTOR ROLLUP
#
# print(paste0("Getting rates across sectors for ", species_itis, " ", FY)) 
 
stratvars_assumed = c("SPECIES_STOCK"
											, "CAMS_GEAR_GROUP"
											# , "GEARCODE"
											, "MESHGROUP"
											, "SECTOR_TYPE")


### All tables in previous run can be re-used wiht diff stratification

# Run the discaRd functions on previous year
d_prev_pass2 = run_discard(bdat = bdat_prev_gf
											 , ddat = ddat_prev_gf
											 , c_o_tab = ddat_prev
											 # , year = 2018
											 # , species_nespp3 = species_nespp3
										   , species_itis = species_itis
											 , stratvars = stratvars_assumed
											 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used.. 
											, aidx = c(1)  # this creates an unstratified broad stock rate
											 )


# Run the discaRd functions on current year
d_focal_pass2 = run_discard(bdat = bdat_gf
											 , ddat = ddat_focal_gf
											 , c_o_tab = ddat_focal
											 # , year = 2019
											 # , species_nespp3 = '081' # haddock...
											 # , species_nespp3 = species_nespp3  #'081' #cod...
											 , species_itis = species_itis
											 , stratvars = stratvars_assumed
											 # , aidx = c(1:length(stratvars_assumed))  # this makes sure this isn't used.. 
											, aidx = c(1)  # this creates an unstratified broad stock rate
											 )

# summarize each result for convenience
dest_strata_p_pass2 = d_prev_pass2$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

dest_strata_f_pass2 = d_focal_pass2$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

# substitute transition rates where needed

trans_rate_df_pass2 = dest_strata_f_pass2 %>% 
  left_join(., dest_strata_p_pass2, by = 'STRATA') %>% 
  mutate(STRATA = STRATA
         , n_obs_trips_f = n.x
  			 , n_obs_trips_p = n.y
         , in_season_rate = drate.x
         , previous_season_rate = drate.y
  ) %>% 
	mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>% 
  mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
                                         , l_assumed_rate = previous_season_rate
                                         , l_inseason_rate = in_season_rate
                                         )
         ) %>% 
  dplyr::select(STRATA
         , n_obs_trips_f
         , n_obs_trips_p
         , in_season_rate 
         , previous_season_rate 
         , trans_rate
         , CV_f = CV.x
         )


trans_rate_df_pass2 = trans_rate_df_pass2 %>% 
  mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate)) 
  
 trans_rate_df_pass2$final_rate = coalesce(trans_rate_df_pass2$final_rate, trans_rate_df_pass2$in_season_rate)

 
 # get a table of broad stock rates using discaRd functions. Previosuly we used sector rollupresults (ARATE in pass2)


BROAD_STOCK_RATE_TABLE = list()

kk = 1

ustocks = bdat_gf$SPECIES_STOCK %>% unique()

for(k in ustocks){
	BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_rate(bdat = bdat_gf
											 , ddat_focal_sp = ddat_focal_gf
											 , ddat_focal = ddat_focal
											 , species_itis = species_itis
											 , stratvars = stratvars[1]
											 # , aidx = 1
											 , stock = k 
											 )
	kk = kk+1
}

BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

rm(kk, k) 
 
#   
# BROAD_STOCK_RATE_TABLE = d_focal_pass2$res %>% 
#  	group_by(SPECIES_STOCK) %>% 
#  	dplyr::summarise(BROAD_STOCK_RATE = mean(ARATE)) # mean rate is max rate.. they are all the same within STOCK, as they should be
 
# make names specific to the sector rollup pass
 
names(trans_rate_df_pass2) = paste0(names(trans_rate_df_pass2), '_a')
  
#
# join full and assumed strata tables
#
# print(paste0("Constructing output table for ", species_itis, " ", FY)) 

joined_table = assign_strata(full_strata_table, stratvars_assumed) %>% 
	dplyr::select(-STRATA_ASSUMED) %>%  # not using this anymore here..
	dplyr::rename(STRATA_ASSUMED = STRATA) %>% 
	left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>% 
	left_join(x =., y = BROAD_STOCK_RATE_TABLE, by = 'SPECIES_STOCK') %>% 
	mutate(COAL_RATE = case_when(n_obs_trips_f >= 5 ~ final_rate  # this is an in season rate
															 , n_obs_trips_f < 5 & 
															 	n_obs_trips_p >=5 ~ final_rate  # this is a final IN SEASON rate taking transition into account
															 , n_obs_trips_f < 5 & 
															 	n_obs_trips_p < 5 ~ trans_rate_a  # this is an final assumed rate taking trasnition into account
		                           )
	) %>% 
	mutate(COAL_RATE = coalesce(COAL_RATE, BROAD_STOCK_RATE)) %>%
	mutate(SPECIES_ITIS_EVAL = species_itis
 				 , COMNAME_EVAL = species$COMNAME[i]
 				 , FISHING_YEAR = FY
 				 , FY_TYPE = FY_TYPE) 

#
# add discard source
#


# >5 trips in season gets in season rate
# < 5 i nseason but >=5 past year gets transition
# < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
# <5, <5,  and <5 gets broad stock rate

joined_table = joined_table %>% 
    mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) ~ 'O'
    																	, is.na(LINK1) & 
    																		n_obs_trips_f >= 5 ~ 'I'
    																	# , is.na(LINK1) & COAL_RATE == previous_season_rate ~ 'P'
    																	, is.na(LINK1) & 
    																		n_obs_trips_f < 5 & 
    																		n_obs_trips_p >=5 ~ 'T'
    																	, is.na(LINK1) & 
    																		n_obs_trips_f < 5 &
    																		n_obs_trips_p < 5 &
    																		n_obs_trips_f_a >= 5 ~ 'A'
    																	, is.na(LINK1) & 
    																		n_obs_trips_f < 5 &
    																		n_obs_trips_p < 5 &
    																		n_obs_trips_p_a >= 5 ~ 'B'
    																	, is.na(LINK1) & 
    																		n_obs_trips_f < 5 & 
    																		n_obs_trips_p < 5 & 
    																		n_obs_trips_f_a < 5 & 
    																		n_obs_trips_p_a < 5 ~ 'B'
    																	)  # this may be replaced with model estimate!
    			 )

#
# make sure CV type matches DISCARD SOURCE}
#

# obs trips get 0, broad stock rate is NA


joined_table = joined_table %>% 
	mutate(CV = case_when(DISCARD_SOURCE == 'O' ~ 0
												, DISCARD_SOURCE == 'I' ~ CV_f
												, DISCARD_SOURCE == 'T' ~ CV_f
												, DISCARD_SOURCE == 'A' ~ CV_f_a
												, DISCARD_SOURCE == 'B' ~ CV_b
												# , DISCARD_SOURCE == 'AT' ~ CV_f_a
												)  # , DISCARD_SOURCE == 'B' ~ NA
				 )

# Make note of the stratification variables used according to discard source

strata_f = paste(stratvars, collapse = ';')
strata_a = paste(stratvars_assumed, collapse = ';')
strata_b = stratvars[1]

joined_table = joined_table %>% 
	mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' ~ ''
												, DISCARD_SOURCE == 'I' ~ strata_f
												, DISCARD_SOURCE == 'T' ~ strata_f
												, DISCARD_SOURCE == 'A' ~ strata_a
												, DISCARD_SOURCE == 'B' ~ strata_b
												) 
				 )

#
# get the discard for each trip using COAL_RATE}
#

# discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio. 
# the KALLs should be small.. 

joined_table = joined_table %>% 
	mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
	mutate(DISCARD = case_when(!is.na(LINK1) ~ DISC_MORT_RATIO*OBS_DISCARD
														 , is.na(LINK1) ~ DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS)
				 )

joined_table %>% 
	group_by(SPECIES_STOCK, DISCARD_SOURCE) %>% 
	dplyr::summarise(DISCARD_EST = sum(DISCARD)) %>% 
	pivot_wider(names_from = 'SPECIES_STOCK', values_from = 'DISCARD_EST') %>% 
	dplyr::select(-1) %>% 
	colSums(na.rm = T) %>% 
	round()

#-------------------------------#	
# save trip by trip info to RDS 
#-------------------------------#

# saveRDS(joined_table, file = paste0('/home/bgaluardi/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/discard_est_', species_itis, '_gftrips_only.RDS')
				
fst::write_fst(x = joined_table, path = paste0('/home/bgaluardi/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/discard_est_', species_itis, '_gftrips_only', FY,'.fst'))

 t2 = Sys.time()
	
print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))
 
}


stratvars_nongf = c('SPECIES_STOCK'
              ,'CAMS_GEAR_GROUP'
							, 'MESHGROUP'
						  , 'TRIPCATEGORY'
						  , 'ACCESSAREA')


for(i in 1:length(species$SPECIES_ITIS)){

t1 = Sys.time()	
	
print(paste0('Running non-groundfish trips for ', species$COMNAME[i]))	
	
# species_nespp3 = species$NESPP3[i]  
species_itis = species$SPECIES_ITIS[i] 
#---#
# Support table import by species

# GEAR TABLE
CAMS_GEAR_STRATA = tbl(bcon, sql('  select * from MAPS.CAMS_GEARCODE_STRATA')) %>% 
    collect() %>% 
  dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>% 
  # filter(NESPP3 == species_nespp3) %>% 
	filter(SPECIES_ITIS == species_itis) %>%
  dplyr::select(-NESPP3, -SPECIES_ITIS)

# Stat areas table  
# unique stat areas for stock ID if needed
STOCK_AREAS = tbl(bcon, sql('select * from MAPS.CAMS_STATAREA_STOCK')) %>%
  # filter(NESPP3 == species_nespp3) %>%  # removed  & AREA_NAME == species_stock
	filter(SPECIES_ITIS == species_itis) %>%
    collect() %>% 
  group_by(AREA_NAME, SPECIES_ITIS) %>% 
  distinct(STAT_AREA) %>%
  mutate(AREA = as.character(STAT_AREA)
         , SPECIES_STOCK = AREA_NAME) %>% 
  ungroup() 
# %>% 
#   dplyr::select(SPECIES_STOCK, AREA)

# Mortality table
CAMS_DISCARD_MORTALITY_STOCK = tbl(bcon, sql("select * from MAPS.CAMS_DISCARD_MORTALITY_STOCK"))  %>%
  collect() %>%
  mutate(SPECIES_STOCK = AREA_NAME
         , GEARCODE = CAMS_GEAR_GROUP
  			 , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  select(-AREA_NAME) %>%
  # mutate(CAREA = as.character(STAT_AREA)) %>% 
  # filter(NESPP3 == species_nespp3) %>% 
	filter(SPECIES_ITIS == species_itis) %>%
  dplyr::select(-SPECIES_ITIS) %>% 
  dplyr::rename(DISC_MORT_RATIO = Discard_Mortality_Ratio)

#---------#
# haddock example trips with full strata either in year_t or year _t-1
#---------#

# print(paste0("Getting in-season rates for ", species_itis, " ", FY))

# make tables
ddat_focal <- non_gf_dat %>% 
  filter(GF_YEAR == FY) %>%   ## time element is here!!
  filter(AREA %in% STOCK_AREAS$AREA) %>% 
  mutate(LIVE_POUNDS = SUBTRIP_KALL
         ,SEADAYS = 0
	  		 , NESPP3 = NESPP3_FINAL) %>% 
   left_join(., y = STOCK_AREAS, by = 'AREA') %>% 
   left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>% 
   left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
            , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
            ) %>% 
	dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y) %>% 
	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x') %>% 
  relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')


ddat_prev <- non_gf_dat %>% 
  filter(GF_YEAR == FY-1) %>%   ## time element is here!!
  filter(AREA %in% STOCK_AREAS$AREA) %>% 
  mutate(LIVE_POUNDS = SUBTRIP_KALL
         ,SEADAYS = 0
	  		 , NESPP3 = NESPP3_FINAL) %>% 
   left_join(., y = STOCK_AREAS, by = 'AREA') %>% 
   left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>% 
   left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
            , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
            ) %>%  
		dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y) %>% 
	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x') %>% 
  relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')



# need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row.. 
# need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!

ddat_focal_non_gf = ddat_focal %>% 
  filter(!is.na(LINK1)) %>% 
	mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
																					)) %>% 
	mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>% 
  group_by(LINK1, VTRSERNO) %>% 
	arrange(desc(SPECIES_EVAL_DISCARD)) %>% 
	slice(1) %>% 
  ungroup()

# and join to the unobserved trips

ddat_focal_non_gf = ddat_focal_non_gf %>% 
  union_all(ddat_focal %>% 
              filter(is.na(LINK1)) %>% 
               # group_by(VTRSERNO, CAMSID) %>% 
               # slice(1) %>% 
               ungroup()
            )


# if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
# DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS. 

bdat_non_gf = ddat_focal %>% 
  filter(!is.na(LINK1)) %>% 
  mutate(DISCARD_PRORATE = DISCARD
         , OBS_AREA = AREA
         , OBS_HAUL_KALL_TRIP = OBS_KALL
         , PRORATE = 1)


# set up trips table for previous year
ddat_prev_non_gf = ddat_prev %>% 
  filter(!is.na(LINK1)) %>% 
	mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
																					)) %>% 
	mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>% 
  group_by(LINK1, VTRSERNO) %>% 
	arrange(desc(SPECIES_EVAL_DISCARD)) %>% 
	slice(1) %>% 
  ungroup()

ddat_prev_non_gf = ddat_prev_non_gf %>% 
  union_all(ddat_prev %>% 
  						 filter(is.na(LINK1)) %>% 
               # group_by(VTRSERNO, CAMSID) %>% 
               # slice(1) %>% 
               ungroup()
  					)


# previous year observer data needed.. 
bdat_prev_non_gf = ddat_prev %>% 
  filter(!is.na(LINK1)) %>% 
  mutate(DISCARD_PRORATE = DISCARD
         , OBS_AREA = AREA
         , OBS_HAUL_KALL_TRIP = OBS_KALL
         , PRORATE = 1)

# Run the discaRd functions on previous year
d_prev = run_discard(bdat = bdat_prev_non_gf
											 , ddat = ddat_prev_non_gf
											 , c_o_tab = ddat_prev
										   , species_itis = species_itis
											 , stratvars = stratvars_nongf
											 # , aidx = c(1:length(stratvars))
										   , aidx = c(1:2) # uses GEAR as assumed
											 )


# Run the discaRd functions on current year
d_focal = run_discard(bdat = bdat_non_gf
											 , ddat = ddat_focal_non_gf
											 , c_o_tab = ddat_focal
											 , species_itis = species_itis
											 , stratvars = stratvars_nongf
											 # , aidx = c(1:length(stratvars))  # this makes sure this isn't used.. 
											 , aidx = c(1:2) # uses GEAR as assumed
											 )

# summarize each result for convenience
dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

# substitute transition rates where needed

trans_rate_df = dest_strata_f %>% 
  left_join(., dest_strata_p, by = 'STRATA') %>% 
  mutate(STRATA = STRATA
         , n_obs_trips_f = n.x
  			 , n_obs_trips_p = n.y
         , in_season_rate = drate.x
         , previous_season_rate = drate.y
  ) %>% 
	mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>% 
  mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
                                         , l_assumed_rate = previous_season_rate
                                         , l_inseason_rate = in_season_rate
                                         )
         ) %>% 
  dplyr::select(STRATA
         , n_obs_trips_f
         , n_obs_trips_p
         , in_season_rate 
         , previous_season_rate 
         , trans_rate
         , CV_f = CV.x
         )


trans_rate_df = trans_rate_df %>% 
  mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate)) 
  
 trans_rate_df$final_rate = coalesce(trans_rate_df$final_rate, trans_rate_df$in_season_rate)

 
 trans_rate_df_full = trans_rate_df
 
 full_strata_table = trans_rate_df_full %>% 
   right_join(., y = d_focal$res, by = 'STRATA') %>% 
   as_tibble() %>% 
 	 	mutate(SPECIES_ITIS_EVAL = species_itis
 				 , COMNAME_EVAL = species$COMNAME[i]
 				 , FISHING_YEAR = FY
 				 , FY_TYPE = FY_TYPE) %>% 
 	   dplyr::rename(FULL_STRATA = STRATA) 
 
#
# join full and assumed strata tables
#
 
# BROAD_STOCK_RATE_TABLE = d_focal$res %>% 
#  	group_by(SPECIES_STOCK) %>% 
#  	dplyr::summarise(BROAD_STOCK_RATE = mean(ARATE, na.rm = T)) # mean rate is max rate.. they are all the same within STOCK, as they should be 
 
# get a broad stock rate across all gears (no stratification)
# NOTE: This is slightly different than what is used for GF trips. 
# For non-GF trips, the Assumed rate above is GEAR/MESH.
 

 BROAD_STOCK_RATE_TABLE = list()

kk = 1

ustocks = bdat_non_gf$SPECIES_STOCK %>% unique()

for(k in ustocks){
	BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_rate(bdat = bdat_non_gf
											 , ddat_focal_sp = ddat_focal_non_gf
											 , ddat_focal = ddat_focal
											 , species_itis = species_itis
											 , stratvars = stratvars_nongf[1]
											 # , aidx = 1
											 , stock = k 
											 )
	kk = kk+1
}

BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

rm(kk, k) 
 
#  
#  BROAD_STOCK_RATE_TABLE = make_assumed_rate(bdat_non_gf
# 																					 , species_itis = species$SPECIES_ITIS[i]
# 																					 , stratvars = stratvars_nongf[1]) %>% 
#  	mutate(SPECIES_STOCK = STRATA
#  				 , STRAT_DESC = paste(stratvars_nongf[1], sep = '-')) %>% 
#  	dplyr::rename('BROAD_STOCK_RATE' = 'dk') %>% 
#  	dplyr::select(-STRATA, -KALL, -BYCATCH)
 
# print(paste0("Constructing output table for ", species_itis, " ", FY)) 

joined_table = assign_strata(full_strata_table, stratvars_nongf) %>% 
	# dplyr::select(-STRATA_ASSUMED) %>%  # not using this anymore here..
	# dplyr::rename(STRATA_ASSUMED = STRATA) %>% 
	# left_join(., y = trans_rate_df_pass2, by = c('STRATA_ASSUMED' = 'STRATA_a')) %>% 
	left_join(x =., y = BROAD_STOCK_RATE_TABLE, by = c('SPECIES_STOCK')) %>% 
	mutate(COAL_RATE = case_when(n_obs_trips_f >= 5 ~ trans_rate  # this is an in season rate
															 , n_obs_trips_f < 5 & n_obs_trips_p >=5 ~ trans_rate  # this is a final IN SEASON rate taking transition into account
															 , n_obs_trips_f < 5 & n_obs_trips_p < 5 ~ ARATE  # assumed rate
		                           )
	) %>% 
	mutate(COAL_RATE = coalesce(COAL_RATE, BROAD_STOCK_RATE)) %>%
	mutate(SPECIES_ITIS_EVAL = species_itis
 				 , COMNAME_EVAL = species$COMNAME[i]
 				 , FISHING_YEAR = FY
 				 , FY_TYPE = FY_TYPE) 

#
# add discard source
#


# >5 trips in season gets in season rate
# < 5 i nseason but >=5 past year gets transition
# < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
# <5, <5,  and <5 gets broad stock rate

joined_table = joined_table %>% 
    mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) ~ 'O'
    																	, is.na(LINK1) & n_obs_trips_f >= 5 ~ 'I'
    																	# , is.na(LINK1) & COAL_RATE == previous_season_rate ~ 'P'
    																	, is.na(LINK1) & n_obs_trips_f < 5 & n_obs_trips_p >=5 ~ 'T'
    																	, is.na(LINK1) & n_obs_trips_f < 5 &
    																		n_obs_trips_p < 5 &
    																		!is.na(ARATE) ~ 'A'
    																	, is.na(LINK1) & n_obs_trips_f < 5 &
    																		n_obs_trips_p < 5 &
    																		is.na(ARATE) ~ 'B'
    																	# , is.na(LINK1) & 
    																	# 	n_obs_trips_f < 5 & 
    																	# 	n_obs_trips_p < 5 & ~ 'B'
    																		# n_obs_trips_f_a < 5 & 
    																		# n_obs_trips_p_a < 5 
    																	)  # this may be replaced with model estimate!
    			 )

#
# make sure CV type matches DISCARD SOURCE}
#

# obs trips get 0, broad stock rate is NA


joined_table = joined_table %>% 
	mutate(CV = case_when(DISCARD_SOURCE == 'O' ~ 0
												, DISCARD_SOURCE == 'I' ~ CV_f
												, DISCARD_SOURCE == 'T' ~ CV_f
												, DISCARD_SOURCE == 'B' ~ CV_b
												# , DISCARD_SOURCE == 'A' ~ CV_f_a
												# , DISCARD_SOURCE == 'AT' ~ CV_f_a
												)  # , DISCARD_SOURCE == 'B' ~ NA
				 )


# Make note of the stratification variables used according to discard source

strata_nongf = paste(stratvars_nongf, collapse = ';')
strata_nongf_a = paste(stratvars_nongf[1:2], collapse = ';')
strata_nongf_b = stratvars_nongf[1]

joined_table = joined_table %>% 
	mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' ~ ''
												, DISCARD_SOURCE == 'I' ~ strata_nongf
												, DISCARD_SOURCE == 'T' ~ strata_nongf
												, DISCARD_SOURCE == 'A' ~ strata_nongf_a
												, DISCARD_SOURCE == 'B' ~ strata_nongf_b
												) 
				 )


#
# get the discard for each trip using COAL_RATE}
#

# discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio. 
# the KALLs should be small.. 

joined_table = joined_table %>% 
	mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
	mutate(DISCARD = case_when(!is.na(LINK1) ~ DISC_MORT_RATIO*OBS_DISCARD
														 , is.na(LINK1) ~ DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS)
				 )
 
 
 # saveRDS(joined_table, file = paste0('~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/discard_est_', species_itis, '_non_gftrips.RDS'))

fst::write_fst(x = joined_table, path = paste0('~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/discard_est_', species_itis, '_non_gftrips', FY,'.fst'))
 
t2 = Sys.time()
	
print(paste('RUNTIME: ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))
 
}




scal_trips = non_gf_dat %>% 
	filter(substr(ACTIVITY_CODE_1,1,3) == 'SES') 
# %>% 
# 	mutate(PROGRAM = substr(ACTIVITY_CODE_1, 9, 10)) %>% 
#   mutate( SCALLOP_AREA = case_when(PROGRAM == 'OP' ~ 'OPEN' 
#        , PROGRAM == 'NS' ~ 'NLS'
#        , PROGRAM == 'NN' ~ 'NLSN'
#        , PROGRAM == 'NH' ~ 'NLSS'  # includes the NLS south Deep
#        , PROGRAM == 'NW' ~ 'NLSW'
#        , PROGRAM == '1S' ~ 'CAI'
#        , PROGRAM == '2S' ~ 'CAII'
#        , PROGRAM %in% c('MA', 'ET', 'EF', 'HC', 'DM') ~ 'MAA'
# 	   )
# ) %>% 
# 	mutate(SCALLOP_AREA = dplyr::coalesce(SCALLOP_AREA, 'OPEN')) 
# 
# scal_trips$ACCESSAREA[scal_trips$SCALLOP_AREA == 'OPEN'] = 'OPEN'


stratvars_scalgf = c('SPECIES_STOCK'
              ,'CAMS_GEAR_GROUP'
							, 'MESHGROUP'
						  , 'TRIPCATEGORY'
						  , 'ACCESSAREA'
							, 'SCALLOP_AREA')

scal_gf_species = species[species$SPECIES_ITIS %in% c('172909', '172746'),]

# NEED TO LOOP OVER TWO YEARS EACH TIME BEACUSE OF MISMATCH IN GROUNDFISH/SCALLOP YEAR.. E.G. GF YEAR 2018 NEEDS SCAL YEAR 2018 AND 2019.. 
# THIS NEEDS TO BE DONE HERE BECAUSE THE TABLE SUBSTITUTION IS THE NEXT CHUNK... 

for(yy in FY:(FY+1)){

for(i in 1:length(scal_gf_species$SPECIES_ITIS)){

t1 = Sys.time()	
	
print(paste0('ESTIMATING SCALLOP TRIP DISCARDS FOR ', scal_gf_species$COMNAME[i]))	
	
# species_nespp3 = species$NESPP3[i]  
species_itis = scal_gf_species$SPECIES_ITIS[i] 
#---#
# Support table import by species

# GEAR TABLE
CAMS_GEAR_STRATA = tbl(bcon, sql('  select * from MAPS.CAMS_GEARCODE_STRATA')) %>% 
    collect() %>% 
  dplyr::rename(GEARCODE = VTR_GEAR_CODE) %>% 
	filter(SPECIES_ITIS == '079718') %>%  # scallop strata needed here.. or go with above code
  dplyr::select(-NESPP3, -SPECIES_ITIS)

# Stat areas table  
# unique stat areas for stock ID if needed
STOCK_AREAS = tbl(bcon, sql('select * from MAPS.CAMS_STATAREA_STOCK')) %>%
	filter(SPECIES_ITIS == species_itis) %>%
    collect() %>% 
  group_by(AREA_NAME, SPECIES_ITIS) %>% 
  distinct(STAT_AREA) %>%
  mutate(AREA = as.character(STAT_AREA)
         , SPECIES_STOCK = AREA_NAME) %>% 
  ungroup() 
# %>% 
#   dplyr::select(SPECIES_STOCK, AREA)

# Mortality table
CAMS_DISCARD_MORTALITY_STOCK = tbl(bcon, sql("select * from MAPS.CAMS_DISCARD_MORTALITY_STOCK"))  %>%
  collect() %>%
  mutate(SPECIES_STOCK = AREA_NAME
         , GEARCODE = CAMS_GEAR_GROUP
  			 , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  select(-AREA_NAME) %>%
  # mutate(CAREA = as.character(STAT_AREA)) %>% 
  # filter(NESPP3 == species_nespp3) %>% 
	filter(SPECIES_ITIS == species_itis) %>%
  dplyr::select(-SPECIES_ITIS) %>% 
  dplyr::rename(DISC_MORT_RATIO = Discard_Mortality_Ratio)

#---------#
# haddock example trips with full strata either in year_t or year _t-1
#---------#

# print(paste0("Getting in-season rates for ", species_itis, " ", FY))

# make tables
ddat_focal <- scal_trips %>% 
  filter(SCAL_YEAR == yy) %>%   ## time element is here!! NOTE THE SCAL YEAR>>>
  filter(AREA %in% STOCK_AREAS$AREA) %>% 
  mutate(LIVE_POUNDS = SUBTRIP_KALL
         ,SEADAYS = 0
	  		 , NESPP3 = NESPP3_FINAL) %>% 
   left_join(., y = STOCK_AREAS, by = 'AREA') %>% 
   left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>% 
   left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
            , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
            ) %>% 
	dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y) %>% 
	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x') %>% 
  relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')


ddat_prev <- scal_trips %>% 
  filter(SCAL_YEAR == yy-1) %>%   ## time element is here!! NOTE THE SCAL YEAR>>>
  filter(AREA %in% STOCK_AREAS$AREA) %>% 
  mutate(LIVE_POUNDS = SUBTRIP_KALL
         ,SEADAYS = 0
	  		 , NESPP3 = NESPP3_FINAL) %>% 
   left_join(., y = STOCK_AREAS, by = 'AREA') %>% 
   left_join(., y = CAMS_GEAR_STRATA, by = 'GEARCODE') %>% 
   left_join(., y = CAMS_DISCARD_MORTALITY_STOCK
            , by = c('SPECIES_STOCK', 'CAMS_GEAR_GROUP')
            ) %>%  
		dplyr::select(-SPECIES_ITIS.y, -GEARCODE.y) %>% 
	dplyr::rename(SPECIES_ITIS = 'SPECIES_ITIS.x', GEARCODE = 'GEARCODE.x') %>% 
  relocate('COMMON_NAME','SPECIES_ITIS','NESPP3','SPECIES_STOCK','CAMS_GEAR_GROUP','DISC_MORT_RATIO')



# need to slice the first record for each observed trip.. these trips are multi rowed while unobs trips are single row.. 
# need to select only discards for species evaluated. All OBS trips where nothing of that species was disacrded Must be zero!

ddat_focal_scal = ddat_focal %>% 
  filter(!is.na(LINK1)) %>% 
	mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
																					)) %>% 
	mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>% 
  group_by(LINK1, VTRSERNO) %>% 
	arrange(desc(SPECIES_EVAL_DISCARD)) %>% 
	slice(1) %>% 
  ungroup()

# and join to the unobserved trips

ddat_focal_scal = ddat_focal_scal %>% 
  union_all(ddat_focal %>% 
              filter(is.na(LINK1)) %>% 
               # group_by(VTRSERNO, CAMSID) %>% 
               # slice(1) %>% 
               ungroup()
            )


# if using the combined catch/obs table, which seems necessary for groundfish.. need to roll your own table to use with run_discard function
# DO NOT NEED TO FILTER SPECIES HERE. NEED TO RETAIN ALL TRIPS. THE MAKE_BDAT_FOCAL.R FUNCTION TAKES CARE OF THIS. 

bdat_scal = ddat_focal %>% 
  filter(!is.na(LINK1)) %>% 
  mutate(DISCARD_PRORATE = DISCARD
         , OBS_AREA = AREA
         , OBS_HAUL_KALL_TRIP = OBS_KALL
         , PRORATE = 1)


# set up trips table for previous year
ddat_prev_scal = ddat_prev %>% 
  filter(!is.na(LINK1)) %>% 
	mutate(SPECIES_EVAL_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD
																					)) %>% 
	mutate(SPECIES_EVAL_DISCARD = coalesce(SPECIES_EVAL_DISCARD, 0)) %>% 
  group_by(LINK1, VTRSERNO) %>% 
	arrange(desc(SPECIES_EVAL_DISCARD)) %>% 
	slice(1) %>% 
  ungroup()

ddat_prev_scal = ddat_prev_scal %>% 
  union_all(ddat_prev %>% 
  						 filter(is.na(LINK1)) %>% 
               # group_by(VTRSERNO, CAMSID) %>% 
               # slice(1) %>% 
               ungroup()
  					)


# previous year observer data needed.. 
bdat_prev_scal = ddat_prev %>% 
  filter(!is.na(LINK1)) %>% 
  mutate(DISCARD_PRORATE = DISCARD
         , OBS_AREA = AREA
         , OBS_HAUL_KALL_TRIP = OBS_KALL
         , PRORATE = 1)

# Run the discaRd functions on previous year
d_prev = run_discard(bdat = bdat_prev_scal
											 , ddat = ddat_prev_scal
											 , c_o_tab = ddat_prev
										   , species_itis = species_itis
											 , stratvars = stratvars_scalgf
											 # , aidx = c(1:length(stratvars))
										   , aidx = c(1:2) # uses GEAR as assumed
											 )


# Run the discaRd functions on current year
d_focal = run_discard(bdat = bdat_scal
											 , ddat = ddat_focal_scal
											 , c_o_tab = ddat_focal
											 , species_itis = species_itis
											 , stratvars = stratvars_scalgf
											 # , aidx = c(1:length(stratvars))  # this makes sure this isn't used.. 
											 , aidx = c(1:2) # uses GEAR as assumed
											 )

# summarize each result for convenience
dest_strata_p = d_prev$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
                       , N = N
                       , n = n
                       , orate = round(n/N, 2)
                       , drate = RE_mean
                       , KALL = K, disc_est = round(D)
                       , CV = round(RE_rse, 2)
										)

# substitute transition rates where needed

trans_rate_df = dest_strata_f %>% 
  left_join(., dest_strata_p, by = 'STRATA') %>% 
  mutate(STRATA = STRATA
         , n_obs_trips_f = n.x
  			 , n_obs_trips_p = n.y
         , in_season_rate = drate.x
         , previous_season_rate = drate.y
  ) %>% 
	mutate(n_obs_trips_p = coalesce(n_obs_trips_p, 0)) %>% 
  mutate(trans_rate = get.trans.rate(l_observed_trips = n_obs_trips_f
                                         , l_assumed_rate = previous_season_rate
                                         , l_inseason_rate = in_season_rate
                                         )
         ) %>% 
  dplyr::select(STRATA
         , n_obs_trips_f
         , n_obs_trips_p
         , in_season_rate 
         , previous_season_rate 
         , trans_rate
         , CV_f = CV.x
         )


trans_rate_df = trans_rate_df %>% 
  mutate(final_rate = case_when((in_season_rate != trans_rate & !is.na(trans_rate)) ~ trans_rate)) 
  
 trans_rate_df$final_rate = coalesce(trans_rate_df$final_rate, trans_rate_df$in_season_rate)

 
 trans_rate_df_full = trans_rate_df
 
 full_strata_table = trans_rate_df_full %>% 
   right_join(., y = d_focal$res, by = 'STRATA') %>% 
   as_tibble() %>% 
 	 	mutate(SPECIES_ITIS_EVAL = species_itis
 				 , COMNAME_EVAL = species$COMNAME[i]
 				 , FISHING_YEAR = yy
 				 , FY_TYPE = FY_TYPE) %>% 
 	   dplyr::rename(FULL_STRATA = STRATA) 
 
#
# join full and assumed strata tables
#
 
# BROAD_STOCK_RATE_TABLE = d_focal$res %>% 
#  	group_by(SPECIES_STOCK) %>% 
#  	dplyr::summarise(BROAD_STOCK_RATE = mean(ARATE, na.rm = T)) # mean rate is max rate.. they are all the same within STOCK, as they should be 
 
# get a broad stock rate across all gears (no stratification)
# NOTE: This is slightly different than what is used for GF trips. 
# For non-GF trips, the Assumed rate above is GEAR/MESH.
 
# do broad stock using discaRd...
 # Run the discaRd functions on current year
 
BROAD_STOCK_RATE_TABLE = list()

kk = 1

ustocks = bdat_scal$SPECIES_STOCK %>% unique()

for(k in ustocks){
	BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_rate(bdat = bdat_scal
											 , ddat_focal_sp = ddat_focal_scal
											 , ddat_focal = ddat_focal
											 , species_itis = species_itis
											 , stratvars = stratvars_scalgf[1]
											 # , aidx = 1
											 , stock = k 
											 )
	kk = kk+1
}

BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

rm(kk, k)


# BROAD_STOCK_RATE_TABLE = make_assumed_rate(bdat_scal
# 																					 , species_itis = species$SPECIES_ITIS[i]
# 																					 , stratvars = stratvars_scalgf[1]) %>% 
#  	mutate(SPECIES_STOCK = STRATA
#  				 , STRAT_DESC = paste(stratvars_scalgf[1], sep = '-')) %>% 
#  	dplyr::rename('BROAD_STOCK_RATE' = 'dk') %>% 
#  	dplyr::select(-STRATA, -KALL, -BYCATCH)
#  
print(paste0("Constructing output table for ", species_itis, " in SCALLOP YEAR ", yy)) 

joined_table = assign_strata(full_strata_table, stratvars_scalgf) %>% 
	left_join(x =., y = BROAD_STOCK_RATE_TABLE, by = c('SPECIES_STOCK')) %>% 
	mutate(COAL_RATE = case_when(n_obs_trips_f >= 5 ~ trans_rate  # this is an in season rate
															 , n_obs_trips_f < 5 & n_obs_trips_p >=5 ~ trans_rate  # this is a final IN SEASON rate taking transition into account
															 , n_obs_trips_f < 5 & n_obs_trips_p < 5 ~ ARATE  # assumed rate
		                           )
	) %>% 
	mutate(COAL_RATE = coalesce(COAL_RATE, BROAD_STOCK_RATE)) %>%
	mutate(SPECIES_ITIS_EVAL = species_itis
 				 , COMNAME_EVAL = species$COMNAME[i]
 				 , FISHING_YEAR = yy
 				 , FY_TYPE = FY_TYPE) 

#
# add discard source
#


# >5 trips in season gets in season rate
# < 5 i nseason but >=5 past year gets transition
# < 5 and < 5 in season, but >= 5 sector rolled up rate (in season) gets get sector rolled up rate
# <5, <5,  and <5 gets broad stock rate

joined_table = joined_table %>% 
    mutate(DISCARD_SOURCE = case_when(!is.na(LINK1) ~ 'O'
    																	, is.na(LINK1) & n_obs_trips_f >= 5 ~ 'I'
    																	# , is.na(LINK1) & COAL_RATE == previous_season_rate ~ 'P'
    																	, is.na(LINK1) & n_obs_trips_f < 5 & n_obs_trips_p >=5 ~ 'T'
    																	, is.na(LINK1) & n_obs_trips_f < 5 &
    																		n_obs_trips_p < 5 &
    																		!is.na(ARATE) ~ 'A'
    																	, is.na(LINK1) & n_obs_trips_f < 5 &
    																		n_obs_trips_p < 5 &
    																		is.na(ARATE) ~ 'B'
    																	# , is.na(LINK1) & 
    																	# 	n_obs_trips_f < 5 & 
    																	# 	n_obs_trips_p < 5 & ~ 'B'
    																		# n_obs_trips_f_a < 5 & 
    																		# n_obs_trips_p_a < 5 
    																	)  # this may be replaced with model estimate!
    			 )

#
# make sure CV type matches DISCARD SOURCE}
#

# obs trips get 0, broad stock rate is NA


joined_table = joined_table %>% 
	mutate(CV = case_when(DISCARD_SOURCE == 'O' ~ 0
												, DISCARD_SOURCE == 'I' ~ CV_f
												, DISCARD_SOURCE == 'T' ~ CV_f
												, DISCARD_SOURCE == 'B' ~ CV_b
												# , DISCARD_SOURCE == 'A' ~ CV_f_a
												# , DISCARD_SOURCE == 'AT' ~ CV_f_a
												)  
				 )


# Make note of the stratification variables used according to discard source

strata_scalgf = paste(stratvars_scalgf, collapse = ';')
strata_scalgf_a = paste(stratvars_scalgf[1:2], collapse = ';')
strata_scalgf_b = stratvars_scalgf[1]

joined_table = joined_table %>% 
	mutate(STRATA_USED = case_when(DISCARD_SOURCE == 'O' ~ ''
												, DISCARD_SOURCE == 'I' ~ strata_scalgf
												, DISCARD_SOURCE == 'T' ~ strata_scalgf
												, DISCARD_SOURCE == 'A' ~ strata_scalgf_a
												, DISCARD_SOURCE == 'B' ~ strata_scalgf_b
												) 
				 )


#
# get the discard for each trip using COAL_RATE}
#

# discard mort ratio tht are NA for odd gear types (e.g. cams gear 0) get a 1 mort ratio. 
# the KALLs should be small.. 

joined_table = joined_table %>% 
	mutate(DISC_MORT_RATIO = coalesce(DISC_MORT_RATIO, 1)) %>%
	mutate(DISCARD = case_when(!is.na(LINK1) ~ DISC_MORT_RATIO*OBS_DISCARD
														 , is.na(LINK1) ~ DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS)
				 )
 
 
 # saveRDS(joined_table, file = paste0('~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/discard_est_', species_itis, '_non_gftrips.RDS'))

fst::write_fst(x = joined_table, path = paste0('~/PROJECTS/discaRd/CAMS/MODULES/APRIL/OUTPUT/discard_est_', species_itis, '_scal_trips_SCAL', yy,'.fst'))
 
t2 = Sys.time()
	
print(paste(species_itis, ' SCALLOP DISCARDS RAN IN ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))
 
 }
}





# for(j in 2018:2019){
start_time = Sys.time()
		
	GF_YEAR = FY

	for(i in 1:length(scal_gf_species$SPECIES_ITIS)){
			
		print(paste0('Adding scallop trip estimates of: ',  scal_gf_species$COMNAME[i], ' for Groundfish Year ', GF_YEAR))
			
		sp_itis = scal_gf_species$SPECIES_ITIS[i]
		
		# get only the non-gf trips for each species and fishing year	
		gf_file_dir = '~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/'
		gf_files = list.files(gf_file_dir, pattern = paste0('discard_est_', sp_itis), full.names = T)
		gf_files = gf_files[grep(GF_YEAR, gf_files)]
		gf_files = gf_files[grep('non_gf', gf_files)]
		
		# get list all scallop trips bridging fishing years												
		scal_file_dir = '~/PROJECTS/discaRd/CAMS/MODULES/APRIL/OUTPUT/'
		scal_files = list.files(scal_file_dir, pattern = paste0('discard_est_', sp_itis), full.names = T)
		
		# read in files 
		res_scal = lapply(as.list(scal_files), function(x) fst::read_fst(x))
		res_gf = lapply(as.list(gf_files), function(x) fst::read_fst(x))
		
		# create standard output table structures for scallop trips
		# outlist <- lapply(res_scal, function(x) { 
		# 		x %>% 
		# 		mutate(GF_STOCK_DEF = paste0(COMNAME_EVAL, '-', SPECIES_STOCK)) %>% 
		# 		dplyr::select(-COMMON_NAME, -SPECIES_ITIS) %>% 
		# 	dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
		# 								, 'CAMS_DISCARD_RATE' = 'COAL_RATE'
		# 								, 'COMMON_NAME' = 'COMNAME_EVAL'
		# 								, 'SPECIES_ITIS' = 'SPECIES_ITIS_EVAL'
		# 								, 'ACTIVITY_CODE' = 'ACTIVITY_CODE_1'
		# 								, 'N_OBS_TRIPS_F' = 'n_obs_trips_f'
		# 								) %>% 
		# 	mutate(DATE_RUN = as.character(Sys.Date())
		# 				 , FY = as.integer(FY)) %>%
		# 	dplyr::select(
		# 		DATE_RUN,
		# 		FY,
		# 		YEAR,
		# 		MONTH,
		# 		SPECIES_ITIS,
		# 		COMMON_NAME,
		# 		FY_TYPE,
		# 		ACTIVITY_CODE,
		# 		VTRSERNO,
		# 		CAMSID,
		# 		FED_OR_STATE,
		# 		GF,
		# 		AREA,
		# 		LINK1,
		# 		N_OBS_TRIPS_F,
		# 		STRATA_USED,
		# 		STRATA_FULL,
		# 		STRATA_ASSUMED,
		# 		DISCARD_SOURCE,
		# 		OBS_DISCARD,
		# 		SUBTRIP_KALL,
		# 		BROAD_STOCK_RATE,
		# 		CAMS_DISCARD_RATE,
		# 		DISC_MORT_RATIO,
		# 		DISCARD,
		# 		CV,
		# 		SPECIES_STOCK,
		# 		CAMS_GEAR_GROUP,
		# 		MESHGROUP,
		# 		SECTID,
		# 		EM,
		# 		REDFISH_EXEMPTION,
		# 		SNE_SMALLMESH_EXEMPTION,
		# 		XLRG_GILLNET_EXEMPTION,
		# 		TRIPCATEGORY,
		# 		ACCESSAREA,
		# 		SCALLOP_AREA
		# 	  # eval(strata_unique)
		# 	)
		# 	
		# }
		# )
		# 
		# rm(res_scal)
				
		# assign(paste0('outlist_df_scal'),  do.call(rbind, outlist))
		assign(paste0('outlist_df_scal'),  do.call(rbind, res_scal))
		
		# rm(outlist)
		
		# now do the same for GF trips
		
		# outlist <- lapply(res_gf, function(x) { 
		# 		x %>% 
		# 		mutate(GF_STOCK_DEF = paste0(COMNAME_EVAL, '-', SPECIES_STOCK)) %>% 
		# 		dplyr::select(-COMMON_NAME, -SPECIES_ITIS) %>% 
		# 	dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
		# 								, 'CAMS_DISCARD_RATE' = 'COAL_RATE'
		# 								, 'COMMON_NAME' = 'COMNAME_EVAL'
		# 								, 'SPECIES_ITIS' = 'SPECIES_ITIS_EVAL'
		# 								, 'ACTIVITY_CODE' = 'ACTIVITY_CODE_1'
		# 								, 'N_OBS_TRIPS_F' = 'n_obs_trips_f'
		# 								) %>% 
		# 	mutate(DATE_RUN = as.character(Sys.Date())
		# 				 , FY = as.integer(FY)) %>%
		# 	dplyr::select(
		# 		DATE_RUN,
		# 		FY,
		# 		YEAR,
		# 		MONTH,
		# 		SPECIES_ITIS,
		# 		COMMON_NAME,
		# 		FY_TYPE,
		# 		ACTIVITY_CODE,
		# 		VTRSERNO,
		# 		CAMSID,
		# 		FED_OR_STATE,
		# 		GF,
		# 		AREA,
		# 		LINK1,
		# 		N_OBS_TRIPS_F,
		# 		STRATA_USED,
		# 		STRATA_FULL,
		# 		STRATA_ASSUMED,
		# 		DISCARD_SOURCE,
		# 		OBS_DISCARD,
		# 		SUBTRIP_KALL,
		# 		BROAD_STOCK_RATE,
		# 		CAMS_DISCARD_RATE,
		# 		DISC_MORT_RATIO,
		# 		DISCARD,
		# 		CV,
		# 		SPECIES_STOCK,
		# 		CAMS_GEAR_GROUP,
		# 		MESHGROUP,
		# 		SECTID,
		# 		EM,
		# 		REDFISH_EXEMPTION,
		# 		SNE_SMALLMESH_EXEMPTION,
		# 		XLRG_GILLNET_EXEMPTION,
		# 		TRIPCATEGORY,
		# 		ACCESSAREA
		# 		# SCALLOP_AREA
		# 	  # eval(strata_unique)
		# 	) %>% 
		# 		mutate(SCALLOP_AREA = '')
		# 	
		# }
		# )
		
		# rm(res_gf)
				
		# assign(paste0('outlist_df_',sp_itis,'_',GF_YEAR),  do.call(rbind, outlist))
				assign(paste0('outlist_df_',sp_itis,'_',GF_YEAR),  do.call(rbind, res_gf))
		
		# rm(outlist)
		
		t1  = get(paste0('outlist_df_',sp_itis,'_',GF_YEAR))
		t2 = get(paste0('outlist_df_scal'))	%>% 
			filter(GF_YEAR == GF_YEAR)
		
		# index scallop records present in groundfish year table 
		t2idx = t2$CAMS_SUBTRIP %in% t1$CAMS_SUBTRIP # & t2$CAMSID %in% t1$CAMSID
		
		# index records in groundfish table to be removed
		t1idx = t1$CAMS_SUBTRIP %in% t2$CAMS_SUBTRIP # & t1$CAMSID %in% t2$CAMSID
		
		# swap the scallop estimated trips into the groundfish records
		t1[t1idx,] = t2[t2idx,]
		
		
		# test against the scallop fy 19
		# t2 %>% 
		# 	filter(YEAR == 2019 & MONTH >= 4) %>% 
		# 	bind_rows(t2 %>% 
		# 	filter(YEAR == 2020 & MONTH < 4)) %>% 
		# 	group_by(SPECIES_STOCK, ACCESSAREA, FED_OR_STATE) %>% 
		# 	dplyr::summarise(round(sum(DISCARD, na.rm = T))) %>% 
		#   write.csv(paste0('~/PROJECTS/discaRd/CAMS/MODULES/APRIL/OUTPUT/', sp_itis,'_for_SCAL_YEAR_2019.csv'), row.names = F)
		
		write_fst(x = t1, path = gf_files)
		
		end_time = Sys.time()
		
		print(paste('Scallop subsitution took: ', round(difftime(end_time, start_time, units = "mins"),2), ' MINUTES',  sep = ''))
		
		# look at the GF table with scallop trips swapped in. tHIS WILL BE LOWER SINCE THE FISHIGN YEARS BEGIN AT DIFFERNT MONTHS
		# t1 %>% 
		# 	filter(YEAR == 2019 & MONTH >= 5) %>% 
		# 	bind_rows(t1 %>% 
		# 	filter(YEAR == 2020 & MONTH < 4)) %>% 
		# 	filter(substr(ACTIVITY_CODE, 1,3) == 'SES') %>% 
		# 	group_by(SPECIES_STOCK, ACCESSAREA, SPECIES_ITIS, FED_OR_STATE) %>% 
		# 	dplyr::summarise(round(sum(DISCARD, na.rm = T)))
			# write.csv(paste0('~/PROJECTS/discaRd/CAMS/MODULES/APRIL/OUTPUT/', sp_itis,'_for_SCAL_YEAR_2019.csv'), row.names = F)
		
	
	}
	
# }
