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