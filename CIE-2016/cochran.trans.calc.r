#' Estimate the in-season cumulative discard with a transition rate
#' 
#' Apply transition rate to adjust in-season discard rate estimates and calculate the cumulative discard for a set of trips and observed trips, according to a strata definition
#' @param bydat_focal Observed trips for focal year (t)
#' @param trips_focal Trips from DMIS for focal year (t)
#' @param bydat_prev Observed trips for previous year (t-1)
#' @param trips_prev Trips from DMIS for previous year (t-1)
#' @param strata_name Name of the stratification column (default = "STRATA")
#' @param strata_complete Vector of complete names for all strata of interest
#' @param time_span Start and end days of the fishing season
#' @param time_inter The length of the time interval for cumulative calculation (default = 1 day)
#' @param trans_method Method for incorporating the transition rate, 
#' either using a minimum number of trips specified [default] or determined by previous year's CV, a moving window, or no transition.
#' @param trans_num Number used by the \code{trans_method} for determining transition, 
#' either number of trips (\code{trans_method='ntrips'}) 
#' @param trans_numCV Option to output the number of days in transition for
#' @details Each data frame input MUST have matching stratification columns. This variable may be numeric, logical, factor or character.
#'  The cumulative rate can be calculated without any transition rate by using method = "none".
#' @seealso \code{\link{get.cochran.ss.by.strat}}
#' @return A list of Cochran estimates by strata, Discards, Total Discard in the fishery (adjusted by transition rate)
#' @export
#'
#' @examples cochran.trans.calc
cochran.trans.calc <- function(bydat_focal, trips_focal,
                         bydat_prev,  trips_prev,
                         strata_name = "STRATA",
                         strata_complete = NULL,
                         time_span = c(1,365),
                         time_inter = 1,
                         CV_target = 0.3,
                         trans_method = c("ntrips","ntripsCV","moving","none")[1],
                         trans_num = 5,
                         trans_numCV = FALSE){
	# browser()
  day0 <- time_span[1]
  dayT <- time_span[2]
  days <- unique(c(round(seq(day0,dayT,by=time_inter)),dayT))
  
  if(is.null(strata_complete)){
    strata <- sort(unique(c(bydat_focal[,strata_name], trips_focal[,strata_name],
                            bydat_prev[,strata_name],  trips_prev[,strata_name])))
  } else {
    strata <- sort(strata_complete)
  }
  n.strata <- length(strata)

  #calculate the discard rates in year t-1
  cochran_prev  <- get.cochran.ss.by.strat(
    subset(bydat_prev, fday%in%c(day0:dayT)), 
    subset(trips_prev, fday%in%c(day0:dayT)), 
    CV_target, strata_name, strata)
  
  # calculate focal rates with transition adjustment
  if(trans_method %in% c("ntrips","ntripsCV","none")){
    
  # no transition
  if(trans_method=="none"){trans_num <- 0}
  #observed trips to reach CV target
  if(trans_method=="ntripsCV"){
    trans_num <- cochran_prev$C$REQ_SAMPLES
    trans_num[is.na(trans_num)] <- 5
    trans_num[trans_num<5] <- 5
    }
  
  cochran_focal <- llply(days, 
                         function(x) get.cochran.ss.by.strat(
                           subset(bydat_focal, fday %in% c(day0:x)),
                           subset(trips_focal, fday %in% c(day0:x)),
                           strata_name = strata_name,
                           strata_complete = strata))
  
  
  # n, r, K for current year (cumulative)
  daily.n <- t(ldply(cochran_focal,function(x){x$tout$n}))
  daily.r <- t(ldply(cochran_focal,function(x){x$C$RE_mean}))
  daily.K <- t(ldply(cochran_focal,function(x){x$tout$K}))
  
  # calculate assumed rate (assign fishery mean for NAs)
  assumed.rate <- cochran_prev$C$RE_mean
  assumed.rate[is.na(assumed.rate)] <- cochran_prev$rTOT
  # correct strata with n<5 in previous year
  assumed.rate[cochran_prev$C$n < 5] <- cochran_prev$rTOT
  
  # calculate the transition rate
  trans.rate <- get.trans.rate(daily.n,assumed.rate,daily.r,
                               ntrans=trans_num)
  
  daily.D <- daily.K*trans.rate
  
  } else {
    
    cochran_focal <- llply(days, 
                           function(x) get.cochran.ss.by.strat(
                             rbind(
                               subset(bydat_focal, fday%in%c(day0:x)),
                               subset(bydat_prev,  fday%in%c((x+1):dayT))),

                               subset(trips_focal, fday%in%c(day0:x)),
                               
                             strata_name = strata_name,
                             strata_complete = strata))
    
    daily.r <- t(ldply(cochran_focal,function(x){x$C$RE_mean}))
    daily.r[is.na(daily.r)] <- cochran_prev$rTOT
    daily.K <- t(ldply(cochran_focal,function(x){x$tout$K}))
    
    daily.D <- daily.K*daily.r
  }
  rownames(daily.D) <- strata
  colnames(daily.D) <- days
  
  if(trans_numCV & trans_method=="ntripsCV"){
    # determine if/when the trans_num was reached inseason
    trans_out <- apply(ldply(cochran_focal,function(x){x$tout$n}),1,function(x){x >= trans_num})
    # fishing day that stratum is out of transition
    fday_out <- apply(trans_out,1,function(x){min(c(days[which(x)],dayT))})
    transition <- data.frame(ntrips=trans_num,fday=fday_out)
    rownames(transition) <- strata
  }
  
  #option to output the trans_num for each stratum
  if(trans_numCV & trans_method=="ntripsCV"){
    return(list(D=daily.D,transition=transition))
  } else{
    return(list(D=daily.D))
  }
  
  }


