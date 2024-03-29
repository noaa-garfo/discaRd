% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/make.obs.flag.dat.r
\name{make.obs.flag.dat}
\alias{make.obs.flag.dat}
\title{Modify eflalo for Cochran estimation}
\usage{
make.obs.flag.dat(dat, obs_level = 0.1)
}
\arguments{
\item{dat}{the \code{\link{eflalo}} dataset. Other datasets for this function should have simialr column names.}

\item{obs_level}{proportion of trips observed (observer coverage)}
}
\value{
a 'melted' dataframe of trip data where species is a single column
}
\description{
Modifies the eflalo dataset for Cochran ratio estimator. Adds a OBSFLAG field inicating if the trip was observed. This can be set as a percentage of total trips
}
\examples{
#' data(eflalo)
dm = make.obs.flag.dat(eflalo, obs_level = .1)
data(eflalo)
dm = make.obs.flag.dat(eflalo, obs_level = .1)
}
\references{
Niels Hintzen, Francois Bastardie and Doug Beare (2014). vmstools: For analysing fisheries VMS (Vessel Monitoring System) data. R package version 0.72. http://CRAN.R-project.org/package=vmstools
}
