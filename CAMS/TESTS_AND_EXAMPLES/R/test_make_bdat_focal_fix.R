# Cod example check the d/k from discaRd fucntions

# check the input table



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
	
	
	bdat_focal <- bdat_focal %>%
		dplyr::group_by(LINK1
										, CAMS_SUBTRIP # new field that catenates VTRSERNO and CAMS SUBTRIP
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

#----------------------------------------------------



bdat_focal = bdat_gf %>% 
	mutate(SPECIES_DISCARD = case_when(SPECIES_ITIS == species_itis ~ DISCARD_PRORATE)) %>%
	mutate(SPECIES_DISCARD = tidyr::replace_na(SPECIES_DISCARD, 0))

bdat_focal = assign_strata(bdat_focal, stratvars = stratvars)
bdat_focal <- bdat_focal %>%
	dplyr::group_by(LINK1
									, VTRSERNO
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

bdat_focal %>% 
	group_by(STRATA) %>% 
	dplyr::summarise(k = sum(KALL), d = sum(BYCATCH)) %>% 
	mutate(dk = d/k) %>% 
	arrange(desc(k))



dest_strata_f = d_focal$allest$C %>% summarise(STRATA = STRATA
																							 , N = N
																							 , n = n
																							 , orate = round(n/N, 2)
																							 , drate = RE_mean
																							 , OBS_KALL = k
																							 , KALL = K
																							 , disc_est = round(D)
																							 , CV = round(RE_rse, 2)
)

dest_strata_f %>% arrange(desc(n)) %>% View()



joined_table %>% 
	group_by(STRATA_USED) %>% 
	dplyr::summarise(sum_subtrip_kall = sum(SUBTRIP_KALL), sum(DISCARD))

joined_table %>% 
	# filter(STRATA_USED == "") %>%
	filter(DISCARD_SOURCE == 'O') %>% 
	dplyr::select(FULL_STRATA
								,n_obs_trips_f
								, in_season_rate 
								, previous_season_rate
								, trans_rate
								, final_rate
								, in_season_rate_a
								, previous_season_rate_a
								, trans_rate_a
								, final_rate_a
								, BROAD_STOCK_RATE
								, COAL_RATE
								, OBS_DISCARD
								, DISCARD
								, OBS_KALL) %>%
	group_by(FULL_STRATA) %>% 
	dplyr::summarise(n = max(n_obs_trips_f),
									 obs_d = sum(OBS_DISCARD)
									 , obs_kall = sum(OBS_KALL)
									 ,  DK_CALC = sum(OBS_DISCARD)/sum(OBS_KALL)
									 , CAMS_DK = max(COAL_RATE)) %>% 
	mutate(dk_diff = CAMS_DK- DK_CALC) %>% 
	View()




#----------------------------------------------#

outlist_df_18 %>%
	# filter(STRATA_USED == "") %>%
	filter(DISCARD_SOURCE == 'O' & !is.na(COMMON_NAME)) %>% 
	group_by(COMMON_NAME, STRATA_FULL) %>% 
	dplyr::summarise(n = max(N_OBS_TRIPS_F),
									 obs_d = sum(OBS_DISCARD, na.rm = T)
									 , obs_kall = sum(OBS_KALL, na.rm = T)
									 ,  DK_CALC = sum(OBS_DISCARD, na.rm = T)/sum(OBS_KALL, na.rm = T)
									 , CAMS_DK = max(CAMS_DISCARD_RATE)) %>% 
	mutate(dk_diff = CAMS_DK- DK_CALC) %>% 
	View()


# look at one strata
outlist_df_18 %>% 
	filter(STRATA_FULL == 'WGB and South_50_LM_18_EM1_0_0_0' & COMMON_NAME == 'HADDOCK' & !is.na(LINK1))


joined_table %>% 
	mutate(rate_diff = final_rate - trans_rate) %>% 
	filter(n_obs_trips_f >= 5) %>%
	group_by(FULL_STRATA) %>%
	dplyr::select(final_rate, trans_rate, rate_diff) %>% 
	filter(is.na(trans_rate)) %>% 
	dplyr::summarise(max(rate_diff), max(final_rate), max(trans_rate)) %>%
	# arrange(desc(rate_diff)) %>% 
	View()

#----------------------------------------------#

library(DBI)
library(ROracle)
library(tibble)

# odbc <- dbConnect(odbc::odbc(), dsn = "PostgreSQL")
# rodbc <- dbConnect(RODBCDBI::ODBC(), dsn = "PostgreSQL")

rcon <- ROracle::dbConnect(
	drv = ROracle::Oracle(),
	username = "MAPS",
	password = "Aug01?apsd!01",  # You don’t see this
	dbname = "NERO.world"
)

ROracle::dbGetQuery(conn2, "SELECT count(*) FROM CAMS_LANDINGS")

odbc::dbDisconnect(conn2)


drv <- dbDriver("Oracle")
connect.string <- 'apsd'
rcon <- dbConnect(drv, username =dw_apsd$uid, password = dw_apsd$pwd, dbname = connect.string)

# odbc Reading
system.time(odbc_result <- dbReadTable(odbc, "flights"))

# RODBCDBI Reading
system.time(rodbc_result <- dbReadTable(rodbc, "flights"))

# odbc Reading
system.time(dbWriteTable(odbc, "flights3", as.data.frame(flights)))

# RODBCDBI Writing (note: rodbc does not support writing timestamps natively)
system.time(dbWriteTable(rodbc, "flights2", as.data.frame(flights[, names(flights) != "time_hour"])))