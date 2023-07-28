#' Bootstrap discard rate with stratification
#' bootstraps Cochran discard rate from a set of observed trips
#'
#' @param bdat observer data with strata column
#' @param ddat dmis data (commercial trips) with strata column
#' @param days number of days to calculate starting from the first day of the fishing year
#' @param coverage proportion of commercial trips observed (i.e., observer coverage), which can optionally be specified to explore different coverages [default is observed coverage]
#' @param keep.samps option to keep samples for each bootstrap (default = F)
#' @param ... additional arguments to \code{\link{cochran.trans.calc}} (i.e. strata_complete and strata_name, interval)
#'
#' @return list of resampled discard rates
#' @export
#' @details This function runs a single instance with resampled observer data. It may be parallelized easily (see example). This requires mcoptions from \code{\link{setup.parallel}}. Including strata_complete is strongly recemmended. 
#' @seealso \code{\link{samp.by.strat}}
#' @examples
#' nboot = 10

#'mcoptions = setup.parallel()

#'bout.list = foreach(1:nboot, .options.multicore = mcoptions) %dopar% {
#'	library(discaRd)
#'	discaRd::bootr.strat(bdat = bdat, ddat = ddat, focal_year = 2015, nboot = nboot, strata_name = 'strata', strata_complete = strata_complete)
#'}

#'plot(colSums(bout.list[[1]]), typ='l', ylim = c(0,100000),  xlab='Day of year', ylab = 'Discard')
#'for(i in 2:length(bout.list)){
#'	lines(colSums(bout.list[[i]]), typ='l', col =2, lty = 2)
#'}

#'
#'
bootr.strat = function(bdat,
											 ddat,
											 focal_year = 2015,
											 strata_name = 'strata',
											 strata_complete = NULL,
											 coverage = NULL,
											 keep.samps = F, ...)
	# foreach(i = 1:nboot, .options.multicore = mcoptions) %dopar%
{
	# browser()
	bydat_focal = subset(bdat, FY == focal_year)
	bydat_prev = subset(bdat, FY == focal_year - 1)
	trips_focal = subset(ddat, FY == focal_year)
	trips_prev = subset(ddat, FY == focal_year - 1)
	
	ntrips = length(unique(trips_focal$DOCID))
	
	mult = round(ntrips/ nrow(bydat_focal)) ## number of replicates of the observed trips needed for superset
	
	if(!is.null(coverage)){
	  n.samp <- round(coverage*ntrips)
	  if(n.samp > ntrips | n.samp < 1){
	    stop('Error... coverage needs to be >0 and <=1')
	  }
	} else {
	  n.samp <- nrow(bydat_focal)
	}
	
	getsamp = function(bydat_focal, mult, n.samp) {
		sample(rep(1:nrow(bydat_focal), mult), n.samp, replace = F)
	}
	
  samps <- getsamp(bydat_focal, mult, n.samp)
	
	bout = cochran.trans.calc(
		bydat_focal[samps, ],
		trips_focal,
		bydat_prev,
		trips_prev,
		strata_name = strata_name,
		strata_complete = strata_complete, ...
	)
	
	# take care of Infinites
	
	bout[[1]][is.infinite(bout[[1]])] = 0
	
	if(keep.samps){
	  bout$samps=samps}
	
	bout
	
	
}
