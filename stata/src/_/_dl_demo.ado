*******************************************************
** _dl_demo: locate the bundled demo library
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.1.0  2026-08-05
*******************************************************
* Returns the path of a demo library the operator has already built, or nothing
* if there is none.
*
* THIS COMMAND NEVER CREATES ANYTHING. It looks; it does not build. Two reasons.
* A resolver that writes when its read fails makes the configuration golden
* cases non-hermetic, and materialising a library as a side effect of asking
* "where is my library?" is precisely the kind of surprise this package exists
* to avoid. When no demo exists, the caller reports how to build one.
*
* Searched, in order:
*   1. <datalib home>/demo   -- ~/.datalib/demo, the conventional place for a
*      library built by -datalib_makelib- with no path given
*   2. <repo>/examples/demo_library -- resolved relative to the package's own
*      code (-findfile- locates _dl_islib.ado, then two levels up), so a working
*      clone that has generated one there still finds it
*
* NO DEMO SHIPS WITH THE PACKAGE, by design. This package distributes no
* microdata, synthetic or otherwise; and -net install- could not carry a library
* anyway, because it places files in the PLUS tree by basename without
* preserving directories, so a nested tree would arrive flattened. The recipe
* ships instead of the result: -datalib_makelib, families(demo)-.
*
* Returns:
*   r(path)  the demo library path (forward slashes, no trailing separator),
*            empty if not found
*   r(found) 1/0
*******************************************************

capture program drop _dl_demo
program define _dl_demo, rclass

    version 15

    quietly {
        return local path ""
        return scalar found = 0

        * 1. the conventional home for a generated demo
        capture __dtlb_userhome
        if (_rc==0) {
            local dhome = subinstr(`"`r(datalib_home)'"', "\", "/", .)
            if (`"`dhome'"'!="") {
                _dl_islib `"`dhome'/demo"'
                if (r(islib)==1) {
                    return local path `"`r(path)'"'
                    return scalar found = 1
                    exit
                }
            }
        }

        * 2. a demo generated inside a working clone
        * Anchor on a file this package is certain to own.
        capture findfile _dl_islib.ado
        if (_rc) exit
        local anchor = subinstr(`"`r(fn)'"', "\", "/", .)

        * <...>/stata/src/_/_dl_islib.ado -> strip file, then two directory levels
        local dir = substr(`"`anchor'"', 1, strrpos(`"`anchor'"', "/") - 1)
        forvalues i = 1/2 {
            local dir = substr(`"`dir'"', 1, strrpos(`"`dir'"', "/") - 1)
            if (`"`dir'"'=="") exit
        }

        local cand `"`dir'/examples/demo_library"'
        _dl_islib `"`cand'"'
        if (r(islib)==1) {
            return local path `"`r(path)'"'
            return scalar found = 1
        }
    }

end
