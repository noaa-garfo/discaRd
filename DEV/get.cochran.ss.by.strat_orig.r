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
get.cochran.ss.by.strat <- function(bydat, trips, targCV = 0.3,
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
	  tout <- tout %>% complete(STRATA=strata_complete,fill=list(N=0,K=0))
	}
	tout$n <- 0	
	
	midx = match(bydat$STRATA, tout$STRATA)
	
	bydat$N = tout$N[midx]
	bydat$K = tout$K[midx]
	bydat$allN = tout$allN[midx]
	bydat$allK = tout$allK[midx]

	# run cochran on each component and unstratified
	# calculate number of trips for each strata to achieve a CV30 in each strata... 
	CVTOT <- rTOT <- NA
	
	C = data.frame(STRATA = strata_complete,  N = 0, n = 0, RE_mean= 0, RE_var= 0, RE_se= 0, RE_rse = 0, CV_TARG = 0, REQ_SAMPLES = 0, REQ_COV= 0, REQ_SEADAYS= 0, D= 0, K = 0)

	if(nrow(tout)>0){
		C$K = tout$K
		C$N = tout$N
	}
	
	
	
	if(nrow(bydat)>0){
	C = ddply(bydat, "STRATA", function(x) cochran_calc_ss(x, x$N[1], targCV))
	
	C$REQ_SEADAYS = C$REQ_SAMPLES*byout$avg_seadays
  
	# fill in missing strata from tout
	C <- as.data.frame(C %>% complete(STRATA=tout$STRATA,fill=list(n=0)))
	
	# fill in observed trips for tout
	tout$n <- C$n
	
	# calculate discard
	C$D = tout$K*C$RE_mean
	C$K = tout$K
  C$N = tout$N

	# calculate a TOTAL CV from individual results
	if(sum(C$D, na.rm=T)>0){
	  CVTOT = sqrt(sum(tout$K^2*C$RE_var, na.rm=T))/sum(C$D, na.rm=T)
	} else {
		CVTOT = NA
	}
	
	rTOT = (sum(tout$N)*sum(byout$d/byout$n))/(sum(tout$N)*sum(byout$k/byout$n))
	
	}

	list(C = C, tout=tout, CVTOT = CVTOT, rTOT = rTOT)
}


