# Notes on groundfish comparisons
### Ben Galuardi
### January 25, 2022

**APSD.CAMS_DISCARD_EXAMPLE_GF19**

#### OCEAN POUT example

This example includes all trips for Fishing Year 2019 (May 2019 start). Stratification for groundfish trips was

- Stock Area
- Gear (`CAMS_GEAR_GROUP`)
- Mesh (`MESHGROUP`)
- Sector
- Exemption (there are four possible exemptions)

An assumed rate was used for non-groundfish trips

- Stock Area
- Gear (`CAMS_GEAR_GROUP`)

### Issues
according to 2020 ACL accounting, this should include

- Mesh ('MESHGROUP') ADDED

Sector and Exemptions are carrying through to non-groundfish trips. This is affecting which rate is being used. (see below, need to split these out)

- Non-groundfish trips should not include these stratifications.

- Estimates of yellowtail and windowpane from scallop trips need to come from scallop specific stratification.


### Snoops..

Difference in stratification

``` sql
-- number of gear groups for Ocean Pout
select distinct(CAMS_GEAR_GROUP)
from APSD.CAMS_GEARCODE_STRATA
where NESPP3 = 250

```
| CAMS_GEAR_GROUP | Gear Type
| :---  | :---
| 0 | other
| 100 | Gillnet
| 132 | scallop dredge
| 50 | Trawls
| 54 | Ruhle Trawl
| 57 | Haddock Separator Trawl

Dan Caless's summary has nine gear groupings:

Gillnet
Longline and other line gear
Otter trawl
Pot, lobster
Pair trawl
Purse seine
Pot and traps
Twin trawl
Other

#### Scallop Trips:

Dan C. does this separately. Stratifies GF discard rates by
- Gear (Trawl/Dredge)
- Fleet (LA/LAGC)
- does NOT stratify by Access Area/Open; only by stock area
- Yellowtail and Windowpane stocks are derived from scallop in season QM procedure

In summary, QM groundfish gets year-end estiamtes in three steps:
- GF Trips (`Sector/Gear/Mesh/Exemption`)
- Scallop trips (`Gear/Fleet`)
  - YTF and WP on scallop trips done in scallop procedure(module) (`Gear/Fleet/AA vs Open`)
- All other Trips (`Gear group/Mesh`)


``` sql
-- look at CV by strata
select distinct(STRATA_ASSUMED)
, STRATA
, DISC_RATE
, ARATE
, CRATE
, CV
, n_obs_trips
, a.CAMS_GEAR_GROUP
, MESHGROUP
, SPECIES_ITIS_EVAL
from APSD.CAMS_DISCARD_EXAMPLE_GF19 a
where activity_code_1 not like 'NMS%'
order by a.CAMS_GEAR_GROUP, MESHGROUP

```

from Dan Caless:
`DISC_RATE_TYPE of 'I' stands for in-season rate, wholly based on at least five in-season observed trips. Type = 'T' is Transition, based partially on the assumed rate and partially based on between one and four in-season trips, and 'A' are assumed rates based primarily on last year's discard rates.`


*Q: Is (A) specific to strata or does it default to broad stock rate?*

from dan C.:
1. They equal last FY in-season if they exist
2. else they group across sectors, but keep the other strata
3. else they group across all strata by stock

`I keep them if they have five or more trips`

Dan splits groundfish and non-groundfish trips and stratifies separately.

Example:

``` sql
-- pull one strata for ocean POUT

with pout as (
   select SPPCODE
  , SECGEARFISH
  , MESH_CAT
  , SECTOR_ID
  , OTHER_STRATA, DISCARD_RATE
  , DISC_RATE_TYPE
  from fso.T_OBSERVER_DISCARD_RATE
  where fishing_year = 2019
  and nespp3 = 250
  and STOCK_ID = 'OPTGMMA'
  and SECTOR_ID = 10
  and MESH_CAT = 'ELM'
)

select distinct(SECGEARFISH)
  , MESH_CAT
  , OTHER_STRATA
  , DISCARD_RATE
  , DISC_RATE_TYPE
  from pout
  order by SECGEARFISH, MESH_CAT
```

- `discaRd` shows 77 trips observed for strata `Sector 10, XL mesh, Gillnet`

Caless has this sector using an assumed rate, meaning there would not be many (or any) obs trips

*There was a problem with SECTOR_ID in MAPS matchign tables. This has been fixed*

## Feb 1, 2022
- Multiple LINK1 on a single VTR are sneaking through our fix using only observed hauls. THe species foudn on these trips, for the entire 2018-2020 dataset in groundfish tips are : ] "660" "667" "679" "680" "681" "682" "683" "685" "687" "689" NA which correspond to debris unknown fish groups, random invertebrates etc. see following:

```sql
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

Solution may be to filter these rows from the master table (`CAMS_OBS_CATCH`) upon import to `R`. Filtering these will not affect `KEPT ALL` since these are all from trips that (erroneously) have multiple `LINK1` per `VTR`.

## Feb 2, 2022

- found that there are Strata where all trips report 0 `OBS_KALL` and 0 OBS_DISCARD.. This creates NaN in `DISC_EST`, `DRATE` and NA in `CV`

![table illustrating effect of 0 OBS_KALL ](drate_nan.jpg)

![zeros in OBS_KALL](zero_obs_kall.jpg)

**Options**
1. alter the R functions in the `discaRd` package
```r
get.cochran.ss.by.strat
cochran.calc.ss
```
2. Use trip KALL for d/k calculation
3. Ignore these trips. This depends on whether the discard species info can be trusted given the `OBS_KALL` is incorrect.

- May need to change the trip reference in the R functions above. Now, it is `DOCID`. May need to make this generic and use `VTRSERNO`.. This could affect the CV as using DOCID makes the `N` term smaller than if using `VTRSERNO`

- Identified that base table `CAMS_OBS_CATCH` may have been built incorrectly. Never completed the multi-layered join in the case with multiple subtrips per LINK1.

- There may be an issue with the MAPS.MATCH_OBS table. Observed trips for the strata referenced above do can't be found in the OBS data. The LINK1 doe not match and the VTRSERNO do not match anything in MAPS.MATCH_OBS

- found that `TRIPEXT in (C, X)` filtered out records with `L`, which accounts for the mismatch in the above strata.

```sql
-- example shows that there are hailwts on obs hauls
select *
FROM obdbs.obtrp@nova a
left join (select * from obdbs.obhau@nova) b
on a.LINK1 = b.LINK1
left join (select * from obdbs.obspp@nova) s
on b.LINK3 = s.LINK3
where a.link1 = '000201910R33047'
```

revisit against this table:
```sql
select *
from obdbs.obtripext@nova
```

## Feb 3, 2022

- TRIPEXT should be only C and X.. DMIS discards are calculated from a table provided by the observer program; and they only use these trip designations.
- Examined Dan Calles's discard script `Discard_Calculations_21_Mults.sql` this is 1500 lines of nested tables and exceptions.. 
- should re-evaluate whether a new groundfish module is necessary or whether porting the SQL to CAMS is a better option.
- the final discard rate table is not a bad template for an output table.
