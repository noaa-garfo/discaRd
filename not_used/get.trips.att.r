#' get.trip.att
#' Get N, K, n, k for a set of trips and observed trips, according to a strata definition
#' @param trips Trips from DMIS
#' @param bydat Observed trips
#'
#'	@details each data frame input MUST have a stratification column named 'strata'. This may be numeric, logical, factor or character
#' @return a list of OBS and TRIPS metrics
#' @export
#'
#' @examples
get.trips.att = function(bydat, trips){

# nstrata = length(unique(bydat$strata))	

byout = ddply(bydat, 'strata', function(x) data.frame(
 alln = nrow(bydat)
,allk = sum(bydat$KALL)
,n = nrow(x)
,k = sum(x$KALL)
))

tout = ddply(trips, 'strata', function(x) data.frame(
 allN = length(unique(trips$DOCID))
 ,allK = sum(trips$LIVE_POUNDS, na.rm=T)
 ,N = length(unique(x$DOCID))
,K = sum(x$LIVE_POUNDS, na.rm=T)
))

list(obs = byout, trips = tout)

}

# 
# area_select <- 621
# bydat$strata = as.numeric(bydat$AREA>area_select)+1
# trips$strata = as.numeric(trips$AREA>area_select)+1
# 
# get.trip.att( bydat, trips)

