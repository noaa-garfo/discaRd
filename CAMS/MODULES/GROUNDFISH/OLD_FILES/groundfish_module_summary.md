Groundfish Module Summary
================
Ben Galuardi
`lubridate::today()`

# Background

Discards of groundfish species are used for several purposes throughout the year. Quota Monitoring requires these on a weekly basis. Discard rates for sector trips are shared with Sector managers. End of year ACL accounting also requires discard estimates from all trips.

This means a full accounting of groundfish discards occurs in several steps.

### Steps

1.  pull all merged trips from CAMS\_OBS\_CATCH

2.  separate Groundfish trips from non-groundfish trips (Use VMS declaration `like 'NMS%'`)

3.  Set stratification variables for groundfish trips

``` r
# FULL Stratification variables

stratvars = c('SPECIES_STOCK'
              , 'CAMS_GEAR_GROUP'
              , 'MESHGROUP'
              # , 'CAREA'
              , 'SECTID'
              , "PERMIT_EFP_1"
              , "PERMIT_EFP_2"
              , "PERMIT_EFP_3"
              , "PERMIT_EFP_4"
              , "REDFISH_EXEMPTION"
              , "SNE_SMALLMESH_EXEMPTION"
              , "XLRG_GILLNET_EXEMPTION"
              ) 
```

    - SPECIES_sTOCK is taken from CAMS support table `MAPS.CAMS_STATAREA_STOCK`
    - CAMS_GEAR_GROUP is derived from a support table (`MAPS.CAMS_GEARCODE_STRATA`)
    - MESHGROUP is hardcoded for all trips according to decisions made by the mesh subgroup (see summary when available)
    - SECTID comes from a CAMS matching table (`MAPS.MATCH_MULT_SECTID`)
    - EFP and Exemptions come from the CAMS trip atributes View (`MAPS.STG_TRIP_ATTR`), which complements `MAPS.DLR_VTR`

1.  Perform *first pass* of `discaRd`
    -   there are two sub-passes for year t and year t-1
2.  Perform *second pass* of `discaRd` with discard rates rolled up for all Sectors
    -   Common Pool is distinguished from the rest of Sectors
    -   Simplified stratification is used:

``` r
# Assumed Stratification variables

stratvars = c('SPECIES_STOCK'
              , 'CAMS_GEAR_GROUP'
              , 'MESHGROUP'
                            , 'SECTOR_TYPE'
              ) 
```

1.  The discaRd functions allow for an assumed rate to be calculated. This assumed rate is realtive to the stratification used in the functions. Here, we utilize this feature to generate a broad stock rate. the stratification here is simply `SPECIES_STOCK`

2.  For each *pass*, a transition rate is calculated between year t and year t-1. This rate determines how much, if any, information is used from previous years.

3.  The two *passes* are joined in a hierarchical manner. Rates and `DISCARD_SOURCE` (in parentheses) are assigned for each trip according to:

-   1.  in season rate; &gt;= 5 trips in Full Stratification

-   1.  Transition in season rate; &lt; 5 trips in Full Stratification, year t, AND &gt;= 5 trips in year t-1

-   1.  Assumed rate. This is the *second pass* rate when there were &gt;=5 trips in season

-   1.  Broad stock rate is used when other criteria are not met.

-   1.  Observed values used from obserevd trips; discard rate is NOT USED.

1.  CV calculations are available for (I), (T), and (A). Obtaining a CV estimate for (B) would require a *third pass* of discaRd functions. (O) rates are not used and final discard values are not estimated.

2.  Discard pounds per trip are calculated according to

``` r
    mutate(coalesce(DISC_MORT_RATIO, 1)) %>%
    mutate(DISCARD = case_when(!is.na(LINK1) ~ DISC_MORT_RATIO*OBS_DISCARD
                                                         , is.na(LINK1) ~ DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS)
                 
            # COAL_RATE is the final discard rate used. It is 'coalesced' from the (I), (A) and (B) rates    
```

By assigning `SPECIES_STOCK` as a stratification variable, the computation time is reduced. Each subtrip may only occur in a single statistical area so it should never cross stock boundaries.

Once the full table (CAMS\_OBS\_CATCH) is loaded, each species takes ~12 seconds to process on the server.

Output tables are produced for each species. These can easily be recombined. An example table has been shared on `MAPS` and `CAMS_GARFO`

``` sql
    MAPS.CAMS_DISCARD_EXAMPLE_GF19
    CAMS_GARFO.CAMS_DISCARD_EXAMPLE_GF19
```

### Diagnostic Plots/Tables

    ## Registered S3 methods overwritten by 'tibble':
    ##   method     from  
    ##   format.tbl pillar
    ##   print.tbl  pillar

    ## 
    ## Attaching package: 'dbplyr'

    ## The following objects are masked from 'package:dplyr':
    ## 
    ##     ident, sql

    ## Registered S3 methods overwritten by 'ggplot2':
    ##   method         from 
    ##   [.quosures     rlang
    ##   c.quosures     rlang
    ##   print.quosures rlang

    ## Loading required package: plyr

    ## ------------------------------------------------------------------------------

    ## You have loaded plyr after dplyr - this is likely to cause problems.
    ## If you need functions from both plyr and dplyr, please load plyr first, then dplyr:
    ## library(plyr); library(dplyr)

    ## ------------------------------------------------------------------------------

    ## 
    ## Attaching package: 'plyr'

    ## The following objects are masked from 'package:dplyr':
    ## 
    ##     arrange, count, desc, failwith, id, mutate, rename, summarise,
    ##     summarize

    ## Loading required package: tidyr

    ## Loading required package: scales

    ## Loading required package: reshape2

    ## 
    ## Attaching package: 'reshape2'

    ## The following object is masked from 'package:tidyr':
    ## 
    ##     smiths

    ## Loading required package: lubridate

    ## 
    ## Attaching package: 'lubridate'

    ## The following object is masked from 'package:plyr':
    ## 
    ##     here

    ## The following object is masked from 'package:base':
    ## 
    ##     date

    ## Loading required package: xtable

    ## Loading required package: DT

    ## Loading required package: foreach

    ## Loading required package: doParallel

    ## Loading required package: iterators

    ## Loading required package: parallel

![Discard Rates by Stock, Species, Discard Source](groundfish_module_summary_files/figure-markdown_github/make%20diagnostic%20plot-1.png)

    ## `summarise()` has grouped output by 'SPECIES_ITIS_EVAL', 'COMNAME_EVAL', 'DISCARD_SOURCE'. You can override using the `.groups` argument.

![Discard Estimate by Stock, Species, Discard Source](groundfish_module_summary_files/figure-markdown_github/plot%202-1.png)

``` r
db_example %>% 
    group_by(COMNAME_EVAL
                     , SPECIES_STOCK) %>% 
    dplyr::summarise(nvtr = n_distinct(VTRSERNO)
                                     , KALL = sum(SUBTRIP_KALL, na.rm = T)
                                     , DISCARD = round(sum(DISCARD, na.rm = T))) %>% 
    knitr::kable(format.args = list(big.mark = ","))
```

    ## `summarise()` has grouped output by 'COMNAME_EVAL'. You can override using the `.groups` argument.

| COMNAME\_EVAL                       | SPECIES\_STOCK |   nvtr|        KALL|  DISCARD|
|:------------------------------------|:---------------|------:|-----------:|--------:|
| COD                                 | EGB            |    177|   2,603,239|    2,355|
| COD                                 | GOM            |  4,882|  38,473,880|   20,343|
| COD                                 | MA             |    304|   1,208,706|       27|
| COD                                 | SNE            |    758|   5,026,253|      130|
| COD                                 | WGB            |  2,875|  28,280,827|    7,959|
| FLOUNDER, AMERICAN PLAICE /DAB      | GBK            |  3,052|  30,884,066|   31,879|
| FLOUNDER, AMERICAN PLAICE /DAB      | GOM            |  4,882|  38,473,880|   71,639|
| FLOUNDER, AMERICAN PLAICE /DAB      | MA             |    304|   1,208,706|       13|
| FLOUNDER, AMERICAN PLAICE /DAB      | SNE            |    758|   5,026,253|       79|
| FLOUNDER, SAND-DAB / WINDOWPANE / B | GBGOM          |  7,931|  69,356,507|   42,731|
| FLOUNDER, SAND-DAB / WINDOWPANE / B | SNEMA          |  1,065|   6,236,398|   34,169|
| FLOUNDER, WINTER / BLACKBACK        | GB             |    572|  11,526,753|    1,339|
| FLOUNDER, WINTER / BLACKBACK        | GOM            |  4,882|  38,473,880|    2,999|
| FLOUNDER, WINTER / BLACKBACK        | SNEMA          |  3,542|  25,592,272|    3,141|
| FLOUNDER, WITCH / GRAY SOLE         | GBGOM          |  7,934|  69,357,946|   68,502|
| FLOUNDER, WITCH / GRAY SOLE         | OTHER          |  1,062|   6,234,959|      477|
| FLOUNDER, YELLOWTAIL                | CCGOM          |  7,359|  57,829,754|   26,813|
| FLOUNDER, YELLOWTAIL                | GB             |    572|  11,526,753|      864|
| FLOUNDER, YELLOWTAIL                | MA             |      5|       9,740|        0|
| FLOUNDER, YELLOWTAIL                | SNE            |  1,060|   6,226,658|      233|
| HADDOCK                             | EGB            |    177|   2,603,239|   42,618|
| HADDOCK                             | GOM            |  4,882|  38,473,880|  159,259|
| HADDOCK                             | MA             |    304|   1,208,706|       13|
| HADDOCK                             | WGB and South  |  3,633|  33,307,080|  290,508|
| HAKE, WHITE                         | MA             |    304|   1,208,706|       13|
| HAKE, WHITE                         | NE             |  8,692|  74,384,199|   30,246|
| HALIBUT, ATLANTIC                   | MA             |    304|   1,208,706|       10|
| HALIBUT, ATLANTIC                   | NE             |  8,692|  74,384,199|   73,320|
| OCEAN POUT                          | GB\_SNE        |  4,114|  37,119,025|   71,518|
| OCEAN POUT                          | GOM            |  4,882|  38,473,880|   12,636|
| POLLOCK                             | MA             |      5|       9,740|        0|
| POLLOCK                             | NE             |  8,920|  74,714,281|  119,073|
| REDFISH / OCEAN PERCH               | MA             |    304|   1,208,706|       13|
| REDFISH / OCEAN PERCH               | NE             |  8,692|  74,384,199|   89,056|
| WOLFFISH / OCEAN CATFISH            | GBK            |    765|   5,095,798|       47|
| WOLFFISH / OCEAN CATFISH            | GOM            |  7,914|  69,264,904|    5,276|
| WOLFFISH / OCEAN CATFISH            | MA             |    304|   1,208,706|        1|

