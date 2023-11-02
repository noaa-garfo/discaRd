#' Get Scallop bycatch data for simulation
#'
#' @param dmisfile R workspace with DMIS data
#' @param obsfile R workspace with Observer data
#' @param fystart years day for the first day of the fishing year (specific year does not matter). Use a NON -leap year for this. i.e. March 1, 2001 is day 60
#'
#' @return a list with DMIS and OBS data formatted for simulations
#' @export
#'
#' @examples
get.scalb.data = function(dmisfile, obsfile, fystart = 60){
	# browser()
	# Observer data 
	load(obsfile)
	obs = obsdat
	rm(obsdat)
	
	# DMIs Data 
	load(dmisfile)
	trips = dmisdat
	rm(dmisdat)
	
	# add FY, yday and fday columns
	names(obs)[grep('FISHING_YEAR',names(obs))] = 'FY'
	names(trips)[grep('FISHING_YEAR',names(trips))] = 'FY'
	dayadd = 365-fystart
	
	# deal with leap years..
	lyidx = obs$FY%in%c(2011,2015)
	obs$yday = yday(obs$DATELAND)
	obs$fday0 = ifelse(lyidx, fystart+1, fystart)
	obs$fday = ifelse(obs$yday<obs$fday0, obs$yday+dayadd, obs$yday-obs$fday0+1)
	#obs$fday[obs$yday==obs$fday0] = 1

	lyidx = trips$FY%in%c(2011,2015)
	trips$yday = yday(trips$DATE_TRIP)
	trips$fday0 = ifelse(lyidx, fystart+1, fystart)
	trips$fday = ifelse(trips$yday<trips$fday0, trips$yday+dayadd, trips$yday-trips$fday0+1)
	#trips$fday[trips$yday==trips$fday0] = 1
	
	# make the STRAT A column character (not a factor)
	obs$STRATA = as.character(obs$STRATA)
	trips$STRATA = as.character(trips$STRATA)
	
	#get rid of NA in NESPP3
	
	obs = obs[!is.na(obs$NESPP3), ]
	
	# trips$LIVE_POUNDS = trips$POUNDS
	
	trips = trips[,c('FY','DOCID','NESPP3','DATE_TRIP','STRATA','fday','yday', 'LIVE_POUNDS')]
	
	obs = obs[,c('FY','NESPP3','DATESAIL','DATELAND','STRATA','fday','yday', 'CALCLIVEWT','CATDISP','LINK1','LINK3','BAREA')]
	
	list(obs = obs, trips = trips)
}
