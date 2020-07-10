#' Get Fishery data, specify bycatch species
#' 
#' Function to make dataframe according to bycatch species, fishery etc..
# designed to work with one dataset/fishery... many bycatch species
#' @param fdat name of file to be loaded OR name of variable in workspace containing data
#' @param load should data be loaded into the workspace? If already loaded, specify fdat as the variable name in your workspace and flag load=F
#' @param bspec bycatch species desired
#' @param catch_disp catch disposition of the bycatch (0 = discard, 1 = kept).  Default is 0.
#' @param aggfact aggregation factor. for NOAA data, LINK1 usually indicates trip level. Using \code{\link{eflalo}}, 'FT_REF' is indicates trips
#'
#' @details The catch disposition is typically 0 for discards, but some fisheries (herring) may want both.
#' @return dataframe of observed catch summed by some aggregating factor (\code{aggfact})
#'  for the bycatch species of interest (\code{bspec}) and the total catch
#' @export
#'
#' @examples
#' data(eflalo)
#' dm = make.obs.flag.dat(eflalo, obs_level = .1)
#' dmo = dm[dm$OBSFLAG==1&dm$FY==1800,]  # one year of data
#' # Define a bycatch species
#' bspec = 'LE_KG_BSS' # European seabass (FAO code BSS)
#' bdat = get.bydat(dmo, aggfact = 'DOCID',load = F, bspec = bspec, catch_disp = 1) # unstratified

get.bydat <-
	function(fdat, load = T, bspec = 366, aggfact = 'LINK1', catch_disp = c(0,1)[1]) {
		bdat = list()
		# for (i in 1:length(bfish)) {
		if(load == T){
			bfile = fdat
			load(bfile)
		} else {
			dat = fdat
		}
		# for(i in 1:length(bspec)){
			bdat = ddply(dat, aggfact, function(x)
				data.frame(
					BYCATCH = sum(x$CALCLIVEWT[x$CATDISP %in% catch_disp &
																		 	x$NESPP3 %in% bspec], na.rm = T)
					, KALL = sum(x$CALCLIVEWT[x$CATDISP == 1], na.rm =
											 	T)
					# , YEAR = x$YEAR[1]
					, FY = x$FY[1]
					, yday = x$yday[1]
					, fday = x$fday[1]
					# , AREA = x$AREA[1]
					# , NEGEAR = x$NEGEAR[1]
					# , SECGEARFISH = x$SECGEARFISH[1]
					# , MESH = x$MESH_CAT[1]
					# , VESSEL_LENGTH = x$VESSEL_LENGTH[1]
					, SEADAYS = as.numeric(x$DATELAND[1] - x$DATESAIL[1])
				  # , PROGRAM = ifelse('PROGRAM'%in%names(dat)==T, x$PROGRAM[1], NA)
					# , STRATA = x$strata[1]
				))
		# }
		bdat
	}
