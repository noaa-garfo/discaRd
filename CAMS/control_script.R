

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

for(i in 2017:2022){
	require(glue)
	make_cams_obdbs(con_maps, i, sql_file = "inst/SQL/make_obdbs_table_cams.sql") # convert to within package
}

# CAMS_OBS_CATCH
make_cams_obs_catch(con_maps, sql_file = 'inst/SQL/MERGE_CAMS_CATCH_OBS.sql') # convert to within package


## ----get obs and catch data from oracle, eval = T---------------------------------------------------------------------------------

# get catch and matched obs data together

# long enough - move to function/sql folder
# make year specific?
import_query = "  with obs_cams as (
   select year
	, month
	, date_trip
  , PERMIT
--	, case when month in (5,6,7,8,9,10) then 1
	--       when month in (11,12,1,2,3,4) then 2
	  --     end as halfofyear
  , AREA
	, vtrserno
	, CAMS_SUBTRIP
	, link1 as link1
	, link3
	, link3_obs
	, fishdisp
	, docid
	, CAMSID
	, nespp3
  , itis_tsn as SPECIES_ITIS
  , SECGEAR_MAPPED as GEARCODE
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	, SECTID
  , GF
, case when activity_code_1 like 'NMS-COM%' then 'COMMON_POOL'
       when activity_code_1 like 'NMS-SEC%' then 'SECTOR'
			 else 'non_GF' end as SECTOR_TYPE
, case when PERMIT = '000000' then 'STATE'
       else 'FED' end as FED_OR_STATE
	, tripcategory
	, accessarea
	, activity_code_1
  , EM
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	, NVL(sum(discard),0) as discard
	, NVL(sum(discard_prorate),0) as discard_prorate
	, NVL(round(max(subtrip_kall)),0) as subtrip_kall
	, NVL(round(max(obs_kall)),0) as obs_kall
	from CAMS_OBS_CATCH
	group by year

  , AREA
  , PERMIT
	, vtrserno
	, CAMS_SUBTRIP
	, link1
	, link3
	, link3_obs
	, fishdisp
	, docid
	, nespp3
  , itis_tsn
    , SECGEAR_MAPPED
	, NEGEAR
	, GEARTYPE
	, MESHGROUP
	, SECTID
  , GF
  , case when activity_code_1 like 'NMS-COM%' then 'COMMON_POOL'
       when activity_code_1 like 'NMS-SEC%' then 'SECTOR'
			 else 'non_GF' end
  , case when PERMIT = '000000' then 'STATE'
       else 'FED' end
  , CAMSID
  , month
  , date_trip
	-- , halfofyear
	, tripcategory
	, accessarea
	, activity_code_1
  , EM
  , redfish_exemption
	, closed_area_exemption
	, sne_smallmesh_exemption
	, xlrg_gillnet_exemption
	order by vtrserno asc
    )

  select case when o.MONTH in (1,2,3,4) then o.YEAR-1 else o.YEAR end as GF_YEAR
  , case when o.MONTH in (1,2,3) then o.YEAR-1 else o.YEAR end as SCAL_YEAR
  , o.*
 -- , c.date_trip
  from obs_cams o
 -- left join (
 --     select
 --     distinct(camsid)
 --     , date_trip
 --     from cams_landings
 -- ) c
 -- on o.camsid = c.camsid


"
c_o_dat2 <- ROracle::dbGetQuery(con_maps, import_query)

