# discaRd

## an R package for calculating discard sing the Cochran ratio estimator

This package was developed as part of the GARFO discard peer review in 2016. More information on the review may be found here: https://www.fisheries.noaa.gov/new-england-mid-atlantic/science-data/discard-methodology 

## Install
`remotes` is the small part of `devtools` for loading remote data so either work

```
library(remotes)
install_github("NOAA-Fisheries-Greater-Atlantic-Region/discaRd")
```

## Use

The `discaRd` package does not set the stratifications. The functions take the stratifications as an input argument from the user.

To see an example vignette:

```
library(discaRd)
vignette("eflalo_demo")
```

One of the main functions is `get.cochran.ss.by.strat()`. To see the instructions for this run `?get.cochran.ss.by.strat` in R. (NO HELP FILE FOR THIS CURRENTLY - ADDING GITHUB ISSUE)
