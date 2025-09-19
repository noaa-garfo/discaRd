devtools::load_all()
library(ROracle)
library(tidyverse)

options(scipen = 999)

# connection ----


keyring::keyring_unlock(keyring = 'apsd')

## table CAMS_GARFO.CAMS_alloc_gf_mrem not found on DB01P
# need to use MAPS schema on either DB01P or CAMSDB
# CAMS_GARFO on CAMSDB is dead

schema = 'maps'
key_service = 'CAMSDB'
key_name = 'apsd'
database_name = 'CAMSDB'

con_maps <- ROracle::dbConnect(
  drv = ROracle::Oracle(),
  username = paste0(as.character(
    keyring::key_list(key_service, key_name)$username
  ), "[", schema, "]")
  , password = keyring::key_get(
    service = key_service,
    username = as.character(keyring::key_list(key_service, key_name)$username),
    keyring = key_name
  ),
  , dbname = database_name
)


# load data ----

start_year = 2023
end_year = 2025

dat = get_catch_obs(con_maps, start_year, end_year)
gf_dat = dat$gf_dat
non_gf_dat = dat$non_gf_dat
all_dat = dat$all_dat
rm(dat)
gc()


# windowpane example ----
species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>%
  filter(RUN_ID == 'GROUNDFISH') %>%
  collect() %>%
  group_by(ITIS_TSN) %>%
  slice(1) %>%
  ungroup()%>%
  filter(NESPP3 == '125') # WP


# GEAR TABLE
CAMS_GEAR_STRATA = tbl(con_maps, sql('  select * from CFG_GEARCODE_STRATA')) %>%
  collect() %>%
  dplyr::rename(GEARCODE = SECGEAR_MAPPED) %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  dplyr::select(-NESPP3, -ITIS_TSN)

# Stock (Estimation) areas table

STOCK_AREAS = tbl(con_maps, sql('select * from CFG_STATAREA_STOCK')) %>%

  collect() %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  # mutate(AREA_NAME = SPECIES_ESTIMATION_REGION) |>
  group_by(SPECIES_ESTIMATION_REGION, ITIS_TSN) %>%
  distinct(AREA) %>%
  mutate(AREA = as.character(AREA)
         # , SPECIES_STOCK = AREA_NAME
         ) %>%
  ungroup()

# Discard Mortality table

