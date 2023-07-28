#' Get Groundfish data for simulation
#'
#' @param dmisfile R workspace with DMIS data
#' @param obsfile R workspace with Observer data
#' @param fystart first day of the fishing year (specific year does not matter)
#'
#' @return a list with DMIS and OBS data formatted for simulations
#' @export
#'
#' @examples
get.gf.data = function(dmisfile, obsfile, fystart = '5-1-2001'){

# Observer data 
load(obsfile)
obs = obsdat
rm(obsdat)

# DMIs Data 
load(dmisfile)
trips = dmisdat
rm(dmisdat)

# add FY, yday and fday columns
names(obs)[grep('MULT_YEAR',names(obs))] = 'FY'

# deal with leap years..
lyidx = obs$FY%in%c(2011,2015)
obs$yday = yday(obs$DATELAND)
obs$fday0 = ifelse(lyidx, 122, 121)
obs$fday = ifelse(obs$yday<obs$fday0, obs$yday+244, obs$yday-obs$fday0)
obs$fday[obs$yday==obs$fday0] = 1

lyidx = trips$FY%in%c(2011,2015)
trips$yday = yday(trips$DATE_TRIP)
trips$fday0 = ifelse(lyidx, 122, 121)
trips$fday = ifelse(trips$yday<trips$fday0, trips$yday+244, trips$yday-trips$fday0)
trips$fday[trips$yday==trips$fday0] = 1

# make the STRAT A column character (not a factor)
obs$STRATA = as.character(obs$STRATA)
trips$STRATA = as.character(trips$STRATA)

#get rid of NA in NESPP3

obs = obs[!is.na(obs$NESPP3), ]

# trips$LIVE_POUNDS = trips$POUNDS

trips = trips[,c('FY','DOCID','BYCATCH','NESPP3_BYCATCH','NESPP3','DATE_TRIP','STRATA','fday','yday', 'LIVE_POUNDS')]

obs = obs[,c('FY','BYCATCH','NESPP3','DATESAIL','DATELAND','STRATA','fday','yday', 'CALCLIVEWT','CATDISP','LINK1','LINK3')]

list(obs = obs, trips = trips)
}
