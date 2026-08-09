*! _scanlog.do
*! Define (or restore) the log reader used by qa/run_tests.do
*! Sourced at start and after every suite, because each suite calls -clear all-
*! which drops Mata functions and programs alike. This mirrors
*! yaml-dev/qa/_define_helpers.do, which exists for the same reason.

capture mata: mata drop dtlb_scanlog()

mata:
// Read a suite log and report what it says.
//
// In MATA on purpose. A Stata log echoes the suite's own source, which is full
// of backticks and compound quotes. The moment a line containing the two
// characters  "'  reaches a macro-expanded string expression such as
//     local l = trim(`"`macval(line)'"')
// it closes the quote early and the caller dies with "too few quotes" (r 132).
// Mata reads the file as data, so nothing in the content can be taken for
// syntax.
//
// Sets, in the caller: s_pass, s_fail, s_done, s_skip, s_ids.
void dtlb_scanlog(string scalar path)
{
    string colvector lines
    real scalar      i, np, nf, done, skip
    string scalar    s, ids

    np = 0 ; nf = 0 ; done = 0 ; skip = 0 ; ids = ""
    lines = cat(path)

    for (i=1; i<=rows(lines); i++) {
        s = strtrim(lines[i])

        // A verdict counts only when the line STARTS with the token. The
        // suites' own -display- statements are echoed into the log as well,
        // and those begin with "." or a line number, so they do not count.
        if (substr(s,1,6)=="PASS: ") np = np + 1
        if (substr(s,1,6)=="FAIL: ") {
            nf  = nf + 1
            ids = ids + " " + strtrim(substr(s,7,12))
        }

        // The completion sentinel. Its ABSENCE is the signal that matters:
        // a suite that was killed, hung or crashed leaves a log full of PASS
        // lines and no sentinel, and must never be recorded green.
        if (strpos(s,"ALL CHECKS PASSED")      > 0) done = 1
        if (strpos(s,"ALL SMOKE TESTS PASSED") > 0) done = 1
        if (strpos(s,"ALL TESTS PASSED")       > 0) done = 1
        // verify_install.ps1 signs off differently from the -do- suites.
        if (strpos(s,"ACCEPTANCE PASSED")      > 0) done = 1

        // A missing PREREQUISITE is not a defect in the code under test, so it
        // is reported as SKIPPED rather than counted against the gate -- the
        // same distinction yaml-dev draws with test_skip for optional
        // dependencies. It is still recorded, because a suite that quietly
        // stops running is how one drifts out of the gate altogether.
        if (substr(s,1,6)=="SKIP: ")             skip = 1
        if (strpos(s,"Fixtures missing")   > 0)  skip = 1
    }

    st_local("s_pass", strofreal(np))
    st_local("s_fail", strofreal(nf))
    st_local("s_done", strofreal(done))
    st_local("s_skip", strofreal(skip))
    st_local("s_ids",  ids)
}
end