``` r
db_example %>% 
    group_by(COMNAME_EVAL
                     , DISCARD_SOURCE
                     , STRATA_FULL
                     , STRATA_ASSUMED) %>% 
    dplyr::summarise(DISCARD_RATE = max(DISCARD_RATE)
                                     , KALL = sum(SUBTRIP_KALL, na.rm = T)) %>% 
    knitr::kable(format.args = list(big.mark = ","))
```

    ## `summarise()` has grouped output by 'COMNAME_EVAL', 'DISCARD_SOURCE', 'STRATA_FULL'. You can override using the `.groups` argument.

<table>
<colgroup>
<col width="20%" />
<col width="8%" />
<col width="38%" />
<col width="18%" />
<col width="7%" />
<col width="6%" />
</colgroup>
<thead>
<tr class="header">
<th align="left">COMNAME_EVAL</th>
<th align="left">DISCARD_SOURCE</th>
<th align="left">STRATA_FULL</th>
<th align="left">STRATA_ASSUMED</th>
<th align="right">DISCARD_RATE</th>
<th align="right">KALL</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">98,673</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">421,522</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">192,169</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">40,997</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">477,729</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">470,139</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">110,925</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">75,055</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">45,485</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">353,077</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">32,791</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">5,872</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">9,260</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">279,662</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">2,127</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">6,030</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">64,924</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">9,478</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">564</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">438,545</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">84,170</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">136,610</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">314,548</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">29,708</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">6,480</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">109,568</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">12,521</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">730</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">6,197</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">73,905</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">249,764</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">141,825</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">15,823</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">52,963</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">5,521</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">3,099</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">22,914</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">45,861</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">3,267</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">6,470</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">84,071</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">651</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">7,963</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">367</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">280,625</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">166,129</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">11,288</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">56,194</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">1,413</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">159,269</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">13,416</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">436,410</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">153,599</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">A</td>
<td align="left">WGB_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">3,072</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">EGB_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_10_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">5,762</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">EGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_LM_SECTOR</td>
<td align="right">0.0042235</td>
<td align="right">31,277</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">EGB_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_LM_SECTOR</td>
<td align="right">0.0042235</td>
<td align="right">10,341</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">EGB_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_XL_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">EGB_20_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_20_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">11,688</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">EGB_20_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_20_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">388</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">25,074</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">32,781</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">154</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">118,788</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">14</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">2,058</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">4,618</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">9,070</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">32,437</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">103,064</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">2,375</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_132_na_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,852</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">390</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">4,763</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">823</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">45,853</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">17,316</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_20_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_20_na_SECTOR</td>
<td align="right">0.0072853</td>
<td align="right">398</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_200_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_200_na_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">976</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_200_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_200_na_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">6,228</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0068714</td>
<td align="right">43,711</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0068714</td>
<td align="right">939</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0003732</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">MA_20_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_20_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">47</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">5,304</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">2,066</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0001302</td>
<td align="right">18,180</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0001302</td>
<td align="right">128,811</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0001302</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0001302</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">SNE_20_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_20_na_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">170</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_10_na_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">56</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_10_na_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">13,674</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_10_na_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">609</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_20_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_20_na_COMMON_POOL</td>
<td align="right">0.0003728</td>
<td align="right">1,357</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_20_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_20_na_SECTOR</td>
<td align="right">0.0375940</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_20_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_20_na_SECTOR</td>
<td align="right">0.0375940</td>
<td align="right">8,330</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">B</td>
<td align="left">WGB_20_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_20_na_SECTOR</td>
<td align="right">0.0375940</td>
<td align="right">10,523</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001156</td>
<td align="right">1,054,105</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0018682</td>
<td align="right">264,356</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0035041</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0169280</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007377</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0012233</td>
<td align="right">4,392,857</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0002251</td>
<td align="right">6,889,791</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">139,083</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004179</td>
<td align="right">3,869,101</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000766</td>
<td align="right">5,155,547</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000656</td>
<td align="right">6,460,201</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001573</td>
<td align="right">90,226</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">194,935</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000207</td>
<td align="right">1,970,071</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">258,959</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000401</td>
<td align="right">12,741</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000401</td>
<td align="right">1,193,492</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">673,093</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">677,164</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">372,311</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0006946</td>
<td align="right">1,756,663</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000153</td>
<td align="right">5,890,051</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">540,197</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0001217</td>
<td align="right">2,128,780</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003764</td>
<td align="right">1,642,610</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">908,963</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0004873</td>
<td align="right">5,195,777</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0002504</td>
<td align="right">2,492,826</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">1,098,584</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">I</td>
<td align="left">WGB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0012372</td>
<td align="right">1,914,307</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">EGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_LM_SECTOR</td>
<td align="right">0.0042235</td>
<td align="right">5,707</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">EGB_20_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_20_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">100,284</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">8,993</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">83,062</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0010289</td>
<td align="right">18,779</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0241581</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001156</td>
<td align="right">84,124</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">5,323</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0018682</td>
<td align="right">9,405</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0035041</td>
<td align="right">47,473</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">1,736</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0016444</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0169280</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">444</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">886</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0044328</td>
<td align="right">18,560</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0012809</td>
<td align="right">3,532</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">16,306</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007377</td>
<td align="right">54,302</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0012233</td>
<td align="right">649,922</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0002251</td>
<td align="right">779,504</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">11,833</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">1,546</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">321</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0068714</td>
<td align="right">2,147</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">6,393</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004179</td>
<td align="right">361,676</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000766</td>
<td align="right">575,659</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000656</td>
<td align="right">747,319</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0004186</td>
<td align="right">29,915</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001573</td>
<td align="right">13,541</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">24,399</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000207</td>
<td align="right">278,246</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0003732</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">346</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">89,694</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">2,619</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000401</td>
<td align="right">140,985</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">7,613</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">78,893</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">125,581</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">72,387</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">16,530</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0006946</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_LM_SECTOR</td>
<td align="right">0.0007304</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">5,907</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">15,358</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000153</td>
<td align="right">159,859</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_100_XL_SECTOR</td>
<td align="right">0.0000358</td>
<td align="right">226</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">93,666</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0001217</td>
<td align="right">192,791</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003764</td>
<td align="right">305,405</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">17,410</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">47,078</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0004873</td>
<td align="right">365,532</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0002504</td>
<td align="right">256,906</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003728</td>
<td align="right">209,230</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0003777</td>
<td align="right">25,524</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">O</td>
<td align="left">WGB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB_50_LM_SECTOR</td>
<td align="right">0.0012372</td>
<td align="right">257,382</td>
</tr>
<tr class="odd">
<td align="left">COD</td>
<td align="left">T</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">COD</td>
<td align="left">T</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0012809</td>
<td align="right">27,844</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_0_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">110,181</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">3,099,505</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_0_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">166,656</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_0_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">96,488</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,267</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,470</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">84,071</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,304</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">367</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,879</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">79,204</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,612</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">364,300</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">280,625</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14,218</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">166,129</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">1,413</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">159,269</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">88,471</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">315,239</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">89,902</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">3,072</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">89,047</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">1,006</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">9,260</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">51,484</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">279,662</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,432</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,478</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">986</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">88,760</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">70,803</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">3,253</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">3,777</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">21,027</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">564</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">438,545</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">27,365</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">286,579</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">84,170</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">136,610</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">308,983</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">29,708</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">6,480</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">2,359</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">1,102</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">109,568</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">12,521</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">4,190</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">730</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">6,197</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">73,905</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">249,764</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">141,825</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">15,823</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">52,963</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">5,521</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">3,099</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">22,914</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">45,861</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_COMMON_POOL</td>
<td align="right">0.0005654</td>
<td align="right">1,357</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,688</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,523</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">388</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_10_na_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">56</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_10_na_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">19,436</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GBK_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_10_na_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">609</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">5,565</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">390</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">5,739</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">823</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">45,853</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,316</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,228</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">398</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,074</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">32,781</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">154</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">118,788</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,058</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,618</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,070</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">32,437</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">103,064</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_132_na_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0151145</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0151145</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">MA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">170</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">47</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">5,304</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_COMMON_POOL</td>
<td align="right">0.0000450</td>
<td align="right">2,066</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,180</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">128,811</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,756,663</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,890,051</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">620,494</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0004494</td>
<td align="right">2,440,121</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0035074</td>
<td align="right">1,834,779</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0002524</td>
<td align="right">949,960</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0009084</td>
<td align="right">2,574,001</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0044232</td>
<td align="right">2,962,965</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">800,672</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0010941</td>
<td align="right">2,267,384</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001156</td>
<td align="right">1,054,105</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0003114</td>
<td align="right">264,356</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000696</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0078989</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0028102</td>
<td align="right">4,392,857</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007044</td>
<td align="right">6,889,791</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">139,083</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006948</td>
<td align="right">3,869,101</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0032397</td>
<td align="right">5,155,547</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0023450</td>
<td align="right">6,460,201</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0102274</td>
<td align="right">90,226</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">194,935</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0012187</td>
<td align="right">1,970,071</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">133,789</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000115</td>
<td align="right">12,741</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000115</td>
<td align="right">1,193,492</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">673,093</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">677,164</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">372,311</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">22,623</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">666</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">300,735</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0011045</td>
<td align="right">82,793</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,907</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,358</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">226</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">71,043</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0004494</td>
<td align="right">192,791</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0035074</td>
<td align="right">304,739</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">17,410</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0002524</td>
<td align="right">47,078</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0009084</td>
<td align="right">165,081</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0044232</td>
<td align="right">265,899</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0005654</td>
<td align="right">209,499</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0016288</td>
<td align="right">25,524</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0010941</td>
<td align="right">276,161</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,334</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001156</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0003114</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000696</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">571</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001651</td>
<td align="right">11,320</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0130666</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0078989</td>
<td align="right">52,968</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0028102</td>
<td align="right">649,922</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007044</td>
<td align="right">779,504</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0151145</td>
<td align="right">2,147</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006948</td>
<td align="right">361,676</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0032397</td>
<td align="right">575,659</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0023450</td>
<td align="right">747,319</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0021314</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0102274</td>
<td align="right">13,541</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0012187</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">61</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">285</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,002</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000115</td>
<td align="right">140,985</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">7,613</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000450</td>
<td align="right">125,581</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">72,387</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000039</td>
<td align="right">16,530</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">T</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, AMERICAN PLAICE /DAB</td>
<td align="left">T</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0130666</td>
<td align="right">27,844</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">2,127</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">6,030</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">64,924</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">219,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">280,625</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_0_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">604,674</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">27,365</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">11,288</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">138,023</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">314,548</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">511,603</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">2,359</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">1,102</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">295,958</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">4,190</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">730</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">6,197</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">74,767</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">253,023</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">149,136</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">21,238</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">52,963</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">5,521</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">3,099</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0032684</td>
<td align="right">24,578</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">53,409</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">32,437</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,130</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">33,171</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">7,250</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">149,912</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,982</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,270</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">46,241</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,330</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,286</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,016</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,679</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">103,064</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_0_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_132_na_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0001478</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">GBGOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0001478</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_LM_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">1,397</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">6,692</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">348</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">1,076</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">156</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_XL_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">2,066</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,180</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">128,811</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_0_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_132_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_132_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">6,458</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_SM_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">B</td>
<td align="left">SNEMA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_SM_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_0_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,057,372</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">270,826</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0000232</td>
<td align="right">211,790</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_0_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0009459</td>
<td align="right">1,756,663</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_0_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_0_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000204</td>
<td align="right">5,899,529</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">144,806</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0118028</td>
<td align="right">442,735</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0003292</td>
<td align="right">5,031,727</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,440,093</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">139,083</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0040637</td>
<td align="right">1,835,343</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,819,061</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000157</td>
<td align="right">10,829,053</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000121</td>
<td align="right">9,423,166</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">1,293,679</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0002208</td>
<td align="right">249,495</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,058,542</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0088225</td>
<td align="right">2,273,864</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0072534</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0072534</td>
<td align="right">1,208,763</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0113859</td>
<td align="right">851,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">701,714</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0038987</td>
<td align="right">542,637</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">531,783</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0000232</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0009459</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0003126</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">444</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000204</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_0_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000698</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0022375</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0118028</td>
<td align="right">54,302</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0003292</td>
<td align="right">743,588</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">972,295</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0040637</td>
<td align="right">305,405</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">17,410</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0001478</td>
<td align="right">2,147</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">408,754</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000157</td>
<td align="right">1,041,460</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000121</td>
<td align="right">1,013,218</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">292,292</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008970</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0002208</td>
<td align="right">39,065</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0088225</td>
<td align="right">276,161</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_0_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_0_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_132_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_132_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0072534</td>
<td align="right">141,331</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">10,467</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0113859</td>
<td align="right">166,488</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000397</td>
<td align="right">131,060</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0038987</td>
<td align="right">142,271</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">101,931</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">15</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0093907</td>
<td align="right">17,357</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">O</td>
<td align="left">SNEMA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_SM_COMMON_POOL</td>
<td align="right">0.0000397</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">T</td>
<td align="left">GBGOM_0_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, SAND-DAB / WINDOWPANE / B</td>
<td align="left">T</td>
<td align="left">GBGOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0022375</td>
<td align="right">27,844</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">327,166</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">1,596,810</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">22,605</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">120,986</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">1,400,922</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">75,055</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">455,171</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GB_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">154,673</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">5,872</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">9,260</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">279,662</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">2,127</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,030</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">64,924</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,478</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">564</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">438,545</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">84,170</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">136,610</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">314,548</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">29,708</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">6,480</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">109,568</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">12,521</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">2,671</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">84,071</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">651</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">5,865</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">367</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">5,304</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">30,652</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">298,805</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">730</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">6,197</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">74,767</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">253,023</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">149,136</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">143,524</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">21,238</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">1,413</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">159,269</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">13,416</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">26,724</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0004493</td>
<td align="right">24,578</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">85,126</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">3,072</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">A</td>
<td align="left">SNEMA_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_0_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">17,450</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_0_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">388</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,267</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,799</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,277</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,439</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GB_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_XL_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,074</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">33,171</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">5,893</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">118,788</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">823</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">45,853</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,330</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,286</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,016</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,070</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">32,437</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">103,064</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_132_na_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0019541</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0019541</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">56</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">8,049</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">13,674</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,523</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">156</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">609</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">2,066</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_132_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_132_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">6,458</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_SM_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">7,127</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">B</td>
<td align="left">SNEMA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_SM_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">704</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000251</td>
<td align="right">1,662,671</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000279</td>
<td align="right">2,908,513</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">552,922</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0003039</td>
<td align="right">1,106,307</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000128</td>
<td align="right">1,054,105</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">264,356</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001392</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0082404</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001494</td>
<td align="right">4,392,857</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,889,791</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">139,083</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000025</td>
<td align="right">3,869,101</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000032</td>
<td align="right">5,155,547</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,460,201</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0018095</td>
<td align="right">90,226</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">194,935</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,970,071</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000148</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000102</td>
<td align="right">6,018,862</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">311,704</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">953,492</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0002144</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002144</td>
<td align="right">1,380,871</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0031891</td>
<td align="right">851,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">701,714</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0005719</td>
<td align="right">542,637</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">531,783</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">828,974</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,769,076</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,562,043</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">656,587</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">I</td>
<td align="left">SNEMA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,214,040</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_0_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,707</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">63,107</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">82,668</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000251</td>
<td align="right">227,075</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">14,921</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000279</td>
<td align="right">290,781</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000946</td>
<td align="right">76,048</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">183,892</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0003039</td>
<td align="right">121,737</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000128</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001392</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">571</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000528</td>
<td align="right">11,320</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005315</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0082404</td>
<td align="right">54,302</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001494</td>
<td align="right">649,922</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">779,504</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0019541</td>
<td align="right">2,147</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000025</td>
<td align="right">361,676</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000032</td>
<td align="right">575,659</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">747,319</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001815</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0018095</td>
<td align="right">13,541</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">4,144</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">20,786</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000148</td>
<td align="right">35,353</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">637</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_LM_SECTOR</td>
<td align="right">0.0000810</td>
<td align="right">2,619</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000102</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_100_XL_SECTOR</td>
<td align="right">0.0000082</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_132_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_132_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">30,559</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">110,123</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002144</td>
<td align="right">219,661</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">2,489</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">10,467</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0031891</td>
<td align="right">166,488</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">78,893</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">131,060</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0005719</td>
<td align="right">142,271</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">101,931</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">47,078</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">175,035</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">189,851</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0002049</td>
<td align="right">108,400</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0005453</td>
<td align="right">25,524</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">171,781</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">O</td>
<td align="left">SNEMA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNEMA_50_SM_COMMON_POOL</td>
<td align="right">0.0002049</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">T</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WINTER / BLACKBACK</td>
<td align="left">T</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005315</td>
<td align="right">27,844</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">2,127</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,030</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">64,924</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">219,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">280,625</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">604,674</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">27,365</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">11,288</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">138,023</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">308,983</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">344,947</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">2,359</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">1,102</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">199,470</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">4,190</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_57_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">110,181</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">3,099,505</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_57_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">166,656</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">GBGOM_57_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">96,488</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">730</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">6,197</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">74,767</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">253,023</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">149,136</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">6,251</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">21,238</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">4,083</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">52,963</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_COMMON_POOL</td>
<td align="right">0.0000636</td>
<td align="right">24,578</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">53,409</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">A</td>
<td align="left">OTHER_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">6,246</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">5,565</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,130</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">33,171</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">7,250</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">149,912</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,346</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">46,241</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,330</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,286</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,016</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,679</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">32,437</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">103,064</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_132_na_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0567448</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">GBGOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0567448</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_0_na_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">6,692</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_0_na_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">156</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_100_LM_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">1,397</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_100_LM_SECTOR</td>
<td align="right">0.0000429</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">OTHER_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_100_XL_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">2,066</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,180</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">OTHER_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">128,811</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">OTHER_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_SM_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">7,127</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">B</td>
<td align="left">OTHER_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_SM_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">704</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000385</td>
<td align="right">1,057,372</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">270,826</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000232</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,899,529</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0001102</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008750</td>
<td align="right">5,013,351</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0003385</td>
<td align="right">9,329,912</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">139,083</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0015322</td>
<td align="right">1,835,343</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006747</td>
<td align="right">4,819,061</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0020165</td>
<td align="right">7,729,548</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0020485</td>
<td align="right">9,423,166</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">884,842</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0017940</td>
<td align="right">249,495</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">194,935</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0009123</td>
<td align="right">2,058,542</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">GBGOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0015580</td>
<td align="right">2,273,864</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_COMMON_POOL</td>
<td align="right">0.0002077</td>
<td align="right">12,741</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0002077</td>
<td align="right">1,208,763</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">733,065</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000429</td>
<td align="right">673,093</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000429</td>
<td align="right">701,714</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_COMMON_POOL</td>
<td align="right">0.0000810</td>
<td align="right">542,637</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">I</td>
<td align="left">OTHER_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">531,783</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">1,334</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">666</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">1,906</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000385</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000232</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_LM_SECTOR</td>
<td align="right">0.0000158</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_COMMON_POOL</td>
<td align="right">0.0006544</td>
<td align="right">444</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0022216</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0001102</td>
<td align="right">52,968</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0008750</td>
<td align="right">720,965</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0003385</td>
<td align="right">972,295</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0015322</td>
<td align="right">304,739</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">17,410</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0567448</td>
<td align="right">2,147</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006747</td>
<td align="right">408,754</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0020165</td>
<td align="right">740,740</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0020485</td>
<td align="right">1,013,218</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">209,499</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0013062</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0017940</td>
<td align="right">39,065</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0006544</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0009123</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0015580</td>
<td align="right">276,161</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">22,623</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">298,829</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">GBGOM_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_57_LM_SECTOR</td>
<td align="right">0.0002684</td>
<td align="right">82,793</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">61</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_100_LM_SECTOR</td>
<td align="right">0.0000429</td>
<td align="right">2,619</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">OTHER_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0002077</td>
<td align="right">141,270</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">10,467</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">151,229</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000429</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000429</td>
<td align="right">131,060</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_COMMON_POOL</td>
<td align="right">0.0000810</td>
<td align="right">142,271</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">101,931</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_LM_SECTOR</td>
<td align="right">0.0000633</td>
<td align="right">17,357</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">O</td>
<td align="left">OTHER_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">OTHER_50_SM_COMMON_POOL</td>
<td align="right">0.0000429</td>
<td align="right">396</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">T</td>
<td align="left">GBGOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, WITCH / GRAY SOLE</td>
<td align="left">T</td>
<td align="left">GBGOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBGOM_50_LM_SECTOR</td>
<td align="right">0.0022216</td>
<td align="right">27,844</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">89,047</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">1,006</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">84,071</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">5,872</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">651</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">31,113</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">5,023</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">57,665</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">497,273</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">15,125</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">51,484</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">280,029</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">1,432</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">280,625</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">582,069</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">27,365</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">11,288</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">138,023</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">308,983</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">50,553</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">2,359</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">1,102</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">140,773</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">CCGOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">4,190</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">313,737</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">1,553,744</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">22,605</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">120,986</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">1,400,922</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">75,055</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">294,394</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">58,697</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">13,429</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_57_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">43,066</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">1,369,717</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_57_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">160,777</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">GB_57_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">95,976</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">730</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">6,197</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">73,905</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">253,023</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">149,136</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">6,251</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">21,238</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">52,963</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">5,521</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">3,099</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000266</td>
<td align="right">24,578</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">53,409</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">A</td>
<td align="left">SNE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">390</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">7,096</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,982</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,270</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">45,853</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,316</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,228</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">398</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,130</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">32,781</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_COMMON_POOL</td>
<td align="right">0.0005166</td>
<td align="right">154</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">132,462</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,058</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,618</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,679</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005166</td>
<td align="right">32,437</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005166</td>
<td align="right">103,064</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005166</td>
<td align="right">2,375</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_132_na_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">1,852</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0074877</td>
<td align="right">43,711</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0074877</td>
<td align="right">939</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_54_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">CCGOM_54_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">5,565</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,947</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_57_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">67,115</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,729,788</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_57_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,879</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">CCGOM_57_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">512</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_0_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">11,688</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_0_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">388</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_10_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">5,762</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,267</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,799</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,277</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,439</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">GB_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_XL_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">6,879</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">118,712</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">6,692</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">348</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">1,076</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_na_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">156</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">5,304</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">2,066</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,180</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">128,811</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_SM_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_SM_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">B</td>
<td align="left">SNE_52_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_52_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">6,458</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,054,105</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0028023</td>
<td align="right">267,027</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0003945</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0000296</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000051</td>
<td align="right">5,899,529</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0216760</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0015204</td>
<td align="right">4,699,614</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0002307</td>
<td align="right">7,776,168</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">139,083</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000981</td>
<td align="right">172,672</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000025</td>
<td align="right">4,698,075</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0001053</td>
<td align="right">6,190,752</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000010</td>
<td align="right">8,022,244</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">331,920</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0035880</td>
<td align="right">249,495</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">194,935</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,983,487</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">CCGOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000232</td>
<td align="right">1,167,557</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">GB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0001325</td>
<td align="right">1,662,671</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000319</td>
<td align="right">1,538,796</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">GB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">552,922</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">GB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,106,307</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000168</td>
<td align="right">12,741</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000168</td>
<td align="right">1,208,763</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000907</td>
<td align="right">733,065</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">673,093</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">701,714</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000340</td>
<td align="right">542,637</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">I</td>
<td align="left">SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">531,783</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_0_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">1,334</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">84,124</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">5,323</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0028023</td>
<td align="right">9,405</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0003945</td>
<td align="right">47,473</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005166</td>
<td align="right">1,736</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0000296</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_LM_SECTOR</td>
<td align="right">0.0001871</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005166</td>
<td align="right">444</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000051</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000037</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0127277</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0216760</td>
<td align="right">52,968</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0015204</td>
<td align="right">680,481</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0002307</td>
<td align="right">889,627</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000981</td>
<td align="right">78,330</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">2,489</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_COMMON_POOL</td>
<td align="right">0.0074877</td>
<td align="right">2,147</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000025</td>
<td align="right">408,754</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0001053</td>
<td align="right">686,623</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000010</td>
<td align="right">937,170</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">34,473</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0006565</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0035880</td>
<td align="right">39,065</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0005166</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0000232</td>
<td align="right">154,424</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">64,056</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">CCGOM_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_57_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,927</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_0_na_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">1,517</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">40,484</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">82,668</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0001325</td>
<td align="right">226,409</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">14,921</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000319</td>
<td align="right">54,117</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000433</td>
<td align="right">76,048</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">175,026</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">121,737</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_54_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_54_LM_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">666</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_54_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_54_LM_SECTOR</td>
<td align="right">0.0005982</td>
<td align="right">1,906</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">22,623</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">234,758</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">GB_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_57_LM_SECTOR</td>
<td align="right">0.0000141</td>
<td align="right">8,866</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">3,968</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,259</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_100_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000168</td>
<td align="right">141,270</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">10,467</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000907</td>
<td align="right">151,229</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">78,893</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">131,060</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000340</td>
<td align="right">138,303</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">101,931</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_LM_SECTOR</td>
<td align="right">0.0000549</td>
<td align="right">16,530</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_50_SM_COMMON_POOL</td>
<td align="right">0.0000398</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_52_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_52_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_54_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_54_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">61</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">O</td>
<td align="left">SNE_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">SNE_57_LM_SECTOR</td>
<td align="right">0.0000398</td>
<td align="right">15</td>
</tr>
<tr class="odd">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">T</td>
<td align="left">CCGOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">FLOUNDER, YELLOWTAIL</td>
<td align="left">T</td>
<td align="left">CCGOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">CCGOM_50_LM_SECTOR</td>
<td align="right">0.0127277</td>
<td align="right">27,844</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">98,673</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">392,553</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">192,169</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">40,997</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">368,749</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">470,139</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">110,925</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">75,055</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">22,832</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">353,077</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">EGB_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">32,791</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">5,872</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">9,260</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">279,662</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">2,127</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">6,030</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">64,924</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">9,478</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">564</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">438,545</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">84,170</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">136,610</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">314,548</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">29,708</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">6,480</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">109,568</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">12,521</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">3,267</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">6,470</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">84,071</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">651</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">7,963</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">367</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">5,304</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">219,560</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">79,204</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,612</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">364,300</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">298,805</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14,218</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">730</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">6,197</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">73,905</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">249,764</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">141,825</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">6,251</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">166,129</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">15,823</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">1,413</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">159,269</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">13,416</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">292,407</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">22,914</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">102,972</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">3,072</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_57_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">81,212</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">2,990,525</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_57_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">144,003</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">A</td>
<td align="left">WGB and South_57_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">96,488</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_0_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">11,688</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_0_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">388</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_10_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">5,762</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_LM_SECTOR</td>
<td align="right">0.0032755</td>
<td align="right">31,277</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_LM_SECTOR</td>
<td align="right">0.0032755</td>
<td align="right">10,341</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_XL_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">6,879</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_57_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_57_LM_SECTOR</td>
<td align="right">0.0301705</td>
<td align="right">28,969</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_57_LM_SECTOR</td>
<td align="right">0.0301705</td>
<td align="right">108,980</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">EGB_57_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_57_LM_SECTOR</td>
<td align="right">0.0301705</td>
<td align="right">22,653</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">390</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_COMMON_POOL</td>
<td align="right">0.6279070</td>
<td align="right">5,739</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">823</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">45,853</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">17,316</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">6,228</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0319167</td>
<td align="right">398</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">25,074</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">68,713</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">32,781</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">8,705</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">154</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">118,788</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">14</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">2,058</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">4,618</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">9,070</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">32,437</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">103,064</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_132_na_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0006650</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0006650</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">MA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_0_na_COMMON_POOL</td>
<td align="right">0.0003160</td>
<td align="right">1,527</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,523</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_0_na_COMMON_POOL</td>
<td align="right">0.0003160</td>
<td align="right">47</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_10_na_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">56</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_10_na_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">13,674</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_10_na_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">609</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_COMMON_POOL</td>
<td align="right">0.0003160</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">B</td>
<td align="left">WGB and South_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_COMMON_POOL</td>
<td align="right">0.0003160</td>
<td align="right">2,066</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007710</td>
<td align="right">1,054,105</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">264,356</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007194</td>
<td align="right">211,790</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0005837</td>
<td align="right">420,401</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">144,806</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0046599</td>
<td align="right">442,735</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0176298</td>
<td align="right">4,392,857</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0035187</td>
<td align="right">6,889,791</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">139,083</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006420</td>
<td align="right">3,869,101</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0009970</td>
<td align="right">5,155,547</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0019476</td>
<td align="right">6,460,201</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0095980</td>
<td align="right">90,226</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005543</td>
<td align="right">1,970,071</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">258,959</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0001921</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,018,862</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">521,821</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0016982</td>
<td align="right">2,047,568</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_COMMON_POOL</td>
<td align="right">0.0029115</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0029115</td>
<td align="right">2,836,102</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">677,164</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">372,311</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0016087</td>
<td align="right">908,963</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0111625</td>
<td align="right">2,205,252</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0184077</td>
<td align="right">2,492,826</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">689,747</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">I</td>
<td align="left">WGB and South_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0236110</td>
<td align="right">1,967,270</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_0_na_SECTOR</td>
<td align="right">0.0011926</td>
<td align="right">1,517</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_100_LM_SECTOR</td>
<td align="right">0.0032755</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">8,993</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">74,629</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_50_LM_SECTOR</td>
<td align="right">0.0135002</td>
<td align="right">18,779</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">EGB_57_LM_SECTOR</td>
<td align="right">0.0301705</td>
<td align="right">100,284</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">EGB_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">EGB_57_LM_SECTOR</td>
<td align="right">0.0301705</td>
<td align="right">8,433</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0203849</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007710</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007194</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">571</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0007396</td>
<td align="right">11,320</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0005837</td>
<td align="right">12,730</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0002860</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0229962</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0046599</td>
<td align="right">54,302</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0176298</td>
<td align="right">649,922</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0035187</td>
<td align="right">779,504</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0006650</td>
<td align="right">2,147</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006420</td>
<td align="right">361,676</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0009970</td>
<td align="right">575,659</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0019476</td>
<td align="right">747,319</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0047054</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0095980</td>
<td align="right">13,541</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005543</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">346</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">89,694</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0001921</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_LM_SECTOR</td>
<td align="right">0.0006075</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">71,043</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0016982</td>
<td align="right">192,791</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0029115</td>
<td align="right">446,390</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">17,410</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">7,613</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">125,581</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">72,387</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0016087</td>
<td align="right">47,078</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0111625</td>
<td align="right">166,987</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0184077</td>
<td align="right">256,906</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0003160</td>
<td align="right">134,870</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">579</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0075726</td>
<td align="right">25,524</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_50_LM_SECTOR</td>
<td align="right">0.0236110</td>
<td align="right">273,912</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">22,623</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">198,545</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">O</td>
<td align="left">WGB and South_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">WGB and South_57_LM_SECTOR</td>
<td align="right">0.0301717</td>
<td align="right">74,360</td>
</tr>
<tr class="odd">
<td align="left">HADDOCK</td>
<td align="left">T</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">HADDOCK</td>
<td align="left">T</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0229962</td>
<td align="right">27,844</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">1,432</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">6,879</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">79,204</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">10,612</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">364,300</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">298,805</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">14,218</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">986</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">88,760</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">70,803</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">3,253</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">9,974</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">21,027</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">73,905</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">249,764</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">141,825</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">604,674</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">15,823</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">286,579</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">56,194</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">138,023</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">314,548</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">511,603</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">23,853</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">341,819</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">MA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">390</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">7,266</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,688</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,346</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">46,241</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,316</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,228</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">398</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">47</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,130</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">32,781</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">154</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">138,224</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,058</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,618</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,679</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">33,834</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">105,130</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">2,375</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">B</td>
<td align="left">NE_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_132_na_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">1,852</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">133,789</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0020559</td>
<td align="right">1,057,372</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">270,826</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001035</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,028,340</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000918</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003363</td>
<td align="right">5,031,727</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000876</td>
<td align="right">9,440,093</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">139,813</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000379</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000379</td>
<td align="right">3,028,835</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">677,164</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">416,022</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0023564</td>
<td align="right">4,819,061</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003422</td>
<td align="right">10,829,053</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0002037</td>
<td align="right">9,423,166</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">1,293,679</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000828</td>
<td align="right">249,495</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0001171</td>
<td align="right">2,058,542</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">I</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003665</td>
<td align="right">2,326,827</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">346</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,002</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">1,334</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0020559</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001035</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0012838</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">5,907</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">15,358</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">226</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">886</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0001139</td>
<td align="right">18,560</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,532</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">16,306</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000918</td>
<td align="right">52,968</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003363</td>
<td align="right">743,588</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000876</td>
<td align="right">972,295</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">11,833</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">1,546</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">321</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000379</td>
<td align="right">446,390</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">17,410</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">7,613</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">78,893</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">125,581</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">74,534</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0023564</td>
<td align="right">408,754</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003422</td>
<td align="right">1,041,475</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0002037</td>
<td align="right">1,013,218</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">292,292</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003702</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000828</td>
<td align="right">39,065</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0001171</td>
<td align="right">278,246</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">O</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003665</td>
<td align="right">292,691</td>
</tr>
<tr class="odd">
<td align="left">HAKE, WHITE</td>
<td align="left">T</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">HAKE, WHITE</td>
<td align="left">T</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">27,844</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">110,181</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">3,099,505</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">5,565</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">166,656</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_0_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">96,488</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">1,432</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">6,879</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">79,204</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">10,612</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">364,300</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">298,805</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">14,218</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">986</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">88,760</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">70,803</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">3,253</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">9,974</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">21,027</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">73,905</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">249,764</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">141,825</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">604,674</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">15,823</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">286,579</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">56,194</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">138,023</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">308,983</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">344,947</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">23,853</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">245,331</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">MA_20_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_20_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">976</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">6,228</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">47</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,130</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">32,781</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">154</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">138,224</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,058</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,618</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,679</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">33,834</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">105,130</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">390</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">6,290</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,688</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,346</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">46,241</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,316</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">B</td>
<td align="left">NE_20_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">398</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">133,789</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000771</td>
<td align="right">1,057,372</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0017644</td>
<td align="right">270,826</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000696</td>
<td align="right">211,790</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0035023</td>
<td align="right">420,401</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,028,340</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">144,806</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0001470</td>
<td align="right">442,735</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0004860</td>
<td align="right">5,013,351</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005743</td>
<td align="right">9,329,912</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">139,813</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0010709</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0010709</td>
<td align="right">3,028,835</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">677,164</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">416,022</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0010750</td>
<td align="right">4,819,061</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0022061</td>
<td align="right">7,729,548</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0020738</td>
<td align="right">9,423,166</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">884,842</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0006348</td>
<td align="right">249,495</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0028093</td>
<td align="right">2,058,542</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">I</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0049893</td>
<td align="right">2,326,827</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">61</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">285</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,002</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">1,334</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">22,623</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">666</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">300,735</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0008274</td>
<td align="right">82,793</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000771</td>
<td align="right">84,124</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">5,323</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0017644</td>
<td align="right">9,405</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000696</td>
<td align="right">47,473</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">1,736</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">5,707</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">4,144</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">20,786</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">35,353</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">637</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0009881</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0114174</td>
<td align="right">8,351</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0035023</td>
<td align="right">12,730</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">5,907</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">15,358</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">226</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">886</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0031963</td>
<td align="right">18,560</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_20_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_20_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0001470</td>
<td align="right">52,968</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0004860</td>
<td align="right">720,965</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005743</td>
<td align="right">972,295</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0010709</td>
<td align="right">445,724</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">17,410</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">7,613</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">125,581</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">74,534</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">6,393</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0010750</td>
<td align="right">408,754</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0022061</td>
<td align="right">740,740</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0020738</td>
<td align="right">1,013,218</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">29,915</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">209,499</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024385</td>
<td align="right">579</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0006348</td>
<td align="right">39,065</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">24,399</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0028093</td>
<td align="right">278,246</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">O</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0049893</td>
<td align="right">292,691</td>
</tr>
<tr class="even">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">T</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0114174</td>
<td align="right">290,336</td>
</tr>
<tr class="odd">
<td align="left">HALIBUT, ATLANTIC</td>
<td align="left">T</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">27,844</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,267</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,470</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,928</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,113</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,023</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">57,665</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">497,273</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,304</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">367</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">219,560</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">298,805</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">730</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">6,197</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">74,767</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">253,023</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">149,136</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">166,129</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">21,238</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">1,413</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">159,269</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">88,471</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">315,239</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0003669</td>
<td align="right">24,578</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">143,311</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">3,072</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_57_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">110,181</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">3,099,505</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_57_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">166,656</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GB_SNE_57_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">96,488</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">89,047</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,006</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,260</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">51,484</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">279,662</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,432</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,478</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">986</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">88,760</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">70,803</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">3,253</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">3,777</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">21,027</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">564</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">438,545</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">27,365</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">286,579</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">84,170</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">136,610</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">308,983</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">29,708</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">6,480</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">2,359</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">1,102</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">109,568</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">12,521</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">4,190</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">56</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">8,049</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">31,124</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,330</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,523</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">388</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">156</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">609</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">2,066</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_SM_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GB_SNE_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_SM_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">25,074</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">33,171</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">5,893</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">118,788</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">823</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">45,853</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">1,866</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">17,330</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">8,286</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">5,016</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">9,070</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">32,437</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">103,064</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_132_na_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0005911</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0005911</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">B</td>
<td align="left">GOM_54_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_54_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">5,565</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,756,663</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,018,862</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">620,494</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0007399</td>
<td align="right">2,440,121</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0015577</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0015577</td>
<td align="right">3,043,542</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0308321</td>
<td align="right">733,065</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">701,714</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0004385</td>
<td align="right">542,637</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">531,783</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0013691</td>
<td align="right">949,960</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0005955</td>
<td align="right">2,578,084</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004062</td>
<td align="right">2,962,965</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">800,672</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GB_SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0040277</td>
<td align="right">2,320,347</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,054,105</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">264,356</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">211,790</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">144,806</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0025350</td>
<td align="right">442,735</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0009213</td>
<td align="right">4,392,857</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0002566</td>
<td align="right">6,889,791</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">139,083</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,869,101</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000574</td>
<td align="right">5,155,547</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0002936</td>
<td align="right">6,460,201</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0095980</td>
<td align="right">90,226</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">1,970,071</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,707</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,144</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">20,786</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">35,353</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">637</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,619</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">71,043</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0007399</td>
<td align="right">192,791</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0015577</td>
<td align="right">446,009</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">17,410</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">10,467</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0308321</td>
<td align="right">151,229</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">131,060</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0004385</td>
<td align="right">142,271</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">101,931</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0013691</td>
<td align="right">47,078</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0005955</td>
<td align="right">165,081</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004062</td>
<td align="right">265,899</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">209,499</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">579</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0031857</td>
<td align="right">25,524</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_LM_SECTOR</td>
<td align="right">0.0040277</td>
<td align="right">293,518</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_50_SM_COMMON_POOL</td>
<td align="right">0.0004435</td>
<td align="right">396</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_54_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_54_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">727</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_54_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_54_LM_SECTOR</td>
<td align="right">0.0004435</td>
<td align="right">1,906</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_57_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">22,623</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_57_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">298,829</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GB_SNE_57_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GB_SNE_57_LM_SECTOR</td>
<td align="right">0.0029923</td>
<td align="right">82,793</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">1,334</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0039463</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">84,124</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,323</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,405</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">47,473</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">1,736</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">571</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,320</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0005245</td>
<td align="right">444</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">886</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,560</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0054185</td>
<td align="right">3,532</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">16,306</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0025350</td>
<td align="right">52,968</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0009213</td>
<td align="right">649,922</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0002566</td>
<td align="right">779,504</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">11,833</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">1,546</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">321</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0005911</td>
<td align="right">2,147</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">6,393</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">361,676</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000574</td>
<td align="right">575,659</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0002936</td>
<td align="right">747,319</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003797</td>
<td align="right">29,915</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0095980</td>
<td align="right">13,541</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005245</td>
<td align="right">24,399</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">278,246</td>
</tr>
<tr class="odd">
<td align="left">OCEAN POUT</td>
<td align="left">T</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">OCEAN POUT</td>
<td align="left">T</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0054185</td>
<td align="right">27,844</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">30,652</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">219,560</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">298,805</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">9,558</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">18,076</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">9,974</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">73,905</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">253,023</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">149,136</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">6,251</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">597,637</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">21,238</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">286,579</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">56,194</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">138,023</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">314,548</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">511,603</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">25,517</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">349,367</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">0</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">390</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">13,788</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">11,688</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">8,330</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">11,346</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">46,241</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">1,866</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">17,316</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">6,228</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">398</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">156</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">25,130</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">32,781</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">154</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">138,224</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">14</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">2,058</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">4,618</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">9,679</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">33,834</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">105,130</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">2,375</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_132_na_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">1,852</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_SM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">B</td>
<td align="left">NE_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_SM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0019917</td>
<td align="right">1,057,372</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0002076</td>
<td align="right">270,826</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0287756</td>
<td align="right">211,790</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0005025</td>
<td align="right">1,756,663</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0006671</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,028,340</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">144,806</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">442,735</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0044349</td>
<td align="right">5,002,550</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0038079</td>
<td align="right">9,440,093</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">139,813</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">12,741</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,044,106</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">733,065</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">673,093</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">701,714</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">586,348</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">531,783</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0012864</td>
<td align="right">4,647,774</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005735</td>
<td align="right">10,577,851</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0008331</td>
<td align="right">9,294,874</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">1,293,679</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0002208</td>
<td align="right">249,495</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000379</td>
<td align="right">1,890,751</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">I</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000943</td>
<td align="right">2,326,827</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">3,968</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,334</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0869234</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0018948</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0019917</td>
<td align="right">84,124</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">5,323</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0002076</td>
<td align="right">9,405</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0287756</td>
<td align="right">47,473</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">1,736</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">5,707</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">4,144</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">20,786</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0005025</td>
<td align="right">35,353</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">637</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">571</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">11,320</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0104067</td>
<td align="right">2,619</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0003679</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0006671</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">5,907</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">15,358</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">226</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">886</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0005363</td>
<td align="right">18,560</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,532</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">16,306</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">52,968</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0044349</td>
<td align="right">743,588</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0038079</td>
<td align="right">972,295</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">11,833</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">1,546</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">321</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">446,736</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">17,410</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">10,467</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">151,229</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">78,893</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">131,060</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">140,450</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">101,931</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">6,393</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0012864</td>
<td align="right">376,846</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005735</td>
<td align="right">991,884</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0008331</td>
<td align="right">1,005,696</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">29,915</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">292,292</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014827</td>
<td align="right">579</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0002208</td>
<td align="right">39,065</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005736</td>
<td align="right">24,399</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000379</td>
<td align="right">253,169</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000943</td>
<td align="right">292,691</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">O</td>
<td align="left">NE_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_SM_COMMON_POOL</td>
<td align="right">0.0005736</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">POLLOCK</td>
<td align="left">T</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0003679</td>
<td align="right">290,336</td>
</tr>
<tr class="odd">
<td align="left">POLLOCK</td>
<td align="left">T</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">27,844</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">110,181</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">3,099,505</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">5,565</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">166,656</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_0_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">96,488</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">5,304</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">2,127</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,030</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">64,924</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,432</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">219,560</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,879</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">79,204</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,612</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">364,300</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">298,805</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14,218</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">986</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">88,760</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">70,803</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">3,253</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">9,974</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">21,027</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">73,905</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">249,764</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">141,825</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">6,251</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">604,674</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">15,823</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">27,365</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">11,288</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">286,579</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">56,194</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">138,023</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">308,983</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">344,947</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">5,521</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">3,099</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">2,359</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">1,102</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">23,853</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">245,331</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">A</td>
<td align="left">NE_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">4,190</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">118,712</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">MA_52_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_52_LM_SECTOR</td>
<td align="right">0.0000321</td>
<td align="right">6,458</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">0</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">390</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">7,266</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">11,688</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">8,330</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">11,346</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">46,241</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">1,866</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">17,316</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">6,228</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">398</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">47</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">25,130</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">68,713</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">32,781</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,705</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">154</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">138,224</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">14</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,058</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,618</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,679</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">33,834</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">105,130</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">2,375</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">B</td>
<td align="left">NE_132_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_132_na_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">1,852</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">133,789</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001670</td>
<td align="right">1,057,372</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">270,826</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0003713</td>
<td align="right">211,790</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,756,663</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,028,340</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">144,806</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000735</td>
<td align="right">442,735</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024056</td>
<td align="right">5,013,351</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014773</td>
<td align="right">9,329,912</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">139,813</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000892</td>
<td align="right">12,741</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000892</td>
<td align="right">3,028,835</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">673,093</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">677,164</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">416,022</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0015155</td>
<td align="right">4,819,061</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0040000</td>
<td align="right">7,729,548</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003661</td>
<td align="right">9,423,166</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">884,842</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005520</td>
<td align="right">249,495</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">194,935</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0001549</td>
<td align="right">2,058,542</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">I</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0021191</td>
<td align="right">2,326,827</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">61</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,259</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">285</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,002</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">MA_52_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_52_LM_SECTOR</td>
<td align="right">0.0000321</td>
<td align="right">1,433</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">1,334</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">22,623</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">666</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">300,735</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_LM_SECTOR</td>
<td align="right">0.0004433</td>
<td align="right">82,793</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_0_na_SECTOR</td>
<td align="right">0.0008200</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_10_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001670</td>
<td align="right">84,124</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">5,323</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001038</td>
<td align="right">9,405</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0003713</td>
<td align="right">47,473</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">1,736</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">5,707</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">4,144</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">20,786</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">35,353</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">637</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">571</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">11,320</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_LM_SECTOR</td>
<td align="right">0.0001828</td>
<td align="right">2,619</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_COMMON_POOL</td>
<td align="right">0.0005966</td>
<td align="right">444</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,907</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,358</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">226</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">886</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,560</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005023</td>
<td align="right">3,532</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">16,306</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000735</td>
<td align="right">52,968</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0024056</td>
<td align="right">720,965</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0014773</td>
<td align="right">972,295</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">11,833</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">1,546</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">321</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000892</td>
<td align="right">445,724</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">17,410</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">7,613</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">125,581</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">74,534</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">6,393</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0015155</td>
<td align="right">408,754</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0040000</td>
<td align="right">740,740</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0003661</td>
<td align="right">1,013,218</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">29,915</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">209,499</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0016747</td>
<td align="right">579</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005520</td>
<td align="right">39,065</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005966</td>
<td align="right">24,399</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0001549</td>
<td align="right">278,246</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">O</td>
<td align="left">NE_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0021191</td>
<td align="right">292,691</td>
</tr>
<tr class="even">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">T</td>
<td align="left">NE_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="odd">
<td align="left">REDFISH / OCEAN PERCH</td>
<td align="left">T</td>
<td align="left">NE_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">NE_50_LM_SECTOR</td>
<td align="right">0.0005023</td>
<td align="right">27,844</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,706</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,197</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,905</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">249,764</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">141,825</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_18_NA_NA_NA_NA_0_1_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,251</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">150,580</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,823</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,224</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">58,742</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,521</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,099</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">22,914</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">45,861</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GBK_50_LM_NA_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,246</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">18,376</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">110,181</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">3,095,180</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">408,837</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">5,565</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">166,656</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_0_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">96,488</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">89,047</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">1,006</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">84,071</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">5,872</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">31,928</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">31,113</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">5,023</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">57,665</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">497,273</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">27,564</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">51,484</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">280,029</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">2,127</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">6,030</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">64,924</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">1,432</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_22_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">219,560</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">6,879</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">79,204</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">10,612</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">364,300</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">280,625</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">14,218</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">986</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">88,760</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_100_XL_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">70,803</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">3,253</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">1,433</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">3,777</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">21,027</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">604,674</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">27,365</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">11,288</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">286,579</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">56,194</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">138,023</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_5_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">308,983</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_7_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">344,947</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">2,359</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_MREM_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">1,102</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">199,470</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">15,593</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">GOM_50_LM_NA_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">4,190</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">125,170</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">15,271</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">862</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,259</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,311</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">24,550</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_MREM_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,415</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">4,083</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">1,664</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">A</td>
<td align="left">MA_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,548</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">4,325</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_COMMON_POOL</td>
<td align="right">0.0004305</td>
<td align="right">170</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">348</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">1,076</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_na_COMMON_POOL</td>
<td align="right">0.0004305</td>
<td align="right">47</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_COMMON_POOL</td>
<td align="right">0.0004305</td>
<td align="right">1,397</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">5,304</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_COMMON_POOL</td>
<td align="right">0.0004305</td>
<td align="right">2,066</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_XL_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,180</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">128,811</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">9,558</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GBK_100_XL_NA_NA_NA_NA_NA_0_0_1</td>
<td align="left">GBK_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">18,076</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">0</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">390</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">7,096</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">11,688</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,982</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_3_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">10,270</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">46,241</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">3,718</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">17,316</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">6,228</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_0_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">398</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">25,130</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">68,713</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">32,781</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">8,705</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_COMMON_POOL</td>
<td align="right">0.0006016</td>
<td align="right">154</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">138,224</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">14</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_6_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">2,058</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">4,618</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_10_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">9,679</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0006016</td>
<td align="right">32,437</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0006016</td>
<td align="right">103,064</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_100_XL_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0006016</td>
<td align="right">2,375</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0067980</td>
<td align="right">43,711</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">GOM_50_LM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0067980</td>
<td align="right">939</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">MA_0_na_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">6,522</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">MA_0_na_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_na_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">109</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">30,652</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">7,127</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">B</td>
<td align="left">MA_50_SM_NA_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">704</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">12,741</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,221,532</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">599,276</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">673,093</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">677,164</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GBK_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">367,510</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,057,372</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0072652</td>
<td align="right">270,826</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0004641</td>
<td align="right">211,790</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0002808</td>
<td align="right">1,756,663</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">420,401</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,899,529</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">144,806</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0056762</td>
<td align="right">442,735</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007938</td>
<td align="right">5,008,645</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003417</td>
<td align="right">9,329,912</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">139,083</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0009127</td>
<td align="right">1,807,303</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003373</td>
<td align="right">4,819,061</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005229</td>
<td align="right">7,724,324</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007464</td>
<td align="right">9,423,166</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">884,842</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0018216</td>
<td align="right">249,495</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">194,935</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001618</td>
<td align="right">2,058,542</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0070788</td>
<td align="right">2,268,085</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">133,789</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">170,326</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">I</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">381,203</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">15</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_0_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">8,866</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_100_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_100_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">2,619</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">150,407</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">7,613</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">78,227</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_18_PARTIAL EM 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">78,893</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0004305</td>
<td align="right">125,581</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">54,421</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">10,053</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,095</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GBK_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GBK_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">20,676</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">1,334</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">22,623</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">666</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">300,720</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_0_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_LM_SECTOR</td>
<td align="right">0.0005480</td>
<td align="right">73,927</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_0_na_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_0_na_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">1,517</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_10_na_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_10_na_SECTOR</td>
<td align="right">0.0449412</td>
<td align="right">575</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">84,124</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_10_PARTIAL EM 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">5,323</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0072652</td>
<td align="right">9,405</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0004641</td>
<td align="right">47,473</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_COMMON_POOL</td>
<td align="right">0.0006016</td>
<td align="right">1,736</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">5,707</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">4,144</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">20,786</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0002808</td>
<td align="right">35,353</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">637</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">571</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_LM_SECTOR</td>
<td align="right">0.0005974</td>
<td align="right">11,320</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">8,351</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">12,730</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_COMMON_POOL</td>
<td align="right">0.0006016</td>
<td align="right">444</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_3_AUDIT MODEL 2019_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">5,907</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">575</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_3_CFF GILLNET RENEWAL_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">15,358</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_3_NA_NA_NA_NA_0_0_1</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">159,859</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_5_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">226</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">886</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_100_XL_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000551</td>
<td align="right">18,560</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0027876</td>
<td align="right">3,532</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_10_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">16,306</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_11_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0056762</td>
<td align="right">52,968</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007938</td>
<td align="right">720,965</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003417</td>
<td align="right">972,295</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_12_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">11,833</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">1,546</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_15_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">321</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0009127</td>
<td align="right">295,317</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_16_NA_NA_NA_NA_0_1_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">17,410</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_COMMON_POOL</td>
<td align="right">0.0067980</td>
<td align="right">2,147</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">6,393</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_20_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0003373</td>
<td align="right">408,754</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0005229</td>
<td align="right">740,740</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0007464</td>
<td align="right">1,013,218</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_NA_NA_NA_NA_1_1_1</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">29,915</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_22_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">188,404</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_3_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0010147</td>
<td align="right">579</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_5_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0018216</td>
<td align="right">39,065</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_AUDIT MODEL 2019_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0006016</td>
<td align="right">24,399</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_6_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0001618</td>
<td align="right">278,246</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">GOM_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0070788</td>
<td align="right">272,015</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_0_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">61</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_0_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_0_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">16,692</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_100_XL_12_NA_NA_NA_NA_0_0_1</td>
<td align="left">MA_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">21,783</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_16_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">285</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_AUDIT MODEL 2019_STUDY FLEET 2019_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">2,854</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">73,002</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_18_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">5,479</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000000</td>
<td align="right">69,884</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_2_STUDY FLEET 2019_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">91,878</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_LM_9_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_LM_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">827</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">O</td>
<td align="left">MA_50_SM_2_NA_NA_NA_NA_0_0_0</td>
<td align="left">MA_50_SM_COMMON_POOL</td>
<td align="right">0.0000321</td>
<td align="right">396</td>
</tr>
<tr class="odd">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">T</td>
<td align="left">GOM_100_XL_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_100_XL_SECTOR</td>
<td align="right">0.0000000</td>
<td align="right">290,336</td>
</tr>
<tr class="even">
<td align="left">WOLFFISH / OCEAN CATFISH</td>
<td align="left">T</td>
<td align="left">GOM_50_LM_10_NA_NA_NA_NA_0_0_0</td>
<td align="left">GOM_50_LM_SECTOR</td>
<td align="right">0.0027876</td>
<td align="right">27,844</td>
</tr>
</tbody>
</table>

