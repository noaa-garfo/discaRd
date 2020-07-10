#' Bootstrap discard rate
#' bootstraps Cochran discard rate from a set of observed trips
#' @param N number of observed trips
#' @param bdat observed trips
#' @param nboot number of resamples desired
#'
#' @return list of resampled discard rates
#' @export
#'
#' @examples
bootr = function(bdat, nboot){
	# bout = matrix(0, ncol = nrow(bdat), nrow = nboot)
	N = nrow(bdat)
	bout = lapply(1:nboot, function(x) sampr(bdat))
	names(bout) = paste0('samp',1:nboot)
	bout = as.data.frame(bout)
	bout
}










