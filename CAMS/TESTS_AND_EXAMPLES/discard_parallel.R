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

# sfExport('discaRd')

sfLapply(as.list(1:nrow(species)), function(x) {
	keyring::keyring_unlock("apsd_ma", password = '')
	con_maps = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')
	# discaRd::discard_november(con = con_maps
	# 						, species = species[x,] 
	# 						, FY = fy
	# 						, non_gf_dat = non_gf_dat
	# 						, save_dir = save_dir
	# )
}
)

sfStop()


for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	discard_may(con = con_maps
							, species = species
							, FY = fy
							, non_gf_dat = non_gf_dat
							, save_dir = save_dir
	)
	
	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}