### Issues

### To-do

1.  complete code for non-groundifsh trips in groundfish module.
    -   combine with previous work (or not) so we have a full set of trips for each groundfish stock
    -   Scallop Trips: Dan C. does this separately from other trips. Stratifies GF discard rates by - Gear (Trawl/Dredge) - Fleet (LA/LAGC) - does NOT stratify by Access Area/Open; only by stock area - Yellowtail and Windowpane stocks are derived from scallop in season QM procedure
2.  Apply discard rates to State trips
3.  Incorporate EM (including MREM) records is using those values for discard amounts. This shoudl be a matter of substitution on a trip by trip basis. This may yield another `DISCARD_SOURCE` (e.g. (EM)?)

#### OCEAN POUT example

Difference in stratification

``` sql
-- number of gear groups for Ocean Pout
select distinct(CAMS_GEAR_GROUP)
from APSD.CAMS_GEARCODE_STRATA
where NESPP3 = 250
```

| CAMS\_GEAR\_GROUP | Gear Type               |
|:------------------|:------------------------|
| 0                 | other                   |
| 100               | Gillnet                 |
| 132               | scallop dredge          |
| 50                | Trawls                  |
| 54                | Ruhle Trawl             |
| 57                | Haddock Separator Trawl |

Dan Caless's summary has nine gear groupings:

