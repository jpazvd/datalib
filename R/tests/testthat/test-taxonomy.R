test_that("survey id and version names", {
  expect_equal(dl_survey_id("bra", 2019, "mics"), "BRA_2019_MICS")
  expect_equal(dl_version_name("BRA", 2023, "SAEB"), "BRA_2023_SAEB_v01_M")
  expect_equal(dl_version_name("BRA", 2023, "SAEB", collection = "gmd"),
               "BRA_2023_SAEB_v01_M_v01_A_GMD")
})

test_that("parse id", {
  info <- dl_parse_id("BRA_2023_SAEB_v01_M_v01_A_GMD")
  expect_true(info$harmonized)
  expect_equal(info$clct, "GMD")
  expect_equal(dl_parse_id("BRA_2023_SAEB_v01_M")$kind, "master")
  expect_null(dl_parse_id("nope"))
})
