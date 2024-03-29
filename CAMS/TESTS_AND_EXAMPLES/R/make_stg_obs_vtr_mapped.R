# upload gear groupings to MAPS

library(odbc)
library(readxl)
library(dplyr)

setwd("~/GitHub/discaRd/CAMS")

# connection
dw_maps <- config::get(value = "maps", file = "K:/R_DEV/config.yml")

bcon <- dbConnect(odbc::odbc(), 
                  DSN = dw_maps$dsn, 
                  UID = dw_maps$uid, 
                  PWD = dw_maps$pwd)


# read excel table
tab = readxl::read_excel('NEGEAR_GEARCODE_MAPPING.xlsx', sheet = 'upload table 2')


# drop and write
odbc::dbRemoveTable(conn = bcon, name = 'STG_OBS_VTR_GEARMAP')
odbc::dbWriteTable(conn =  bcon, name = 'STG_OBS_VTR_GEARMAP', value = tab, overwrite = T)

# test it
tbl(bcon, sql('select * from MAPS.STG_OBS_VTR_GEARMAP')) %>% 
  collect() %>% 
filter(NEGEAR == '400')

# this should be a CFG table.. csv put into MAPS/data-raw for auto-building

