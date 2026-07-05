*==============================================================================*
*! datalib example (Stata): put / check / read back
*! Self-contained - uses a temp folder as the archive root; safe to run as-is.
*! Requires the datalib package on the adopath (net install datalib).
*==============================================================================*
version 15
clear all
set more off

* ---- 0. Demo archive root (a scratch folder; swap for your real library) ----
local demo_root = subinstr("`c(tmpdir)'", "\", "/", .) + "/datalib_demo"
cap mkdir "`demo_root'"
di as txt "demo archive root: " as res "`demo_root'"

* ---- 1. PUT a MASTER: original data as provided (immutable once archived) ----
sysuse auto, clear
_dtlb_put, country(BRA) year(2023) survey(DEMO) root("`demo_root'")
di as res "  deposited: " r(target)

* ---- 2. PUT a HARMONIZED adaptation: its own _A_ folder, never mixed in ----
sysuse auto, clear
keep make price mpg foreign
label var price "Harmonized price (USD)"
_dtlb_put, country(BRA) year(2023) survey(DEMO) collection(GMD) module(adult) ///
    root("`demo_root'")
di as res "  deposited: " r(target)

* ---- 3. CHECK: validate the archive against the IHSN template ----
_dtlb_check, path("`demo_root'")
di as res "  violations: " r(violations) "  (0 = conformant)"

* ---- 4. Read a deposited file back ----
use "`demo_root'/BRA/BRA_2023_DEMO/BRA_2023_DEMO_v01_M/Data/Stata/BRA_2023_DEMO_v01_M.dta", clear
di as res "  read back MASTER: " _N " obs, " c(k) " vars"

* ---- 5. MASTER immutability: a second put without -overwrite- is refused ----
sysuse auto, clear
cap _dtlb_put, country(BRA) year(2023) survey(DEMO) root("`demo_root'")
di as res "  re-deposit refused with rc=602 (as designed): rc=" _rc

* ---- To use a real library instead of the demo root: ----
* global datalib "/path/to/your/datalib"
* _dtlb_put, country(CCC) year(YYYY) survey(SSSS) ...      // root() defaults to ${datalib}
