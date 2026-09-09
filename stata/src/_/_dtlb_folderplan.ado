*******************************************************************************
* _dtlb_folderplan
*! v1.11.0  12Aug2026                by Joao Pedro Azevedo (UNICEF)
*!                                   and Minh Cong Nguyen (World Bank)
* The vintage folder plan: which subfolders a version folder contains.
*
* THE ONE STATA COPY. Before this, the plan was a hard-coded literal in six
* creation sites -- four blocks in _dtlb_mkdir, plus _dtlb_put,
* _dtlb_ipums_extract and datalib_makelib -- and they had already drifted:
* datalib_makelib built no Data/Other, and none of the six built the three
* Doc/ subfolders Annex 1 of the ECAPOV Harmonization Guideline specifies.
*
* config/folderplan.yml is the CANONICAL definition, shared with the R and
* Python legs. It is not read at runtime: config/ is not in datalib.pkg, so an
* installed user does not have it, and a creation path should not depend on a
* YAML parse. The literal below is the Stata copy, and
* python/tests/test_folderplan.py asserts it equals the YAML -- so the copy
* cannot drift without a test failing, which is the property the six copies
* lacked.
*
* Returns r(subfolders): the leaves to create, relative to the vintage folder,
* parents first, quoted for -foreach ... in-.
*******************************************************************************

capture program drop _dtlb_folderplan
program define _dtlb_folderplan, rclass

    version 15

    syntax [, PLAn(string) KINd(string) DATa(string) DOC(string) ]

    * Trim BEFORE defaulting, both of them: plan("  ") is a blank plan, not a
    * plan named "  ", and defaulting after the trim is what makes it fall back
    * rather than fail an equality test against every branch below.
    local plan = lower(trim("`plan'"))
    local kind = lower(trim("`kind'"))
    if ("`plan'"=="") local plan "default"
    if ("`kind'"=="") local kind "master"

    * kind() is documented as master|adaptation, so anything else is refused
    * rather than silently treated as master -- kind(adaptaton) would otherwise
    * build a master tree and say nothing.
    if !inlist("`kind'","master","adaptation") {
        di as err `"{p}kind() must be {bf:master} or {bf:adaptation}; you gave {bf:`kind'}.{p_end}"'
        exit 198
    }

    * ---- config/folderplan.yml, transcribed --------------------------------
    if ("`plan'"=="default") {
        local p_data "Original Stata SPSS R Other"
        local p_doc  "Questionnaires Reports Technical"
    }
    else if ("`plan'"=="ihsn2014") {
        local p_data "Original Stata Other"
        local p_doc  "Questionnaires Reports Technical"
        if ("`kind'"=="adaptation") {
            local p_data "Harmonized"
            local p_doc  ""
        }
    }
    else if ("`plan'"=="minimal") {
        local p_data ""
        local p_doc  ""
    }
    else {
        di as err `"{p}plan() must be {bf:default}, {bf:ihsn2014} or {bf:minimal}; you gave {bf:`plan'}. To vary one axis, keep the plan and pass {bf:data()} or {bf:doc()}.{p_end}"'
        exit 198
    }

    * data() and doc() replace ONE axis each, so plan(ihsn2014) data(Original
    * Stata SPSS) is Annex 1's tree with SPSS promoted rather than a
    * restatement of eleven folders. An override is recorded: a convention that
    * can be departed from without leaving a trace is not a convention.
    local deviation 0
    if (`"`data'"'!="") {
        local p_data `"`data'"'
        local deviation 1
    }
    if (`"`doc'"'!="") {
        local p_doc `"`doc'"'
        local deviation 1
    }

    * A plan names LEAVES, not paths. Rejecting separators matters more than it
    * looks: the root is usually a network share, so a name carrying a path
    * would write outside the vintage folder.
    foreach nm of local p_data {
        _dtlb_folderplan_leafok `"`nm'"'
    }
    foreach nm of local p_doc {
        _dtlb_folderplan_leafok `"`nm'"'
    }

    * Data/, Doc/ and Programs/ are structural: always created, never listed in
    * a plan. Parents come first so a caller can mkdir the list in order.
    local subs `""Data""'
    foreach nm of local p_data {
        local subs `"`subs' "Data/`nm'""'
    }
    local subs `"`subs' "Doc""'
    foreach nm of local p_doc {
        local subs `"`subs' "Doc/`nm'""'
    }
    local subs `"`subs' "Programs""'

    return local plan        "`plan'"
    return local kind        "`kind'"
    return local data_leaves `"`p_data'"'
    return local doc_leaves  `"`p_doc'"'
    return local subfolders  `"`subs'"'
    return scalar deviation = `deviation'

end

*******************************************************************************
* A folder name is a single leaf token.
*******************************************************************************
capture program drop _dtlb_folderplan_leafok
program define _dtlb_folderplan_leafok
    version 15
    args nm
    if (`"`nm'"'=="") {
        di as err "a folder name cannot be blank."
        exit 198
    }
    if (strpos(`"`nm'"',"/") | strpos(`"`nm'"',"\") | strpos(`"`nm'"',"..")) {
        di as err `"{p}{bf:`nm'} is not a folder name: data() and doc() name LEAVES under Data/ and Doc/, so a value containing {bf:/}, {bf:\} or {bf:..} is refused. The library root is normally a network share, and a name carrying a path would write outside the vintage folder.{p_end}"'
        exit 198
    }
end
