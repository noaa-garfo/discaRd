
#' Alt version get_covrow.R
#'
#' @param joined_table
#'
#' @return
#' @export
#'
#' @examples
get_covrow_bg <- function(joined_table){

	options(dplyr.summarise.inform = FALSE)

	# Go through each STRATA_USED and split out the columns used
  sidx = joined_table %>%
    filter(!(DISCARD_SOURCE %in% c('O', 'R', 'N'))) %>%
    dplyr::select(STRATA_USED, DISCARD_SOURCE) %>%
    distinct()


	# Use the individual columns to group and tally N

	for(iloop in 1:nrow(sidx)){
		# print(iloop)
		svars = str_split(sidx$STRATA_USED[iloop], ';')	%>% unlist()
		cidx = sapply(1:length(svars), function(x) which(colnames(joined_table) == svars[x])) %>% unlist()

		dtype = sidx$DISCARD_SOURCE[iloop]

		N_name = paste('N', dtype, sep = '_')
		n_name = paste('n', dtype, sep = '_')

		# STRATA_USED_DESC = c(joined_table[1,cidx])

		ntable = joined_table %>%
			group_by_at(vars((cidx))) %>%
			dplyr::summarize(N = n_distinct(paste(CAMSID,SUBTRIP,sep="_"))
											 , n = n_distinct(LINK1)) %>%
			dplyr::rename({{N_name}} := N
										, {{n_name}} := n)

		joined_table = joined_table %>%
			left_join(., ntable, by = svars )

	}

	# add columns so case_when doesn't crash

	cols <- c(N_I = NA_integer_
						, N_GM = NA_integer_
						, N_G = NA_integer_
						, N_B = NA_integer_
						, N_A = NA_integer_
						, N_DELTA = NA_integer_
						, N_EM = NA_integer_
						, n_I = NA_integer_
						, n_GM = NA_integer_
						, n_G = NA_integer_
						, n_B =  NA_integer_
						, n_A = NA_integer_
						, n_DELTA = NA_integer_
						, n_EM = NA_integer_
	)

	joined_table = tibble::add_column(joined_table, !!!cols[setdiff(names(cols), names(joined_table))])

	# join back to original table using STRATA_USED or DISCARD SOURCE

	joined_table = joined_table %>%
		mutate(N_USED = dplyr::case_when(DISCARD_SOURCE == 'I' ~ N_I
																		 , DISCARD_SOURCE == 'T' ~ N_I
																		 , DISCARD_SOURCE == 'GM' ~ N_GM
																		 , DISCARD_SOURCE == 'G' ~ N_G
																		 , DISCARD_SOURCE == 'B' ~ N_B
																		 , DISCARD_SOURCE == 'A' ~ N_A
																		 , DISCARD_SOURCE == 'DELTA' ~ NA_integer_
																		 , DISCARD_SOURCE == 'EM' ~ NA_integer_
																		 , DISCARD_SOURCE == 'R' ~ NA_integer_
																		 , TRUE ~ NA_integer_
		)
		, n_USED = dplyr::case_when(DISCARD_SOURCE == 'I' ~ n_I
																, DISCARD_SOURCE == 'T' ~ n_I
																, DISCARD_SOURCE == 'GM' ~ n_GM
																, DISCARD_SOURCE == 'G' ~ n_G
																, DISCARD_SOURCE == 'B' ~ n_B
																, DISCARD_SOURCE == 'A' ~ n_A
																, DISCARD_SOURCE == 'DELTA' ~ NA_integer_ # n_DELTA
																, DISCARD_SOURCE == 'EM' ~ NA_integer_
																, DISCARD_SOURCE == 'R' ~ NA_integer_
																, TRUE ~ NA_integer_
		) #n_EM
		)


	# add Legaults covrow ----
	rule_based_tab = joined_table %>%
		filter(DISCARD_SOURCE == 'R')

	est_table = joined_table %>%
		filter(DISCARD_SOURCE != 'R')

	# cov_table = est_table %>%
	# 	filter(DISCARD_SOURCE != 'R') %>%
	# 	tidyr::unite(., col = 'STRATA_USED_DESC', unlist(strsplit(est_table$STRATA_USED, ';')), remove = F, sep = ';')

	# this works. create a list of data frames
	tab_list = est_table %>%
	  group_split(DISCARD_SOURCE, GF) %>%   # group_split may be deprecated in the future..
	  lapply(., unite_by_source)

	cov_table = do.call(rbind, tab_list) %>%
	  as_tibble()


	# Legaults covrow ----
	cov_table = cov_table %>%
		mutate(var = (DISCARD * CV)^2)
	#    mutate(var = kall_pro^2 * (dk * cv)^2)

	mysdsum <- cov_table %>%
		group_by(STRATA_USED_DESC) %>%
		dplyr::summarise(sdsum = sum(sqrt(var), na.rm = T))

	cov_table <- cov_table %>%
		left_join(., mysdsum, by = 'STRATA_USED_DESC') %>%
		mutate(covrow = sqrt(var) * sdsum)

	joined_table = bind_rows(cov_table, rule_based_tab) %>% as_tibble()

	joined_table

}


