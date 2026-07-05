# datalib (R) - access the IHSN-organized survey archive.
# Mirrors the Python reference package and the Stata `datalib` command.
# See docs/taxonomy.md. Requires `haven` for read/write of Stata .dta.
#
# Prototype: functions are sourceable now; a proper R package (DESCRIPTION,
# NAMESPACE, roxygen man/) is the next step.

DATALIB_SKELETON <- c("Data/Original", "Data/Stata", "Data/Other", "Doc", "Programs")

dl_root <- function(root = NULL) {
  if (is.null(root)) root <- Sys.getenv("DATALIB_ROOT", unset = "")
  if (!nzchar(root))
    stop("datalib root not set; pass root= or set DATALIB_ROOT (e.g. F:/datalib).")
  sub("/+$", "", gsub("\\\\", "/", root))
}

dl_survey_id <- function(country, year, survey)
  sprintf("%s_%04d_%s", toupper(country), as.integer(year), toupper(survey))

dl_version_name <- function(country, year, survey, vm = 1, collection = NULL, va = 1) {
  base <- sprintf("%s_v%02d_M", dl_survey_id(country, year, survey), as.integer(vm))
  if (!is.null(collection) && nzchar(collection))
    sprintf("%s_v%02d_A_%s", base, as.integer(va), toupper(collection))
  else base
}

dl_parse_id <- function(name) {
  re <- "^([A-Za-z]{3})_([0-9]{4})_([A-Za-z0-9]+)_v([0-9]+)_M(?:_v([0-9]+)_A_([A-Za-z0-9]+))?$"
  m <- regmatches(name, regexec(re, name, perl = TRUE))[[1]]
  if (length(m) == 0) return(NULL)
  harmonized <- nzchar(m[7])
  list(ctry = m[2], year = m[3], svy = m[4], vm = m[5], va = m[6], clct = m[7],
       harmonized = harmonized, kind = if (harmonized) "harmonized" else "master")
}

dl_version_dir <- function(root, country, year, survey, vm = 1, collection = NULL, va = 1)
  file.path(root, toupper(country), dl_survey_id(country, year, survey),
            dl_version_name(country, year, survey, vm, collection, va))

dl_data_file <- function(root, country, year, survey, module = NULL,
                         vm = 1, collection = NULL, va = 1) {
  vdir <- dl_version_dir(root, country, year, survey, vm, collection, va)
  ver <- basename(vdir)
  suffix <- if (!is.null(module) && nzchar(module)) paste0("_", module) else ""
  file.path(vdir, "Data", "Stata", paste0(ver, suffix, ".dta"))
}

dl_find_latest <- function(root, country, year, survey, collection = NULL) {
  sdir <- file.path(root, toupper(country), dl_survey_id(country, year, survey))
  if (!dir.exists(sdir)) return(NULL)
  best_key <- c(-1, -1); best_dir <- NULL
  for (nm in list.dirs(sdir, recursive = FALSE, full.names = FALSE)) {
    info <- dl_parse_id(nm); if (is.null(info)) next
    if (!is.null(collection) && nzchar(collection)) {
      if (!info$harmonized || toupper(info$clct) != toupper(collection)) next
      key <- c(as.integer(info$vm), as.integer(info$va))
    } else {
      if (info$harmonized) next
      key <- c(as.integer(info$vm), 0)
    }
    if (key[1] > best_key[1] || (key[1] == best_key[1] && key[2] > best_key[2])) {
      best_key <- key; best_dir <- file.path(sdir, nm)
    }
  }
  best_dir
}

dl_get <- function(country, year, survey, module = NULL, collection = NULL,
                   vm = 1, va = 1, latest = FALSE, root = NULL) {
  root <- dl_root(root)
  if (latest) {
    vdir <- dl_find_latest(root, country, year, survey, collection)
    if (is.null(vdir)) stop("no matching version found")
    ver <- basename(vdir)
    suffix <- if (!is.null(module) && nzchar(module)) paste0("_", module) else ""
    path <- file.path(vdir, "Data", "Stata", paste0(ver, suffix, ".dta"))
  } else {
    path <- dl_data_file(root, country, year, survey, module, vm, collection, va)
  }
  if (!file.exists(path)) stop(sprintf("dataset not found: %s", path))
  haven::read_dta(path)
}

dl_put <- function(data, country, year, survey, module = NULL, collection = NULL,
                   vm = 1, va = 1, root = NULL, overwrite = FALSE, strict = TRUE) {
  root <- dl_root(root)
  vdir <- dl_version_dir(root, country, year, survey, vm, collection, va)
  ver <- basename(vdir)
  for (sub in DATALIB_SKELETON)
    dir.create(file.path(vdir, sub), recursive = TRUE, showWarnings = FALSE)
  suffix <- if (!is.null(module) && nzchar(module)) paste0("_", module) else ""
  target <- file.path(vdir, "Data", "Stata", paste0(ver, suffix, ".dta"))
  if (file.exists(target) && !overwrite) {
    kind <- if (!is.null(collection) && nzchar(collection)) "HARMONIZED" else "MASTER"
    stop(sprintf("%s file already archived: %s\n  %s data is immutable - bump vm/va or overwrite=TRUE.",
                 kind, target, kind))
  }
  haven::write_dta(data, target)
  if (strict) {
    v <- dl_check(root = root, country = country,
                  survey = dl_survey_id(country, year, survey))
    if (length(v)) stop(paste0("IHSN conformance failed after put:\n  ",
                               paste(v, collapse = "\n  ")))
  }
  target
}

dl_check <- function(root = NULL, country = NULL, survey = NULL) {
  root <- dl_root(root)
  viol <- character(0)
  countries <- if (!is.null(country)) toupper(country)
               else list.dirs(root, recursive = FALSE, full.names = FALSE)
  for (c in countries) {
    cdir <- file.path(root, c)
    surveys <- if (!is.null(survey)) survey
               else list.dirs(cdir, recursive = FALSE, full.names = FALSE)
    for (s in surveys) {
      sdir <- file.path(cdir, s)
      if (!dir.exists(sdir)) next
      if (!grepl("^[A-Z]{3}_[0-9]{4}_[A-Z0-9]+$", toupper(s)))
        viol <- c(viol, sprintf("%s: survey name not CCC_YYYY_SSSS", s))
      has_master <- FALSE
      for (v in list.dirs(sdir, recursive = FALSE, full.names = FALSE)) {
        vdir <- file.path(sdir, v); info <- dl_parse_id(v)
        if (is.null(info)) {
          viol <- c(viol, sprintf("%s/%s: version name not IHSN-conformant", s, v)); next
        }
        if (!info$harmonized) has_master <- TRUE
        for (sub in DATALIB_SKELETON)
          if (!dir.exists(file.path(vdir, sub)))
            viol <- c(viol, sprintf("%s/%s: missing /%s", s, v, sub))
        sdta <- file.path(vdir, "Data", "Stata")
        if (dir.exists(sdta))
          for (f in list.files(sdta, pattern = "\\.dta$", ignore.case = TRUE)) {
            has_a <- grepl("_a_", tolower(f))
            if (!info$harmonized && has_a)
              viol <- c(viol, sprintf("%s/%s: HARMONIZED (_A_) file in MASTER folder -> %s", s, v, f))
            if (info$harmonized && !has_a)
              viol <- c(viol, sprintf("%s/%s: non-harmonized file in HARMONIZED folder -> %s", s, v, f))
          }
      }
      if (!has_master) viol <- c(viol, sprintf("%s: no MASTER (_M) version", s))
    }
  }
  viol
}
