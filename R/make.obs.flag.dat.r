#' Modify eflalo for Cochran estimation
#' 
#' Modifies the eflalo dataset for Cochran ratio estimator. Adds a OBSFLAG field inicating if the trip was observed. This can be set as a percentage of total trips
#' @param dat the \code{\link{eflalo}} dataset. Other datasets for this function should have simialr column names. 
#' @param obs_level proportion of trips observed (observer coverage)
#' 
#' @return a 'melted' dataframe of trip data where species is a single column
#' @references  Niels Hintzen, Francois Bastardie and Doug Beare (2014). vmstools: For analysing fisheries VMS (Vessel Monitoring System) data. R package version 0.72. http://CRAN.R-project.org/package=vmstools
#' @export
#' @examples
#' #' data(eflalo)
#' dm = make.obs.flag.dat(eflalo, obs_level = .1)
	#' data(eflalo)
	#' dm = make.obs.flag.dat(eflalo, obs_level = .1)
make.obs.flag.dat <- function(dat, obs_level = .1){
	# obs_level = obs_level*100
  # browser()
	dat$OBSFLAG = 0
	dat$FT_REF2 = 1:nrow(dat)
	obstrips = sample(unique(dat$FT_REF2), round(length(unique(dat$FT_REF2))*obs_level),  replace = F)
	obidx = match(obstrips, dat$FT_REF2)
	dat$OBSFLAG[obidx] = 1
	
	dm = melt(dat[,c(1:110, 190, 191)],c(1:31,111,112))
	dm$variable = as.character(dm$variable)
	
	# change names for species and pounds
	names(dm)[34:35] = c('NESPP3','LIVE_POUNDS')
	
	# Add CALCLIVEWT
	dm$CALCLIVEWT = dm$LIVE_POUNDS 
	
	
	
	# Add a CATDISP column
	dm$CATDISP = 1
	
	# 'FT_REF' is the equivalent of DOCID/LINK1
	dm$DOCID = dm$FT_REF2
	
	# 'LE_MET_level6' is STRATA
	dm$STRATA = dm$LE_MET_level6
	
	# Date sail and land
	dm$DATESAIL = parse_date_time(paste0(dm$FT_DDAT, ' ', dm$FT_DTIME), '%d/%m/%Y %H:%M:%S')
	dm$DATELAND = parse_date_time(paste0(dm$FT_LDAT, ' ', dm$FT_LTIME), '%d/%m/%Y %H:%M:%S')
	dm$DATE_TRIP = dm$DATELAND
	
	# add FY
	dm$FY = year(dm$DATE_TRIP)
	
	# add fday
	# add yday
	dm$fday = dm$yday = day(dm$DATE_TRIP)
	
	dm
}
