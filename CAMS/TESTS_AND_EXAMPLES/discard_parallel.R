# try it in parallel ----
install.packages('snowfall', lib = '/opt/R/4.2.1/lib/R/library/')

devtools::install_github('https://github.com/noaa-garfo/discaRd/tree/paths')

library(snowfall)


species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>%
	filter(RUN_ID == 'NOVEMBER') %>%
	collect() %>%
	group_by(ITIS_TSN) %>%
	slice(1) %>%
	ungroup()

save_dir = file.path(getOption("maps.discardsPath"), "november")


fy = 2018

# sfExport(list = c('species','non_gf_dat','con_maps','fy','save_dir','discard_november'))

# Init Snowfall with explicit settings.
sfInit( parallel=TRUE, cpus = 2 )

if( sfParallel() )
	cat( "Running in parallel mode on", sfCpus(), "nodes.\n" )

sfExportAll()

# sfExport(con_maps)

sfLibrary(stringr)
sfLibrary(discaRd)
sfLibrary(MAPS)
sfLibrary(dplyr)
sfLibrary(dbplyr)
sfLibrary(fst)
sfLibrary(apsdFuns)
sfLibrary(odbc)
sfLibrary(ROracle)
sfLibrary(keyring)
sfLibrary(config)

# sfExport('discaRd')

# sfLapply(as.list(1:nrow(species)), function(x) {
sfLapply(as.list(1), function(x) {
	
	dw_apsd <- config::get(value = "maps", file = "~/config.yml")
	
	con_maps <- ROracle::dbConnect(
		drv = ROracle::Oracle(),
		username = dw_apsd$uid,
		password = dw_apsd$pwd,  
		dbname = "NERO.world"
	)
	
	
	# roracle_login <- function (key_name, key_service) {
	# 	conn <- ROracle::dbConnect(
	# 		drv = ROracle::Oracle()
	# 		, username = as.character(keyring::key_list(key_service, key_name)$username)
	# 		, password = keyring::key_get(
	# 					service = key_service,
	# 					username = as.character(keyring::key_list(key_service, key_name)$username),
	# 					keyring = key_name
	# 			 )
	# 		  , dbname = keyring::key_get(service = "dbname", keyring = key_name)
	# 		)
	# 	return(conn)
	# }
	# 
	# 
	# keyring::keyring_unlock("apsd_ma", password = '')
	# con_maps = roracle_login(key_name = 'apsd_ma', key_service = 'maps')
	# discaRd::discard_november(con = con_maps
	# 						, species = species[x,]
	# 						, FY = fy
	# 						, non_gf_dat = non_gf_dat
	# 						, save_dir = save_dir
	# )
}
)

sfStop()

#-- try parallel ----
library(parallel)

cl = parallel::makeCluster(2)

parallel::clusterEvalQ(cl = cl, 
	{
	dw_apsd <- config::get(value = "maps", file = "~/config.yml")
	
	con_maps <- odbc::dbConnect(odbc::odbc(),
							DSN = dw_apsd$dsn, 
							UID = dw_apsd$uid, 
							PWD = dw_apsd$pwd)
	
	dplyr::tbl(con_maps, dplyr::sql('select * from CAMS_STATAREA_STOCK'))
	
	
})


# loop ----

for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	discard_may(con = con_maps
							, species = species
							, FY = fy
							, non_gf_dat = non_gf_dat
							, save_dir = save_dir
	)

	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}



########################################
# foreach version

library(doParallel)
cl <- makePSOCKcluster(detectCores())
registerDoParallel(cl)

clusterEvalQ(cl, {
  library(DBI)
  library(RPostgreSQL)
  drv <- dbDriver("PostgreSQL")
  con <- dbConnect(drv, dbname="nsdq")
  NULL
})

for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
  discard_may(con = con_maps
              , species = species
              , FY = fy
              , non_gf_dat = non_gf_dat
              , save_dir = save_dir
  )

  parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}

tmp_foreach <- foreach(i=1588:3638, .inorder=FALSE,
                          .noexport="con",
                          .packages=c("DBI", "RPostgreSQL")) %dopar% {
                            lst <- eval(expr.01)  #contains the SQL query which depends on 'i'
                            qry <- dbSendQuery(con, lst)
                            tmp <- fetch(qry, n=-1)
                            dt <- dates.qed2[i]
                            list(date=dt, idreuters=tmp$idreuters)
                          }

clusterEvalQ(cl, {
  dbDisconnect(con)
})