CAMS_DISCARD_MORTALITY_STOCK = tbl(con_maps, sql("select * from CFG_DISCARD_MORTALITY_STOCK"))  %>%

  collect() %>%
  mutate(#SPECIES_STOCK = SPECIES_ESTIMATION_REGION
          GEARCODE = CAMS_GEAR_GROUP
         , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  # select(-SPECIES_ESTIMATION_REGION) %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  dplyr::select(-ITIS_TSN) |>
  dplyr::select(COMMON_NAME, NESPP3, CAMS_GEAR_GROUP, GEARCODE, DISC_MORT_RATIO, SPECIES_ESTIMATION_REGION) |>
  distinct()


OBS_REMOVE = ROracle::dbGetQuery(con_maps, "select * from CFG_OBSERVER_CODES")  %>%
  dplyr::filter(ITIS_TSN == species$ITIS_TSN) %>%
  distinct(OBS_CODES)

FY = 2025

discard_wp = discard_groundfish_diagnostic(con = con_maps
                                           , test_schema = 'MAPS'

                                                      , FY = FY
                                                      , species = species
                                                      , gf_dat = gf_dat
                                                      , non_gf_dat = non_gf_dat
                                                      , return_table = T
                                                      , return_summary = T
                                                      , CAMS_GEAR_STRATA = CAMS_GEAR_STRATA
                                                      , STOCK_AREAS = STOCK_AREAS
                                                      , CAMS_DISCARD_MORTALITY_STOCK = CAMS_DISCARD_MORTALITY_STOCK
                                                      , OBS_REMOVE = OBS_REMOVE
)

discard_wp$trips_discard = discard_wp$trips_discard |>
  parse_discard_diag()

# unique trips in the set

discard_wp$trips_discard |>
  dplyr::summarise(ntrips = n_distinct(CAMSID)
                   , KALL = sum(SUBTRIP_KALL)/2204.62262
                   , discard = sum(CAMS_DISCARD, na.rm = T)/2204.62262)

# yellowtail example ----

species <- tbl(con_maps, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>%
  filter(RUN_ID == 'GROUNDFISH') %>%
  collect() %>%
  group_by(ITIS_TSN) %>%
  slice(1) %>%
  ungroup()%>%
  filter(NESPP3 == '123') # YT


# GEAR TABLE
CAMS_GEAR_STRATA = tbl(con_maps, sql('  select * from CFG_GEARCODE_STRATA')) %>%
  collect() %>%
  dplyr::rename(GEARCODE = SECGEAR_MAPPED) %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  dplyr::select(-NESPP3, -ITIS_TSN)

# Stock (Estimation) areas table
STOCK_AREAS = tbl(con_maps, sql('select * from CFG_STATAREA_STOCK')) %>%
  collect() %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  # mutate(AREA_NAME = SPECIES_ESTIMATION_REGION) |>
  group_by(SPECIES_ESTIMATION_REGION, ITIS_TSN) %>%
  distinct(AREA) %>%
  mutate(AREA = as.character(AREA)
         # , SPECIES_STOCK = AREA_NAME
  ) %>%
  ungroup()

# Discard Mortality table

CAMS_DISCARD_MORTALITY_STOCK = tbl(con_maps, sql("select * from CFG_DISCARD_MORTALITY_STOCK"))  %>%

  collect() %>%
  mutate(#SPECIES_STOCK = SPECIES_ESTIMATION_REGION
    GEARCODE = CAMS_GEAR_GROUP
    , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  # select(-SPECIES_ESTIMATION_REGION) %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  dplyr::select(-ITIS_TSN) |>
  dplyr::select(COMMON_NAME, NESPP3, CAMS_GEAR_GROUP, GEARCODE, DISC_MORT_RATIO, SPECIES_ESTIMATION_REGION) |>
  distinct()


OBS_REMOVE = ROracle::dbGetQuery(con_maps, "select * from CFG_OBSERVER_CODES")  %>%
  dplyr::filter(ITIS_TSN == species$ITIS_TSN) %>%
  distinct(OBS_CODES)

FY = 2025

discard_yt = discard_groundfish_diagnostic(con = con_maps
                                           , test_schema = 'MAPS'
                                           , FY = FY
                                           , species = species
                                           , gf_dat = gf_dat
                                           , non_gf_dat = non_gf_dat
                                           , return_table = T
                                           , return_summary = T
                                           , CAMS_GEAR_STRATA = CAMS_GEAR_STRATA
                                           , STOCK_AREAS = STOCK_AREAS
                                           , CAMS_DISCARD_MORTALITY_STOCK = CAMS_DISCARD_MORTALITY_STOCK
                                           , OBS_REMOVE = OBS_REMOVE
)

discard_yt$trips_discard = discard_yt$trips_discard |>
  parse_discard_diag()

# unique trips in the set

discard_yt$trips_discard |>
  dplyr::summarise(ntrips = n_distinct(CAMSID)
                   , KALL = sum(SUBTRIP_KALL)/2204.62262
                   , discard = sum(CAMS_DISCARD, na.rm = T)/2204.62262)

# cod example ----
species <- tbl(con, sql("
  select *
  from CFG_DISCARD_RUNID
  ")) %>%
  filter(RUN_ID == 'GROUNDFISH') %>%
  collect() %>%
  group_by(ITIS_TSN) %>%
  slice(1) %>%
  ungroup()%>%
  filter(NESPP3 == '081') # YT


# GEAR TABLE
CAMS_GEAR_STRATA = tbl(con, sql('  select * from CFG_GEARCODE_STRATA')) %>%
  collect() %>%
  dplyr::rename(GEARCODE = SECGEAR_MAPPED) %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  dplyr::select(-NESPP3, -ITIS_TSN)

# Stock (Estimation) areas table

STOCK_AREAS = tbl(con_maps, sql('select * from CFG_STATAREA_STOCK')) %>%
  collect() %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  # mutate(AREA_NAME = SPECIES_ESTIMATION_REGION) |>
  group_by(SPECIES_ESTIMATION_REGION, ITIS_TSN) %>%
  distinct(AREA) %>%
  mutate(AREA = as.character(AREA)
         # , SPECIES_STOCK = AREA_NAME
  ) %>%
  ungroup()

# Discard Mortality table
CAMS_DISCARD_MORTALITY_STOCK = tbl(con_maps, sql("select * from CFG_DISCARD_MORTALITY_STOCK"))  %>%
  collect() %>%
  mutate(#SPECIES_STOCK = SPECIES_ESTIMATION_REGION
    GEARCODE = CAMS_GEAR_GROUP
    , CAMS_GEAR_GROUP = as.character(CAMS_GEAR_GROUP)) %>%
  # select(-SPECIES_ESTIMATION_REGION) %>%
  filter(ITIS_TSN == species$ITIS_TSN) %>%
  dplyr::select(-ITIS_TSN) |>
  dplyr::select(COMMON_NAME, NESPP3, CAMS_GEAR_GROUP, GEARCODE, DISC_MORT_RATIO, SPECIES_ESTIMATION_REGION) |>
  distinct()


OBS_REMOVE = ROracle::dbGetQuery(con_maps, "select * from CFG_OBSERVER_CODES")  %>%
  dplyr::filter(ITIS_TSN == species$ITIS_TSN) %>%
  distinct(OBS_CODES)

FY = 2025

# run groundfish diagnostic for cod with standard info

discard_cod = discard_groundfish_diagnostic(con = con
                                           , FY = FY
                                           , species = species
                                           , gf_dat = gf_dat
                                           , non_gf_dat = non_gf_dat
                                           , return_table = T
                                           , return_summary = T
                                           , CAMS_GEAR_STRATA = CAMS_GEAR_STRATA
                                           , STOCK_AREAS = STOCK_AREAS
                                           , CAMS_DISCARD_MORTALITY_STOCK = CAMS_DISCARD_MORTALITY_STOCK
                                           , OBS_REMOVE = OBS_REMOVE
)

discardcod$trips_discard = discardcod$trips_discard |>
  parse_discard_diag()

# unique trips in the set

discard_cod$trips_discard = discard_cod$trips_discard |>
  parse_discard_diag()

# unique trips in the set ----

discard_cod$trips_discard |>
  dplyr::summarise(ntrips = n_distinct(CAMSID)
                   , KALL = sum(SUBTRIP_KALL)/2204.62262
                   , discard = sum(CAMS_DISCARD, na.rm = T)/2204.62262)



# summarise all three ----
discard_cod$trips_discard |>
  rbind(discard_wp$trips_discard) |>
  rbind(discard_yt$trips_discard) |>
  group_by(COMMON_NAME) |>
  dplyr::summarise(ntrips = n_distinct(CAMSID)
                   , KALL = sum(SUBTRIP_KALL)/2204.62262
                   , discard = sum(CAMS_DISCARD, na.rm = T)/2204.62262)

