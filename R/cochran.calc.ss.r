#' Estimates Cochran discard rate and required sample sizes
#'
#' This function estimates the discard rate using the Cochran ratio estimator and returns the mean rate as well as estimates of uncertainty and required sample sizes for a target CV
#' @param l_df dataframe where each row is a trip. Requires LINK1, BYCATCH, KALL naming convention
#' @param l_N Number of total trips
#' @param l_CVtarg target CV
#'
#' @return observed sample size needed for target CV
#' @export
#' @references Wiley: Sampling Techniques, 3rd Edition - William G. Cochran. (n.d.). Available from http://www.wiley.com/WileyCDA/WileyTitle/productCd-047116240X.html [accessed 1 August 2016].
#'
#' Wigley SE, Rago PJ, Sosebee KA, Palka DL. 2007. The Analytic Component to the Standardized Bycatch Reporting Methodology Omnibus Amendment: Sampling Design, and Estimation of Precision and Accuracy (2nd Edition). US Dep. Commer., Northeast Fish. Sci. Cent. Ref. Doc. 07-09; 156 p
#' @examples cochran.calc.ss
cochran.calc.ss<-function(l_df, l_N, l_CVtarg = NA){
	n<-nrow(l_df)
	if(l_N<n){warning('Warning...Total trips less than observed trips')}
	r<-sum(l_df$BYCATCH)/sum(l_df$KALL)
	l_df['DN']<-l_df$BYCATCH/n
	l_df['KN']<-l_df$KALL/n
	l_df['DSQ']<-l_df$BYCATCH^2
	l_df['KSQ']<-l_df$KALL^2
	l_df['RSQKSQ']<-l_df$KSQ*r^2
	l_df['R2DK']<-r*2*l_df$BYCATCH*l_df$KALL
	l_df['DSQ_RSQKSQ_R2DK']<-l_df$DSQ+l_df$RSQKSQ-l_df$R2DK

	dsq_rsqksq_r2dk_term<-sum(l_df$DSQ_RSQKSQ_R2DK)/(n-1)
	if(l_N<n){
	  N_term<-0
	} else{
	  N_term<-(l_N-n)/(l_N*n)}
	K_term<-1/((sum(l_df$KALL)/n)^2)
	RE_var<-N_term*K_term*dsq_rsqksq_r2dk_term
	RE_se<-sqrt(RE_var)
	RE_rse<-ifelse(r==0,0,RE_se/r)
	req_samples<-NA
	#SECTION FOR SAMPLE SIZE TARGET
	if(!is.na(l_CVtarg)){
		CVD<-(l_CVtarg*r)^2
		T1<-dsq_rsqksq_r2dk_term/((sum(l_df$KALL)/n)^2)
		T2<-CVD+(T1/l_N)
		req_samples<-T1/T2
	}
	output<-data.frame(N=l_N,n=n,RE_mean=r,RE_var=RE_var,RE_se=RE_se,RE_rse=RE_rse,CV_TARG=l_CVtarg,REQ_SAMPLES=req_samples,REQ_COV=req_samples/l_N)

	return(output)
}
