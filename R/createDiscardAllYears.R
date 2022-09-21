#' createDiscardAllYears
#'
#' @param con Oracle connection (ROracle preferred)
#' @param path Path to discard fst files
#'
#' @return Oracle table of merged CAMS landings and observer data
#' @export
#'
#' @examples
#'
#' \dontrun{
#' # unlock keyring
#'
#' keyring::keyring_unlock("apsd_ma")
#' con_maps = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')
#' createDiscardAllYears(con = con_maps)
#' }
createDiscardAllYears <- function(con, drop = FALSE) {

  if(drop) {
    if(ROracle::dbExistsTable(con, paste0('CAMS_DISCARD_ALL_YEARS'))) {
      DBI::dbExecute(
        con,
        paste0("DROP TABLE CAMS_DISCARD_ALL_YEARS"),
        purge = TRUE
      )
      ROracle::dbCommit(con)
    }
  }

    sql_create_table <- paste0("
                               create table CAMS_DISCARD_ALL_YEARS
  DATE_RUN	          DATE
  FY	                NUMBER(4,0)
  DATE_TRIP	          DATE
  YEAR	              NUMBER(4,0)
  MONTH	              NUMBER(2,0)
  ITIS_TSN          	VARCHAR2(6 CHAR)
  COMMON_NAME	        VARCHAR2(30 CHAR)
  FY_TYPE	            VARCHAR2(15 CHAR)
  ACTIVITY_CODE	      VARCHAR2(14 CHAR)
  VTRSERNO	          VARCHAR2(16 CHAR)
  CAMSID	            VARCHAR2(75 CHAR)
  DOCID	              VARCHAR2(15 CHAR)
  CAMS_SUBTRIP	      VARCHAR2(80 CHAR) --need to add just subtrip
  FED_OR_STATE	      VARCHAR2(10 CHAR)
  GF	                VARCHAR2(5 CHAR)
  AREA	              VARCHAR2(3 CHAR)
  LINK1	              VARCHAR2(15 CHAR)
  N_OBS_TRIPS_F	      NUMBER(5,0)
  STRATA_USED	        VARCHAR2(200 CHAR)
  STRATA_FULL	        VARCHAR2(200 CHAR)
  STRATA_ASSUMED	    VARCHAR2(200 CHAR)
  DISCARD_SOURCE	    VARCHAR2(10 CHAR)
  OBS_DISCARD	        NUMBER(12,2)
  OBS_KALL	          NUMBER(12,2)
  SUBTRIP_KALL	      NUMBER(12,2)
  CAMS_DISCARD_RATE	  NUMBER(7,6)
  DISCARD_RATE_S_GM	  NUMBER(7,6)
  DISCARD_RATE_G	    NUMBER(7,6)
  CAMS_CV	            NUMBER(6,3)
  CV_I_T	            NUMBER(6,3)
  CV_S_GM	            NUMBER(6,3)
  CV_G	              NUMBER(6,3)
  DISC_MORT_RATIO	    NUMBER(4,3)
  CAMS_DISCARD	      NUMBER(12,2)
  SPECIES_STOCK	      VARCHAR2(15 CHAR)
  GEARCODE	          VARCHAR2(4 CHAR)
  NEGEAR	            VARCHAR2(3 CHAR)
  GEARTYPE	          VARCHAR2(50 CHAR)
  CAMS_GEAR_GROUP	    VARCHAR2(15 CHAR)
  MESH_CAT	          VARCHAR2(3 CHAR)
  SECTID	            VARCHAR2(3 CHAR)
  EM	                VARCHAR2(10 CHAR)
  REDFISH_EXEMPTION	  VARCHAR2(1 CHAR)
  SNE_SMALLMESH_EXEMPTION	VARCHAR2(1 CHAR)
  XLRG_GILLNET_EXEMPTION	VARCHAR2(1 CHAR)
  TRIPCATEGORY	      VARCHAR2(5 CHAR)
  ACCESSAREA	        VARCHAR2(5 CHAR)
  SCALLOP_AREA	      VARCHAR2(5 CHAR)
  ")

    if(!ROracle::dbExistsTable(con, toupper("cams_discard_all_years"))) {

      # Create Table
      ROracle::dbGetQuery(con, create_table)

      # Add NOLOGGING for speed since we don't roll back currently
      ROracle::dbGetQuery(con, paste0("alter table CAMS_DISCARD_ALL_YEARS nologging"))

      # Grant permissions
      ROracle::dbGetQuery(con, paste0("GRANT SELECT ON CAMS_DISCARD_ALL_YEARS TO MAPS, APSD, CAMS_GARFO, CAMS_GARFO_FOR_NEFSC")) # any problem with granting the MAPS. version? This may need to depend on the schema and can be if-else with the configRun.toml production indicator

      # Add indexes

      # Commit
      ROracle::dbCommit(con)
    }

  }


  #' appendDiscardAllYears
  #'
  #' @param con Oracle connection (ROracle preferred)
  #' @param file File including path to discard fst file to append (maybe use FY and module name to define to get path and what to delete before appending)
  #'
  #' @return Oracle table of merged CAMS landings and observer data
  #' @export
  #'
  #' @examples
  #'
  #' \dontrun{
  #' # unlock keyring
  #'
  #' keyring::keyring_unlock("apsd_ma")
  #' con_maps = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')
  #' createDiscardAllYears(con = con_maps)
  #' }
  appendDiscardAllYears <- function(con, path = getOption("maps.discardsPath")) {

    ins_str <- paste0("insert into CAMS_CFLEN", year_run, "AA values(:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18, :19, :20, :21, :22, :23, :24, :25, :26, :27, :28, :29, :30, :31, :32, :33, :34, :35, :36, :37, :38, :39, :40, :41, :42, :43, :44, :45, :46, :47, :48, :49)")

    # delete existing data
    ROracle::dbGetQuery(con,
                        paste0("delete from CAMS_CFLEN", year_run, "AA where year in (", year_run, ")"))
    ROracle::dbCommit(con)

    ROracle::dbGetQuery(con, ins_str_year, cflen_full)
    ROracle::dbCommit(con)

    rebuild_indexes_cflen_aa(con = con, table = paste0("CAMS_CFLEN", year_run, "AA"))
    ROracle::dbCommit(con)

  }