Gillnet Longline and other line gear Otter trawl Pot, lobster Pair trawl Purse seine Pot and traps Twin trawl Other

## Feb 1, 2022

-   Multiple LINK1 on a single VTR are sneaking through our fix using only observed hauls. The species found on these trips, for the entire 2018-2020 dataset in groundfish tips are : \] "660" "667" "679" "680" "681" "682" "683" "685" "687" "689" NA which correspond to debris unknown fish groups, random invertebrates etc. see following:

``` sql
select *
from obdbs.obspec@NOVA
where substr(NESPP4,1,3) in (660
  , 667
  , 679
  , 680
  , 681
  , 682
  , 683
  , 685
  , 687
  , 689)
```

There are no `SPECIES ITIS` codes for these `NESPP3` codes and are most likely not ever estimated.

Solution : this has been fixed at the SPECIES\_ITIS level

## Feb 3, 2022

-   TRIPEXT should be only C and X.. DMIS discards are calculated from a table provided by the observer program; and they only use these trip designations.
-   Examined Dan Caless's discard script `Discard_Calculations_21_Mults.sql` this is 1500 lines of nested tables and exceptions..
-   should re-evaluate whether a new groundfish module is necessary or whether porting the SQL to CAMS is a better option.
-   the final discard rate table is not a bad template for an output table.

