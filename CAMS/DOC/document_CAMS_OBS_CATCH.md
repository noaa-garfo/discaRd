CAMS: Observer & Catch Table
================
Ben Galuardi

## Summary

## Description

-   **OUTPUT TABLE:** APSD.BG_CAMS_OBS_CATCH
-   **YEARS:** 2018-2020
-   **RESOLUTION:** VTRSERNO (subtrip)\~LINK1
-   **DEVELOPMENT LANGUAGE:** SQL
-   **CODE:**
    <https://github.com/NOAA-Fisheries-Greater-Atlantic-Region/discaRd/tree/model_estimator/CAMS>

## Data Sources

-   CAMS Apportionment and Trip attributes (GARFO)
-   CAMS prorated observer data
    -   NEFOP (NEFSC)
    -   ASM (NEFSC)

![Figure 1. APSD.BG_CAMS_OBS_CATCH table
lineage](document_CAMS_OBS_CATCH_files/figure-gfm/table_flow0-1.png)

## Approach

The use of a combined catch and observation table allows for a single
source table to be used in discard estimation. Previous methods took a
two table approach, where catch information and observer records were
stratified independently, and then matched to calculate discard (e.g.,
*D* = *K* \* *d*/*k*). This approach had the possibility of mismatches
between observed strata and trip strata. In reality, this cannot occur.
We therefore do trip by trip matching, using `gear`, `meshgroup`,
`statistical area`, and `LINK1`, to match observer recorded species
discards with commercial trip activity.

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

The matching occurs in a staged manner. All commercial trips with a
`LINK1` field that is not null get a value for how many unique VTR
serial numbers are associated with it. The vast majority of observed
trips have a single VTR, and only require matching by `LINK1`. For
multiple VTR trips, a match as described above is used (`gear`,
`meshgroup`, `statistical area`, and `LINK1`).

`meshgroup` has been defined several ways depending on the data stream.
CAMS is using the following definition for `meshgroup`

All nets:

-   `small` : \< 3.99 (inches)
-   `medium` : 4-5.74 (inches)
-   `large` : \>= 5.75 (inches)

Gill Nets:

-   `extra large` \>= 8 (inches)

`gear` groupings for matching purposes required a mapping of NEGEAR
codes from observed and commercial trips to common gear codes
(e.g. `DRS`, `PTO`, etc). The relationship in our database tables
(VLGEAR, FVTR_GEAR) are many-to-many and do not map easily. Furthermore,
there are several NEGEAR codes in VTR that do not occur in observer
records, and vice versa. Therefore, a support table,
`MAPS.SECGEAR_MAPPED` was constructed to facilitate gear matching.

IMPORTANT!: The table itself is a hybrid. For trips that were not
observed, there will be a single row with all trip metrics and a total
`KALL` per subtrip. When a trip was observed, there are multiple rows
where the trip metric information is repeated, and each row shows
species, discarded amount, and other observer recorded information for
each row. Total `KALL` CANNOT be calculated without filtering rows by
`LINK1` to indicate an observed trip or not. These steps are outlined in
subsequent R modules used to run discaRd.

## Data Dictionary

    ## Warning: package 'knitr' was built under R version 4.0.5

| Name                    | Description                                  | Data Type    |
|:------------------------|:---------------------------------------------|:-------------|
| PERMIT                  | 6 digit permit number                        | VARCHAR2(6)  |
| DMIS_TRIP_ID            | CAMS unique trip identifier                  | VARCHAR2(60) |
| YEAR                    | Calendar Year                                | NUMBER       |
| MONTH                   | Month                                        | NUMBER       |
| REGION                  | N (AREA \< 600) or S (AREA \>= 600)          | CHAR(1)      |
| HALFOFYEAR              | 1 (Jan - June) or 2 (July-Dec)               | NUMBER       |
| DOCID                   | VTR Document ID                              | VARCHAR2(40) |
| VTRSERNO                | VTR serial number; identifies subtrip        | VARCHAR2(13) |
| GEARCODE                | three letter VTR gear code                   | VARCHAR2(3)  |
| GEARTYPE                | Gear description                             | VARCHAR2(34) |
| NEGEAR                  | two digit gearcode; used by NEFOP            | VARCHAR2(3)  |
| MESH                    | VTR mesh size in inches                      | NUMBER(6,1)  |
| MESHGROUP               | Categoried mesh: sm, lg, xlg, na             | VARCHAR2(3)  |
| AREA                    | statistical area from VTR                    | VARCHAR2(3)  |
| CAREA                   | Calculated Statisticl area from VTR position | VARCHAR2(3)  |
| SUBTRIP_KALL            | Total live pounds from subtrip               | NUMBER       |
| SECTOR_ID               | Groundfish sector membership                 | VARCHAR2(50) |
| ACTIVITY_CODE_1         | VMS declaration                              | VARCHAR2(18) |
| ACTIVITY_CODE_2         | VMS declaration (if more than 1)             | VARCHAR2(18) |
| ACTIVITY_CODE_3         | VMS declaration (if more than 2)             | VARCHAR2(18) |
| PERMIT_EFP_1            | EFP trip fishing under                       | VARCHAR2(50) |
| PERMIT_EFP_2            | EFP trip fishing under                       | VARCHAR2(50) |
| PERMIT_EFP_3            | EFP trip fishing under                       | VARCHAR2(50) |
| PERMIT_EFP_4            | EFP trip fishing under                       | VARCHAR2(50) |
| REDFISH_EXEMPTION       | Exemption fishing under                      | NUMBER       |
| CLOSED_AREA_EXEMPTION   | Exemption fishing under                      | NUMBER       |
| SNE_SMALLMESH_EXEMPTION | Exemption fishing under                      | NUMBER       |
| XLRG_GILLNET_EXEMPTION  | Exemption fishing under                      | NUMBER       |
| TRIPCATEGORY            | Scallop fleet designtion (LA, GEN, ALL)      | CHAR(3)      |
| ACCESSAREA              | Scallop Access Area                          | VARCHAR2(4)  |
| LINK1                   | Observer LINK1 if trip was obsevered         | VARCHAR2(35) |
| OBSVTR                  | Observer recorded VTR serial number          | VARCHAR2(15) |
| OBS_LINK1               | Obsever recorded LINK1                       | VARCHAR2(15) |
| LINK3                   | Observer recorded haul                       | VARCHAR2(19) |
| OBS_AREA                | Observer recorded statistical area           | VARCHAR2(3)  |
| NESPP3                  | three digit species code                     | VARCHAR2(3)  |
| DISCARD                 | Prorated observer recorded discard           | NUMBER       |
| OBS_HAUL_KEPT           | Observer recorded total pounds kept per haul | NUMBER       |
| OBS_KALL                | Observer recorded total pounds kept per trip | NUMBER       |
| OBS_GEAR                | Observer recorded gear (NEGEAR)              | VARCHAR2(3)  |
| OBS_MESH                | Observer recorded meshsize                   | NUMBER       |
| OBS_MESHGROUP           | Observer recorded mesh category              | VARCHAR2(4)  |
