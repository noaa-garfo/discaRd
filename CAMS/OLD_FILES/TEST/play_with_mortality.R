# import mortality info from Dan's spreadsheet..

library(readxl)
library(dplyr)

cgtab = read_xlsx('/home/bgaluardi/CAMS/center_gear_info_DL.xlsx')

cgtab %>% 
  filter(`Discard Mortality Ratio` != 1) %>% 
  dplyr::group_by(`Discard Mortality Ratio`, SPECIES_ITIS, `AREA_FISHED_for_discards`, GEAR_GROUP, MESHSIZE_ABBREV) %>% 
  distinct(`common name`)


# join catch data to stat/stock area to add area fished and stock definiton..

# get species names
species = tbl(bcon, sql('select * from apsd.NESPP3_FMP')) %>% 
  collect() %>% 
  mutate(NESPP3 = stringr::str_pad(NESPP3, width = 3, side = 'left', pad = 0))

# get speciesITIS

sp_itis = tbl(bcon, sql('select * from fso.t_observer_species_itis')) %>% 
  collect() %>% 
  mutate(NESPP3 = stringr::str_pad(NESPP3, width = 3, side = 'left', pad = 0))

# set NESPP3

stat_area_sp = stat_area_sp %>% 
  collect() %>% 
  mutate(NESPP3 = str_pad(NESPP3, width = 3, pad = 0, side = 'left')) %>% 
  left_join(sp_itis, by = 'NESPP3')

# join
gf_ex$res %>% 
  mutate(NESPP3 = gf_ex$species) %>% 
  mutate(STAT_AREA = as.numeric(CAREA)) %>% 
  left_join(., stat_area_sp, by = c('NESPP3', 'STAT_AREA')) %>% 
  distinct(NEGEAR)

# add gear group to catch records...

# determine unique combination of maortalities within the sotck in question.. 
# for GOM Cod, there are 4 gear groups but no distinction of mesh differences within the gear groups. 
  


