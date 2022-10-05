#' append_discard_all_years: Delete and fill
#'
#' @param con ROracle connection to Oracle (e.g. MAPS)
#' @param data Dataframe to delete and insert into Oracle discard_all_years table
#' @param drop Logical whether to drop and recreate the cams_discard_all_years table
#'
#' @export
#'
#' @examples
#'
append_discard_all_years <- function(con = con, data = outlist, drop = FALSE) {

  # drop if desired
  if(drop) {
    ROracle::dbRemoveTable(con, "CAMS_DISCARD_ALL_YEARS")
  }

  # create including grants if doesn't exist
  if (!ROracle::dbExistsTable(con, "CAMS_DISCARD_ALL_YEARS")){
    create_discard_all_years(con = con)
  }

  # Get FY and RUNID to delete

  # checks?

  # Delete
  # tmp <- ROracle::dbGetQuery(
  #   con = con,
  #   paste("DELETE FROM cams_discard_all_years WHERE (fy = ", paste(unique(data$FY), collapse = ","), "AND run_id IN (", paste(unique(data$RUN_ID), collapse = ","), "))")
  # )
  tmp <- ROracle::dbGetQuery(
    con = con,
    paste("DELETE FROM cams_discard_all_years WHERE (fy = ", paste(unique(data$FY), collapse = ","), "AND itis_tsn IN (", paste(unique(data$ITIS_TSN), collapse = ","), "))")
  )

  # Insert append
  ins_str <- paste0("INSERT /*+ append*/ INTO cams_discard_all_years VALUES(:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18, :19, :20, :21, :22, :23, :24, :25, :26, :27, :28, :29, :30, :31, :32, :33, :34, :35, :36, :37, :38, :39, :40, :41, :42, :43, :44, :45, :46, :47, :48, :49)")

  ROracle::dbGetQuery(con, ins_str, data = data)
  ROracle::dbCommit(con)

  # checks?

}
