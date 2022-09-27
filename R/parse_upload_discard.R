#' Parse and Upload Discard Table
#' Parses discard results, cleans the table (e.g. infinite) and uploads to Oracle. This is designed to be used for a series of single species (itis), for a single fishing year, that reside in a folder. This function will upload all species within the folder that correspond to the provided fishing year.
#'
#' N.B.! This function will remove the previous table(s) on MAPS.
#'
#' @param con ROracle connection to Oracle (e.g. MAPS)
#' @param filepath path to .fst discard results
#' @param FY Fishing Year to upload, should correspond to those results in filepath
#'
#' @return nothing; cleans, deletes, and appends the Oracle table
#' @export
#'
#' @examples
#' \dontrun{
#'parse_upload_discard(con = con_maps, filepath = getOption("maps.discardsPath"), FY = 2018)
#'}
parse_upload_discard <- function(con = con_maps, filepath = getOption("maps.discardsPath"), FY = 2018){

	# require(ROracle)

	t1 = Sys.time()

	assign('resfiles', list.files(path = filepath, pattern = paste0(FY,'.fst'), full.names = T))

# drop ones containing scal_trips_SCAL because they are already added into non_gftrips for those species. Maybe move to their own folder.

	species = lapply(stringr::str_split(resfiles, pattern = '_'), function(x) x[3]) %>% unlist %>% unique


	for (kk in species){
		spfiles = resfiles[grep(pattern = kk, x = resfiles)]

		# vectorize over mulitple files for a year for the same species
		res = lapply(as.list(spfiles), function(x) fst::read_fst(x))

		# vectorize over mulitple files for a year for the same species
		outlist <- lapply(res, function(x) {
			# x = fst::read_fst(jj)
			x %>%
				mutate(
				  GF_STOCK_DEF = paste0(COMMON_NAME, '-', SPECIES_STOCK),
				  SUBTRIP = stringr::str_extract(CAMS_SUBTRIP, "[^_]*$")
				  ) %>%
				dplyr::select(-SPECIES_ITIS) %>%
				# dplyr::select(-COMMON_NAME, -SPECIES_ITIS) %>%
				dplyr::rename('STRATA_FULL' = 'FULL_STRATA'
											, 'CAMS_DISCARD_RATE' = 'COAL_RATE'
											, 'CAMS_DISCARD' = 'DISCARD'
											# , 'COMMON_NAME' = 'COMNAME_EVAL'
											, 'ITIS_TSN' = 'SPECIES_ITIS_EVAL'
											, 'ACTIVITY_CODE' = 'ACTIVITY_CODE_1'
											, 'N_OBS_TRIPS_F' = 'n_obs_trips_f'
											, 'CV_I_T' ='CV_f'
											, 'CV_S_GM' ='CV_f_a'
											, 'CV_G' ='CV_b'
											, 'DISCARD_RATE_S_GM' = 'trans_rate_a'
											, 'DISCARD_RATE_G' = 'BROAD_STOCK_RATE'
											, 'CAMS_CV' = 'CV'
				) %>%
				mutate(DATE_RUN = Sys.Date()
							 , FY = as.integer(FY)
							 , DOCID = dplyr::case_when(
							   nchar(DOCID, keepNA = TRUE) > 15 ~ NA_character_,
							   TRUE ~ DOCID
							   )
							 ) %>%
				dplyr::select(
					DATE_RUN
					, FY
					, DATE_TRIP
					, YEAR
					, MONTH
					, ITIS_TSN
					, COMMON_NAME
					, FY_TYPE
					, ACTIVITY_CODE
					, VTRSERNO
					, CAMSID
					, DOCID
					, CAMS_SUBTRIP
					, SUBTRIP
					, FED_OR_STATE
					, GF
					, AREA
					, LINK1
					, N_OBS_TRIPS_F
					, STRATA_USED
					, STRATA_FULL
					, STRATA_ASSUMED
					, DISCARD_SOURCE
					, OBS_DISCARD
					, OBS_KALL
					, SUBTRIP_KALL
					# , SPECIES_ITIS
					, ACTIVITY_CODE
					, N_OBS_TRIPS_F
					, CAMS_DISCARD_RATE
					, DISCARD_RATE_S_GM
					, DISCARD_RATE_G
					, CAMS_CV
					, CV_I_T
					, CV_S_GM
					, CV_G
					, DISC_MORT_RATIO
					, CAMS_DISCARD
					, SPECIES_STOCK
					, GEARCODE
					, NEGEAR
					, GEARTYPE
					, CAMS_GEAR_GROUP
					, MESHGROUP
					, SECTID
					, EM
					, REDFISH_EXEMPTION
					, SNE_SMALLMESH_EXEMPTION
					, XLRG_GILLNET_EXEMPTION
					, TRIPCATEGORY
					, ACCESSAREA
					, SCALLOP_AREA
					# eval(strata_unique)
				)
		  # add left join run_id

		} ) # end lapply




		# convert list to data frame
		outlist = do.call(rbind, outlist)

		# adjust for DISACRD_SOURCE = N, nan and infinite values

		outlist <- outlist %>%
			dplyr::mutate(DISCARD_SOURCE = case_when(is.na(CAMS_DISCARD) ~ 'N',TRUE ~ DISCARD_SOURCE)) %>%
			dplyr::mutate(STRATA_USED = case_when(is.na(CAMS_DISCARD) ~ 'NA',TRUE ~ STRATA_USED))


		outlist$CAMS_CV[is.nan(outlist$CAMS_CV)]<-NA

		outlist$CAMS_CV[is.infinite(outlist$CAMS_CV)] <- NA

		outlist$CV_I_T[is.nan(outlist$CV_I_T)]<-NA

		outlist$CV_I_T[is.infinite(outlist$CV_I_T)] <- NA

		outlist$CV_S_GM[is.nan(outlist$CV_S_GM)]<-NA

		outlist$CV_S_GM[is.infinite(outlist$CV_S_GM)] <- NA

		outlist$CV_G[is.nan(outlist$CV_G)]<-NA

		outlist$CV_G[is.infinite(outlist$CV_G)] <- NA

		outlist$CAMS_DISCARD_RATE[is.nan(outlist$CAMS_DISCARD_RATE)]<-NA

		outlist$CAMS_DISCARD_RATE[is.infinite(outlist$CAMS_DISCARD_RATE)] <- NA

		outlist$DISCARD_RATE_G[is.nan(outlist$DISCARD_RATE_G)]<-NA

		outlist$DISCARD_RATE_G[is.infinite(outlist$DISCARD_RATE_G)] <- NA

		outlist$DISCARD_RATE_S_GM[is.nan(outlist$DISCARD_RATE_S_GM)]<-NA

		outlist$DISCARD_RATE_S_GM[is.infinite(outlist$DISCARD_RATE_S_GM)] <- NA

		outlist$CAMS_DISCARD[is.nan(outlist$CAMS_DISCARD)]<-NA

		outlist$CAMS_DISCARD[is.infinite(outlist$CAMS_DISCARD)] <- NA

		t2 = Sys.time()

		# print(paste('TABLE ', paste0('outlist_df_',FY), ' BUILT IN ', round(difftime(t2, t1, units = "mins"),2), ' MINUTES',  sep = ''))

		# species_name = stringr::str_remove(outlist$COMMON_NAME[1], pattern = ', ')
		# species_name = stringr::str_remove(species_name, pattern = ' ')
		#
		# species_name = stringr::str_replace(species_name, pattern = '-', replacement = '_')
		# species_name = stringr::str_replace(species_name, pattern = ' ', replacement = '_')
		#
		# species_name = stringr::str_replace(species_name, pattern = "[(]", replacement = '')
		# species_name = stringr::str_replace(species_name, pattern = "[)]", replacement = '')

		# upload_table = paste0('CAMS_DISCARD_', species_name, '_', outlist$FY[1])

		# print(paste('UPLOADING RUN GROUP: ', upload_table))

		# upload_table = paste0('CAMS_DISCARD_EXAMPLE_GF',i)

		# if (ROracle::dbExistsTable(con, upload_table)){
		# 	ROracle::dbRemoveTable(con, upload_table)
		# }

		# ROracle::dbWriteTable(conn = con, name = upload_table, value =  outlist, row.names = FALSE, overwrite = FALSE)

		# idx1 = paste0("CREATE INDEX year", outlist$FY[1], "idx", outlist$SPECIES_ITIS[1], " ON ", upload_table ,"(YEAR, MONTH, SPECIES_ITIS)")
		# idx2 = paste0("CREATE INDEX itisidx_gf", i, " ON ", paste0('CAMS_DISCARD_EXAMPLE_GF', i) ,"(SPECIES_ITIS)")
		# ROracle::dbSendQuery(con, idx1)
		# ROracle::dbSendQuery(con, idx2)

		append_discard_all_years(con = con, data = outlist, drop = FALSE)

		t3 = Sys.time()
		print(paste('SPECIES ', kk, ' ' , FY, ' UPDATED IN ', round(difftime(t3, t2, units = "mins"),2), ' MINUTES',  sep = ''))

	} # end species loop

	gc()

}
