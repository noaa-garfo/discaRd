# evaluate groundfish results

# which geartypes have no discard source?

final_table %>%
	filter(is.na(DISCARD_SOURCE)) %>% 
	group_by(CAMS_GEAR_GROUP) %>% 
	dplyr::summarise(nvtr = n_distinct(VTRSERNO))


## primarily lobster pots. some shrimp trawls, then handlines and unknowns

# what is the discard rate for these trips?
res_list[[1]] %>%
	filter(is.na(DISCARD_SOURCE)) %>% 
	dplyr::select(
		DISCARD_SOURCE,
		CAMS_GEAR_GROUP,
		ACTIVITY_CODE_1,
		VTRSERNO,
		ARATE,
		CRATE,
		DISC_RATE,
		STRATA,
		STRATA_ASSUMED,
		LINK1,
		EST_DISCARD,
		DISCARD,
		OBS_DISCARD
	)

## no assumed rate because no obsevations
## changing the make these DISCARD_SOURCE = 'A' 



# make a smaller output table
dplyr::select(
	SPECIES_ITIS_EVAL,
	DISCARD_SOURCE,
	ACTIVITY_CODE_1,
	VTRSERNO,
	ARATE,
	CRATE,
	DISC_RATE,
	STRATA,
	STRATA_ASSUMED,
	LINK1,
	EST_DISCARD,
	DISCARD,
	OBS_DISCARD,
	eval(stratvars)
)

# --------------------------------------------
# Check Caless's results for EGB

# re-ran the haddock estimate
# recall the GEAR mathcing table had been updated

hadd = readRDS('discard_est_164744.RDS')

hadd %>% 
	filter(substr(ACTIVITY_CODE_1, 1, 3) == 'NMS' &
									SPECIES_STOCK == 'EGB') %>% 
	group_by(DISCARD_SOURCE) %>% 
	dplyr::summarise(
										OBS_DISCARD = sum(OBS_DISCARD, na.rm = T),
										FINAL_DISCARD = sum(DISCARD, na.rm = T)
									)

# look by STRATA
hadd %>% 
	filter(substr(ACTIVITY_CODE_1, 1, 3) == 'NMS' &
				 	SPECIES_STOCK == 'EGB') %>% 
	group_by(STRATA) %>% 
	dplyr::summarise(
		OBS_DISCARD = sum(OBS_DISCARD, na.rm = T),
		FINAL_DISCARD = sum(DISCARD, na.rm = T)
	)

# difference now much smaller

# A tibble: 3 x 3
DISCARD_SOURCE OBS_DISCARD FINAL_DISCARD
<chr>                <dbl>         <dbl>
	1 A                        0          880.
2 E                        0        66779.
3 O                    33926        33926 
