#' Resample discard rate
#' Resamples Cochran estimated discard rate from a set of observed trips. If transiton arguements are included, this uses the \code{\link{get.trans.rate}} calculation
#' 
#' @param bdat observed trips 
#' @param prate previous time periods transition rate
#' @param tdays number of days to include in transition calcualtion
#'
#' @return discard rate calculated using \code{\link{cochran_rse}}
#' @export
#'
#' @examples
#' 
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