## Feb 4, 2022

-   Removing TRIP\_EXT != C or X removes 30,000 of ~80,000 link1 for the entire OBS matching table.

-   This should be done in the `MERGE_CAMS_OBS.sql` stage

#### Comparison of results for Haddock 2019

-   discard rates for EGB Haddock were ~ 4x lower using CAMS approach than DMIS approach.

-   There were ~12 strata in DMIS that did not show up in CAMS as being in season (&gt;=5 trips in the strata). These all fell into the `Trawl LM` category.

-   After controlling other aspects, this is likely due to the `CAMS_GEAR_GROUP` and `MESHGROUP` used in CAMS.

-   There is a possibility that CAMS trips are not matching to OBS trips on multi-VTR trips due to one element (e.g. AREA) not matching. This is less likely however than the previous point.

``` sql
select distinct(discard_rate)
--,disc_rate_type
, sector_id
, secgearfish
, mesh_cat
from fso.t_observer_discard_rate_priv
where fishing_year = 2019
and STOCK_ID = 'HADGBE'
and disc_rate_type = 'I'
```

| DISCARD\_RATE | SECTOR\_ID | SECGEARFISH | MESH\_CAT |
|---------------|------------|-------------|-----------|
| 0.019379591   | 16         | OTB         | LM        |
| 0.019379591   | 16         | OTF         | LM        |
| 0.036318597   | 22         | OTF         | LM        |
| 0.019379591   | 16         | OTC         | LM        |
| 0.076209491   | 22         | OTB         | LM        |
| 0.076209491   | 22         | OTF         | LM        |
| 0.019379591   | 16         | OTH         | LM        |
| 0.036318597   | 22         | OTC         | LM        |
| 0.076209491   | 22         | OTC         | LM        |
| 0.036318597   | 22         | OTH         | LM        |
| 0.036318597   | 22         | OTB         | LM        |
| 0.076209491   | 22         | OTH         | LM        |

