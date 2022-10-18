
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

## ----Refresh and rebuild obdbs and cams_obs_catch---------------------------------------------------------------------------------

for(i in 2022){
	require(glue)
	make_cams_obdbs(con_maps, i, sql_file = "inst/SQL/make_obdbs_table_cams.sql") # convert to within package
}

# Rebuild CAMS_OBS_CATCH ---- 
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


# send the job

rstudioapi::jobRunScript(
	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_gf_job.R',
	name = paste0('Run groundfish discards for 2018-2022'),
	encoding = "unknown",
	workingDir = NULL,
	importEnv = T,
	exportEnv = ""
)

# test only YT and WP 
# rstudioapi::jobRunScript(
# 	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_gf_job.R',
# 	name = paste0('Run YT/WP discards for ', fy),
# 	encoding = "unknown",
# 	workingDir = NULL,
# 	importEnv = T,
# 	exportEnv = ""
# )

# upload  it
for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml

	# 	rstudioapi::jobRunScript(
	# 	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_upload_job.R',
	# 	name = paste0('Upload groundfish discards for 2018-2022'),
	# 	encoding = "unknown",
	# 	workingDir = NULL,
	# 	importEnv = T,
	# 	exportEnv = ""
	# )
	
	parse_upload_discard(con = con_maps, filepath = file.path(getOption("maps.discardsPath"), 'groundfish'), FY = fy, gf_only = T)
}

# commit DB

ROracle::dbCommit(con_maps)

## ---- gf: create/rebuild indexes for discard_all_years ---- 

MAPS::indexAllTables(con_maps, tables = "CAMS_DISCARD_ALL_YEARS")  

## ----run calendar year species RMD as a script, eval = T---------------------------------------------
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

gc()

##-- background job test ----

# define a fishing year
fy = 2018

rstudioapi::jobRunScript(
	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_calendar_job_noyear.R',
	name = paste0('Run calendar year discards for ', fy),
	encoding = "unknown",
	workingDir = NULL,
	importEnv = T,
	exportEnv = ""
)

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

# for this one, loop over 2018 to 2022

rstudioapi::jobRunScript(
	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_discard_job_noyear.R',
	name = 'Run may year discards for 2018:2022',
	encoding = "unknown",
	workingDir = NULL,
	importEnv = T,
	exportEnv = ""
)


# try background processes.. 

# fy = 2018

# may18 = callr::r_bg(function() {source('~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_calendar_job_noyear.R')}, env = c(callr::rcmd_safe_env()), args = list( save_dir = save_dir, species = species[1,], all_dat = all_dat, fy = 2018))
# 
# may19 = callr::r_bg(function() {source('~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_calendar_job_noyear.R')}, env = c(callr::rcmd_safe_env()), args = list( save_dir = save_dir, species = species[1,], all_dat = all_dat, fy = 2019))

# processx::poll(list(may18, may19), 1000)


for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	# discard_generic(con = con_maps
	# 						, species = species
	# 						, FY = fy
	# 						, all_dat = all_dat
	# 						, save_dir = save_dir
	# )
	
	parse_upload_discard(con = con_maps, filepath = file.path(getOption("maps.discardsPath"), "may"), FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

gc()


## ----run November year species RMD as a script, eval = F--------------------------------------------------------------------------


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

rstudioapi::jobRunScript(
	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_discard_job_noyear.R',
	name = 'Run november year discards for 2018:2022',
	encoding = "unknown",
	workingDir = NULL,
	importEnv = T,
	exportEnv = ""
)


for(fy in 2018:2021){ # TODO: move years to configDefaultRun.toml
	# discard_generic(con = con_maps
	# 								 , species = species
	# 								 , FY = fy
	# 								 , all_dat = all_dat
	# 								 , save_dir = save_dir
	# )
	
	parse_upload_discard(con = con_maps, filepath = file.path(getOption("maps.discardsPath"), "november"), FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

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

rstudioapi::jobRunScript(
	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_discard_job_noyear.R',
	name = 'Run march year discards for 2018:2022',
	encoding = "unknown",
	workingDir = NULL,
	importEnv = T,
	exportEnv = ""
)


for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	# discard_generic(con = con_maps
	# 							, species = species
	# 							, FY = fy
	# 							, all_dat = all_dat
	# 							, save_dir = save_dir
	# )
	
	parse_upload_discard(con = con_maps, filepath = file.path(getOption("maps.discardsPath"), "march"), FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

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

rstudioapi::jobRunScript(
	path = '~/PROJECTS/discaRd/CAMS/TESTS_AND_EXAMPLES/run_discard_job_noyear.R',
	name = 'Run april year discards for 2018:2022',
	encoding = "unknown",
	workingDir = NULL,
	importEnv = T,
	exportEnv = ""
)

for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	# discard_generic(con = con_maps
	# 							, species = species
	# 							, FY = fy
	# 							, all_dat = all_dat
	# 							, save_dir = save_dir
	# )
	
	parse_upload_discard(con = con_maps, filepath = file.path(getOption("maps.discardsPath"), "april"), FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

gc()

## ----run Herring RMD as a script ----------------------------------------------------------------------------

# remove previous data pull

rm(alldat, non_gf_dat, gf_dat)

# pull herring specific data
start_year = 2018
end_year = 2019

alldat = get_catch_obs_herring(con_maps, start_year, end_year)


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


for(fy in 2019){ # TODO: move years to configDefaultRun.toml
	discard_herring(con = con_maps
									, species = species
									, FY = fy
									, all_dat = all_dat
									, save_dir = save_dir
	)
	
	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

# clean the workspace; restart likely not necessary anymore
# rm(list = ls())
gc()
# .rs.restartR()

#--- grant permissions to CAMS_GARFO and create tables ---- 
con_cams = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'cams_garfo')

for (i in 2018:2022){
	for(j in c('may','march','april','november','calendar', 'groundfish')){
		save_dir = file.path(getOption("maps.discardsPath"), j)
		parse_upload_discard(con = con_cams, filepath = save_dir, FY = i)
	}
}

#--- rebuild indices on MAPS and CAMS_GARFO ---- 

# --- add comments on MAPS and CAMS_GARFO ----

#--- grant CAMS_GARFO permissions to CAMS_GARFO_FOR_NEFSC ---- 



