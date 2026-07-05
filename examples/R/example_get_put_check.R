# datalib example (R): put / get / check.
# Self-contained - uses a temp folder as the archive root; safe to run as-is.
# Requires: haven. Run from the REPO ROOT so the source() below resolves:
#   Rscript examples/R/example_get_put_check.R

source("R/R/datalib.R")
if (!requireNamespace("haven", quietly = TRUE)) {
  stop("This example needs the 'haven' package:  install.packages(\"haven\")")
}

demo_root <- file.path(tempdir(), "datalib_demo")
dir.create(demo_root, showWarnings = FALSE)
cat("demo archive root:", demo_root, "\n")

df <- data.frame(
  hhid   = 1:4,
  region = c(1, 1, 2, 3),
  poor   = c(0, 1, 1, 0)
)

# 1. PUT a MASTER: original data as provided (immutable once archived)
target <- dl_put(df, country = "BRA", year = 2023, survey = "DEMO", root = demo_root)
cat("  deposited MASTER    ->", target, "\n")

# 2. PUT a HARMONIZED adaptation: its own _A_ folder, never mixed in
target <- dl_put(df[, c("hhid", "poor")], country = "BRA", year = 2023,
                 survey = "DEMO", collection = "GMD", module = "adult",
                 root = demo_root)
cat("  deposited HARMONIZED ->", target, "\n")

# 3. GET them back by coordinates - no file paths needed
master <- dl_get(country = "BRA", year = 2023, survey = "DEMO", root = demo_root)
adult  <- dl_get(country = "BRA", year = 2023, survey = "DEMO",
                 collection = "GMD", module = "adult", latest = TRUE,
                 root = demo_root)
cat("  get MASTER:", nrow(master), "x", ncol(master),
    "  get HARMONIZED (latest):", nrow(adult), "x", ncol(adult), "\n")

# 4. CHECK: validate the archive against the IHSN template
violations <- dl_check(root = demo_root)
cat("  check violations:",
    if (length(violations)) paste(violations, collapse = "; ") else "NONE (conformant)", "\n")

# 5. MASTER immutability: a second put without overwrite=TRUE is refused
res <- tryCatch(
  { dl_put(df, country = "BRA", year = 2023, survey = "DEMO", root = demo_root); "OVERWROTE (bug!)" },
  error = function(e) "re-deposit refused (MASTER is immutable) - as designed"
)
cat(" ", res, "\n")

# To use a real library instead of the demo root:
#   Sys.setenv(DATALIB_ROOT = "/path/to/your/datalib")   # then omit root =
