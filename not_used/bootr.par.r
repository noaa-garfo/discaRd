#' Bootstrap discard rate
#' bootstraps Cochran discard rate from a set of observed trips
#' @param N number of observed trips
#' @param bdat observed trips
#' @param nboot number of resamples desired
#'
#' @return list of resampled discard rates
#' @export
#' @details requires mcoptions from \code{\link{setup.parallel}}
#' @seealso \code{\link{sampr}}
#' @examples
bootr.par = function(bdat, nboot)
	foreach(i = 1:nboot, .options.multicore = mcoptions) %dopar%
	{

		sampr = function(bdat, prate = NULL, tdays = 1){
			N = nrow(bdat)
			bidx = apply(data.frame(1:N), 1, function(x) sample(1:N, x, replace = T))
			r = ldply(apply(data.frame(1:N), 1, function(x) sample(1:N, x, replace = T)), function(x) data.frame(RE_rse = cochran_rse(bdat[x,], N)$r))
			r$n = 1:nrow(r)
			names(r)[1] = 'r'
			if(!is.null(prate)){
				r$r = get.trans.rate(r$n, prate, r$r, tdays)
			}
			r$r
		}	
		
	# bout = matrix(0, ncol = nrow(bdat), nrow = nboot)
	# N = nrow(bdat)
	bout = lapply(nboot, function(x) sampr(bdat))
	names(bout) = paste0('samp',nboot)
	bout = as.data.frame(bout)
	bout
}

