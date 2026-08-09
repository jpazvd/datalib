#' datalib configuration: resolve the curated archive root
#'
#' Resolution is pure candidate selection, in this order, and touches no disk:
#'
#'     argument -> DATALIB_ROOT -> option(datalib.root) -> config_generic ->
#'     config_package
#'
#' The first non-empty candidate wins and is returned as given. It is never
#' probed for existence and never overridden by a later stage: a configured
#' archive that is momentarily unreachable fails at the file operation instead
#' of resolving to some other library.
#'
#' The two configuration files are read block-by-block, never merged. The root
#' comes from the FIRST file whose block for this user carries a non-empty
#' `datalib` key:
#'
#'     ~/.config/user_config.yml     -> stage "config_generic"
#'     ~/.config/datalib_config.yml  -> stage "config_package"
#'
#' `DATALIB_CONFIG` pins one file (fallback off); `DATALIB_CONFIG_DIR` moves the
#' search elsewhere (fallback preserved). The stage names are byte-identical to
#' the Stata and Python legs. The three agree on the resolved directory, not on
#' its spelling: this leg normalises through `fs::path_norm`.
#'
#' @name datalib-config
NULL

.DL_GENERIC_FILE <- "user_config.yml"
.DL_PACKAGE_FILE <- "datalib_config.yml"
.DL_BLOCK_KEYS <- c("githubFolder", "teamsRoot", "zDrive", "zDriveUNC", "datalib")

.dl_home <- function() {
  # USERPROFILE first, so Windows agrees with the Stata leg
  h <- Sys.getenv("USERPROFILE", "")
  if (!nzchar(h)) h <- Sys.getenv("HOME", "~")
  h
}

.dl_config_dir <- function(configdir = NULL) {
  if (!is.null(configdir) && nzchar(configdir)) return(configdir)
  env_dir <- Sys.getenv("DATALIB_CONFIG_DIR", "")
  if (nzchar(env_dir)) return(env_dir)
  file.path(.dl_home(), ".config")
}

.dl_config_file_list <- function(config = NULL, configdir = NULL) {
  if (!is.null(config) && nzchar(config)) return(config)
  env_file <- Sys.getenv("DATALIB_CONFIG", "")
  if (nzchar(env_file)) return(env_file)
  base <- .dl_config_dir(configdir)
  c(file.path(base, .DL_GENERIC_FILE), file.path(base, .DL_PACKAGE_FILE))
}

.dl_stage_for <- function(path) {
  if (basename(path) == .DL_GENERIC_FILE) "config_generic" else "config_package"
}

.dl_parse <- function(path, user) {
  if (!file.exists(path)) return(NULL)
  doc <- tryCatch(yaml::read_yaml(path), error = function(e) NULL)
  if (is.null(doc) || !is.list(doc)) return(NULL)
  block <- doc[[user]]
  if (is.null(block) || !is.list(block)) return(NULL)
  out <- lapply(.DL_BLOCK_KEYS, function(k) {
    v <- block[[k]]
    if (is.null(v)) "" else as.character(v)
  })
  names(out) <- .DL_BLOCK_KEYS
  out$user <- user
  out$file <- path
  out
}

#' Read this operator's configuration block
#'
#' @param user Username whose block to read; defaults to the current user.
#' @param config Pin exactly one configuration file.
#' @param configdir Search the two-file list in this directory.
#' @return A list with the block's keys plus `user` and `file`.
#' @export
datalib_config <- function(user = NULL, config = NULL, configdir = NULL) {
  if (is.null(user)) user <- unname(Sys.info()[["user"]])
  files <- .dl_config_file_list(config, configdir)

  seen_any <- FALSE
  block <- NULL
  root <- ""
  root_file <- NULL

  for (f in files) {
    if (!file.exists(f)) next
    seen_any <- TRUE
    parsed <- .dl_parse(f, user)
    if (is.null(parsed)) next
    if (is.null(block)) block <- parsed
    if (!nzchar(root) && nzchar(parsed$datalib)) {
      root <- parsed$datalib
      root_file <- f
    }
  }

  if (!seen_any) {
    stop(structure(
      class = c("datalib_error_config_missing", "error", "condition"),
      list(message = paste0(
        "No configuration file found at: ", files[1],
        ". A template lives in the repository under config/",
        .DL_GENERIC_FILE, "."), call = NULL)))
  }
  if (is.null(block)) {
    stop(structure(
      class = c("datalib_error_user_missing", "error", "condition"),
      list(message = paste0(
        "Configuration found at ", files[1],
        ", but it has no block for user '", user, "'."), call = NULL)))
  }

  if (nzchar(root) && !identical(root, block$datalib)) {
    block$datalib <- root
    block$file <- root_file
  }
  block
}

#' Resolve the datalib library root
#'
#' @param root Explicit root; wins over everything.
#' @param user,config,configdir Passed to [datalib_config()].
#' @param report If `TRUE`, return a list with `root`, `source_stage` and
#'   `source_file` rather than the path alone.
#' @return A normalised path, or a list when `report = TRUE`.
#' @export
datalib_root <- function(root = NULL, user = NULL, config = NULL,
                         configdir = NULL, report = FALSE) {
  finish <- function(path, stage, file = NULL) {
    norm <- as.character(fs::path_norm(path))
    if (report) list(root = norm, source_stage = stage, source_file = file) else norm
  }

  if (!is.null(root) && nzchar(root)) return(finish(root, "argument"))

  env_root <- Sys.getenv("DATALIB_ROOT", "")
  if (nzchar(env_root)) return(finish(env_root, "env"))

  opt_root <- getOption("datalib.root", "")
  if (is.character(opt_root) && length(opt_root) == 1 && nzchar(opt_root)) {
    return(finish(opt_root, "option"))
  }

  block <- tryCatch(
    datalib_config(user = user, config = config, configdir = configdir),
    datalib_error_config_missing = function(e) NULL,
    datalib_error_user_missing = function(e) NULL)

  if (!is.null(block) && nzchar(block$datalib)) {
    return(finish(block$datalib, .dl_stage_for(block$file), block$file))
  }

  stop(structure(
    class = c("datalib_error_root_unset", "error", "condition"),
    list(message = paste0(
      "datalib root not set; pass root=, set DATALIB_ROOT, or add a 'datalib' ",
      "key to your block in ~/.config/", .DL_GENERIC_FILE,
      " (template: config/", .DL_GENERIC_FILE, ")."), call = NULL)))
}
