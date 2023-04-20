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
		edate = lubridate::as_date(paste(y+1, 2, ifelse(c(y+1) %in% seq(1900, 2100, by = 4), 29, 28), sep = '-')) # account for leap years
	}
	if(FY_TYPE == 'MAY'){
		sdate = lubridate::as_date(paste(y, 5, 1, sep = '-'))
		edate = lubridate::as_date(paste(y+1, 4, 30, sep = '-'))
	}
	if(FY_TYPE == 'NOVEMBER'){
		smonth = dplyr::case_when(y < 2022 ~ 11
											 , y == 2022 ~ 11
											 , y > 2022 ~ 1
		)
		emonth = dplyr::case_when(y < 2022 ~ 10
											 , y == 2022 ~ 12
											 , y > 2022 ~ 12
		)
		syear = dplyr::case_when(y < 2022 ~ as.numeric(y-1)
											, y == 2022 ~ as.numeric(y-1)
											, y > 2022 ~ as.numeric(y)
		)
		sdate = lubridate::as_date(paste(syear, smonth, 1, sep = '-'))
		edate = lubridate::as_date(paste(y, emonth, 31, sep = '-'))
	}
	if(FY_TYPE == 'CALENDAR'){
		sdate = lubridate::as_date(paste(y, 1, 1, sep = '-'))
		edate = lubridate::as_date(paste(y, 12, 31, sep = '-'))
	}
	
	if(FY_TYPE == 'HERRING'){
		sdate = lubridate::as_date(paste(y, 1, 1, sep = '-'))
		edate = lubridate::as_date(paste(y, 12, 31, sep = '-'))
	}
	sdate = lubridate::floor_date(sdate, unit = 'day')
	c(sdate, edate)
	
}

# test it.. 

# fylist = list()
# 
# for (k in c('APRIL','MAY','CALENDAR','NOVEMBER','MARCH','HERRING')){
# 	
# 	for(i in 2017:2023){
# 		
# 		df = data.frame(FY_TYPE = k
# 										, FY = i
# 										, fy_start = get_date_range(FY = i, FY_TYPE = k)[1]
# 										, fy_end = get_date_range(FY = i, FY_TYPE = k)[2])
# 		
# 		fylist[[k]] = bind_rows(fylist[[k]], df)
# 		
# 	}
# 	
# }
# 
# fylist

