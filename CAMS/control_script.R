
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
		discard_groundfish(con = con_maps
											 , species = species #[c(7,11),]
											 , gf_dat = gf_dat
		                   , non_gf_dat = non_gf_dat
											 , gf_trips_only = F
											 , save_dir = save_dir
											 , FY = fy)

  parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
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
	discard_calendar(con = con_maps
										 , species = species
										 , FY = fy
										 , all_dat = all_dat
										 , save_dir = save_dir
	)
		
		parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
	}

# commit DB

ROracle::dbCommit(con_maps)

# fix some file permissions that keep geting effed up
# system('chmod 770 -R .git/index')
# system('chmod 770 -R .git/objects')


# clean the workspace; restart likely not necessary anymore
# rm(list = ls())
gc()
# .rs.restartR()




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
	discard_may(con = con_maps
									 , species = species
									 , FY = fy
									 , all_dat = all_dat
									 , save_dir = save_dir
	)
	
	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

# fix some file permissions that keep geting effed up
# system('chmod 770 -R .git/index')
# system('chmod 770 -R .git/objects')


# clean the workspace; restart likely not necessary anymore
# rm(list = ls())
gc()
# .rs.restartR()

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


for(fy in 2018:2022){ # TODO: move years to configDefaultRun.toml
	discard_november(con = con_maps
									 , species = species
									 , FY = fy
									 , all_dat = all_dat
									 , save_dir = save_dir
	)
	
	parse_upload_discard(con = con_maps, filepath = save_dir, FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

# fix some file permissions that keep geting effed up
# system('chmod 770 -R .git/index')
# system('chmod 770 -R .git/objects')

  # clean the workspace; restart likely not necessary anymore
  # rm(list = ls())
  gc()
  # .rs.restartR()




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
  	discard_march(con = con_maps
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
  	discard_april(con = con_maps
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
  

## ---- create/rebuild indexes for discard_all_years ---- 
  
MAPS::indexAllTables(con_maps, tables = "CAMS_DISCARD_ALL_YEARS")  
  
## ---- Add comments ----  


 ## ----grant all discard tables from MAPS to CAMS_GARFO, eval = F-------------------------------------------------------------------

  tab_list = ROracle::dbGetQuery(con_maps, "
  SELECT object_name, object_type
      FROM all_objects
      WHERE object_type = 'TABLE'
      and owner = 'MAPS'
  and object_name like 'CAMS_DISCARD%'
  and object_name not like '%DISCARD_MORTALITY%'
  															 ")

    sq = paste0("GRANT SELECT ON ", tab_list$OBJECT_NAME," TO CAMS_GARFO")

    # sq = stringr::str_flatten(sq)

    for(i in 1:nrow(tab_list)){
    	ROracle::dbSendQuery(con_maps, sq[i])
    }


## ----create tables on cams_garfo via upload---------------------------------------------------------------------------------------
 # now make the tables on CAMS_GARFO

con_cams = apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'cams_garfo')

 Sys.setenv(TZ = "America/New_York")
 Sys.setenv(ORA_SDTZ = "America/New_York")


for (FY in 2018:2021){

 parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/CALENDAR/OUTPUT/', FY = FY)

 parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/MAY/OUTPUT/', FY = FY)

 parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/NOVEMBER/OUTPUT/', FY = FY)

 parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/MARCH/OUTPUT/', FY = FY)

 parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/APRIL/OUTPUT/', FY = FY) # be careful of this one.. groundfish should not be uploaded from here!

parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/APRIL/SCALLOP', FY = FY) # Scallop only

 parse_upload_discard(con_cams, filepath = '/maps/devel/output/MODULES/GROUNDFISH/OUTPUT/', FY = FY)	# loading this last #ensures that yellowtail and windowpane are correct
#
}

# Commit DB
ROracle::dbCommit(con_cams)

gc()



#'
## # make a list of tables to  add

## tab_list_cm = ROracle::dbGetQuery(con_cams, "

## SELECT object_name, object_type

##     FROM all_objects

##     WHERE object_type = 'TABLE'

##     and owner = 'MAPS'

## and object_name like 'CAMS_DISCARD%'

## and object_name not like '%DISCARD_MORTALITY%'

##  -- and created >= SYSDATE - 10   --include if we want to only copy over newer tables. should work well for a weekly run or similar..

## 															 "

## )

##

## # remove all the old tables

##  for(i in 1:nrow(tab_list_cm)){

##     	if(ROracle::dbExistsTable(con_cams, tab_list_cm$OBJECT_NAME[i])){

##     		ROracle::dbRemoveTable(con_cams, tab_list_cm$OBJECT_NAME[i])

##     	}

##  }

##

##

## # make a script version of the list of tables to  add

##   make_tab_sq = paste0("CREATE TABLE CAMS_GARFO.", tab_list_cm$OBJECT_NAME," AS SELECT * FROM ", tab_list_cm$OBJECT_NAME)

##

## # make the tables from MAPS

##   for(i in 1:nrow(tab_list_cm)){

##   	if(DBI::dbExistsTable(con_cams, tab_list_cm$OBJECT_NAME[i])) next

##   	print(paste0("MAKING TABLE ",  tab_list_cm$OBJECT_NAME[i], " ON CAMS_GARFO"))

##   	ROracle::dbSendQuery(con_cams, make_tab_sq[i])

##   }

##

#'
## ----make a view for all discards on MAPS-----------------------------------------------------------------------------------------
# get list of discard tables on CAMS_GARFO

tab_list = ROracle::dbGetQuery(con_maps, "
SELECT object_name, object_type
    FROM all_objects
    WHERE object_type = 'TABLE'
    and owner = 'MAPS'
and object_name like 'CAMS_DISCARD%'
and object_name not like '%DISCARD_MORTALITY%'
and object_name not like '%CY%'  -- gets rid of experimental tables
															 ")

st = "CREATE OR REPLACE VIEW CAMS_DISCARD_ALL_YEARS AS "

tab_line = paste0("select * from ", tab_list$OBJECT_NAME," UNION ALL " )  # [22:23]  # groundfish only..

# bidx = grep('*MORTALITY*', tab_line)
#
# tab_line = tab_line[-bidx]

tab_line[length(tab_line)] = gsub(replacement = "", pattern = "UNION ALL", x = tab_line[length(tab_line)])


# create a script to pass to SQL

sq = stringr::str_c(st, stringr::str_flatten(tab_line))

# pass the script to make a view
ROracle::dbSendQuery(con_maps, sq)


# Commit DB
ROracle::dbCommit(con_maps)

# test it!


ROracle::dbGetQuery(con_maps, "
	select round(sum(cams_discard)) as total_discard
	, species_stock
	, COMMON_NAME
	, species_itis
	, FY
	, GF
	from CAMS_DISCARD_ALL_YEARS
	group by species_itis, fy, species_stock, GF, COMMON_NAME
	order by COMMON_NAME
	"
)



#'
## ----make a view for all discards on CAMS_GARFO-----------------------------------------------------------------------------------
# get list of discard tables on CAMS_GARFO

tab_list = ROracle::dbGetQuery(con_cams, "
SELECT object_name, object_type
    FROM all_objects
    WHERE object_type = 'TABLE'
    and owner = 'CAMS_GARFO'
and object_name like 'CAMS_DISCARD%'
and object_name not like '%DISCARD_MORTALITY%'
and object_name not like '%CY%'  -- gets rid of experimental tables
															 ")

st = "CREATE OR REPLACE VIEW CAMS_GARFO.CAMS_DISCARD_ALL_YEARS AS "

tab_line = paste0("select * from CAMS_GARFO.", tab_list$OBJECT_NAME," UNION ALL " )  # [22:23]  # groundfish only..

# bidx = grep('*MORTALITY*', tab_line)
#
# tab_line = tab_line[-bidx]

tab_line[length(tab_line)] = gsub(replacement = "", pattern = "UNION ALL", x = tab_line[length(tab_line)])


# create a script to pass to SQL

sq = stringr::str_c(st, stringr::str_flatten(tab_line))

# pass the script to make a view
ROracle::dbSendQuery(con_cams, sq)


# Grant to CAMS_GARFO @NOVA

# ROracle::dbSendQuery(con_maps, "GRANT SELECT ON CAMS_DISCARD_ALL_YEARS TO CAMS_GARFO")

# Grant to CAMS_GARFO_FOR_NEFSC

ROracle::dbSendQuery(con_cams, "GRANT SELECT ON CAMS_GARFO.CAMS_DISCARD_ALL_YEARS TO CAMS_GARFO_FOR_NEFSC")

# Commit DB
ROracle::dbCommit(con_cams)

# test it!


ROracle::dbGetQuery(con_cams, "
	select round(sum(cams_discard)) as total_discard
	, species_stock
	, COMMON_NAME
	, species_itis
	, FY
	, GF
	from CAMS_GARFO.CAMS_DISCARD_ALL_YEARS
	group by species_itis, fy, species_stock, GF, COMMON_NAME
	order by COMMON_NAME
	"
)




## ----add comments to tables on MAPS and CAMS_GARFO--------------------------------------------------------------------------------
#===============================================
# comments

print(paste("Updating Oracle comments"))

definitions <-
	googlesheets4::read_sheet(
		"https://docs.google.com/spreadsheets/d/1YorwnjozdPwVFJPabC7Ikta6wNzlhzkUtO1TPRbR9-s/edit?usp=sharing"
	)

# save(definitions, file = "data/definitions.rda")
devtools::load_all('~/PROJECTS/MAPS/')

# con_maps <- apsdFuns::roracle_login("apsd_ma", key_service = "maps")

add_comments(con = con_maps, schema = "MAPS", definitions = definitions) # 3-10 minutes

add_comments(con = con_cams, schema = "CAMS_GARFO", definitions = definitions) # 3-10 minutes

# dbDisconnect(con_maps)


#'
## ----remove table logging for performance-----------------------------------------------------------------------------------------

sq_m = "begin
for r in ( select table_name from all_tables where owner='MAPS' and table_name like 'CAMS_DISCARD%' and logging='YES')
loop
execute immediate 'alter table '|| r.table_name ||' NOLOGGING';
end loop;
end;
"

ROracle::dbSendQuery(con_maps, sq_m)


sq_c = "begin
for r in ( select table_name from all_tables where owner='CAMS_GARFO' and table_name like 'CAMS_DISCARD%' and logging='YES')
loop
execute immediate 'alter table CAMS_GARFO.'|| r.table_name ||' NOLOGGING';
end loop;
end;"


ROracle::dbSendQuery(con_cams, sq_c)

# Commit DB
ROracle::dbCommit(con_maps)
ROracle::dbCommit(con_cams)

# Disconnect DB
ROracle::dbDisconnect(con_maps)
ROracle::dbDisconnect(con_cams)


# add group write permissions
# system(paste("chmod g+w -R", file.path(getOption("maps.discardsPath"))))
system(paste("chmod 770 -R", file.path(getOption("maps.discardsPath"))))