c_o_dat2 = c_o_dat2 %>%
	mutate(PROGRAM = substr(ACTIVITY_CODE_1, 9, 10)) %>%
  mutate(SCALLOP_AREA = case_when(substr(ACTIVITY_CODE_1,1,3) == 'SES' & PROGRAM == 'OP' ~ 'OPEN'
       , PROGRAM == 'NS' ~ 'NLS'
       , PROGRAM == 'NN' ~ 'NLSN'
       , PROGRAM == 'NH' ~ 'NLSS'  # includes the NLS south Deep
       , PROGRAM == 'NW' ~ 'NLSW'
       , PROGRAM == '1S' ~ 'CAI'
       , PROGRAM == '2S' ~ 'CAII'
       , PROGRAM %in% c('MA', 'ET', 'EF', 'HC', 'DM') ~ 'MAA'
	   )
) %>%
	mutate(SCALLOP_AREA = case_when(substr(ACTIVITY_CODE_1,1,3) == 'SES' ~ dplyr::coalesce(SCALLOP_AREA, 'OPEN'))) %>%
	mutate(DOCID = CAMS_SUBTRIP)

# NOTE: CAMS_SUBTRIP being defined as DOCID so the discaRd functions don't have to change!! DOCID hard coded in the functions..


# 4/13/22
# need to make LINK1 NA when LINK3 is null.. this is due to data mismatches in putting hauls at the subtrip level. If we don't do this step, OBS trips will get values of 0 for any evaluated species. this may or may not be correct.. it's not possible to know without a haul to subtrip match. This is a hotfix that may change in the future

# 8/17/22 this may not be needed anymore..

link3_na = c_o_dat2 %>%
	filter(!is.na(LINK1) & is.na(LINK3))


# make these values 0 or NA or 'none' depending on the default for that field

link3_na = link3_na %>%
	mutate(LINK1 = NA
				 , DISCARD = NA
				 , DISCARD_PRORATE = NA
				 , OBSRFLAG = NA
				 , OBSVTR = NA
				 , OBS_AREA = NA
				 , OBS_GEAR = NA
				 , OBS_HAUL_KALL_TRIP = 0
				 , OBS_HAUL_KEPT = 0
				 , OBS_KALL = 0
				 , OBS_LINK1 = NA
				 , OBSVTR = NA
				 , OBS_MESHGROUP = 'none'
				 , PRORATE = NA)

# this was dropping full trips...
# tidx = c_o_dat2$CAMSID %in% link3_na$CAMSID


# 8/17/22 Changing the method to remove only the records where link1 has no link3.. previously, this removed the entire trip which is probelmatic for multiple subtrip LINK1 trips

tidx = which(!is.na(c_o_dat2$LINK1) & is.na(c_o_dat2$LINK3))

c_o_dat2 = c_o_dat2[-tidx,]

# c_o_dat2 = c_o_dat2[tidx == F,]

c_o_dat2 = c_o_dat2 %>%
	bind_rows(link3_na)

# continue the data import


state_trips = c_o_dat2 %>% filter(FED_OR_STATE == 'STATE')
fed_trips = c_o_dat2 %>% filter(FED_OR_STATE == 'FED')

fed_trips = fed_trips %>%
	mutate(ROWID = 1:nrow(fed_trips)) %>%
	relocate(ROWID)

# filter out link1 that are doubled on VTR

multilink = fed_trips %>%
	filter(!is.na(LINK1)) %>%
	group_by(VTRSERNO) %>%
	dplyr::summarise(nlink1 = n_distinct(LINK1)) %>%
	arrange(desc(nlink1)) %>%
	filter(nlink1>1)

remove_links = fed_trips %>%
	filter(is.na(SPECIES_ITIS) & !is.na(LINK1) & VTRSERNO %in% multilink$VTRSERNO) %>%
	dplyr::select(LINK1) %>%
	distinct()

remove_id = fed_trips %>%
    filter(is.na(SPECIES_ITIS) & !is.na(LINK1) & VTRSERNO %in% multilink$VTRSERNO) %>%
	  distinct(ROWID)

fed_trips =
	fed_trips %>%
	filter(ROWID %!in% remove_id$ROWID)

non_gf_dat = fed_trips %>%
	filter(GF == 0) %>%
	bind_rows(., state_trips) %>%
	mutate(GF = "0")

gf_dat = fed_trips%>%
	filter(GF == 1)

# need this for anything not in the groundfish loop...
all_dat = non_gf_dat %>%
	bind_rows(., gf_dat)

