
# Setup ----
# library(odbc)
library(ROracle)
library(MAPS)
#library(keyring)
library(apsdFuns)
library(dplyr, warn.conflicts = FALSE)
library(dbplyr)
library(ggplot2)
# library(config)
library(stringr)
# library(discaRd)
library(fst)
options(scipen = 999)


# load discard functions
devtools::load_all()

# unlock keyring
keyring::keyring_unlock("apsd_ma")

# connect to MAPS
con_maps = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')

'%!in%' <- function(x,y)!('%in%'(x,y))

Sys.setenv(TZ = "America/New_York")
Sys.setenv(ORA_SDTZ = "America/New_York")

## ----refresh and rebuild obdbs and cams_obs_catch---------------------------------------------------------------------------------

for(i in 2022){
	require(glue)
	make_cams_obdbs(con_maps, i, sql_file = "inst/SQL/make_obdbs_table_cams.sql") # convert to within package
}

# CAMS_OBS_CATCH
make_cams_obs_catch(con_maps, sql_file = 'inst/SQL/MERGE_CAMS_CATCH_OBS.sql') # convert to within package


## ----get obs and catch data from oracle ---------------------------------------------------------------------------------

start_year = 2017
end_year = 2022

dat = get_catch_obs(con_maps, start_year, end_year)
gf_dat = dat$gf_dat
non_gf_dat = dat$non_gf_dat
all_dat = dat$all_dat
rm(dat)
gc()

#'
## ----run groundfish species RMD as a script -----------------------------------------------------------------------------

# this section may be repeated for other modules with other lists of species

#--------------------------------------------------------------------------#
# get groundfish species list

species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
	filter(RUN_ID == 'GROUNDFISH') %>% 
	collect() %>% 
	group_by(ITIS_TSN) %>% 
	slice(1) %>% 
	ungroup()

save_dir = file.path(getOption("maps.discardsPath"), 'groundfish')

# run it
for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	# FY <- jj
	# FY_TYPE = 'MAY START' # moved into function
  # source('groundfish_loop.R') # move this to R/ and run as function
		# discard_groundfish(con = con_maps
		# 									 , species = species #[c(7,11),]
		# 									 , gf_dat = gf_dat
		#                    , non_gf_dat = non_gf_dat
		# 									 , gf_trips_only = F
		# 									 , save_dir = save_dir
		# 									 , FY = fy)

  parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy, gf_only = F)
}

# commit DB

ROracle::dbCommit(con_maps)

# fix some file permissions that keep geting effed up
# system('chmod 770 -R .git/index')
# system('chmod 770 -R .git/objects')

#'
## ----run calendar year species RMD as a script, eval = T--------------------------------------------------------------------------

#--------------------------------------------------------------------------#
# group of species

species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
	filter(RUN_ID == 'CALENDAR') %>% 
	collect() %>% 
	group_by(ITIS_TSN) %>% 
	slice(1) %>% 
	ungroup()

save_dir = file.path(getOption("maps.discardsPath"), "calendar")

for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	discard_generic(con = con_maps
										 , species = species
										 , FY = fy
										 , all_dat = all_dat
										 , save_dir = save_dir
	)
		
		parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
	}

# commit DB

ROracle::dbCommit(con_maps)

# clean the workspace
gc()





 ## ----run may year species RMD as a script, eval = F-------------------------------------------------------------------------------

species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
	filter(RUN_ID == 'MAY') %>% 
	collect() %>% 
	group_by(ITIS_TSN) %>% 
	slice(1) %>% 
	ungroup()

save_dir = file.path(getOption("maps.discardsPath"), "may")


for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	discard_generic(con = con_maps
									 , species = species
									 , FY = fy
									 , all_dat = all_dat
									 , save_dir = save_dir
	)
	
	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

# clean the workspace
gc()


 ## ----run November year species RMD as a script, eval = F -------------------

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


for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	discard_generic(con = con_maps
									 , species = species
									 , FY = fy
									 , all_dat = all_dat
									 , save_dir = save_dir
	)
	
	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)


# clean the workspace
gc()





 ## ----run march year species RMD as a script, eval = F-----------------------------------------------------------------------------

  
  species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
  	filter(RUN_ID == 'MARCH') %>% 
  	collect() %>% 
  	group_by(ITIS_TSN) %>% 
  	slice(1) %>% 
  	ungroup()
  
  save_dir = file.path(getOption("maps.discardsPath"), "march")
  
  
  for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
  	discard_generic(con = con_maps
  									 , species = species
  									 , FY = fy
  									 , all_dat = all_dat
  									 , save_dir = save_dir
  	)
  	
  	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
  }
  
# commit DB

ROracle::dbCommit(con_maps)

# clean workspace
gc()
  




 ## ----run april year species RMD as a script -----------------------------------------------------------------------------

  
  species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
  	filter(RUN_ID == 'APRIL') %>% 
  	collect() %>% 
  	group_by(ITIS_TSN) %>% 
  	slice(1) %>% 
  	ungroup()
  
  save_dir = file.path(getOption("maps.discardsPath"), "april")
  
  
  for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
  	discard_generic(con = con_maps
  									 , species = species
  									 , FY = fy
  									 , all_dat = all_dat
  									 , save_dir = save_dir
  	)
  	
  	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
  }
  
  # commit DB
  
  ROracle::dbCommit(con_maps)

# clean the workspace
gc()



  ## ----run Herring RMD as a script ----------------------------------------------------------------------------
  
  # remove previous data pull
  
  rm(alldat, non_gf_dat, gf_dat)
  
  # pull herring specific data
  start_year = 2018
  end_year = 2022
  
  all_dat = get_catch_obs_herring(con_maps, start_year-1, end_year)
  
  
  species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
  	filter(RUN_ID == 'HERRING') %>% 
  	collect() %>% 
  	group_by(ITIS_TSN) %>% 
  	slice(1) %>% 
  	ungroup()
  
  save_dir = file.path(getOption("maps.discardsPath"), "herring")
  
  
  for(fy in start_year:end_year){ # TODO: move years to configDefaultRun.toml
  	discard_herring(con = con_maps
  								, species = species
  								, FY = fy
  								, all_dat = all_dat
  								, save_dir = save_dir
  	)

  	# parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
  }
  
  # commit DB
  
  ROracle::dbCommit(con_maps)
  
# clean the workspace
  gc()

  

## ---- create/rebuild indexes for discard_all_years ---- 
  
MAPS::indexAllTables(con_maps, tables = "CAMS_DISCARD_ALL_YEARS")  
  
## ---- Add comments ----  

  ## ---- Push to CAMS_GARDO ----

devtools::load_all('~/PROJECTS/MAPS/')
  
con_cams = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'cams_garfo')

'%!in%' <- function(x,y)!('%in%'(x,y))

Sys.setenv(TZ = "America/New_York")
Sys.setenv(ORA_SDTZ = "America/New_York")

pushToCamsGarfo(con = con_cams, tables = c("cams_discard_all_years"))
