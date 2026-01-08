#' Estimates Cochran discard rate and required sample sizes
#'
#' This function estimates the discard rate using the Cochran ratio estimator and returns the mean rate as well as estimates of uncertainty and required sample sizes for a target CV
#' @param df dataframe where each row is a trip. Requires LINK1, BYCATCH, KALL naming convention
#' @param n_trips Number of total trips
#' @param CV_targ target CV
#'
#' @return observed sample size needed for target CV
#' @export
#' @references Wiley: Sampling Techniques, 3rd Edition - William G. Cochran. (n.d.). Available from http://www.wiley.com/WileyCDA/WileyTitle/productCd-047116240X.html [accessed 1 August 2016].
#'
#' Wigley SE, Rago PJ, Sosebee KA, Palka DL. 2007. The Analytic Component to the Standardized Bycatch Reporting Methodology Omnibus Amendment: Sampling Design, and Estimation of Precision and Accuracy (2nd Edition). US Dep. Commer., Northeast Fish. Sci. Cent. Ref. Doc. 07-09; 156 p
#' @examples
#'
# --- Step 1: Create Dummy Data ---
# 5 observed trips
#'test_df <- data.frame(
#'  LINK1 = c("Trip_A", "Trip_B", "Trip_C", "Trip_D", "Trip_E"),
#'  BYCATCH = c(10, 50, 20, 10, 0),    # Discard weight
#'  KALL = c(100, 500, 150, 100, 200)  # Kept weight
#')

#' # --- Step 2: Run the function ---
#' # Scenario: Total fleet size is 1000 trips, we observed 5. Target CV is 30% (0.30)
#'result <- calc_cochran_rate(
#'  df = test_df,
#'  n_trips = 1000,
#'  n_obs = nrow(test_df),
#'  CV_targ = 0.30
#')

#' # --- Step 3: View Results ---
#' print(result)

calc_cochran_rate = function(df, n_trips, n_obs, CV_targ = NA){

  n = n_obs

	# if(n_trips<n){warning('Warning...Total trips less than observed trips')}
	r = sum(df$BYCATCH)/sum(df$KALL)
	df['DN'] = df$BYCATCH/n
	df['KN'] = df$KALL/n
	df['DSQ'] = df$BYCATCH^2
	df['KSQ'] = df$KALL^2
	df['RSQKSQ'] = df$KSQ*r^2
	df['R2DK'] = r*2*df$BYCATCH*df$KALL
	df['DSQ_RSQKSQ_R2DK'] = df$DSQ+df$RSQKSQ-df$R2DK

	dsq_rsqksq_r2dk_term = sum(df$DSQ_RSQKSQ_R2DK)/(n-1)
	if(n_trips<n){
	  N_term = 0
	} else{
	  N_term = (n_trips-n)/(n_trips*n)}
	K_term = 1/((sum(df$KALL)/n)^2)
	RE_var = N_term*K_term*dsq_rsqksq_r2dk_term
	RE_se = sqrt(RE_var)
	RE_rse = ifelse(r==0,0,RE_se/r)
	req_samples = NA
	#SECTION FOR SAMPLE SIZE TARGET
	if(!is.na(CV_targ)){
		CVD = (CV_targ*r)^2
		T1 = dsq_rsqksq_r2dk_term/((sum(df$KALL)/n)^2)
		T2 = CVD+(T1/n_trips)
		req_samples = T1/T2
	}
	output = data.frame(
	  N = n_trips,
	  n = n,
	  RE_mean = r,
	  RE_var = RE_var,
	  RE_se = RE_se,
	  RE_rse = RE_rse,
	  CV_TARG = CV_targ,
	  REQ_SAMPLES = req_samples,
	  REQ_COV = req_samples / n_trips
	)

	return(output)
}
