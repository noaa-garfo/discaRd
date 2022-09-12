/*

Create table of discarded species for a calendar year 
this follows the steps used in Mid-Atlantic discard estaimtion for year end reports

The eventual goal is to replace the CASE code for gear, mesh and area with tale based joins. 

Created by: Ben Galuardi, modified from Jay Hermsen's code

12-23-20

modified 
3-18-21
12-2-21 changed meshgroup defnitions to match CAMS definitons. changed name of final output table
12-21-21 change output names to MAPS.CAMS_OBDBS_YYYY
01-04-22 update mesh categories (meshgroup): 0-3.99 = sm, >=4 = L, FOR GILLNETS, >=8 = XL
02-03-22 update filter for tripext to include Limited sampling trips (see obdbs.tripext@nova)
04-12-22 changed the date filter in table 3 to match only on year rather than dateland.. this was dropping trips for timestamp reasons

The year variable can be defined, and then the entire script run (F5 in sqldev)

This version ues left joins in the first set of tables which preserves more information than previous versions which used hard matches

we also keep all hauls, not just observed hauls, so prorating can be done

RUN FROM MAPS SCHEMA

*/

DEF year = &1;
/

DROP TABLE obdbs_cams_&year;
/

DROP TABLE bg_obtables_join_1_&year;
/

CREATE TABLE bg_obtables_join_1_&year AS

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
where a.YEAR = &year
AND b.YEAR = &year
AND s.fishdisp <> '039'
--AND b.OBSRFLAG <> '1' -- this contorls observed vs unobserved hauls
AND s.program <> '127'
AND a.tripext IN ('C', 'X');
/

