*******************************************************************************
* _dtlb_show
*! v1.8.0  08Aug2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Render a catalog frame in the Results window as a LIST, a GRID, or a MATRIX.
*
* One renderer, three formats, differing only in how many dimensions are bound
* to axes:
*
*   list    0 pivots  one record per line, attributes in columns
*   grid    1 pivot   one dimension's values, wrapped across the line
*   matrix  2 pivots  row x col, an aggregate in each cell
*
* Only the matrix can show ABSENCE: it allocates a cell to every combination of
* its axes, so a gap is rendered. A list of what exists has no row for the
* survey nobody deposited.
*
*   _dtlb_show, format(matrix) row(country) col(survey)         ///
*               [ cell(varname) linkcmd(string) frame(name)     ///
*                 title(string) nolinks ]
*
* WHY THIS IS HAND-ROLLED AND NOT -tabdisp-
* Measured on Stata 17: tabdisp does not interpret SMCL in cells (a 14-char
* link that fits whole still renders as literal markup, while the same string
* through -display- renders as a working link), and it truncates string cells
* at 20 characters. Either alone rules it out for a clickable menu. This is
* also why datalibweb's dlw_display is 124 lines of hand-rolled _col().
*
* WIDTH ARITHMETIC USES THE LABEL, NOT THE MARKUP
* Also measured: SMCL directives cost no display columns -- `{stata di 1:AAAA}'
* and a plain `AAAA' put a following _col(11) in the same place. So every width
* below is computed from the visible label; the emitted string is far longer.
*
* linkcmd() is a template. @row and @col are replaced by the current cell's
* coordinates, so the renderer needs no knowledge of what it is rendering.
*
* Never changes the caller's data or current frame.
*******************************************************************************

