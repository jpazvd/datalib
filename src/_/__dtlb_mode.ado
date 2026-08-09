*******************************************************
* __dtlb_mode: return the mode of a numeric variable in r(mode).
* Private to the datalib package.
*! v1.1.0
*******************************************************
capture program drop __dtlb_mode
program define __dtlb_mode, rclass
    version 15
    syntax varlist(max=1 numeric)
    tempvar modetemp
    egen `modetemp' = mode(`varlist')
    qui sum `modetemp', meanonly
    local modevalue = r(mean)
    return scalar mode = `modevalue'
end
