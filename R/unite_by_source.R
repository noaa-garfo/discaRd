#' Unite by source
#' This function gets a `STRATA_USED_DESC` for a data frame. This must be used witha specific `DISCARD_SOURCE` and `GF` grouping.
#' @param mytable input table from discard estiamtion
#' @author Benjamin Galuardi
#' @return table with STRATA_USED_DESC column
#' @export
#'
#' @examples
#'
#' tab_list =joined_table %>%
#' group_split(DISCARD_SOURCE, GF) %>%   # group_split may be deprecated in the future..
#'   lapply(., unite_by_source)
#'
#' joined_table = do.call(rbind, tab_list) %>%
#'   as_tibble()
#'
unite_by_source = function(mytable){
  cols_used = unlist(str_split(mytable$STRATA_USED, pattern =';')) %>%
    unique()

  if(cols_used[1] == ""){
    mytable$STRATA_USED_DESC = ""
  } else {
    mytable = mytable %>%
      dplyr::rowwise() %>%
      tidyr::unite(., col = 'STRATA_USED_DESC', cols_used, remove = F, sep = ';')
  }

  mytable

}
