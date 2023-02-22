#' Reduce the dataframe for inputting into discards to one row per species-subtrip-link1
#' @author Daniel J. Hocking
#'
#' @param dataframe
#'
#' @details Reduce the dataframe for inputting into discards to one row per species-subtrip-link1
#'
#' @return dataframe
#' @export
#'
#' @examples
summarise_single_discard_row <- function(data) {

data_summary <- data %>%
  dplyr::filter(!is.na(LINK1)) %>%
  mutate(
    SPECIES_EVAL_DISCARD = case_when(
      SPECIES_ITIS == species_itis ~ DISCARD,
      TRUE ~ 0.0
    )
  )

species_subtrip_link1_totals <- data_summary %>%
  group_by(LINK1, CAMSID, CAMS_SUBTRIP, ITIS_TSN) |>
  dplyr::summarise(
    DISCARD = sum(DISCARD, na.rm = TRUE),
    DISCARD_PRORATE = sum(DISCARD_PRORATE, na.rm = TRUE),
    OBS_DISCARD = sum(OBS_DISCARD, na.rm = TRUE),
    SPECIES_EVAL_DISCARD = sum(SPECIES_EVAL_DISCARD, na.rm = TRUE),
    .groups = 'drop'
  )

data_summary <- data_summary |>
  group_by(LINK1, CAMSID, CAMS_SUBTRIP, ITIS_TSN) |>
  arrange(desc(SPECIES_EVAL_DISCARD)) %>%
  slice(1) %>%
  ungroup() |>
  dplyr::select(
    -DISCARD,
    -DISCARD_PRORATE,
    -OBS_DISCARD,
    -SPECIES_EVAL_DISCARD
  ) |>
  left_join(
    species_subtrip_link1_totals,
    by = c("CAMS_SUBTRIP", "LINK1", "CAMSID", "ITIS_TSN")
  )

return(data_summary)
}
