
getSQL <- function(filepath){
	con = file(filepath, "r")
	sql.string <- ""
	
	while (TRUE){
		line <- readLines(con, n = 1)
		
		if ( length(line) == 0 ){
			break
		}
		
		line <- gsub("\\t", " ", line)
		
		if(grepl("--",line) == TRUE){
			line <- paste(sub("--","/*",line),"*/")
		}
		
		sql.string <- paste(sql.string, line)
	}
	
	close(con)
	return(sql.string)
}

obdbs_build_year = 2021

obdbs_sq = getSQL('../../SQL/make_obdbs_table_cams_v2.sql') %>% 
	gsub(x = ., pattern = 'DEF year = 2021', replacement = paste0('DEF year = ', obdbs_build_year)) %>% 
	gsub(x = ., pattern = '&year', replacement = obdbs_build_year)


obdbs_sq = readr::read_lines('../../SQL/make_obdbs_table_cams_v2.sql')[1:155] %>% 
	glue::glue_collapse(sep = '\n') %>%
  gsub(x = ., pattern = 'DEF year = 2021', replacement = paste0('DEF year = ', obdbs_build_year)) %>% 
	gsub(x = ., pattern = '&year', replacement = obdbs_build_year) %>%
	# gsub(x = ., pattern = '/', replacement = ';') %>% 
	glue::glue_sql(.con = bcon)

cams_obs_catch_sq = readr::read_lines('../../SQL/MERGE_CAMS_CATCH_OBS.sql') %>% glue::glue_collapse(sep = '\n')


# build obdbs years

ROracle::dbSendQuery(bcon, obdbs_sq)


year = 2021

sq = "
DROP TABLE bg_obtables_join_1_?year
/

CREATE TABLE bg_obtables_join_1_?year AS

SELECT a.FLEET_TYPE, 
a.DATELAND, 
a.DATESAIL, 
a.DEALNUM, 
a.GEARCAT, 
a.HULLNUM1, 
a.LINK1, 
a.MONTH, 
a.PERMIT1, 
a.PORT, 
a.STATE, 
a.VMSCODE, 
a.VTRSERNO, 
a.YEAR, 
a.YEARLAND, 
a.TRIPEXT,
b.LINK3, 
b.NEGEAR, 
b.NEMAREA, 
b.AREA, 
b.OBSRFLAG, 
b.ONEFFORT, 
b.QDSQ, 
b.QTR, 
b.TENMSQ, 
b.TRIPID,
b.LATHBEG,
b.LATSBEG,
b.LATHEND,
b.LATSEND, 
e.FISHDISPDESC, 
s.catdisp, 
s.drflag, 
s.estmeth, 
s.fishdisp, 
s.hailwt, 
s.nespp4,  
s.program, 
s.wgttype
FROM obdbs.obtrp@nova a
left join (select * from obdbs.obhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.obspp@nova) s
on b.LINK3 = s.LINK3
left join (select * from obdbs.obfishdisp@nova) e
on s.FISHDISP = e.FISHDISP
where a.YEAR = ?year
AND b.YEAR = ?year
AND s.fishdisp <> '039'
--AND b.OBSRFLAG <> '1' -- this contorls observed vs unobserved hauls
AND s.program <> '127'
AND a.tripext IN ('C', 'X')

;
---Pull data from the ASM tables in the OBDBS tables on NOVA  

;

DROP TABLE bg_asmtables_join_1_?year 

;

CREATE TABLE bg_asmtables_join_1_?year AS
SELECT a.FLEET_TYPE, 
a.DATELAND, 
a.DATESAIL, 
a.DEALNUM, 
a.GEARCAT, 
a.HULLNUM1, 
a.LINK1, 
a.MONTH, 
a.PERMIT1, 
a.PORT, 
a.STATE, 
a.VMSCODE, 
a.VTRSERNO, 
a.YEAR, 
a.YEARLAND, 
a.TRIPEXT,
b.LINK3, 
b.NEGEAR, 
b.NEMAREA, 
b.AREA, 
b.OBSRFLAG, 
b.ONEFFORT, 
b.QDSQ, 
b.QTR, 
b.TENMSQ, 
b.TRIPID,
b.LATHBEG,
b.LATSBEG,
b.LATHEND,
b.LATSEND, 
e.FISHDISPDESC, 
s.catdisp, 
s.drflag, 
s.estmeth, 
s.fishdisp, 
s.hailwt, 
s.nespp4,  
s.program, 
s.wgttype

FROM obdbs.asmtrp@nova a
left join (select * from obdbs.asmhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.asmspp@nova) s
on b.LINK3 = s.LINK3
left join (select * from obdbs.obfishdisp@nova) e
on s.FISHDISP = e.FISHDISP
where a.YEAR = ?year
AND b.YEAR = ?year
AND s.fishdisp <> '039'
--AND b.OBSRFLAG <> '1' -- this contorls observed vs unobserved hauls
AND s.program <> '127'
AND a.tripext IN ('C', 'X')
;
"

sq = DBI::sqlInterpolate(bcon, sql = sq, year = 2021)

dbSendQuery(bcon, sq)

## try sqlplus in bash shell

setwd('/home/bgaluardi/PROJECTS/discaRd/CAMS/SQL')

com = paste0('sqlplus -S ', dw_apsd$uid, '/', dw_apsd$pwd, '@NERO.WORLD @', '"make_obdbs_table_cams_v2.sql"')

system(com)
