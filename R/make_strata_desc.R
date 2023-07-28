#' make_strata_desc
#' @details Make the strata description based on the STRATA_USED and associated columns
#' @author Daniel Hocking, Benjamin Galuardi
#' @param x data.frame with column STRATA_USED and the associated, named columns
#' @param remove logical indicating whether to return just summarized descriptions or full data set with the new columns added.
#'
#' @return data frame of trips and discards
#' @export
#'
#' @examples
#'
#' \dontrun{
#' library(dplyr)
#' library(tidyr)
#' library(stringr)
#'
#' foo <- data.frame(
#'   STRATA_USED = c("A", "A;B", "B;C", "A;B;C", "A;B", "A", "", NA_character_, NA_character_),
#'   A = c("A1", "A2", "A3", "A4", "", NA_character_, NA_character_, NA_character_, "A8"),
#'   B = c("B1", "B2", "B3", "B4", "B5", "B6", NA_character_, NA_character_, NA_character_#' ),
#' #'   C = c("C1", "C2", "C3", "C4", "C5", "C6", NA_character_, NA_character_, "C8")
#' )
#'
#' make_strata_desc(foo)
#' }
make_strata_desc <- function(x, remove = FALSE) {

  x <- x |>
    dplyr::ungroup() |>
    dplyr::mutate(row_x = dplyr::row_number())

  x_missing <- x |>
    # dtplyr::lazy_dt() |>
    dplyr::filter(is.na(STRATA_USED) | STRATA_USED == '') |>
    as.data.frame()

  x <- x |>
    # dtplyr::lazy_dt() |>
    dplyr::filter(!(row_x %in% unique(x_missing$row_x))) |>
    as.data.frame()

  x_list <- x |>
    dplyr::group_by(STRATA_USED) |>
    dplyr::group_split()

  for(i in 1:length(x_list)) {

    cols <- unlist(stringr::str_split(unique(x_list[[i]]$STRATA_USED), ";"))

    if(is.na(cols[1])) next
    if(cols[1] == "") next

    tmp <- x_list[[i]] |>
      tidyr::unite(col = STRATA_USED_DESC, cols, sep = ";", remove = FALSE) |>
      as.data.frame()

    if(!exists("tab")) {
      tab <- tmp
    } else {
      tab <- dplyr::bind_rows(tmp, tab)
    }
  }

  tab <- dplyr::ungroup(tab)

  if(isTRUE(remove)) {
    return(tab)
  } else {
    tab <- dplyr::bind_rows(tab, x_missing)
    return(tab)
  }
}
