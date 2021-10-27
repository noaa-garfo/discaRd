CAMS: Observer & Catch Table
================
Ben Galuardi

## Summary

## Description

  - **OUTPUT TABLE:** APSD.BG\_CAMS\_OBS\_CATCH
  - **YEARS:** 2018-2020
  - **RESOLUTION:** VTRSERNO (subtrip)\~LINK1
  - **DEVELOPMENT LANGUAGE:** SQL
  - **CODE:**
    <https://github.com/NOAA-Fisheries-Greater-Atlantic-Region/discaRd/tree/model_estimator/CAMS>

## Data Sources

  - CAMS Apportionment and Trip attributes (GARFO)
  - CAMS prorated observer data
      - NEFOP (NEFSC)
      - ASM (NEFSC)

![Figure 1. APSD.BG\_CAMS\_OBS\_CATCH table
lineage](document_CAMS_OBS_CATCH_files/figure-gfm/table_flow0-1.png)
\#\# Approach

The use of a combined catch and observation table allows for a single
source table to be used in discard estimation. Previous methods took a
two table approach, where catch information and observer records were
stratified independently, and then matched to calculate discard (e.g.,
\(D = K*d/k\)). This approach had the possibility of mismatches between
observed strata and trip strata. In reality, this cannot occur. We
therefore do trip by trip matching, using `gear`, `mesh`, `statistical
area`, and `LINK1`, to match observer recorded species discards with
commercial trip activity.

The primary driver for this approach was to use the trip recorded
metrics as the stratification source. This reduces the possibility of
mismatches and removes much of the hard-coding that has been used to
date. Upfront matching also allows observed discards to easily be used
as the official discard for a particular trip. Furthermore, we recognize
that data errors either from the catch, or observer data, will result in
a non-match. This likely reduces the total pool of observed trips that
are being used, but we feel the benefits of using outweigh a reduced
sample size. Quality control of these data are outside the purview of
the CAMS project. Last, we only use observed trips (`LINK1`) where valid
`LINK3` (hauls) occurred to alleviate issues of multiple `LINK1` records
for a single subtrip.

IMPORTANT\!: The table itself is a hybrid. For trips that were not
observed, there will be a single row with all trip metrics and a total
`KALL` per subtrip. When a trip was observed, there are multiple rows
where the trip metric information is repeated, and each row shows
species, discarded amount, and other observer recorded information for
each row. Total `KALL` CANNOT be calculated without filtering rows by
`LINK1` to indicate an observed trip or not. These steps are outlined in
subsequent R modules used to run disacRd.

## Data Dictionary

    ## Warning: package 'knitr' was built under R version 4.0.5

| Name                      | Description                                  | Data Type    |
| :------------------------ | :------------------------------------------- | :----------- |
| PERMIT                    | 6 digit permit number                        | VARCHAR2(6)  |
| DMIS\_TRIP\_ID            | CAMS unique trip identifier                  | VARCHAR2(60) |
| YEAR                      | Calendar Year                                | NUMBER       |
| MONTH                     | Month                                        | NUMBER       |
| REGION                    | N (AREA \< 600) or S (AREA \>= 600)          | CHAR(1)      |
| HALFOFYEAR                | 1 (Jan - June) or 2 (July-Dec)               | NUMBER       |
| DOCID                     | VTR Document ID                              | VARCHAR2(40) |
| VTRSERNO                  | VTR serial number; identifies subtrip        | VARCHAR2(13) |
| GEARCODE                  | three letter VTR gear code                   | VARCHAR2(3)  |
| GEARTYPE                  | Gear description                             | VARCHAR2(34) |
| NEGEAR                    | two digit gearcode; used by NEFOP            | VARCHAR2(3)  |
| MESH                      | VTR mesh size in inches                      | NUMBER(6,1)  |
| MESHGROUP                 | Categoried mesh: sm, lg, xlg, na             | VARCHAR2(3)  |
| AREA                      | statistical area from VTR                    | VARCHAR2(3)  |
| CAREA                     | Calculated Statisticl area from VTR position | VARCHAR2(3)  |
| SUBTRIP\_KALL             | Total live pounds from subtrip               | NUMBER       |
| SECTOR\_ID                | Groundfish sector membership                 | VARCHAR2(50) |
| ACTIVITY\_CODE\_1         | VMS declaration                              | VARCHAR2(18) |
| ACTIVITY\_CODE\_2         | VMS declaration (if more than 1)             | VARCHAR2(18) |
| ACTIVITY\_CODE\_3         | VMS declaration (if more than 2)             | VARCHAR2(18) |
| PERMIT\_EFP\_1            | EFP trip fishing under                       | VARCHAR2(50) |
| PERMIT\_EFP\_2            | EFP trip fishing under                       | VARCHAR2(50) |
| PERMIT\_EFP\_3            | EFP trip fishing under                       | VARCHAR2(50) |
| PERMIT\_EFP\_4            | EFP trip fishing under                       | VARCHAR2(50) |
| REDFISH\_EXEMPTION        | Exemption fishing under                      | NUMBER       |
| CLOSED\_AREA\_EXEMPTION   | Exemption fishing under                      | NUMBER       |
| SNE\_SMALLMESH\_EXEMPTION | Exemption fishing under                      | NUMBER       |
| XLRG\_GILLNET\_EXEMPTION  | Exemption fishing under                      | NUMBER       |
| TRIPCATEGORY              | Scallop fleet designtion (LA, GEN, ALL)      | CHAR(3)      |
| ACCESSAREA                | Scallop Access Area                          | VARCHAR2(4)  |
| LINK1                     | Observer LINK1 if trip was obsevered         | VARCHAR2(35) |
| OBSVTR                    | Observer recorded VTR serial number          | VARCHAR2(15) |
| OBS\_LINK1                | Obsever recorded LINK1                       | VARCHAR2(15) |
| LINK3                     | Observer recorded haul                       | VARCHAR2(19) |
| OBS\_AREA                 | Observer recorded statistical area           | VARCHAR2(3)  |
| NESPP3                    | three digit species code                     | VARCHAR2(3)  |
| DISCARD                   | Prorated observer recorded discard           | NUMBER       |
| OBS\_HAUL\_KEPT           | Observer recorded total pounds kept per haul | NUMBER       |
| OBS\_KALL                 | Observer recorded total pounds kept per trip | NUMBER       |
| OBS\_GEAR                 | Observer recorded gear (NEGEAR)              | VARCHAR2(3)  |
| OBS\_MESH                 | Observer recorded meshsize                   | NUMBER       |
| OBS\_MESHGROUP            | Observer recorded mesh category              | VARCHAR2(4)  |
