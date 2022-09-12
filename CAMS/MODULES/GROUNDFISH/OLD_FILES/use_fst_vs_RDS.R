
# test fst use vs RDS.. 

FY = 19
f1 = readRDS(resfiles[26])



write.fst(f1, path = '~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/test.fst')


tmp = fst('~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/test.fst')

incols = c(	
					'YEAR',
					'MONTH',
					'SPECIES_ITIS_EVAL',
					'COMNAME_EVAL',
					'FY_TYPE',
					'ACTIVITY_CODE_1',
					'VTRSERNO',
					'CAMSID',
					'TRIP_TYPE',
					'GF',
					'AREA',
					'LINK1',
					'n_obs_trips_f',
					'STRATA_USED',
					'FULL_STRATA',
					'STRATA_ASSUMED',
					'DISCARD_SOURCE',
					'OBS_DISCARD',
					'SUBTRIP_KALL',
					'BROAD_STOCK_RATE',
					'COAL_RATE',
					'DISC_MORT_RATIO',
					'DISCARD',
					'CV')


tmp[, incols] %>% 		
	# mutate(GF_STOCK_DEF = paste0(COMNAME_EVAL, '-', SPECIES_STOCK)) %>% 
	# dplyr::select(-COMMON_NAME, -SPECIES_ITIS) %>% 
	dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
								, 'CAMS_DISCARD_RATE' = 'COAL_RATE'
								, 'COMMON_NAME' = 'COMNAME_EVAL'
								, 'SPECIES_ITIS' = 'SPECIES_ITIS_EVAL'
								, 'ACTIVITY_CODE' = 'ACTIVITY_CODE_1'
								, 'N_OBS_TRIPS_F' = 'n_obs_trips_f'
	) %>% 
	mutate(DATE_RUN = as.character(Sys.Date())
				 , FY = as.integer(FY)) %>%
	dplyr::select(
		DATE_RUN,
		FY,
		YEAR,
		MONTH,
		SPECIES_ITIS,
		COMMON_NAME,
		FY_TYPE,
		ACTIVITY_CODE,
		VTRSERNO,
		CAMSID,
		TRIP_TYPE,
		GF,
		AREA,
		LINK1,
		N_OBS_TRIPS_F,
		STRATA_USED,
		STRATA_FULL,
		STRATA_ASSUMED,
		DISCARD_SOURCE,
		OBS_DISCARD,
		SUBTRIP_KALL,
		BROAD_STOCK_RATE,
		CAMS_DISCARD_RATE,
		DISC_MORT_RATIO,
		DISCARD,
		CV
		# eval(strata_unique)
	)
			
			