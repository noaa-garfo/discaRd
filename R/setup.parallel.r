#' Setup parallel
#'
#' @return creates settings to allow parallel processing
#' @export
#'
#' @examples setup.parallel

setup.parallel <- function(n.cores=NULL){
  if(is.null(n.cores)){
    n.cores <- detectCores()
  }
	if(n.cores==1) registerDoSEQ() else registerDoParallel(cores=n.cores) # multicore functionality
	mcoptions <- list(preschedule=TRUE)
	cat(paste("\nUsing",n.cores,"cores for parallel processing."))
	mcoptions
}