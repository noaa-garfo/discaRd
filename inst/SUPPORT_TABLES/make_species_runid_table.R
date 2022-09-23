#--- ├ Groundfish ----
gf_species = tbl(con_maps, sql("
select distinct(b.species_itis)
    , COMNAME
    , a.nespp3
from fso.v_obSpeciesStockArea a
left join (select *  from MAPS.CAMS_GEARCODE_STRATA) b on a.nespp3 = b.nespp3
where stock_id not like 'OTHER'
and b.species_itis is not null
")
) %>% 
	collect() %>% 
	dplyr::rename(COMMON_NAME = COMNAME) %>% 
 mutate('RUN_ID' = 'GROUNDFISH')
#--- ├calendar year --- 
	
	itis <-  c(
		'167687',
		'168559',
		'172567',
		'082372',
		'172414',
		'082521',
		'172735',
		'169182',
		'080944',
		'081343',
		'161706',
		'172413',
		'164740',
		'097314',
		'098678',
		'160230'
		)  
	
	
	itis_num <- as.character(itis)
	
	cal_species = tbl(con_maps, sql("select *
												from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
		
		collect() %>% 
		
		filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
		slice(1) %>% 
		dplyr::select(SPECIES_ITIS, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'CALENDAR')
	
# --- ├ May year ----
	
	#--------------------------------------------------------------------------#
	# group of species
	itis <-  c(
		'164499',
		'160617',
		'564139',
		'160855',
		'564136',
		'564130',
		'564151',
		'564149',
		'564145',
		'164793',
		'164730',
		'164791'
	)  
	
	itis_num <- as.numeric(itis)
	
	
	may_species = tbl(con_maps, sql("select *
												from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
		
		collect() %>% 
		
		filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
		slice(1)	%>% 
		dplyr::select(SPECIES_ITIS, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'MAY')
	
#--- ├ November ----
	
	
	#--------------------------------------------------------------------------#
	# group of species
	itis <-  c('168546',
						 '168543')
	
	#itis <- itis
	itis_num <- as.numeric(itis)
	
	
	nov_species = tbl(con_maps, sql("select *
												from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
		collect() %>% 
		filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
		slice(1)%>% 
		dplyr::select(SPECIES_ITIS, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'NOVEMBER')
	
#--- ├ March ----
	
	#--------------------------------------------------------------------------#
	# group of species
	itis <-  c('620992')
	
	#itis <- itis
	itis_num <- as.numeric(itis)
	
	march_species = tbl(con_maps, sql("select *
												from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
		collect() %>% 
		filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
		slice(1) %>% 
		dplyr::select(SPECIES_ITIS, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'MARCH')

#--- ├ April ----

#--------------------------------------------------------------------------#
# group of species
	itis <-  c('079718')

#itis <- itis
itis_num <- as.numeric(itis)

april_species = tbl(con_maps, sql("select *
											from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
	collect() %>% 
	filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
	slice(1) %>% 
	dplyr::select(SPECIES_ITIS, COMMON_NAME, NESPP3) %>% 
	mutate('RUN_ID' = 'APRIL')

#  ├ Combine ----
	
runid_tab = bind_rows(gf_species, cal_species, may_species, nov_species, april_species)

runid_tab %>% View()
