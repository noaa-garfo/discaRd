#' Get Date Range
#' get date range for particular type of fishing year
#' @param FY Fishing Year (e.g. 2020)
#' @param FY_TYPE  Type of fishing year (e.g. CALENDAR). This is case sensitive as it calls `CFG_DISCARD_RUNID`
#'
#' @return a start and end date
#' @export
#'
#' @examples
get_date_range = function(FY, FY_TYPE){
	y = FY
	if(FY_TYPE == 'APRIL'){
		smonth = ifelse(y <= 2018, 3, 4)
		emonth = ifelse(y < 2018, 2, 3)
		eday = ifelse(y < 2018, 28, 31)
		sdate = lubridate::as_date(paste(y, smonth, 1, sep = "-"))
		edate = lubridate::as_date(paste(y + 1, emonth, eday, 
																		 sep = "-"))
	}
	if(FY_TYPE == 'MARCH'){
		sdate = lubridate::as_date(paste(y, 3, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 3, 1, sep = '-'))
	}
	if(FY_TYPE == 'MAY'){
		sdate = lubridate::as_date(paste(y, 5, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 5, 1, sep = '-'))
	}
	if(FY_TYPE == 'NOVEMBER'){
		smonth = case_when(y <= 2021 ~ 11
											 , y == 2022 ~ 11
											 , y > 2022 ~ 1
		)
		emonth = case_when(y <= 2021 ~ 10
											 , y == 2022 ~ 12
											 , y > 2022 ~ 12
		)
		syear = case_when(y <= 2021 ~ y-1
											, y == 2022 ~ y-1
											, y > 2022 ~ y
		)
		sdate = lubridate::as_date(paste(syear, smonth, 1, sep = '-'))
		edate = lubridate::as_date(paste(y, emonth, 31, sep = '-'))
	}
	if(FY_TYPE == 'CALENDAR'){
		sdate = lubridate::as_date(paste(y, 1, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 1, 1, sep = '-'))
	}
	
	if(FY_TYPE == 'HERRING'){
		sdate = lubridate::as_date(paste(y, 1, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 1, 1, sep = '-'))
	}
	sdate = lubridate::floor_date(sdate, unit = 'day')
	c(sdate, edate)
	
}
