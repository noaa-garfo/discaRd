

#' Parse Upload Discard
#' parses discard resutls, cleans the table (e.g. infinites) and uploads to Orac;e
#' @param con connection to Oracel (e.g. MAPS)
#' @param filepath path to .fst discard results
#' @param FY Fishing Year to upload, should correspond to those results in filepath
#'
#' @return 
#' @export
#'
#' @examples
#' 
parse_upload_discard <- function(con = bcon, filepath = '~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/', FY = 2018){

	require(ROracle)
	
	t1 = Sys.time()	

assign('resfiles', list.files(path = filepath, pattern = paste0(FY,'.fst'), full.names = T))


species = lapply(stringr::str_split(resfiles, pattern = '_'), function(x) x[3]) %>% unlist %>% unique

	
for (kk in species){
	spfiles = resfiles[grep(pattern = kk, x = resfiles)]

	# vectorize over mulitple files for a year for the same species	
	res = lapply(as.list(spfiles), function(x) fst::read_fst(x))

	# vectorize over mulitple files for a year for the same species	
	outlist <- lapply(res, function(x) {
			# x = fst::read_fst(jj)
			x %>% 
			mutate(GF_STOCK_DEF = paste0(COMMON_NAME, '-', SPECIES_STOCK)) %>% 
			dplyr::select(-SPECIES_ITIS) %>%
			# dplyr::select(-COMMON_NAME, -SPECIES_ITIS) %>%
			dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
										, 'CAMS_DISCARD_RATE' = 'COAL_RATE'
										# , 'COMMON_NAME' = 'COMNAME_EVAL'
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
				FED_OR_STATE,
				GF,
				AREA,
				LINK1,
				N_OBS_TRIPS_F,
				STRATA_USED,
				STRATA_FULL,
				STRATA_ASSUMED,
				DISCARD_SOURCE,
				OBS_DISCARD,
				OBS_KALL,
				SUBTRIP_KALL,
				BROAD_STOCK_RATE,
				CAMS_DISCARD_RATE,
				DISC_MORT_RATIO,
				DISCARD,
				CV,
				SPECIES_STOCK,
				CAMS_GEAR_GROUP,
				MESHGROUP,
				SECTID,
				EM,
				REDFISH_EXEMPTION,
				SNE_SMALLMESH_EXEMPTION,
				XLRG_GILLNET_EXEMPTION,
				TRIPCATEGORY,
				ACCESSAREA,
				SCALLOP_AREA
				# eval(strata_unique)
			)
		
} ) # end lapply

	

	
	# convert list to data frame
	outlist = do.call(rbind, outlist)
	
	# adjust for DISACRD_SOURCE = N, nan and infinite values	
	
	outlist <- outlist %>% 
		dplyr::mutate(DISCARD_SOURCE = case_when(is.na(DISCARD) ~ 'N',TRUE ~ DISCARD_SOURCE)) %>% 
		dplyr::mutate(STRATA_USED = case_when(is.na(DISCARD) ~ 'NA',TRUE ~ STRATA_USED))
	
	
	outlist$CV[is.nan(outlist$CV)]<-NA
	
	outlist$CV[is.infinite(outlist$CV)] <- NA    
	
	outlist$CAMS_DISCARD_RATE[is.nan(outlist$CAMS_DISCARD_RATE)]<-NA
	
	outlist$CAMS_DISCARD_RATE[is.infinite(outlist$CAMS_DISCARD_RATE)] <- NA 
	
	outlist$BROAD_STOCK_RATE[is.nan(outlist$BROAD_STOCK_RATE)]<-NA
	
	outlist$BROAD_STOCK_RATE[is.infinite(outlist$BROAD_STOCK_RATE)] <- NA 
	
	outlist$DISCARD[is.nan(outlist$DISCARD)]<-NA
	
	outlist$DISCARD[is.infinite(outlist$DISCARD)] <- NA 

	t2 = Sys.time()
	
	# print(paste('TABLE ', paste0('outlist_df_',FY), ' BUILT IN ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))
	
	species_name = stringr::str_remove(outlist$COMMON_NAME[1], pattern = ', ')
	species_name = stringr::str_remove(species_name, pattern = ' ')
	
	upload_table = paste0('CAMS_DISCARD_', species_name, '_', outlist$FY[1])
	
	print(paste('UPLOADING TABLE: ', upload_table))
	
	# upload_table = paste0('CAMS_DISCARD_EXAMPLE_GF',i)
	
	if (ROracle::dbExistsTable(bcon, upload_table, "MAPS")){
		ROracle::dbRemoveTable(bcon, upload_table)
	}
	
	ROracle::dbWriteTable(conn = bcon, name = upload_table, value =  outlist, row.names = FALSE, overwrite = FALSE)

	idx1 = paste0("CREATE INDEX year", outlist$FY[1], "idx", outlist$SPECIES_ITIS[1], " ON ", upload_table ,"(YEAR, MONTH, SPECIES_ITIS)")
	# idx2 = paste0("CREATE INDEX itisidx_gf", i, " ON ", paste0('CAMS_DISCARD_EXAMPLE_GF', i) ,"(SPECIES_ITIS)")
	ROracle::dbSendQuery(bcon, idx1)
	# ROracle::dbSendQuery(bcon, idx2)
	
	t3 = Sys.time()
	print(paste('TABLE ', upload_table, ' UPLOADED IN ', round(difftime(t3, t2, units = "mins"),2), ' MINUTES',  sep = ''))
	
} # end species loop

gc()

}


parse_upload_discard(bcon, filepath = '~/PROJECTS/discaRd/CAMS/MODULES/GROUNDFISH/OUTPUT/', FY = 2021)