program define _dtlb_show, rclass
    version 16

    syntax [,                       ///
                FORMat(string)      ///
                row(string)         ///
                col(string)         ///
                cell(string)        ///
                frame(string)       ///
                LINKcmd(string)     ///
                title(string)       ///
                NOLinks             ///
                MAXCols(integer 0)  ///
            ]

    // ---- defaults -------------------------------------------------------
    if ("`frame'"=="")  local frame "dtlb_catalog"
    if ("`format'"=="") local format = cond("`col'"!="", "matrix",  ///
                                       cond("`row'"!="", "grid", "list"))
    local format = lower("`format'")
    if !inlist("`format'","list","grid","matrix") {
        display as error "format() must be list, grid or matrix"
        exit 198
    }
    if ("`format'"=="matrix" & ("`row'"=="" | "`col'"=="")) {
        display as error "format(matrix) requires both row() and col()"
        exit 198
    }
    if ("`format'"=="grid" & "`row'"=="") {
        display as error "format(grid) requires row()"
        exit 198
    }

    capture frame `frame': describe, short
    if (_rc) {
        display as error "frame `frame' not found -- run: _dtlb_catalog, scan"
        exit 111
    }

    // The caller's frame is restored no matter which branch exits. datalib is
    // called mid-analysis; a renderer that leaves you in another frame is a
    // renderer nobody trusts.
    local _dtlb_caller_frame = c(frame)
    cwf `frame'

    quietly count
    local N = r(N)
    if (`N'==0) {
        cwf `_dtlb_caller_frame'
        display as text "  (catalog is empty)"
        return scalar rows = 0
        exit 0
    }

    local LS = c(linesize)
    if (`LS' < 40) local LS 40

    if ("`title'"!="") {
        display as text _n "  `title'"
        display as text "  {hline `=min(length("`title'"), `LS'-2)'}"
    }

    if ("`format'"=="list")   _dtlb_show_list,   linkcmd(`"`linkcmd'"') `nolinks' ls(`LS')
    if ("`format'"=="grid")   _dtlb_show_grid,   row(`row') linkcmd(`"`linkcmd'"') `nolinks' ls(`LS')
    if ("`format'"=="matrix") _dtlb_show_matrix, row(`row') col(`col') cell(`cell') ///
                                  linkcmd(`"`linkcmd'"') `nolinks' ls(`LS') maxcols(`maxcols')

    local nr = r(nrows)
    local nc = r(ncols)
    local nt = r(ntrunc)

    cwf `_dtlb_caller_frame'

    return scalar rows   = `N'
    return scalar nrows  = `nr'
    return scalar ncols  = `nc'
    return scalar ntrunc = `nt'
    return local  format "`format'"
end


*===============================================================================
* LIST -- zero pivots. One record per line.
*===============================================================================
program define _dtlb_show_list, rclass
    version 16
    syntax , ls(integer) [linkcmd(string) NOLinks]

    local vars country year survey version kind
    local shown ""
    foreach v of local vars {
        capture confirm variable `v'
        if (_rc==0) local shown "`shown' `v'"
    }
    local shown = trim("`shown'")

    // Column widths from the widest VALUE actually present, never a guess.
    local pos 3
    local hdr ""
    local i 0
    foreach v of local shown {
        local i = `i' + 1
        capture confirm string variable `v'
        if (_rc==0) quietly gen long _w`i' = length(`v')
        else        quietly gen long _w`i' = length(strofreal(`v'))
        quietly summarize _w`i', meanonly
        local w`i' = max(r(max), length("`v'"))
        drop _w`i'
        local hdr `"`hdr' _col(`pos') "`v'""'
        local p`i' = `pos'
        local pos = `pos' + `w`i'' + 2
    }
    local nv = `i'

    display as text `hdr'
    display as text "  {hline `=min(`pos'-2, `ls'-2)'}"

    forvalues r = 1/`=_N' {
        local line ""
        local i 0
        foreach v of local shown {
            local i = `i' + 1
            capture confirm string variable `v'
            if (_rc==0) local val = `v'[`r']
            else        local val = strofreal(`v'[`r'])
            local line `"`line' _col(`p`i'') "`val'""'
        }
        display as text `line'
    }

    return scalar nrows  = _N
    return scalar ncols  = `nv'
    return scalar ntrunc = 0
end


*===============================================================================
* GRID -- one pivot. The distinct values of one dimension, wrapped.
*===============================================================================
program define _dtlb_show_grid, rclass
    version 16
    syntax , row(string) ls(integer) [linkcmd(string) NOLinks]

    quietly levelsof `row', local(vals) clean
    local n : word count `vals'

    // Widest label decides the column; +2 gutter.
    local w 0
    foreach v of local vals {
        if (length("`v'") > `w') local w = length("`v'")
    }
    local cw = `w' + 3
    local percol = max(1, int((`ls' - 4) / `cw'))

    display as text "  `row' {hline 1} {res:`n'}"
    display as text "  {hline `=min(min(`percol',`n')*`cw', `ls'-2)'}"

    local i 0
    local line ""
    foreach v of local vals {
        local i = `i' + 1
        local slot = mod(`i'-1, `percol')
        local at = 3 + `slot'*`cw'
        local lbl "`v'"
        if ("`nolinks'"=="" & `"`linkcmd'"'!="") {
            local cmd = subinstr(`"`linkcmd'"', "@row", "`v'", .)
            local lbl `"{stata `cmd':`v'}"'
        }
        local line `"`line' _col(`at') `"`lbl'"'"'
        if (`slot'==`percol'-1 | `i'==`n') {
            display as text `line'
            local line ""
        }
    }

    return scalar nrows  = ceil(`n'/`percol')
    return scalar ncols  = `percol'
    return scalar ntrunc = 0
end


*===============================================================================
* MATRIX -- two pivots. The only format that renders ABSENCE.
*===============================================================================
program define _dtlb_show_matrix, rclass
    version 16
    syntax , row(string) col(string) ls(integer) ///
             [cell(string) linkcmd(string) NOLinks maxcols(integer 0)]

    quietly levelsof `row', local(rvals) clean
    quietly levelsof `col', local(cvals) clean
    local nr : word count `rvals'
    local nc : word count `cvals'

    // An axis may be numeric (year) or string (country). Quoting a numeric
    // comparison exits 109, so the quoting is decided once, here, rather than
    // assumed -- found by pointing the matrix at year.
    capture confirm string variable `row'
    local rq = cond(_rc==0, `"""', "")
    capture confirm string variable `col'
    local cq = cond(_rc==0, `"""', "")

    // Stub width from the widest row label; cell width from the widest of the
    // column headers and the widest cell CONTENT that will actually print.
    local sw = length("`row'")
    foreach r of local rvals {
        if (length("`r'") > `sw') local sw = length("`r'")
    }
    local sw = `sw' + 2

    local cw 1
    foreach c of local cvals {
        if (length("`c'") > `cw') local cw = length("`c'")
    }
    // widest cell content: counts, or the cell() variable's values
    foreach r of local rvals {
        foreach c of local cvals {
            quietly count if `row'==`rq'`r'`rq' & `col'==`cq'`c'`cq'
            local k = r(N)
            local txt = cond(`k'==0, ".", strofreal(`k'))
            if ("`cell'"!="" & `k'>0) {
                quietly levelsof `cell' if `row'==`rq'`r'`rq' & `col'==`cq'`c'`cq', local(cv) clean
                local txt : word 1 of `cv'
                if (`k' > 1) local txt "`txt'+"
            }
            if (length("`txt'") > `cw') local cw = length("`txt'")
        }
    }
    local cw = `cw' + 2

    // Fit. A matrix wider than the line must say so, never silently truncate.
    local fits = int((`ls' - `sw' - 2) / `cw')
    if (`fits' < 1) local fits 1
    if (`maxcols' > 0 & `maxcols' < `fits') local fits `maxcols'
    local ntrunc = max(0, `nc' - `fits')

    local shown = min(`fits', `nc')
    local width = `sw' + 1 + `shown'*`cw'
    if (`width' > `ls'-1) local width = `ls'-1

    // header
    local hdr ""
    local i 0
    foreach c of local cvals {
        local i = `i' + 1
        if (`i' > `fits') continue, break
        local at = `sw' + 1 + (`i'-1)*`cw' + (`cw' - length("`c'"))
        local hdr `"`hdr' _col(`at') "`c'""'
    }
    display as text _col(`=`sw'-length("`row'")') "`row'" _col(`sw') "{c |}" as result `hdr'
    display as text "{hline `sw'}{c +}{hline `=`width'-`sw''}"

    // body
    foreach r of local rvals {
        local line ""
        local i 0
        foreach c of local cvals {
            local i = `i' + 1
            if (`i' > `fits') continue, break
            quietly count if `row'==`rq'`r'`rq' & `col'==`cq'`c'`cq'
            local k = r(N)
            if (`k'==0) {
                // The empty cell is the point of the format. It is rendered,
                // not skipped, and it means "nothing here" -- never "the
                // renderer lost it".
                local at = `sw' + 1 + (`i'-1)*`cw' + (`cw' - 1)
                local line `"`line' _col(`at') "{txt:.}""'
            }
            else {
                local txt = strofreal(`k')
                if ("`cell'"!="") {
                    quietly levelsof `cell' if `row'==`rq'`r'`rq' & `col'==`cq'`c'`cq', local(cv) clean
                    local txt : word 1 of `cv'
                    if (`k' > 1) local txt "`txt'+"
                }
                local at = `sw' + 1 + (`i'-1)*`cw' + (`cw' - length("`txt'"))
                local lbl "`txt'"
                if ("`nolinks'"=="" & `"`linkcmd'"'!="") {
                    local cmd = subinstr(`"`linkcmd'"', "@row", "`r'", .)
                    local cmd = subinstr(`"`cmd'"',     "@col", "`c'", .)
                    local lbl `"{stata `cmd':`txt'}"'
                }
                local line `"`line' _col(`at') `"`lbl'"'"'
            }
        }
        display as text _col(`=`sw'-length("`r'")') "`r'" _col(`sw') "{c |}" `line'
    }
    display as text "{hline `sw'}{c BT}{hline `=`width'-`sw''}"

    if (`ntrunc' > 0) {
        display as error "  `ntrunc' of `nc' `col' columns not shown -- widen linesize or filter"
    }

    return scalar nrows  = `nr'
    return scalar ncols  = `nc'
    return scalar ntrunc = `ntrunc'
end
