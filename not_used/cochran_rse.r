# COCHRAN RATIO ESTIMATOR STANDARD ERROR
# Accepts 3 column dataframe where each row is a trip
# requires LINK1, BYCATCH, KALL naming convention
# returns mean ratio_estimator (rate), standard error, and relative standard error (CV)
#' COCHRAN RATIO ESTIMATOR STANDARD ERROR
#'
#' @param dat dataframe where each row is a trip. Requires LINK1, BYCATCH, KALL naming convention
#' @param N Number of total trips
#'
#' @return dataframe: Total trips (N), total observed trips (n), mean (r), variance (RE_var), standard deviation (RE_se), CV (RE_rse)
#' @export
#' @references Wiley: Sampling Techniques, 3rd Edition - William G. Cochran. (n.d.). Available from http://www.wiley.com/WileyCDA/WileyTitle/productCd-047116240X.html [accessed 1 August 2016].
#'
#' Wigley SE, Rago PJ, Sosebee KA, Palka DL. 2007. The Analytic Component to the Standardized Bycatch Reporting Methodology Omnibus Amendment: Sampling Design, and Estimation of Precision and Accuracy (2nd Edition). US Dep. Commer., Northeast Fish. Sci. Cent. Ref. Doc. 07-09; 156 p
#' @examples
#'

cochran_rse <- function(dat,N){
	n <- nrow(dat)
	if(N<n){stop('Error...Total trips less than observed trips')}
	r <- sum(dat$BYCATCH)/sum(dat$KALL)
	dat['DN'] <- dat$BYCATCH/n
	dat['KN'] <- dat$KALL/n
	dat['DSQ'] <- dat$BYCATCH^2
	dat['KSQ'] <- dat$KALL^2
	dat['RSQKSQ'] <- dat$KSQ * r^2
	dat['R2DK'] <- r * 2 * dat$BYCATCH * dat$KALL
	dat['DSQ_RSQKSQ_R2DK'] <- dat$DSQ + dat$RSQKSQ - dat$R2DK
	dsq_rsqksq_r2dk_term <- sum(dat$DSQ_RSQKSQ_R2DK)/(n - 1)
	N_term <- (N - n)/(N * n)
	K_term <- 1/((sum(dat$KALL)/n)^2)
	RE_var <- N_term * K_term * dsq_rsqksq_r2dk_term
	RE_se <- sqrt(RE_var)
	RE_rse <- RE_se/r  # possibly try and optimize by minimization???
	# CV = sqrt(K^2*RE_var)/(K*r)
	output <- data.frame(N = N, n = n, r = r, RE_var = RE_var,
	                     RE_se = RE_se, RE_rse = RE_rse)

	return(output)
}