Table of DMIS discards for HADGBE 2019 strata not in CAMS

``` sql
select distinct(discard_rate)
,disc_rate_type
from fso.t_observer_discard_rate_priv
where fishing_year = 2019
and STOCK_ID = 'HADGBE'
and disc_rate_type <> 'I'
```

| DISCARD\_RATE | DISC\_RATE\_TYPE |
|---------------|------------------|
| 0.046521148   | A                |
| 0             | A                |
| 0.057787552   | A                |
| 0.034521631   | A                |
| 0.035437883   | T                |
| 0.021208026   | T                |
| 0.032564803   | T                |
| 0.044642809   | T                |
| 0.040299341   | T                |
| 0.033404436   | T                |
| 0.024165142   | T                |

unique rates, either Assumed (A) or Transition (T) from DMIS. Different combinations of gear and mesh may share rates; this is all unique values.

| SECTOR\_TYPE | DISCARD\_SOURCE | CAMS\_GEAR\_GROUP | MESHGROUP |      drate|
|:-------------|:----------------|:------------------|:----------|----------:|
| COMMON\_POOL | A               | 50                | LM        |  0.0000000|
| COMMON\_POOL | B               | 0                 | na        |  0.0003783|
| COMMON\_POOL | B               | 10                | na        |  0.0005245|
| COMMON\_POOL | B               | 100               | LM        |  0.0027069|
| COMMON\_POOL | B               | 100               | XL        |  0.0000105|
| COMMON\_POOL | B               | 50                | LM        |  0.0006650|
| COMMON\_POOL | B               | 50                | SM        |  0.0000000|
| SECTOR       | A               | 100               | LM        |  0.0006698|
| SECTOR       | A               | 100               | XL        |  0.0000776|
| SECTOR       | A               | 50                | LM        |  0.0066887|
| SECTOR       | A               | 57                | LM        |  0.0301717|
| SECTOR       | AT              | 0                 | na        |  0.0005245|
| SECTOR       | AT              | 10                | na        |  0.0203849|
| SECTOR       | B               | 0                 | na        |  0.0005402|
| SECTOR       | B               | 10                | na        |  0.0004913|
| SECTOR       | B               | 100               | LM        |  0.0032755|
| SECTOR       | B               | 100               | XL        |  0.0006957|
| SECTOR       | B               | 132               | na        |  0.0005245|
| SECTOR       | B               | 57                | LM        |  0.0301705|

