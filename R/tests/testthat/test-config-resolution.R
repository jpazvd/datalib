# Golden cases for library-root resolution, mirroring the Python suite
# (python/tests/test_config_resolution.py) case for case, so the two legs can be
# compared directly. Every case pins its configuration directory, so none reads
# the operator's real ~/.config.

USER <- "tester"

write_cfg <- function(dir, name, text, bom = FALSE) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(dir, name)
  con <- file(path, open = "wb")
  if (bom) writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)
  writeBin(charToRaw(text), con)
  close(con)
  path
}

# no ambient root or config may leak into a case
clean_env <- function(expr) {
  withr::with_envvar(
    c(DATALIB_ROOT = NA, DATALIB_CONFIG = NA, DATALIB_CONFIG_DIR = NA),
    withr::with_options(list(datalib.root = NULL), expr))
}

test_that("CFG-01 an explicit argument outranks everything", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  clean_env({
    res <- datalib_root("F:/explicit", user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "argument")
  })
})

test_that("CFG-02 the environment variable outranks both files", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  clean_env(withr::with_envvar(c(DATALIB_ROOT = "F:/from_env"), {
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "env")
  }))
})

test_that("the option stage sits between env and the files (R only)", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  clean_env(withr::with_options(list(datalib.root = "F:/from_option"), {
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "option")
  }))
})

test_that("CFG-03 the generic file supplies the root", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "config_generic")
    expect_match(res$root, "from_generic")
  })
})

test_that("CFG-04 the package file supplies it when the generic one is absent", {
  d <- withr::local_tempdir()
  write_cfg(d, "datalib_config.yml", sprintf("%s:\n  datalib: F:/from_package\n", USER))
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "config_package")
  })
})

test_that("CFG-05 with both present the generic file wins; blocks never merge", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  write_cfg(d, "datalib_config.yml", sprintf("%s:\n  datalib: F:/from_package\n", USER))
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "config_generic")
    expect_match(res$root, "from_generic")
  })
})

test_that("CFG-06 key presence, not file presence, drives the fallback", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  githubFolder: C:/GitHub\n", USER))
  write_cfg(d, "datalib_config.yml", sprintf("%s:\n  datalib: F:/from_package\n", USER))
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "config_package")
  })
})

test_that("CFG-07 an empty datalib: value counts as absent", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib:\n", USER))
  write_cfg(d, "datalib_config.yml", sprintf("%s:\n  datalib: F:/from_package\n", USER))
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_equal(res$source_stage, "config_package")
  })
})

test_that("CFG-08 nothing configured is an error, not a guess", {
  d <- withr::local_tempdir()
  clean_env(expect_error(datalib_root(user = USER, configdir = d),
                         class = "datalib_error_root_unset"))
})

test_that("CFG-09 DATALIB_CONFIG pins one file and turns the fallback off", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  pkg <- write_cfg(d, "datalib_config.yml",
                   sprintf("%s:\n  datalib: F:/from_package\n", USER))
  clean_env(withr::with_envvar(c(DATALIB_CONFIG = pkg), {
    res <- datalib_root(user = USER, report = TRUE)
    expect_equal(res$source_stage, "config_package")
  }))
})

test_that("CFG-10 DATALIB_CONFIG_DIR redirects the search, fallback preserved", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/from_generic\n", USER))
  clean_env(withr::with_envvar(c(DATALIB_CONFIG_DIR = d), {
    res <- datalib_root(user = USER, report = TRUE)
    expect_equal(res$source_stage, "config_generic")
  }))
})

test_that("CFG-11 a configured-but-unreachable root is returned unchanged", {
  # The safety property: it must fail at the file operation, never drift.
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml",
            sprintf("%s:\n  datalib: F:/definitely/not/here\n", USER))
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_match(res$root, "definitely/not/here")
    expect_equal(res$source_stage, "config_generic")
  })
})

test_that("a UTF-8 BOM does not hide the first block", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml", sprintf("%s:\n  datalib: F:/after_bom\n", USER),
            bom = TRUE)
  clean_env({
    res <- datalib_root(user = USER, configdir = d, report = TRUE)
    expect_match(res$root, "after_bom")
  })
})

test_that("reserved sibling-tool keys are parsed and published", {
  d <- withr::local_tempdir()
  write_cfg(d, "user_config.yml",
            sprintf("%s:\n  githubFolder: C:/GitHub\n  datalib: F:/lib\n", USER))
  clean_env({
    block <- datalib_config(user = USER, configdir = d)
    expect_equal(block$githubFolder, "C:/GitHub")
    expect_equal(block$datalib, "F:/lib")
  })
})

test_that("typed conditions distinguish a missing file from a missing block", {
  d <- withr::local_tempdir()
  clean_env(expect_error(datalib_config(user = USER, configdir = d),
                         class = "datalib_error_config_missing"))

  write_cfg(d, "user_config.yml", "somebodyelse:\n  datalib: F:/theirs\n")
  clean_env(expect_error(datalib_config(user = USER, configdir = d),
                         class = "datalib_error_user_missing"))
})

test_that("dl_root keeps its original return shape", {
  clean_env(withr::with_envvar(c(DATALIB_ROOT = "F:\\some\\where\\"), {
    expect_equal(dl_root(), "F:/some/where")
  }))
  # and still stops when nothing resolves -- with the config dir isolated, since
  # dl_root now reaches the configuration stages too
  d <- withr::local_tempdir()
  clean_env(withr::with_envvar(c(DATALIB_CONFIG_DIR = d),
                               expect_error(dl_root())))
})
