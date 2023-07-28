
library(ROracle)
library(dplyr, warn.conflicts = FALSE)
# library(dbplyr)
library(ggplot2)
# library(config)
library(stringr)
library(discaRd)
library(fst)
options(scipen = 999)

# local run
# dw_apsd <- config::get(value = "apsd", file = "K:/R_DEV/config.yml")

# if on server..
dw_apsd <- config::get(value = "maps", file = "~/config.yml")

bcon <- ROracle::dbConnect(
	drv = ROracle::Oracle(),
	username = dw_apsd$uid,
	password = dw_apsd$pwd,  
	dbname = "NERO.world"
)

# get list of discard tables on MAPS

tab_list = ROracle::dbGetQuery(bcon, " 
SELECT object_name, object_type
    FROM all_objects
    WHERE object_type = 'TABLE'
    and owner = 'MAPS'
and object_name like 'CAMS_DISCARD_EX%'
															 ")

st = "CREATE OR REPLACE VIEW MAPS.CAMS_DISCARD_ALL_YEARS AS "

tab_line = paste0("select * from MAPS.", tab_list$OBJECT_NAME," UNION ALL " )[22:23]

tab_line[length(tab_line)] = gsub(replacement = "", pattern = "UNION ALL", x = tab_line[length(tab_line)])


# create a script to pass to SQL

sq = stringr::str_c(st, stringr::str_flatten(tab_line))

# pass the script to make a view
ROracle::dbSendQuery(bcon, sq)

# Might be best to repeat this on CAMS_GARFO. using a View means users will need access to all underlying tables
# ROracle::dbSendQuery(bcon, "GRANT SELECT MAPS.CAMS_DISCARD_ALL_YEARS TO CAMS_GARFO")





