#' Make CAMS OBDBS All YEARS
#' builds table for one calendar year of observer data.
#' @param con ROracle connection
#'
#' @return builds a table on Oracle schema specified (e.g. MAPS)
#' @export
#'
make_cams_obdbs_all_years <- function(con){

  # list of tables

  # range of years for tables starting with CAMS_OBDBS_

  # check years in CAMS_OBDBS_ALL_YEARS

  # If year not in all years then recreate the table with an additional union

  # ALTERNATIVE: Stop making the annual tables and just make one big table - will be far more efficient and allow for a cleaner, easier to maintain schema

  # for now just do it manually as a view until have time to revamp the system
  rs <- ROracle::dbGetQuery(
    con,
    "CREATE OR REPLACE FORCE EDITIONABLE VIEW cams_obdbs_all_years AS (
    SELECT * FROM cams_obdbs_2015
    UNION ALL
    SELECT * FROM cams_obdbs_2016
    UNION ALL
    SELECT * FROM cams_obdbs_2017
    UNION ALL
    SELECT * FROM cams_obdbs_2018
    UNION ALL
    SELECT * FROM cams_obdbs_2019
    UNION ALL
    SELECT * FROM cams_obdbs_2020
    UNION ALL
    SELECT * FROM cams_obdbs_2021
    UNION ALL
    SELECT * FROM cams_obdbs_2022
    UNION ALL
    SELECT * FROM cams_obdbs_2023
    )"
  )

  rs <- DBI::dbCommit(con)
}
