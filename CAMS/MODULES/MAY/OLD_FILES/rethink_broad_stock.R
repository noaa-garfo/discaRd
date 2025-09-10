# 1. import data

# 2. run may loop up to to the broad stock section

# 3. fix some things in the function

get_broad_stock_gear_rate = function(bdat, ddat_focal_sp, ddat_focal, species_itis, stratvars, stock = 'GOM', CAMS_GEAR_GROUP = '0'){ 	
	
	btmp = 	bdat %>%
		filter(SPECIES_ESTIMATION_REGION == stock & CAMS_GEAR_GROUP == CAMS_GEAR_GROUP)
	dstmp = ddat_focal_sp %>%
		filter(SPECIES_ESTIMATION_REGION == stock & CAMS_GEAR_GROUP == CAMS_GEAR_GROUP)
	dtmp = 	ddat_focal %>%
		filter(SPECIES_ESTIMATION_REGION == stock & CAMS_GEAR_GROUP == CAMS_GEAR_GROUP)
	
	d_broad_stock = run_discard(bdat = btmp
															, ddat = dstmp
															, c_o_tab = dtmp
															, species_itis = species_itis
															, stratvars = stratvars
															, aidx = 1:length(stratvars)  # this makes sure this isn't used..
	)
	
	
	print(d_broad_stock$allest$C)
	
	data.frame(SPECIES_ESTIMATION_REGION = stock
						 , CAMS_GEAR_GROUP = CAMS_GEAR_GROUP
						 , BROAD_STOCK_RATE = d_broad_stock$allest$rTOT
						 , CV_b = d_broad_stock$allest$CVTOT
	)
	
	
	
}


#------------------------------------------------------------------------------------------
# 4. run the discard loop for gear and stock only

BROAD_STOCK_RATE_TABLE = list()

kk = 1

ustocks = bdat_cy$SPECIES_ESTIMATION_REGION %>% unique()

UGEARS = bdat_cy$CAMS_GEAR_GROUP %>% unique()

bdat_2yrs = bind_rows(bdat_prev_cy, bdat_cy)
ddat_cy_2yr = bind_rows(ddat_prev_cy, ddat_focal_cy)
ddat_2yr = bind_rows(ddat_prev, ddat_focal)

for(k in 1:length(ustocks)){
	# for(j in 1:length(CAMS_GEAR_GROUP)){
		BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_gear_rate(bdat = bdat_2yrs
																														 , ddat_focal_sp = ddat_cy_2yr
																														 , ddat_focal = ddat_2yr
																														 , species_itis = species_itis
																														 , stratvars = stratvars[1:2]
																														 # , aidx = 1
																														 , stock = ustocks[k] 
																														 , CAMS_GEAR_GROUP = UGEARS[1]
		)
		
		kk = kk+1
}

rm(bdat_2yrs, ddat_2yr, ddat_cy_2yr)

gc()

BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

#--------------------------------------------------------------
## NOTES
# If you want to run just stock and Gear, perhaps run_discard is a better option. the get_broad_stock function was meant to grab only the final broad stock rate (i.e. d_broad_stock$allest$rTOT) for a species that has multiple stocks
# 


# 5. run the run_discard instead

i = 3 # monkfish

species_itis = species$SPECIES_ITIS[i]

mnk2 = run_discard( bdat = bdat_2yrs
			, ddat_focal = ddat_cy_2yr %>% filter(FED_OR_STATE != 'STATE')
			, c_o_tab = ddat_2yr %>% filter(FED_OR_STATE != 'STATE')
			, species_itis = species_itis
			, stratvars = stratvars[1:2]  #"SPECIES_ESTIMATION_REGION"   "CAMS_GEAR_GROUP"
			)

# rate table
mnk$allest$C

# grab strata that had n = 0
mnk$allest$C %>% 
	filter(n == 0)

# note the very high K on southern seine
# STRATA                      N n RE_mean RE_var RE_se RE_rse CV_TARG REQ_SAMPLES REQ_COV REQ_SEADAYS  D         K k d
# 1   NORTHERN_0_gillnet     74 0      NA     NA    NA     NA      NA          NA      NA          NA NA    224366 0 0
# 2 NORTHERN_0_longlinep     13 0      NA     NA    NA     NA      NA          NA      NA          NA NA      3987 0 0
# 3     NORTHERN_0_other 359172 0      NA     NA    NA     NA      NA          NA      NA          NA NA 136440244 0 0
# 4 SOUTHERN_0_longlinep    701 0      NA     NA    NA     NA      NA          NA      NA          NA NA   2564262 0 0
# 5     SOUTHERN_0_other 264294 0      NA     NA    NA     NA      NA          NA      NA          NA NA 169080804 0 0
# 6     SOUTHERN_0_seine   2720 0      NA     NA    NA     NA      NA          NA      NA          NA NA 836673654 0 0


# Broad stock
# NOTE: this final rate uses stock as a strata.. so these rates are combined for multiple stocks, This was the purpose of using the get_broad_stock function..

# final rate
mnk$allest$rTOT
# [1] 0.004870581

# final CV
mnk$allest$CVTOT
# [1] 0.05168439
