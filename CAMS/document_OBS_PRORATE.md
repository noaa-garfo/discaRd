CAMS: Prorated Observer Table
================
Ben Galuardi

## Summary

## Description

  - **OUTPUT TABLE:** APSD.OBS\_CAMS\_PRORATE
  - **YEARS:** 2017-2020
  - **RESOLUTION:** LINK3\~LINK1
  - **DEVELOPMENT LANGUAGE:** SQL
  - **CODE:**
    <https://github.com/NOAA-Fisheries-Greater-Atlantic-Region/discaRd/tree/model_estimator/CAMS>

## Data Sources

  - OBDBS (NEFOP, NEFSC)

![Figure 1. APSD.OBS\_CAMS\_PRORATE table
lineage](document_OBS_PRORATE_files/figure-gfm/table_flow0-1.png) \#\#
Approach

Following the standard approach taken for groundfish quota monitoring,
observed discards on unobserved hauls are prorated within a subtrip.
This is done by applying a ratio of kept all on the entire trip to kept
all on the unobserved hauls only:

\[d_{total} = d_{observedhauls}*(1+KALL_{unobserved hauls}/KALL_{subtrip})\]

This approach is used for all observed subtrips in CAMS.

## Data Dictionary

    ## Warning: package 'knitr' was built under R version 4.0.5

| Name                    | Description                                  | Data Type    |
| :---------------------- | :------------------------------------------- | :----------- |
| LINK3                   | Observer recorded haul                       | VARCHAR2(19) |
| LINK1                   | Observer LINK1 if trip was obsevered         | VARCHAR2(15) |
| VTRSERNO                | Observer recorded VTR serial number          | VARCHAR2(15) |
| YEAR                    | Calendar Year                                | NUMBER       |
| MONTH                   | Month                                        | VARCHAR2(2)  |
| OBSRFLAG                | Was the trip observed (0,1)                  | VARCHAR2(1)  |
| OBS\_AREA               | Statistical Area                             | VARCHAR2(3)  |
| OBS\_GEAR               | Observer recorded gear (NEGEAR)              | VARCHAR2(3)  |
| GEARTYPE                | Gear description                             | VARCHAR2(34) |
| OBS\_MESH               | Observer recorded meshsize                   | NUMBER       |
| MESHGROUP               | Observer recorded mesh category              | VARCHAR2(3)  |
| NESPP3                  | 3 digit species code                         | VARCHAR2(3)  |
| DISCARD                 | Observer recorded discard                    | NUMBER       |
| OBS\_HAUL\_KEPT         | Observer recorded total pounds kept per haul | NUMBER       |
| OBS\_HAUL\_KALL\_TRIP   | Observer recorded total pounds kept per trip | NUMBER       |
| OBS\_NOHAUL\_KALL\_TRIP | Observer prorated amount on unobserved hauls | NUMBER       |
| PRORATE                 | ratio of KALL/obs\_hauls                     | NUMBER       |
| HALFOFYEAR              | 1 (Jan - June) or 2 (July-Dec)               | NUMBER       |
| REGION                  | N (AREA \< 600) or S (AREA \>= 600)          | CHAR(1)      |
| DISCARD\_PRORATE        | Prorated observer recorded discard           | NUMBER       |
