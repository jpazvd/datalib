*******************************************************************************
* __dtlb_json
*! v1.1.0  17Jul2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Minimal JSON field extraction for the NADA response shapes.
*
* This is NOT a general JSON parser (Stata has none in pure ado, and full
* DDI/dictionary parsing is an explicit non-goal of the v1 plan — see N7).
* It handles exactly what the api:// read story needs:
*
*   __dtlb_json scalar, file(<body>) key(<name>) [number]
*       First occurrence of "key": "value" (or bare number with -number-).
*       Returns r(found) 0/1 and r(value).
*
*   __dtlb_json list, file(<body>) key(<name>)
*       "key": ["a", "b", ...] of strings -> r(values) space-separated,
*       r(n). Returns r(found)=0 when the key is absent.
*
*   __dtlb_json split, file(<body>) array(<name>) saving(<out>)
*       Cuts the "array": [ {..}, {..} ] segment and writes ONE OBJECT PER
*       LINE to <out> (so callers stream it with -file read- and extract
*       per-row fields without macro-length pressure on any single object).
*       Returns r(n) = number of objects (0 for an empty array).
*
* Assumptions (the fixture tree pins them; DIVERGENCES-style caveats in the
* sthlp of the callers): objects inside the target array are flat (no
* nested objects/arrays), and string values do not contain escaped quotes.
* Whole-body parsing reads the response into one macro: bodies beyond the
* macro limit (~600KB, roughly 10 NADA pages) raise a clear error telling
* the user to narrow the query.
*
* Internal helper (double-underscore tier): may be refactored without notice.
*******************************************************************************

program define __dtlb_json, rclass
    version 15

    gettoken subcmd 0 : 0, parse(" ,")
    if !inlist("`subcmd'", "scalar", "list", "split") {
        display as error "__dtlb_json: subcommand must be scalar, list, or split"
        exit 198
    }

    if "`subcmd'" == "scalar" {
        syntax , file(string) key(string) [Number]
        __dtlb_json_body, file(`"`file'"')
        local body `"`s(body)'"'
        sreturn clear
        if "`number'" != "" {
            if ustrregexm(`"`body'"', `""`key'"[ ]*:[ ]*(-?[0-9.]+)"') {
                return scalar found = 1
                return local  value = ustrregexs(1)
                exit
            }
        }
        else {
            if ustrregexm(`"`body'"', `""`key'"[ ]*:[ ]*"([^"]*)""') {
                return scalar found = 1
                return local  value `"`=ustrregexs(1)'"'
                exit
            }
            // fall back to bare token (numbers, true/false, null)
            if ustrregexm(`"`body'"', `""`key'"[ ]*:[ ]*([A-Za-z0-9._-]+)"') {
                return scalar found = 1
                return local  value = ustrregexs(1)
                exit
            }
        }
        return scalar found = 0
        return local  value ""
        exit
    }

    if "`subcmd'" == "list" {
        syntax , file(string) key(string)
        __dtlb_json_body, file(`"`file'"')
        local body `"`s(body)'"'
        sreturn clear
        if !ustrregexm(`"`body'"', `""`key'"[ ]*:[ ]*\[([^]]*)\]"') {
            return scalar found = 0
            return scalar n     = 0
            return local  values ""
            exit
        }
        local inner = ustrregexs(1)
        local values ""
        local n = 0
        // pull the quoted strings out one by one
        while ustrregexm(`"`inner'"', `""([^"]*)""') {
            local item = ustrregexs(1)
            local values `"`values' `item'"'
            local ++n
            // chop through the closing quote of the item just captured
            local qpos = strpos(`"`inner'"', `""`item'""')
            local inner = substr(`"`inner'"', `qpos' + length(`"`item'"') + 2, .)
        }
        return scalar found  = 1
        return scalar n      = `n'
        return local  values = strtrim(`"`values'"')
        exit
    }

    if "`subcmd'" == "split" {
        syntax , file(string) array(string) saving(string)
        __dtlb_json_body, file(`"`file'"')
        local body `"`s(body)'"'
        sreturn clear

        // locate the array (tolerate a space after the colon)
        local apos = strpos(`"`body'"', `""`array'":["')
        local skip = length(`""`array'":["')
        if `apos' == 0 {
            local apos = strpos(`"`body'"', `""`array'": ["')
            local skip = length(`""`array'": ["')
        }
        if `apos' == 0 {
            return scalar n = 0
            exit
        }
        local seg = substr(`"`body'"', `apos' + `skip', .)

        // empty array?
        if substr(strtrim(`"`seg'"'), 1, 1) == "]" {
            return scalar n = 0
            exit
        }

        // flat objects -> the array ends at the first "}]"
        local cpos = strpos(`"`seg'"', "}]")
        if `cpos' > 0 local seg = substr(`"`seg'"', 1, `cpos')

        // one object per line
        local seg = subinstr(`"`seg'"', "},{", "}`=char(10)'{", .)
        local seg = subinstr(`"`seg'"', `"}, {"', "}`=char(10)'{", .)

        tempname fh
        file open `fh' using `"`saving'"', write text replace
        file write `fh' `"`seg'"' _n
        file close `fh'

        // count objects = separators + 1
        local n = 1
        local probe `"`seg'"'
        local nnl = length(`"`probe'"') - length(subinstr(`"`probe'"', char(10), "", .))
        local n = `nnl' + 1

        return scalar n = `n'
        exit
    }
end


*===============================================================================
* __dtlb_json_body : read a response body into s(body), newlines flattened
*===============================================================================
program define __dtlb_json_body, sclass
    version 15
    syntax , file(string)

    capture confirm file `"`file'"'
    if _rc {
        display as error `"__dtlb_json: body file not found: `file'"'
        exit 601
    }
    capture local body = fileread(`"`file'"')
    if _rc {
        display as error "__dtlb_json: response too large to parse in pure Stata"
        display as error "  narrow the query (country()/year()/survey() filters, smaller page size)"
        exit 198
    }
    // flatten newlines so key:value regexes work on pretty-printed JSON
    local body = subinstr(`"`body'"', char(13), " ", .)
    local body = subinstr(`"`body'"', char(10), " ", .)
    sreturn local body `"`body'"'
end
