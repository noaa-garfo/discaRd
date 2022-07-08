
with OP as ( 
   SELECT 
    t.link1
    , h.link3
    , G.OBGEARCAT as GEARCAT
    , t.tripext
    , t.program
    , t.year
    , t.permit1
    , t.hullnum1
    , t.fleet_type
    , t.datesail
    , t.dateland
    , h.obsrflag
    , h.area
    , SUBSTR(s.nespp4,1,3) nespp3
    , s.nespp4
    , h.negear
    , s.fishdisp
    , h.CATEXIST as catdisp
    , s.round as drflag
    , s.hailwt
    , 'OBPRELIM' as source

    from
    obprelim.optrp@NOVA t 
    LEFT OUTER JOIN
    obprelim.ophau@NOVA h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obprelim.opcatch@NOVA s ON h.link3 = s.link3
    LEFT OUTER JOIN
    obdbs.obgear@NOVA g ON g.negear = h.negear
    
    WHERE
    t.year in (2022)
    and h.year in (2022)


)

, OB as ( 
   SELECT
    t.link1
    , h.link3
    , t.GEARCAT
    , t.tripext
    , t.program
    , t.year
    , t.permit1
    , t.hullnum1
    , t.fleet_type
    , t.datesail
    , t.dateland
    , s.obsrflag
    , s.area
    , SUBSTR(s.nespp4,1,3) nespp3
    , s.nespp4
    , s.negear
    , s.fishdisp
    , s.catdisp
    , s.drflag
    , s.hailwt
    , 'OBDBS' as source
    
    from
    obdbs.obtrp@nova t 
    LEFT OUTER JOIN
    obdbs.obhau@nova h ON t.link1 = h.link1
    LEFT OUTER JOIN
    obdbs.obspp@nova s ON h.link3 = s.link3

   
    WHERE
    t.year in (2022)
    and h.year in (2022)

)
, ASM as (
SELECT 
--a.DEALNUM, 
a.LINK1,
b.link3,
a.GEARCAT, 
a.TRIPEXT,
a.PROGRAM, 
a.YEAR, 
a.PERMIT1, 
a.HULLNUM1, 
a.FLEET_TYPE, 
a.DATESAIL, 
a.DATELAND,
b.OBSRFLAG, 
b.AREA, 
SUBSTR(s.nespp4,1,3) nespp3
, s.nespp4
, b.negear
, s.fishdisp
, s.catdisp
, s.drflag
, s.hailwt
, 'ASM' as source

FROM obdbs.asmtrp@nova a
left join (select * from obdbs.asmhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.asmspp@nova) s
on b.LINK3 = s.LINK3
left join (select * from obdbs.obfishdisp@nova) e
on s.FISHDISP = e.FISHDISP
where a.year in (2022)
and b.year in (2022)
)
, mesh1 as (
SELECT DISTINCT(a.LINK1), 
a.LINK3, 
a.LINK4, 
a.CODLINERUSD, 
a.CODMSIZE, 
a.LINERMSIZE, 
a.MONTH, 
a.NEGEAR, 
a.PROGRAM, 
a.TRIPID, 
a.YEAR 
FROM obdbs.obotgh@nova a
WHERE a.YEAR = 2022
UNION ALL
SELECT DISTINCT(a.LINK1), 
a.LINK3, 
a.LINK4, 
a.CODLINERUSD, 
a.CODMSIZE, 
a.LINERMSIZE, 
a.MONTH, 
a.NEGEAR, 
a.PROGRAM, 
a.TRIPID, 
a.YEAR 
FROM obdbs.asmotgh@nova a
WHERE a.YEAR = 2022
)
,mesh2 as (

SELECT DISTINCT(a.HAULNUM), 
a.LINK1, 
a.LINK3, 
a.LINK4, 
a.MSMAX, 
a.MSMIN, 
a.MSWGTAVG, 
a.NEGEAR, 
a.TRIPID, 
a.YEAR
FROM obdbs.obgggh@nova a
WHERE a.YEAR = 2022
UNION ALL
SELECT DISTINCT(a.HAULNUM), 
a.LINK1, 
a.LINK3, 
a.LINK4, 
a.MSMAX, 
a.MSMIN, 
a.MSWGTAVG, 
a.NEGEAR, 
a.TRIPID, 
a.YEAR
FROM obdbs.asmgggh@nova a
WHERE a.YEAR = 2022

)

select s.*
, s.hailwt*c.cf_rptqty_lndlb*c.cf_lndlb_livlb livewt
, sum(s.hailwt*c.cf_rptqty_lndlb*c.cf_lndlb_livlb) OVER(PARTITION BY LINK1) as keptall
from (
select *
 from ob
 
 union all 
 
 select *
 from op
 
  union all 
 
 select *
 from asm
 ) s
LEFT OUTER JOIN obdbs.obspecconv@nova c
ON (s.nespp4 = c.nespp4_obs AND s.catdisp = c.catdisp_code AND s.drflag = c.drflag_code)

WHERE s.fishdisp <> '039'
AND s.program <> '127'
AND s.tripext IN ('C', 'X')
AND s.FISHDISP <> '090'


-- liner 
b.CODLINERUSD, 
b.CODMSIZE, 
b.LINERMSIZE
FROM bg_obdbs_tables_3_&year a LEFT OUTER JOIN bg_obdbs_meshsize1_&year b
ON a.link3 = b.link3 