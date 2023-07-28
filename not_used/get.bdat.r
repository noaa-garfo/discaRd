#' Load Fishery/Species Observer Data
#'
#' @param fdata
#' @param year year desired (2010-2014).
#'
#' @return data frame suitable for Cochran estimation.
#' @export
#'
#' @examples
#'
#'# not run.. names of the bycatch fishery c('GROUNDFISH'
#','HADD_HERR_GB'
#','HADD_HERR_GOM'
#','RHS_HERR_GOM_MW'
#','RHS_HERR_CC_MW'
#','RHS_HERR_SNE_MW'
#','RHS_HERR_SNE_BT'
#','RHS_MACK'
#','BUTTERFISH_MORT'
#','SCAL_YT_SNE'
#','SCAL_YT_GB'
#','SCAL_WP_SNE'
#')
#'
#' data(GROUNDFISH)
#' # one year
#' gfish11 = get.bdat(dat, 2011)
#' # many years
#' gfish10_15 = get.bdat(dat, 2010:2015)
#'
#'
get.bdat = function(dat, year = 2010:2014){
	# data(fdata, package = 'SBRMFUN')
	bdat = ddply(dat[dat$YEAR%in%year,], 'LINK1', function(x) data.frame(BYCATCH = sum(x$CALCLIVEWT[x$CATDISP==0], na.rm=T), KALL = sum(x$CALCLIVEWT[x$CATDISP==1], na.rm=T), YEAR = x$YEAR[1]))
	bdat
}
