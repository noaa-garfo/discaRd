
#' Assign Strata
#' uses text input to coalesce variables to a STRATA column
#' @param dat catch or observation input
#' @param stratvars variables in `dat` to coalesce
#'
#' @return a data frame (dat) with a `STRATA` column
#' @export
#'
#' @examples
assign_strata <- function(dat, stratvars){
	stratvars = toupper(stratvars)

	dat <- dat |>
		mutate(STRATA = eval(parse(text = stratvars[1])))

	if(length(stratvars) >1 ){

		for(i in 2:length(stratvars)){

			dat <- dat |>
				mutate(STRATA = paste(STRATA, eval(parse(text = stratvars[i])), sep = '_'))
		}

	}
	dat
}
