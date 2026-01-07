#' notin
#' the most useful function not included in base R!
#' @param x: vector to check
#' @param y: vector to serve as reference
#'
#' @return a vector where x is 'not in' y
#' @export
#'
#' @examples
#' \dontrun{
#' x <- c()
#' x %!in% y
#' }
'%!in%' <- function(x,y)!('%in%'(x,y))
