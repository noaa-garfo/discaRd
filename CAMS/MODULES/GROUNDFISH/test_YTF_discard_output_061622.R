
dw_apsd <- config::get(value = "maps", file = "~/config.yml")


con_maps <- ROracle::dbConnect(
	drv = ROracle::Oracle(),
	username = dw_apsd$uid,
	password = dw_apsd$pwd,  
	dbname = "NERO.world"
)

t1 = tbl(con_maps, sql("
	select fy
	, year
	, discard_source
	, tripcategory
	, scallop_area
	, max(cams_discard_rate)  cams_discard_rate
	, count(*)
	, sum(obs_kall) obs_kall
	, sum(subtrip_kall) subtrip_kall
	, sum(discard) discard
	, sum(discard)*0.00045359237 as dmt
	from (select * from CAMS_DISCARD_YELLOWTAILFLD_2018
	  union all
	  select * from CAMS_DISCARD_YELLOWTAILFLD_2019
	  	  union all
	  select * from CAMS_DISCARD_YELLOWTAILFLD_2020
	  	  union all
	  select * from CAMS_DISCARD_YELLOWTAILFLD_2021
	)
	where SPECIES_ITIS = 172909
	-- and species_stock = 'GB'
	-- and cams_gear_group = '132'
	and year in (2020)
	group by discard_source, tripcategory, scallop_area, fy, year
	order by year, discard_source, tripcategory
											 ")) %>% 
	collect()

t1 %>% 
	dplyr::summarize(D = sum(DISCARD))
