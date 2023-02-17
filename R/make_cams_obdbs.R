#' Make CAMS OBDBS
#' builds table for one calendar year of observer data.
#' @param con ROracle connection
#' @param year Year to build
#' @param sql_file sql file with code to to the table build on Oracle
#'
#' @return builds a table on Oracle schema specified (e.g. MAPS)
#' @export
#'
#' @examples
#' # unlock keyring
#'
#' keyring::keyring_unlock("apsd_ma")
#' con_maps = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')
#'
#' # Make obs tables for several years
#' for(i in 2017:2022){
#' require(glue)
#' make_cams_obdbs(con_maps, i, sql_file = paste0(path.package('discaRd'),'/inst/SQL/make_obdbs_table_cams_v3.sql'))
#'
#' idx1 = paste0("CREATE INDEX i_CAMS_obdbs", i, "_year_link_spp", " ON ", paste0('CAMS_OBDBS_',i) ,"(YEAR, LINK1, LINK3, NESPP3, NESPP4)")
#  idx2 = paste0("CREATE INDEX itisidx_gf", i, " ON ", paste0('CAMS_DISCARD_EXAMPLE_GF', i) ,"(SPECIES_ITIS)")
#' ROracle::dbSendQuery(con_maps, idx1)
#'
#' }
#' #test
#' ROracle::dbGetQuery(con_maps, paste0("select * from MAPS.CAMS_OBDBS_", 2021)) %>% head()

#' # create a view of all obdbs tables on CAMS_GARFO

#' tab_list = ROracle::dbGetQuery(con_maps, "
#' SELECT object_name, object_type
#'     FROM all_objects
#'     WHERE object_type = 'TABLE'
#'     and owner = 'MAPS'
#' and object_name like 'CAMS_OBDBS%'
#'															 ")
#'
#' st = "CREATE OR REPLACE VIEW CAMS_OBDBS_ALL_YEARS AS "
#'
#' tab_line = paste0("select * from MAPS.", tab_list$OBJECT_NAME," UNION ALL " )  # groundfish only..
#'
#' bidx = grep('*MORTALITY*', tab_line)
#'
#' tab_line = tab_line[-bidx]
#'
#' tab_line[length(tab_line)] = gsub(replacement = "", pattern = "UNION ALL", x = tab_line[length(tab_line)])
#'
#'
#' create a script to pass to SQL
#'
#' sq = stringr::str_c(st, stringr::str_flatten(tab_line))
#'
#' pass the script to make a view
#' ROracle::dbSendQuery(con_maps, sq)

# grant all to cams_garfo

#' ROracle::dbSendQuery(con_maps, "GRANT ALL ON CAMS_OBDBS_ALL_YEARS TO CAMS_GARFO WITH GRANT OPTION")

#' # GRANT TO CAMS_GARFO_FOR_NEFSC FROM CAMS_GARFO

#' con_cams = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'cams_garfo')

#' Sys.setenv(TZ = "America/New_York")
#' Sys.setenv(ORA_SDTZ = "America/New_York")

#' ROracle::dbSendQuery(con_cams, "CREATE OR REPLACE VIEW CAMS_GARFO.CAMS_OBDBS_ALL_YEARS AS SELECT * FROM MAPS.CAMS_OBDBS_ALL_YEARS")

#' ROracle::dbSendQuery(con_cams, "GRANT SELECT ON CAMS_GARFO.CAMS_OBDBS_ALL_YEARS TO CAMS_GARFO_FOR_NEFSC")
#'
#'
#'
make_cams_obdbs <- function(con, year = 2022, sql_file = "~/PROJECTS/discaRd/CAMS/SQL/make_obdbs_table_cams_v3.sql"){

	t1 = Sys.time()
	print(paste0('Building CAMS Observer table for: ', year))
	# define year

	y = year

	# drop table
	if(ROracle::dbExistsTable(conn = con, paste0("CAMS_OBDBS_", y)) == T) {
		tab_drop = paste0("DROP TABLE CAMS_OBDBS_", y)
		print(tab_drop)
		ROracle::dbSendQuery(con, tab_drop)
	}


	# build table

	tab_build = readr::read_lines(sql_file) %>%
		glue_collapse(sep = "\n") %>%
		glue_sql(.con = con) %>%
		gsub(x = ., pattern = '&YEAR', replacement = y) %>%
		gsub(x = ., pattern = '&year', replacement = y)

	print(paste0('Building table CAMS_OBDBS_',y))
	ROracle::dbSendQuery(con, tab_build)

	# modify table

	tab_alter = paste0("ALTER TABLE CAMS_OBDBS_", y, " DROP (mesh_cat_pre, tripcategory1, accessarea1)")
	print(tab_alter)

	ROracle::dbSendQuery(con, tab_alter)

	# test
	# ROracle::dbGetQuery(con_maps, paste0("select * from MAPS.CAMS_OBDBS_", y)) %>% head()
	t2 = Sys.time()
	print(paste0("Runtime: ", round(difftime(time1 = t2, time2 = t1, units = 'mins'), 2), " minutes"))

}
