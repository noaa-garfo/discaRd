#' notin
#'
#' @param x: vector to check
#' @param y: vector to serve as reference
#'
#' @return
#' @export
#'
#' @examples
#' \dontrun{
#' x <- c()
#' x %!in% y
#' }
'%!in%' <- function(x,y)!('%in%'(x,y))
