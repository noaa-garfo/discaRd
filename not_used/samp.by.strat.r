#' Resample by stratification
#'
#' @param bdat observer data with strata column
#' @param ddat dmis data (commercial trips) with strata column
#' @param days number of days to calculate starting from the first day of the fishing year
#'
#' @return the overall discard rate for each day after combining all strata. This does NOT return discard rates for each strata.
#' @export
#'
#' @examples
samp.by.strat <- function(bdat, ddat, days, full_strata = NULL){
	
	if(is.null(full_strata)){
	  full_strata = unique(c(bdat$strata, ddat$strata))
	}
	
	mult = round(nrow(ddat)/nrow(bdat)) ## number of replicates of the observed trips needed for superset
	superset = rep(1:nrow(bdat), mult) 
	
	samps = lapply(c(1:days), function(x) sample(1:nrow(bdat)
																						, nrow(subset(bdat, fday%in%c(1:x)))
																						, replace = T) )
	# 
	# samps <- llply(c(days), function(x) get.cochran.ss.by.strat(
	# 					bdat[sample(1:nrow(bdat)
	# 											 , nrow(subset(bdat, fday%in%c(1:x)))
	# 											 , replace = T), ] 
	# 				, subset(ddat, fday %in% c(1:x)), .3, strata_name = "strata", strata_complete = full_strata))
	# 
#   out = numeric(length(days))
	# unlist(lapply(samps, function(x) print(x$rTOT)))
	samps
}

