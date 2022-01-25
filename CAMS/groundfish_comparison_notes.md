# Notes on groundfish comparisons
### Ben Galuardi
### January 25, 2022

**APSD.CAMS_DISCARD_EXAMPLE_GF19**

#### OCEAN POUT example

This example includes all trips for Fishing Year 2019 (May 2019 start). Stratification for groundfish trips was

- Stock Area
- Gear (`CAMS_GEAR_GROUP`)
- Mesh ('MESHGROUP')
- Sector
- Exemption (there are four possible exemptions)

An assumed rate was used for non-groundfish trips

- Stock Area
- Gear (`CAMS_GEAR_GROUP`)

### Issues
according to 2020 ACL accounting, this should include

- Mesh ('MESHGROUP')

Sector and Exemptions are carrying through to non-groundfish trips. This is affecting which rate is being used.
- Non-groundfish trips should not include these stratifications.

Estimates of yellowtail and windowpane from scallop trips need to come from scallop specific stratification.


### Snoops..

Difference in stratification for

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

Dan Caless's sumamry has nine gear groupings:

Gillnet
Longline and other line gear
Otter trawl
Pot, lobster
Pair trawl
Purse seine
Pot and traps
Twin trawl
Other

**no scallop dredge present..**


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


Is (A) specific to strata or does it default to broad stock rate?

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

`discaRd` shows 77 trips observed for strata `Sector 10, XL mesh, Gillnet`
Caless has this sector using an assumed rate, meaning there would not be many (or any) obs trips
