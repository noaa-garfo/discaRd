CAMS: Observer Mockup Tables
================
Ben Galuardi

## Summary

## Description

  - **OUTPUT TABLE:** APSD.BG\_OBDBS\_CAMS\_MOCK(YYYY)
  - **YEARS:** 2017-2020
  - **RESOLUTION:** LINK3\~LINK1
  - **DEVELOPMENT LANGUAGE:** SQL
  - **CODE:**
    <https://github.com/NOAA-Fisheries-Greater-Atlantic-Region/discaRd/tree/model_estimator/CAMS>

## Data Sources

  - OBDBS (NEFOP, @NOVA, NEFSC)

![Figure 1. APSD.BG\_OBDBS\_CAMS\_MOCK(YYYY) table
lineage](document_OBS_CAMS_files/figure-gfm/table_flow0-1.png) \#\#
Approach

These tables are built by calendar year and encompass all information
from NEFOP and ASM, for all observed trips. Tables from the <OBDSB@NOVA>
schema in Oracle are used to build a flat file of all observations at
the LINK3 (haul) level for all discarded species. The general
methodology has been used for the past 5 years at GARFO for annual ACL
monitoring in many managed fisheries (e.g. Squid/Mack/Butterfish,
dogfish, monkfish, black sea bass, etc.). Since CAMS discard methodology
relies on commerical trip metrics for stratification, many variables in
these tables are not used directly as in the past. They are used,
however, to match the observed records to the corresponding commercial
trip.

Refer to [OBDBS](http://nova.nefsc.noaa.gov/datadict/) documentation for
details on individual input tables.

## Data Dictionary

    ## Warning: package 'knitr' was built under R version 4.0.5

| Name         | Description                             | Data Type    |
| :----------- | :-------------------------------------- | :----------- |
| AREA         | see OBDBS                               | VARCHAR2(3)  |
| CATDISP      | see OBDBS                               | VARCHAR2(1)  |
| FLEET\_TYPE  | see OBDBS                               | VARCHAR2(3)  |
| DATELAND     | see OBDBS                               | DATE         |
| DATESAIL     | see OBDBS                               | DATE         |
| DEALNUM      | see OBDBS                               | VARCHAR2(25) |
| DRFLAG       | see OBDBS                               | VARCHAR2(1)  |
| ESTMETH      | see OBDBS                               | VARCHAR2(2)  |
| FISHDISP     | see OBDBS                               | VARCHAR2(3)  |
| FISHDISPDESC | see OBDBS                               | VARCHAR2(80) |
| GEARCAT      | see OBDBS                               | VARCHAR2(2)  |
| HAILWT       | see OBDBS                               | NUMBER(7,1)  |
| HULLNUM1     | see OBDBS                               | VARCHAR2(10) |
| LATHBEG      | see OBDBS                               | VARCHAR2(6)  |
| LATHEND      | see OBDBS                               | VARCHAR2(6)  |
| LATSBEG      | see OBDBS                               | VARCHAR2(6)  |
| LATSEND      | see OBDBS                               | VARCHAR2(6)  |
| LINK1        | see OBDBS                               | VARCHAR2(15) |
| LINK3        | see OBDBS                               | VARCHAR2(19) |
| LIVEWT       | see OBDBS                               | NUMBER       |
| MONTH        | see OBDBS                               | VARCHAR2(2)  |
| NEGEAR       | see OBDBS                               | VARCHAR2(3)  |
| NEMAREA      | see OBDBS                               | VARCHAR2(3)  |
| NESPP4       | see OBDBS                               | VARCHAR2(4)  |
| OBSRFLAG     | see OBDBS                               | VARCHAR2(1)  |
| ONEFFORT     | see OBDBS                               | VARCHAR2(1)  |
| PERMIT1      | see OBDBS                               | NUMBER       |
| PORT         | see OBDBS                               | VARCHAR2(6)  |
| PROGRAM      | see OBDBS                               | VARCHAR2(3)  |
| QDSQ         | see OBDBS                               | VARCHAR2(5)  |
| QTR          | see OBDBS                               | NUMBER       |
| STATE        | see OBDBS                               | VARCHAR2(2)  |
| TENMSQ       | see OBDBS                               | VARCHAR2(2)  |
| TRIPEXT      | see OBDBS                               | VARCHAR2(1)  |
| TRIPID       | see OBDBS                               | VARCHAR2(6)  |
| VMSCODE      | see OBDBS                               | VARCHAR2(2)  |
| VTRSERNO     | see OBDBS                               | VARCHAR2(15) |
| WGTTYPE      | see OBDBS                               | VARCHAR2(1)  |
| YEAR         | see OBDBS                               | VARCHAR2(4)  |
| YEARLAND     | see OBDBS                               | VARCHAR2(4)  |
| KEPTALL      | see OBDBS                               | NUMBER       |
| CODLINERUSD  | see OBDBS                               | VARCHAR2(1)  |
| CODMSIZE     | see OBDBS                               | NUMBER(3)    |
| LINERMSIZE   | see OBDBS                               | NUMBER       |
| MSWGTAVG     | see OBDBS                               | NUMBER(4,2)  |
| HALFOFYEAR   | 1 (Jan - June) or 2 (July-Dec)          | NUMBER       |
| CALENDARQTR  | see OBDBS                               | NUMBER       |
| MESHSIZE     | Observer recorded meshsize              | NUMBER       |
| REGION       | N (AREA \< 600) or S (AREA \>= 600)     | VARCHAR2(5)  |
| STOCKAREA    | N (AREA \< 600) or S (AREA \>= 600)     | VARCHAR2(7)  |
| GEARTYPE     | Gear description                        | VARCHAR2(34) |
| ACCESSAREA   | Scallop Access Area                     | VARCHAR2(4)  |
| TRIPCATEGORY | Scallop fleet designtion (LA, GEN, ALL) | VARCHAR2(7)  |
| MESHGROUP    | Observer recorded mesh category         | VARCHAR2(3)  |
