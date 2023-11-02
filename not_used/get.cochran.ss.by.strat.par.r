#' Bycatch rates by strata
#' 
#' Get N, K, n, k and Cochran CV and sample size estimates for a set of trips and observed trips, according to a strata definition
#' @param trips Trips from DMIS
#' @param bydat Observed trips
#' @param targCV Target CV for sample size determination
#' @param n number of days in the year to analyze, starting always at day 1. i.e. 365 will process days 1:365
#' @details each data frame input MUST have a stratification column named 'strata'. This may be numeric, logical, factor or character
#' @return a list of Cochran estimaes by strata, Discards, Total Discard in the fishery, Total Cv for the fishery, Required Seadays by strata
#' @export
#'
#' @examples
get.cochran.ss.by.strat.par <- function(n = 1, bydat, trips, targCV)
	foreach(i = 1:n, .options.multicore = mcoptions) %dopar%
	# browser()
{
	bydat = subset(bydat, yday%in%c(1:n))
	trips = subset(trips, yday %in% c(1:n))
	
	byout = plyr::ddply(bydat, 'strata', function(x) data.frame(
		alln = nrow(bydat)
		,allk = sum(bydat$KALL)
		,n = nrow(x)
		,k = sum(x$KALL)
		,avg_seadays = mean(x$SEADAYS, na.rm=T)
	))
	
	tout = plyr::ddply(trips, 'strata', function(x) data.frame(
		allN = length(unique(trips$DOCID))
		,allK = sum(trips$LIVE_POUNDS, na.rm=T)
		,N = length(unique(x$DOCID))
		,K = sum(x$LIVE_POUNDS, na.rm=T)
	))
	
	
	btidx = match(byout$strata, tout$strata)
	tout = tout[btidx,]
	
	midx = match(bydat$strata, tout$strata)
	
	bydat$N = tout$N[midx]
	bydat$K = tout$K[midx]
	bydat$allN = tout$allN[midx]
	bydat$allK = tout$allK[midx]
	
	# run cochran on each component and unstratified
	# calculate number of trips for each strata to achieve a CV30 in each strata... 
	
	C = plyr::ddply(bydat, 'strata', function(x) cochran_calc_ss(x, x$N[1], targCV))
	
	C$REQ_SEADAYS = C$REQ_SAMPLES*byout$avg_seadays
	
	# calculate discard
	C$D = tout$K*C$RE_mean
	C$K = tout$K
	
	
	# calculate a TOTAL CV from individual results
	if(sum(C$D)>0){
		CVTOT = sqrt(sum(tout$K^2*C$RE_var, na.rm=T))/sum(C$D, na.rm=T)
	} else {
		CVTOT = NA
	}
	
	
	list(C = C, CVTOT = CVTOT)
}



