
#' Make CAMS_OBS_CATCH
#'
#' @param con Oracle connection (ROracle preferred)
#' @param sql_file Sql file that builds the table. The SQL lives in another folder within the discaRd project
#'
#' @return Oracle table of merged CAMS landings and observer data
#' @export
#'
#' @examples
#' 
#' # unlock keyring 
#' 
#' keyring::keyring_unlock("apsd_ma")
#' con_maps = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')
#' sqlfile = paste0(path.package('discaRd'),'/inst/SQL/MERGE_CAMS_OBS_CATCH_AUG2022.sql')
#' make_cams_obs_catch(con_maps, sql_file = sqlfile)
#' 
#' # make indices
#' 
#' # share to CAMS_GARFO
#' ROracle::dbSendQuery(con_maps, "GRANT ALL ON CAMS_OBS_CATCH TO CAMS_GARFO WITH GRANT OPTION")
#' 
#' # share to NEFSC
#' con_cams = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'cams_garfo')
#' 
#' Sys.setenv(TZ = "America/New_York")
#' Sys.setenv(ORA_SDTZ = "America/New_York")

#' ROracle::dbSendQuery(con_cams, "CREATE OR REPLACE VIEW CAMS_GARFO.CAMS_OBS_CATCH AS SELECT * FROM MAPS.CAMS_OBS_CATCH")

#' ROracle::dbSendQuery(con_cams, "GRANT SELECT ON CAMS_GARFO.CAMS_OBS_CATCH TO CAMS_GARFO_FOR_NEFSC")
#' 
make_cams_obs_catch <- function(con, sql_file = "~/PROJECTS/discaRd/CAMS/SQL/make_cams_obs_catch_Aug2022.sql"){
	
	t1 = Sys.time()
	print('Building CAMS_OBS_CATCH')
	
	# drop table
	if(ROracle::dbExistsTable(conn = con, paste0("CAMS_OBS_CATCH")) == T) {
		tab_drop = "DROP TABLE CAMS_OBS_CATCH"
		print(tab_drop)
		ROracle::dbSendQuery(con_maps, tab_drop)
	}
	
	
	# build table
	
	tab_build = readr::read_lines(sql_file) %>% 
		glue_collapse(sep = "\n") %>% 
		glue_sql(.con = con) 
	
	print('Building table CAMS_OBS_CATCH')
	ROracle::dbSendQuery(con_maps, tab_build)
	
	# modify table
	
	tab_alter = paste0("ALTER TABLE CAMS_OBS_CATCH", " modify OBS_LINK1 varchar2(100 char)")
	print(tab_alter)
	
	ROracle::dbSendQuery(con_maps, tab_alter)
	
	# test
	# ROracle::dbGetQuery(con_maps, paste0("select * from MAPS.CAMS_OBDBS_", y)) %>% head()
	t2 = Sys.time()
	print(paste0("Runtime: ", round(difftime(time1 = t2, time2 = t1, units = 'mins'), 2), " minutes"))
	
}