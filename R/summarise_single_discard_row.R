#' Reduce the ddat_focal dataframe for inputting into discards to one row per species-subtrip-link1
#' @author Daniel J. Hocking
#' @author Benjamin Galuardi
#'
#' @param ddat_focal dataframe to summarise
#' @param itis_tsn focal species itis code
#'
#' @details Reduce the ddat_focal dataframe for inputting into discards to one row per species-subtrip-link1
#'
#' @return ddat_focal dataframe
#' @export
#'
#' @examples
summarise_single_discard_row <- function(data, itis_tsn) {
	
	ddat_focal_summary <- data %>%
		dplyr::filter(!is.na(LINK1)) %>%
		mutate(
			SPECIES_EVAL_DISCARD = case_when(
				SPECIES_ITIS == itis_tsn ~ DISCARD,
				TRUE ~ 0.0
			)
		)
	
	species_subtrip_link1_totals <- ddat_focal_summary %>%
		group_by(LINK1, CAMSID, CAMS_SUBTRIP, ITIS_TSN) |>
		dplyr::summarise(
			DISCARD = sum(SPECIES_EVAL_DISCARD, na.rm = TRUE),
			DISCARD_PRORATE = sum(DISCARD_PRORATE, na.rm = TRUE),
			OBS_DISCARD = sum(OBS_DISCARD, na.rm = TRUE),
			# SPECIES_EVAL_DISCARD = sum(SPECIES_EVAL_DISCARD, na.rm = TRUE),
			.groups = 'drop'
		)
	
	ddat_focal_summary <- ddat_focal_summary |>
		group_by(LINK1, CAMSID, CAMS_SUBTRIP, ITIS_TSN) |>
		arrange(desc(DISCARD)) %>%
		slice(1) %>%
		ungroup() |>
		dplyr::select(
			-DISCARD,
			-DISCARD_PRORATE,
			-OBS_DISCARD
			, -SPECIES_EVAL_DISCARD
		) |>
		left_join(
			species_subtrip_link1_totals,
			by = c("CAMS_SUBTRIP", "LINK1", "CAMSID", "ITIS_TSN")
		)
	
	return(ddat_focal_summary)
}
