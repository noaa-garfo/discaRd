#' Required Samples across a CV range
#' 
#' Estimate number of required samples (trips), using weighted mean, across a range of CV values for discard rates
#' @param bydat bycatch data, formatted for Cochran caluclations
#' @param bydat bycatch data, formatted for Cochran calculations
#' @param dest2 results from \code{\link{get.cochran.ss.by.strat}}
#'
#' @return a data frame with required samples
#' @export
#' 
#' @seealso \code{\link{get.bydat}}, \code{\link{cochran_calc_ss}}
#' 
#' @examples get.weighted.cv

get.weighted.cv <- function(bydat, dest2){
	nmatch = match(bydat$STRATA, dest2$tout$STRATA)
	bydat$N = dest2$tout$N[nmatch]
	bydat$N[is.na(bydat$N)] = 0
	targall = ddply(bydat, c('STRATA'), function(x) cochran_calc_ss(x, l_N = x$N[1], l_CVtarg = seq(0,1,.01)))
	didx = match(targall$STRATA, dest2$C$STRATA)
	targall$D = dest2$C$D[didx]
	targall$K = dest2$C$K[didx]
	targall$RE_var = dest2$C$RE_var[didx]
	# wtsamp = ddply(targall, 'CV_TARG', function(x) data.frame(REQ_COV_WT = weighted.mean(x$REQ_COV, w = (x$RE_var*x$K^2)/x$D)))
	# w = ddply(targall, 'STRATA', function(x) data.frame(w = sqrt(sum(x$K^2*x$RE_var, na.rm=T))/sum(x$D, na.rm=T)))
	w = ddply(targall, c('STRATA'), function(x) sqrt(sum((x$K^2)*x$RE_var, na.rm=TRUE)/sum(x$D, na.rm=TRUE)))
	# w = ddply(targall, c('STRATA'), function(x) sqrt(sum((x$K^2), na.rm=TRUE)/sum(x$D, na.rm=TRUE)))
	# widx = match(targall$STRATA, w$STRATA)
	# targall$w = w[widx,2]
	# wtsamp = ddply(targall, 'CV_TARG', function(x) data.frame(REQ_COV_WT = weighted.mean(x$REQ_COV, w = x$w, na.rm = T)))
	wtsamp = ddply(targall, 'CV_TARG', function(x) data.frame(REQ_COV_WT = weighted.mean(x$REQ_COV, w = x$D, na.rm = T)))
	mult = nrow(targall)/nrow(wtsamp)
	targall$WT_REQ_COV = rep(wtsamp$REQ_COV_WT, mult)
	didx = match(targall$CV_TARG, wtsamp$CV_TARG)
	targall$REQ_SAMPLES_WT = wtsamp$REQ_COV_WT*targall$N
	# total req_samples for fishery
	samptot = ddply(targall, 'CV_TARG', function(x) data.frame(SAMPTOT = sum(x$REQ_SAMPLES_WT, na.rm=T)))
	totidx = match( targall$CV_TARG, samptot$CV_TARG)
	targall$SAMPTOT = samptot$SAMPTOT[totidx]
	targall
}
