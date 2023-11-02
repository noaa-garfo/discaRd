#' Vary n (# observed trips)
#' 
#' Function to run Cochran estimator on fixed big N with a range of observed trips
#' This function can be used to see the relationship between observer coverage and CV of discard rate. This function samples from the observed trips and is essentially one iteration of a bootstrap. 
#' @param N Number of total commerical trips
#' @param bdat fishery observer data
#'
#' @return dataframe of CV values (RSE of discard rate) for range of observed trips
#' @export
#'
#' @examples
#' data(eflalo)
#' dm = make.obs.flag.dat(eflalo, obs_level = .1)
#' dmo = dm[dm$OBSFLAG==1&dm$FY==1800,] # one year of data
#' bspec = 'LE_KG_BSS' # European seabass (FAO code BSS)
#' bdat = get.bydat(dmo, aggfact = 'DOCID',load = F, bspec = bspec, catch_disp = 1) # unstratified
#' nall = ddply(bdat, c('YEAR'), function(x) varyn(x, N = 5000))
#' plot(nall[,c(3:2)], typ='l')
#' 
#' # do it 100 times (slowly..)
#' nmat = matrix(NaN, nrow = nrow(bdat), ncol = 100)
#' for(i in 1:100){
#'  nmat[,i] = vary.n(5000, bdat)[,1]
#' }
#' 
#' nq = apply(nmat, 1, quantile, probs = c(.025, .5, .975), na.rm = T)
#' matplot((1:nrow(bdat))/nrow(bdat)*100, t(nq), typ='l', lty = c(2,1,2), col = c(2,1,2), xlab = '% Observed trips', ylab = 'CV')

vary.n = function(N, bdat){
	bidx = apply(data.frame(1:nrow(bdat)), 1, function(x) sample(1:nrow(bdat), x, replace = T))
	CV = ldply(bidx, function(x) data.frame(RE_rse = cochran_rse(bdat[x,], N)$RE_rse))
	CV$n = 1:nrow(CV)
	CV
}

