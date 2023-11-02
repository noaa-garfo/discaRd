#' Vary N (# total commercial trips)
#' 
#' Function to run Cochran estimator with a variable big N (total number of trips). Sequences from the numnber of observed trips up to a maximum number of total trips.  N > n
#'
#' @param bdat data loaded from \code{\link{get.bdat}}
#' @param bigN Total trips
#' @param by sequencing step. Start is the number of observed trips, end is big N
#'
#' @return SD and CV from \code{\link{cochran_rse}}
#' @export
#'
#' @examples vary.bigN

vary.bigN = function(bdat, bigN, by = 10){
	N = data.frame(N = seq(nrow(bdat), bigN, by = by))
	s = ddply(N, 1,function(x) cochran_rse(bdat, x))
	names(s)[4:5] = c('RE_se','RE_rse')
	s
}
