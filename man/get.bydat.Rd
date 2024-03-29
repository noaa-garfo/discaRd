% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get.bydat.r
\name{get.bydat}
\alias{get.bydat}
\title{Get Fishery data, specify bycatch species}
\usage{
get.bydat(
  fdat,
  load = T,
  bspec = 366,
  aggfact = "LINK1",
  catch_disp = c(0, 1)[1]
)
}
\arguments{
\item{fdat}{name of file to be loaded OR name of variable in workspace containing data}

\item{load}{should data be loaded into the workspace? If already loaded, specify fdat as the variable name in your workspace and flag load=F}

\item{bspec}{bycatch species desired}

\item{aggfact}{aggregation factor. for NOAA data, LINK1 usually indicates trip level. Using \code{\link{eflalo}}, 'FT_REF' is indicates trips}

\item{catch_disp}{catch disposition of the bycatch (0 = discard, 1 = kept).  Default is 0.}
}
\value{
dataframe of observed catch summed by some aggregating factor (\code{aggfact})
 for the bycatch species of interest (\code{bspec}) and the total catch
}
\description{
Function to make dataframe according to bycatch species, fishery etc..
}
\details{
The catch disposition is typically 0 for discards, but some fisheries (herring) may want both.
}
\examples{
data(eflalo)
dm = make.obs.flag.dat(eflalo, obs_level = .1)
dmo = dm[dm$OBSFLAG==1&dm$FY==1800,]  # one year of data
# Define a bycatch species
bspec = 'LE_KG_BSS' # European seabass (FAO code BSS)
bdat = get.bydat(dmo, aggfact = 'DOCID',load = F, bspec = bspec, catch_disp = 1) # unstratified
}
