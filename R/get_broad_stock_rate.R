#' Get Broad Stock Rate
#' This function is a special case of \link{run_discard}. When stock is used as a stratification variable, it is not straightforward to get a broad stock rate, with a CV. This function simply subsets a larger dataset by stock component before running run_discard.
#' The advantage of having this as a function is it may easily be run in a loop.
#' @param bdat table of observed trips that can include (and should include) multiple years
#' @param ddat_focal_sp table of observed trips for discard year
#' @param ddat_focal matched table of observed and commercial trips
#' @param species_itis species of interest using SPECIES_ITIS code

#' @param stratvars stratification variables desired: should only be SPECIES_STOCK; usually the first of a string of stratification variables
#' @param stock specific stock (name) to run
#'
#' @return a list of:
#' 1) Species stock
#' 2) discaRd rate
#' 3) CV
#' @export
#'
#' @examples
#' stratvars_scalgf = c("SPECIES_ESTIMATION_REGION"
#' , "CAMS_GEAR_GROUP" 
#' , "MESHGROUP"     
#' , "TRIPCATEGORY" 
#' , "ACCESSAREA"  
#' , "SCALLOP_AREA"
#' )
#'
#' BROAD_STOCK_RATE_TABLE = list()

#' kk = 1

#' ustocks = bdat_scal$SPECIES_ESTIMATION_REGION %>% unique()

#' for(k in ustocks){
#'	BROAD_STOCK_RATE_TABLE[[kk]] = get_broad_stock_rate(bdat = bdat_scal
#'																											, ddat_focal_sp = ddat_focal_scal
#'																											, ddat_focal = ddat_focal
#'																											, species_itis = species_itis
#'																											, stratvars = stratvars_scalgf[1]
#'																											, stock = k
#'	)
#'	kk = kk+1
#'}

#' BROAD_STOCK_RATE_TABLE = do.call(rbind, BROAD_STOCK_RATE_TABLE)

#' rm(kk, k)
#'
get_broad_stock_rate = function(bdat, ddat_focal_sp, ddat_focal, species_itis, stratvars, stock = 'GOM'){

	btmp = 	bdat %>%
		filter(SPECIES_ESTIMATION_REGION == stock)
	dstmp = ddat_focal_sp %>%
		filter(SPECIES_ESTIMATION_REGION == stock)
	dtmp = 	ddat_focal %>%
		filter(SPECIES_ESTIMATION_REGION == stock)

	d_broad_stock = run_discard(bdat = btmp
															, ddat = dstmp
															, c_o_tab = dtmp
															, species_itis = species_itis
															, stratvars = stratvars
															, aidx = 1  # this makes sure this isn't used..
	)
	
	data.frame(SPECIES_ESTIMATION_REGION = stock, BROAD_STOCK_RATE = d_broad_stock$allest$rTOT
						 , CV_b = d_broad_stock$allest$CVTOT
	)
	
} 

