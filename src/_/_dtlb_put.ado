*! _dtlb_put v0.1  |  datalib / UNICEF  |  deposit a dataset into the IHSN archive
*!
*! Generic deposit command: files the dataset in memory (or a `using` file) into
*! the curated datalib archive following the IHSN taxonomy. This is the write-side
*! counterpart of `datalib` (read) and `_dtlb_check` (validate), and generalizes the
*! save-into-taxonomy step that `ibge.ado` currently hardcodes for IBGE surveys.
*!
*! Cross-language parity (see 00_documentation/taxonomy.md): the canonical options are
*!   country year survey module collection vm va root original overwrite strict ddi
*! and are shared with the Python (`datalib.put`) and R (`dl_put`) equivalents.
*! Stata-idiomatic aliases are also accepted: path() = root(), replace = overwrite,
*! nostrict/nocheck = strict(off).
*!
*! MASTER (no collection) is immutable: an existing file is NOT overwritten unless
*! -overwrite- (or -replace-) is given; publish a new version with vm()/va() instead.
*!
*! Syntax:
*!   _dtlb_put [using/] , Country() Year() Survey() [ Module() COLLection()
*!            VM() VA() ROOT() Path() ORIGinal() overwrite replace nostrict nocheck ]

program define _dtlb_put, rclass
    version 15
    syntax [using/] , Country(string) Year(string) Survey(string) ///
        [ Module(string) COLLection(string) VM(string) VA(string)  ///
          ROOT(string) Path(string) ORIGinal(string)               ///
          OVERWRITE REPLACE NOSTRict NOCHeck ]

    * ---- archive root (canonical root(); path() is the Stata-side alias) ----
    if ("`root'" != "") local path "`root'"
    if ("`path'" == "") local path "${datalib}"
    if ("`path'" == "") {
        di as err "datalib root not set: pass root() or set global datalib (e.g. F:/datalib)."
        exit 198
    }
    local path = subinstr("`path'", "\", "/", .)

    * ---- normalize the shared boolean options ----
    local overwrite = cond(("`overwrite'" != "") | ("`replace'" != ""), "1", "0")
    local skipcheck = cond(("`nostrict'"  != "") | ("`nocheck'"  != ""), "1", "0")

    * ---- IHSN names (mirrors 00_documentation/taxonomy.md) ----
    local vm = cond("`vm'" == "", "01", string(real("`vm'"), "%02.0f"))
    local va = cond("`va'" == "", "01", string(real("`va'"), "%02.0f"))
    local CCC  = upper("`country'")
    local YYYY = string(real("`year'"), "%04.0f")
    local SSSS = upper("`survey'")
    local sid  "`CCC'_`YYYY'_`SSSS'"
    local ver  "`sid'_v`vm'_M"
    if ("`collection'" != "") local ver "`ver'_v`va'_A_`=upper("`collection'")'"
    local vdir "`path'/`CCC'/`sid'/`ver'"

    local kind = cond("`collection'" == "", "MASTER", "HARMONIZED")

    * ---- build the IHSN skeleton (one level at a time) ----
    cap mkdir "`path'"
    cap mkdir "`path'/`CCC'"
    cap mkdir "`path'/`CCC'/`sid'"
    cap mkdir "`vdir'"
    foreach sub in Data Data/Original Data/Stata Data/Other Doc Programs {
        cap mkdir "`vdir'/`sub'"
    }

    * ---- target file name ----
    local fname "`ver'"
    if ("`module'" != "") local fname "`ver'_`module'"
    local target "`vdir'/Data/Stata/`fname'.dta"

    * ---- guardrail: MASTER/HARMONIZED immutability ----
    cap confirm file "`target'"
    if (_rc == 0) & (`overwrite' == 0) {
        di as err "`kind' file already archived:"
        di as err "    `target'"
        di as err "  `kind' data is immutable - bump vm()/va() for a new version, or use -overwrite-."
        exit 602
    }

    * ---- load the using file if provided ----
    if (`"`using'"' != "") use `"`using'"', clear

    * ---- write the Stata file ----
    label data "`ver'"
    save "`target'", replace
    noi di as res "deposited [`kind']: `target'"

    * ---- preserve the raw original (MASTER deposits only) ----
    if ("`original'" != "") & ("`collection'" == "") {
        cap confirm file "`original'"
        if (_rc == 0) {
            mata: st_local("obase", pathbasename("`original'"))
            cap copy "`original'" "`vdir'/Data/Original/`obase'", replace
            if (_rc == 0) noi di as txt "  preserved original -> Data/Original/`obase'"
        }
    }

    * ---- conformance gate (strict by default; -nostrict- to skip) ----
    local nviol = .
    if (`skipcheck' == 0) {
        cap which _dtlb_check
        if (_rc == 0) {
            _dtlb_check, path("`path'") country("`CCC'") survey("`sid'")
            local nviol = r(violations)
            if (`nviol' > 0) {
                di as err "IHSN conformance FAILED after deposit (`nviol' violation(s))."
                exit 459
            }
        }
    }

    return local target  "`target'"
    return local version "`ver'"
    return local kind    "`kind'"
    return scalar violations = `nviol'
end
