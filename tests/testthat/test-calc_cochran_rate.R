test_that("calc_cochran_rate calculates ratio and variance correctly", {

  # Data setup: 2 trips
  # Trip 1: 5 discard, 100 kept
  # Trip 2: 15 discard, 100 kept
  # Total: 20 discard, 200 kept -> Ratio should be 0.1
  df_small <- data.frame(
    LINK1 = c("T1", "T2"),
    BYCATCH = c(5, 15),
    KALL = c(100, 100)
  )

  n_obs <- 2
  n_trips <- 100 # Population size

  res <- calc_cochran_rate(df_small, n_trips = n_trips, n_obs = n_obs)

  # 1. Test Mean Rate (r)
  expect_equal(res$RE_mean, 0.1)

  # 2. Test Variance manually
  # With equal KALL, Cochran reduces to simple random sampling variance logic
  # but let's check the function's internal math:
  # r = 0.1
  # Trip 1: DSQ=25, KSQ=10000, RSQKSQ=100, R2DK=100 -> term = 25
  # Trip 2: DSQ=225, KSQ=10000, RSQKSQ=100, R2DK=300 -> term = 25
  # Sum terms = 50. Var_term = 50/(2-1) = 50.
  # N_term = (100-2)/(100*2) = 0.49
  # K_term = 1 / (100^2) = 0.0001
  # RE_var = 0.49 * 0.0001 * 50 = 0.00245

  expect_equal(res$RE_var, 0.00245)
  expect_equal(res$RE_se, sqrt(0.00245))
})

test_that("calc_cochran_rate calculates required sample size when CV_targ is provided", {

  df_test <- data.frame(
    LINK1 = c("T1", "T2", "T3"),
    BYCATCH = c(10, 20, 30),
    KALL = c(100, 200, 300)
  )

  # If CV_targ is provided, REQ_SAMPLES should not be NA
  res <- calc_cochran_rate(df_test, n_trips = 1000, n_obs = 3, CV_targ = 0.3)

  expect_false(is.na(res$REQ_SAMPLES))
  expect_gt(res$REQ_SAMPLES, 0)
  expect_equal(res$CV_TARG, 0.3)
})

test_that("calc_cochran_rate returns zero variance for census (n = N)", {

  df_census <- data.frame(
    LINK1 = c("T1", "T2"),
    BYCATCH = c(10, 50),
    KALL = c(100, 200)
  )

  # n_trips equals n_obs (2)
  res <- calc_cochran_rate(df_census, n_trips = 2, n_obs = 2)

  # If we sampled the whole population, uncertainty should be zero
  expect_equal(res$RE_var, 0)
  expect_equal(res$RE_se, 0)
  expect_equal(res$RE_rse, 0)
})
