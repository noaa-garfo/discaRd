#' Bycatch rates by strata
#' 
#' Get N, K, n, k and Cochran CV and sample size estimates for a set of trips and observed trips, according to a strata definition
#' @param bydat Observed trips
#' @param trips Trips from DMIS
#' @param targCV Target CV for sample size determination (default = 0.3)
#' @param strata_name The name of the strata column (defaul = 'STRATA').
#' @param strata_complete NOT OPTIONAL! A vector of all unique strata :)
#' desired from the output (including unobserved).
#' @details Each data frame input MUST have a stratification column that matches. This may be numeric, logical, factor or character
#' @return a list of Cochran estimaes by strata, Discards, Total Discard in the fishery, Total Cv for the fishery, Required Seadays by strata
#' @export
#'
#' @examples
get.cochran.ss.by.strat_alt <- function(bydat, trips, targCV = 0.3,
                                    strata_name = "STRATA",
                                    strata_complete = c('dredge','trawl')){
  
  # standardize the strata names
  names(bydat)[which(names(bydat)==strata_name)] <- "STRATA"
  names(trips)[which(names(trips)==strata_name)] <- "STRATA"
  
	# browser()
	byout = ddply(bydat, "STRATA", function(x) data.frame(
		alln = nrow(bydat)
		,allk = sum(bydat$KALL)
		,d = sum(x$BYCATCH)
		,n = nrow(x)
		,k = sum(x$KALL)
		,avg_seadays = mean(x$SEADAYS, na.rm=T)
	))
	
	tout = ddply(trips, "STRATA", function(x) data.frame(
		allN = length(unique(trips$DOCID))
		,allK = sum(trips$LIVE_POUNDS, na.rm=T)
		,N = length(unique(x$DOCID))
		,K = sum(x$LIVE_POUNDS, na.rm=T)
	))
	
	
	#btidx = match(byout$strata, tout$strata)
	#tout = tout[btidx,]
	
	if(!is.null(strata_complete)){
	  tout <- tout %>% complete(STRATA = strata_complete, fill = list(N = 0, K = 0, allN =0, allK = 0))
	  if(nrow(bydat)>0){
	  	byout <- byout %>% complete(STRATA = strata_complete, fill = list(n = 0, k = 0, d = 0, avg_seadays = 0, alln = 0, allk = 0))
	  }else{
	   byout = data.frame(STRATA = strata_complete, alln = 0, allk = 0, d = 0, n = 0, k = 0, avg_seadays = 0)	
	  }
	}
	
	byout$n[byout$n==0] = NA
	
	# allout = merge(byout, tout, by = "STRATA")
	
	tout$n <- 0	
	
	midx = match(bydat$STRATA, tout$STRATA)
	
	bydat$N = tout$N[midx]
	bydat$K = tout$K[midx]
	bydat$allN = tout$allN[midx]
	bydat$allK = tout$allK[midx]
	
	# bydat$N = allout$N[midx]
	# bydat$K = allout$K[midx]
	# bydat$allN = allout$allN[midx]
	# bydat$allK = allout$allK[midx]

	# run cochran on each component and unstratified
	# calculate number of trips for each strata to achieve a CV30 in each strata... 
	CVTOT <- rTOT <- NA
	
	C = data.frame(STRATA = strata_complete,  N = 0, n = 0, RE_mean= 0, RE_var= 0, RE_se= 0, RE_rse = 0, CV_TARG = 0, REQ_SAMPLES = 0, REQ_COV= 0, REQ_SEADAYS= 0, D= 0, K = 0)

	if(nrow(tout)>0){
		C$K = tout$K
		C$N = tout$N
	}
	
	# if(nrow(allout)>0){
	# 	C$K = allout$K
	# 	C$N = allout$N
	# }
	
	
	
	if(nrow(bydat)>0){
	C = ddply(bydat, "STRATA", function(x) cochran_calc_ss(x, x$N[1], targCV))

		# fill in missing strata from tout
	C <- as.data.frame(C %>% complete(STRATA = tout$STRATA, fill = list(n = 0)))
	# C <- as.data.frame(C %>% complete(STRATA = allout$STRATA, fill = list(n = 0)))

	# C[is.na(C)] = 0
	# C[is.nan(C)] = 0
	# C[is.infinite(C)] = 0
	
	# add required seadays per strata	
	C$REQ_SEADAYS = C$REQ_SAMPLES*byout$avg_seadays
	# C$REQ_SEADAYS = C$REQ_SAMPLES*allout$avg_seadays
  

	# fill in observed trips for tout
	tout$n <- C$n
	
	# calculate discard
	C$D = tout$K*C$RE_mean
	C$K = tout$K
  C$N = tout$N
#   # C$k = byout$k
#   # C$n = byout$n
#   # C$kmean = byout$k/byout$n
	
	# C$D = allout$K*C$RE_mean
	# C$K = allout$K
	# C$N = allout$N
	# C$k = allout$k
	# C$n = allout$n
	# C$kmean = allout$k/allout$n

	# calculate a TOTAL CV from individual results
	if(sum(C$D, na.rm=T)>0){
	  CVTOT = sqrt(sum(tout$K^2*C$RE_var, na.rm=T))/sum(C$D, na.rm=T)
	} else {
		CVTOT = NA
	}
	
	rTOT = (sum(tout$N, na.rm = T)*sum(byout$d/byout$n, na.rm = T))/(sum(tout$N, na.rm = T)*sum(byout$k/byout$n, na.rm = T))
	# rTOT = (sum(allout$N, na.rm = T)*sum(allout$d/allout$n, na.rm = T))/(sum(allout$N, na.rm = T)*sum(allout$k/allout$n, na.rm = T))
	
	}

	list(C = C, tout=tout, CVTOT = CVTOT, rTOT = rTOT)
	# list(C = C, tout = allout, CVTOT = CVTOT, rTOT = rTOT)
}