rm(c_o_dat2, fed_trips, state_trips)

gc()


#'
## ----run groundfish species RMD as a script, eval = T-----------------------------------------------------------------------------

# this section may be repeated for other modules with other lists of species

#--------------------------------------------------------------------------#
# get groundfish species list

# TODO: replace fso.v_obSpeciesStockArea with CAMS object
# species <- tbl(con_maps, sql("
# select distinct(b.species_itis)
#     , COMNAME
#     , a.nespp3
# from fso.v_obSpeciesStockArea a
# left join (select *  from CAMS_GEARCODE_STRATA) b on a.nespp3 = b.nespp3
# where stock_id not like 'OTHER'
# and b.species_itis is not null
# ")) %>%
# 	collect()
# 

species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>% 
	filter(RUN_ID == 'GROUNDFISH') %>% 
	collect() %>% 
	group_by(ITIS_TSN) %>% 
	slice(1) %>% 
	ungroup()


# make a script from RMD..
# knitr::purl(here::here('CAMS', 'MODULES', 'GROUNDFISH', 'groundfish_loop_050422.Rmd'), documentation = 2) # convert permanently and skip this step

# run two years worth of GF
for(fy in 2022){ # TODO: move years to configDefaultRun.toml
	# FY <- jj
	# FY_TYPE = 'MAY START' # moved into function
  # source('groundfish_loop.R') # move this to R/ and run as function
	discard_groundfish(con = con_maps
										 , species = species
										 , gf_dat = gf_dat
	                   , non_gf_dat = non_gf_dat
										 , save_dir = '/home/maps/prod/output/discards/groundfish'
										 , FY = fy)
	
  parse_upload_discard(con = con_maps, filepath = file.path(getOption("maps.discardsPath"), "groundfish"), FY = fy)
}

# commit DB

ROracle::dbCommit(con_maps)

#'
## ----run calendar year species RMD as a script, eval = T--------------------------------------------------------------------------

# this section may be repeated for other modules with other lists of species

