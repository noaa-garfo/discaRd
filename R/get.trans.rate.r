#' TRANSITION RATE
#'
#' @param l_observed_trips number of observed trips in current year
#' @param l_assumed_rate discard rate from previous time period
#' @param l_inseason_rate current in-season discard rate
#' @param ntrans number of trips in current year to use in transitional weighting
#'
#' @return discard rate adjusted using prior years rate
#' @export
#' @details usually not called directly
#' @seealso \code{\link{cochran.trans.calc}}
#'
#' @examples
#'
#' plot(get.trans.rate(l_observed_trips = 1:100, l_assumed_rate = 0.001, l_inseason_rate = .0005, ntrans = 50), typ = 'l', ylab = 'Discard rate', xlab = 'Number of in season trips')
#'
get.trans.rate <- function(l_observed_trips, l_assumed_rate, l_inseason_rate, ntrans = 5){

  # scale of the negative exponential
  r.coef <- 0.7
  
	v_trips <- ifelse(is.na(l_observed_trips), 0, l_observed_trips)
	term1 <- ifelse(v_trips < ntrans
								,ifelse(is.na(r.coef/ifelse(v_trips == 0, NA, v_trips)), 1, r.coef/ifelse(v_trips == 0, NA, v_trips))
								,0
	)
	term2 <- ifelse(v_trips < ntrans
								,1-ifelse(is.na(r.coef/ifelse(v_trips == 0, NA, v_trips)), 1, r.coef/ifelse(v_trips == 0, NA, v_trips))
								,1
	)
	transition_rate<-(term1*l_assumed_rate) + (ifelse(is.na(l_inseason_rate), 0, l_inseason_rate)*term2)
	return(transition_rate)
}
