# 1. Groundfish ----
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
 mutate('RUN_ID' = 'GROUNDFISH') %>% 
	dplyr::rename('ITIS_TSN' = 'SPECIES_ITIS')

# 2. calendar year ----
	
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
		
		filter(ITIS_TSN %in% itis_num) %>% 
		group_by(ITIS_TSN) %>%
		slice(1) %>% 
		dplyr::select(ITIS_TSN, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'CALENDAR')
	
# 3. May year ----
	
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
		
		filter(ITIS_TSN %in% itis_num) %>% 
		group_by(ITIS_TSN) %>%
		slice(1)	%>% 
		dplyr::select(ITIS_TSN, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'MAY')
	
# 4. November ----
	
	
	#--------------------------------------------------------------------------#
	# group of species
	itis <-  c('168546',
						 '168543')
	
	#itis <- itis
	itis_num <- as.numeric(itis)
	
	
	nov_species = tbl(con_maps, sql("select *
												from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
		collect() %>% 
		filter(ITIS_TSN %in% itis_num) %>% 
		group_by(ITIS_TSN) %>%
		slice(1)%>% 
		dplyr::select(ITIS_TSN, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'NOVEMBER')
	
# 5. March ----
	
	#--------------------------------------------------------------------------#
	# group of species
	itis <-  c('620992')
	
	#itis <- itis
	itis_num <- as.numeric(itis)
	
	march_species = tbl(con_maps, sql("select *
												from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
		collect() %>% 
		filter(ITIS_TSN %in% itis_num) %>% 
		group_by(ITIS_TSN) %>%
		slice(1) %>% 
		dplyr::select(ITIS_TSN, COMMON_NAME, NESPP3) %>% 
		mutate('RUN_ID' = 'MARCH') %>% 
		ungroup()

# 6. April ----

#--------------------------------------------------------------------------#
# group of species
	itis <-  c('079718')

#itis <- itis
# itis_num <- as.numeric(itis)

april_species = tbl(con_maps, sql("select *
											from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
	collect() %>% 
	filter(ITIS_TSN %in% itis) %>% 
	group_by(ITIS_TSN) %>%
	slice(1) %>% 
	dplyr::select(ITIS_TSN, COMMON_NAME, NESPP3) %>% 
	mutate('RUN_ID' = 'APRIL')

# 6. Herring ----

#--------------------------------------------------------------------------#
# group of species
itis <-  c('161722')

#itis <- itis
# itis_num <- as.numeric(itis)

herring_species = tbl(con_maps, sql("select *
											from MAPS.CAMS_DISCARD_MORTALITY_STOCK")) %>% 
	collect() %>% 
	filter(ITIS_TSN %in% itis) %>% 
	group_by(ITIS_TSN) %>%
	slice(1) %>% 
	dplyr::select(ITIS_TSN, COMMON_NAME, NESPP3) %>% 
	mutate('RUN_ID' = 'HERRING')

# 7. Combine ----
	
runid_tab = bind_rows(gf_species, cal_species, may_species, nov_species, march_species, april_species, herring_species) 

#	*	7.1 Replace common name with CAMS standard ----

cfg_itis = tbl(con_maps, sql('select * from maps.cfg_itis')) %>% 
	collect()

runid_tab = runid_tab %>% 
	dplyr::select(-COMMON_NAME) %>% 
	left_join(., cfg_itis, by = 'ITIS_TSN') %>% 
	dplyr::select(ITIS_TSN, NESPP3, ITIS_NAME, RUN_ID) %>% 
	group_by(ITIS_TSN) %>% 
	slice(1) %>% 
	ungroup()


# * 7.2 replace ascii characters in common names ----

# not needed if not writing to Oracle based on common name

# runid_tab$ITIS_NAME = stringr::str_replace(runid_tab$ITIS_NAME, pattern = '-', replacement = '_')
# runid_tab$ITIS_NAME = stringr::str_replace(runid_tab$ITIS_NAME, pattern = ' ', replacement = '_')
# runid_tab$ITIS_NAME = stringr::str_replace(runid_tab$ITIS_NAME, pattern = ',', replacement = '_')
# 
# runid_tab$ITIS_NAME = stringr::str_replace(runid_tab$ITIS_NAME, pattern = "[(]", replacement = '')
# runid_tab$ITIS_NAME = stringr::str_replace(runid_tab$ITIS_NAME, pattern = "[)]", replacement = '')


# runid_tab %>% View()

# 8. write to csv ----

write.csv(runid_tab, paste0(here::here('inst/SUPPORT_TABLES/'),'species_runid.csv'), row.names = F)

write.csv(runid_tab, paste0(here::here('../MAPS/data-raw/'),'species_runid.csv'), row.names = F)

# 9. upload to Oracle ----

dbWriteTable(conn = con_maps, name = 'CFG_DISCARD_RUNID', value = runid_tab, overwrite = T)