#--------------------------------------------------------------------------#
# group of species

 itis <-  c(
  '167687',
  '168559',
  '172567',
  '082372',
  '172414',
  '082521',
  '172735',
  '169182',
  '080944',
  '081343',
  '161706',
  '172413',
  '164740',
  '097314',
  '098678',
  '160230')


 itis_num <- as.character(itis)

 species = tbl(con_maps, sql("select *
												from CAMS_DISCARD_MORTALITY_STOCK")) %>%

	collect() %>%

	filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
  slice(1)

 species$ITIS_TSN <- stringr::str_sort(itis)

# make sure the folder is correct
# setwd('~/PROJECTS/discaRd/CAMS/MODULES/CALENDAR/')

# make a script from RMD..
knitr::purl('CAMS/MODULES/CALENDAR/january_loop_062122.Rmd', documentation = 0)

# Define year to run
for(jj in 2022:2022){
	FY <- jj
	FY_TYPE = 'JANUARY START'
  source('january_loop_062122.R')  # this is the script created via purl just above
}

# commit DB

ROracle::dbCommit(con_maps)


# clean the workspace; restart likely not necessary anymore
# rm(list = ls())
gc()
# .rs.restartR()




 ## ----run may year species RMD as a script, eval = F-------------------------------------------------------------------------------

  # setwd("~/PROJECTS/discaRd/CAMS/MODULES/MAY")

  # this section may be repeated for other modules with other lists of species

  #--------------------------------------------------------------------------#
  # group of species
  itis <-  c(
    '164499',
    '160617',
    '564139',
    '160855',
    '564136',
    '564130',
    '564151',
    '564149',
    '564145',
    '164793',
    '164730',
    '164791'
   )

   itis_num <- as.numeric(itis)


   species = tbl(con_maps, sql("select *
  												from CAMS_DISCARD_MORTALITY_STOCK")) %>%

  	collect() %>%

  	filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
    slice(1)

   species$ITIS_TSN <- stringr::str_sort(itis)


  # make a script from RMD..
  knitr::purl('CAMS/MODULES/MAY/may_loop_062122.Rmd', documentation = 0)

  # Define year to run
  for(jj in 2022:2022){
  	FY <- jj
  	FY_TYPE = 'MAY START'
    source('may_loop_062122.R')
  }

  # commit DB

  ROracle::dbCommit(con_maps)

  # clean the workspace; restart likely not necessary anymore
  # rm(list = ls())
  gc()
  # .rs.restartR()




 ## ----run november year species RMD as a script, eval = F--------------------------------------------------------------------------


  # setwd("~/PROJECTS/discaRd/CAMS/MODULES/NOVEMBER/")

  # this section may be repeated for other modules with other lists of species

  #--------------------------------------------------------------------------#
  # group of species
  itis <-  c('168546',
              '168543')

   #itis <- itis
   itis_num <- as.numeric(itis)


   species = tbl(con_maps, sql("select *
  												from CAMS_DISCARD_MORTALITY_STOCK")) %>%

  	collect() %>%

  	filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
    slice(1)

   species$ITIS_TSN <- stringr::str_sort(itis)


  # make a script from RMD..
  knitr::purl('CAMS/MODULES/NOVEMBER/november_loop_062122.Rmd', documentation = 0)

  # Define year to run
  for(jj in 2022:2022){
  	FY <- jj
  	FY_TYPE = 'NOVEMBER START'
    source('november_loop_062122.R')
  }

  # Commit DB
  ROracle::dbDisconnect(con_maps)

  # clean the workspace; restart likely not necessary anymore
  # rm(list = ls())
  gc()
  # .rs.restartR()




 ## ----run march year species RMD as a script, eval = F-----------------------------------------------------------------------------


  # setwd("~/discaRd/CAMS/MODULES/MARCH/")

  # this section may be repeated for other modules with other lists of species

  #--------------------------------------------------------------------------#
  # group of species
  itis <-  c('620992')

   #itis <- itis
   itis_num <- as.numeric(itis)


   species = tbl(con_maps, sql("select *
  												from CAMS_DISCARD_MORTALITY_STOCK")) %>%

  	collect() %>%

  	filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
    slice(1)

   species$ITIS_TSN <- stringr::str_sort(itis)


  # make a script from RMD..
  knitr::purl('CAMS/MODULES/MARCH/march_loop_062122.Rmd', documentation = 0)

  # Define year to run
  for(jj in 2022:2022){
  	FY <- jj
  	FY_TYPE = 'MARCH START'
    source('march_loop_062122.R')
  }

  # Commit DB
  ROracle::dbDisconnect(con_maps)

  # clean the workspace; restart likely not necessary anymore
  # rm(list = ls())
  gc()
  # .rs.restartR()




 ## ----run april year species RMD as a script, eval = F-----------------------------------------------------------------------------


  # setwd("~/discaRd/CAMS/MODULES/APRIL/")

  # this section may be repeated for other modules with other lists of species

  #--------------------------------------------------------------------------#
  # group of species
  itis <-  c('079718')

   #itis <- itis
   itis_num <- as.character(itis)


   species = tbl(con_maps, sql("select *
  												from CAMS_DISCARD_MORTALITY_STOCK")) %>%

  	collect() %>%

  	filter(SPECIES_ITIS %in% itis_num) %>% group_by(SPECIES_ITIS) %>%
    slice(1)

   species$ITIS_TSN <- stringr::str_sort(itis)


  # make a script from RMD..
  knitr::purl('CAMS/MODULES/APRIL/april_loop_062122.Rmd', documentation = 0)

  # Define year to run
  for(jj in 2022:2022){
  	FY <- jj
  	FY_TYPE = 'APRIL START'
    source('april_loop_062122.R')
  }

  # Commit DB
  ROracle::dbDisconnect(con_maps)

  # clean the workspace; restart likely not necessary anymore
  # rm(list = ls())
  gc()
  # .rs.restartR()








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



#'
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
