test_that("calc_cochran_rate_strata handles stratification and aggregation correctly", {

  # --- Setup Data ---
  # Strata A: Large population, high discard
  # Strata B: Small population, low discard

  trips_df <- data.frame(
    CAMSID = c(paste0("A", 1:100), paste0("B", 1:20)),
    LIVE_POUNDS = c(rep(100, 100), rep(100, 20)),
    MY_STRATA = c(rep("A", 100), rep("B", 20))
  )

  obs_df <- data.frame(
    LINK1 = c("L1", "L2", "L3", "L4"),
    CAMSID = c("A1", "A2", "B1", "B2"),
    SUBTRIP = 1,
    # Strata A: 10% discard rate (10/100)
    # Strata B: 50% discard rate (50/100)
    BYCATCH = c(10, 10, 50, 50),
    KALL = c(100, 100, 100, 100),
    MY_STRATA = c("A", "A", "B", "B")
  )

  # --- Run Function ---
  res <- calc_cochran_rate_strata(
    bydat = obs_df,
    trips = trips_df,
    targCV = 0.3,
    strata_name = "MY_STRATA",
    strata_complete = c("A", "B")
  )

  # --- Tests ---

  # 1. Check if Strata renaming worked (Inputs named 'MY_STRATA' -> Output 'STRATA')
  expect_true("STRATA" %in% names(res$C))
  expect_equal(sort(unique(res$C$STRATA)), c("A", "B"))

  # 2. Check Discard Estimates (C$D)
  # Strata A: rate 0.1 * Total K (100 * 100 = 10000) = 1000
  # Strata B: rate 0.5 * Total K (20 * 100 = 2000) = 1000
  expect_equal(res$C$D[res$C$STRATA == "A"], 1000)
  expect_equal(res$C$D[res$C$STRATA == "B"], 1000)

  # 3. Check Population Totals (C$N)
  expect_equal(res$C$N[res$C$STRATA == "A"], 100)
  expect_equal(res$C$N[res$C$STRATA == "B"], 20)

  # 4. Check Total CV (CVTOT)
  # Ensure it calculates a numeric value
  expect_true(is.numeric(res$CVTOT))
  expect_false(is.na(res$CVTOT))
})

test_that("calc_cochran_rate_strata handles unobserved strata correctly", {

  # Trips exist for "A" and "Ghost", but we only observe "A"
  trips_df <- data.frame(
    CAMSID = c("A1", "G1"),
    LIVE_POUNDS = c(100, 100),
    STRATA = c("A", "Ghost")
  )

  obs_df <- data.frame(
    LINK1 = "L1", CAMSID = "A1", SUBTRIP = 1,
    BYCATCH = 10, KALL = 100, STRATA = "A"
  )

  res <- calc_cochran_rate_strata(
    bydat = obs_df,
    trips = trips_df,
    strata_name = "STRATA",
    strata_complete = c("A", "Ghost")
  )

  # The function should return a row for 'Ghost' even if not in observer data
  ghost_row <- res$C[res$C$STRATA == "Ghost", ]

  expect_equal(nrow(ghost_row), 1)
  expect_equal(ghost_row$n, 0) # No observed samples
  expect_equal(ghost_row$N, 1) # But 1 trip in population
})