CAMS Assumed (A, AT) and Broad Stock (B) discard rates for EGB Haddock 2019. Generally, these are much lower than the Assumed rates in DMIS.

``` r
# Get totals by Stock for Haddock 2019

joined_table = joined_table %>%
    mutate(DISCARD = case_when(!is.na(LINK1) ~ DISC_MORT_RATIO*OBS_DISCARD
                                                         , is.na(LINK1) ~ DISC_MORT_RATIO*COAL_RATE*LIVE_POUNDS)
                 )

joined_table %>%
    group_by(SPECIES_STOCK, DISCARD_SOURCE) %>%
    dplyr::summarise(DISCARD_EST = sum(DISCARD)) %>%
    pivot_wider(names_from = 'SPECIES_STOCK', values_from = 'DISCARD_EST') %>%
    dplyr::select(-1) %>%
    colSums(na.rm = T)
```

| SPECIES\_STOCK |  Discard|
|:---------------|--------:|
| EGB            |   25,841|
| GOM            |  150,784|
| MA             |     0.00|
| WGB and South  |  309,689|

CAMS discard estimate for Haddock 2019

| STOCK  | SPECIES | DISCARD ESTIMATE |
|--------|---------|------------------|
| HADGBE | HADDOCK | 107,176          |
| HADGBW | HADDOCK | 384,367          |
| HADGM  | HADDOCK | 202,985          |

DMIS estimate for Haddock 2019

-   EGB shows the highest % difference (~75%) while the others show ~25% difference.
-
