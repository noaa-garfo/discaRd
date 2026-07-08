#' Reduce the ddat_focal dataframe for inputting into discards to one row per species-subtrip-link1
#' @author Daniel J. Hocking
#' @author Benjamin Galuardi
#'
#' @param data dataframe to summarise
#' @param itis_tsn focal species itis code (numeric or character)
#'
#' @return ddat_focal dataframe collapsed to one row per group with summed discards
#' @export
summarise_single_discard_row <- function(data, itis_tsn) {
  # summarise_test <- function(data, itis_tsn) {

  # 1. Isolate the discard values for the target species
  ddat_focal_summary <- data |>
    dplyr::filter(!is.na(LINK1)) |>
    mutate(
      SPECIES_EVAL_DISCARD = case_when(
        SPECIES_ITIS == itis_tsn ~ DISCARD,
        TRUE ~ 0.0
      )
    )

  # 2. Group STRICTLY by trip/subtrip identifiers to calculate totals
  species_subtrip_link1_totals <- ddat_focal_summary |>
    group_by(LINK1, CAMSID, SUBTRIP) |>  # <-- Removed ITIS_TSN
    dplyr::summarise(
      DISCARD = sum(SPECIES_EVAL_DISCARD, na.rm = TRUE),
      DISCARD_PRORATE = sum(DISCARD_PRORATE, na.rm = TRUE),
      OBS_DISCARD = sum(OBS_DISCARD, na.rm = TRUE),
      .groups = 'drop'
    )

  # 3. Collapse to exactly one row per trip/subtrip and join totals
  ddat_focal_summary <- ddat_focal_summary |>
    group_by(LINK1, CAMSID, SUBTRIP) |>  # <-- Removed ITIS_TSN
    arrange(desc(DISCARD)) |>
    slice(1) |>
    ungroup() |>
    dplyr::select(
      -DISCARD,
      -DISCARD_PRORATE,
      -OBS_DISCARD,
      -SPECIES_EVAL_DISCARD
    ) |>
    left_join(
      species_subtrip_link1_totals,
      by = c("CAMSID", "SUBTRIP", "LINK1")  # <-- Removed ITIS_TSN
    ) |>
    # 4. Explicitly stamp the row with the focal species code
    mutate(
      ITIS_TSN = itis_tsn
    )

  return(ddat_focal_summary)
}
