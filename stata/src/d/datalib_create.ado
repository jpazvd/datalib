*******************************************************
* datalib_create: contract v1 vintage-tree creator (check-mode by default)
* Author: Joao Pedro Azevedo
*! Version: 0.9.34      Date: <2026-08-12>
* Without -create-, reports the paths that WOULD be made (zero side effects).
* With -create-, builds the vintage folder and its subfolders from a named
* plan; data() and doc() vary one axis each. vm()/va() resolve -latest-/-next-
* by reading the survey folder; see datalib_create.sthlp.
*******************************************************

capture program drop datalib_create
program define datalib_create, rclass

    version 15

    syntax , country(string) year(string) survey(string)  ///
        [                                                  ///
            KINd(string)                                   ///
            ADAPtation(string)                             ///
            collection(string)                             ///
            VM(string)                                     ///
            VA(string)                                     ///
            master_version(string)                         ///
            adaptation_version(string)                     ///
            create                                         ///
            root(string)                                   ///
            PLAn(string)                                   ///
            DATa(string)                                   ///
            DOC(string)                                    ///
            PLACEholder                                    ///
            PLACEHOLDERName(string)                        ///
        ]

    quietly {
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }
        local country = upper(trim("`country'"))
        local survey  = upper(trim("`survey'"))
        local collection = upper(trim("`collection'"))
        * ---- option synonyms -------------------------------------------------
        * vm()/va() and the -adaptation- flag are what every other command in
        * the family takes (datalib, _dtlb_load, _dtlb_mkdir, ibge). This command
        * was the only one spelling them kind()/master_version()/adaptation_
        * version(), so those are kept as synonyms and the family names are
        * primary. Giving both spellings of the same thing is refused rather
        * than silently resolved one way.
        if ("`vm'"!="" & "`master_version'"!="") {
            di as err "vm() and master_version() are the same option; give one."
            exit 198
        }
        if ("`va'"!="" & "`adaptation_version'"!="") {
            di as err "va() and adaptation_version() are the same option; give one."
            exit 198
        }
        if ("`vm'"=="") local vm "`master_version'"
        if ("`va'"=="") local va "`adaptation_version'"

        * adaptation() carries the NAME in position 8 -- ECAPOV, HLT, SILC, HOI.
        * That is Annex 1's own word for it ("HHHH for the name of the
        * adaptation"); contract v1 calls the same thing a collection. Both
        * spellings are accepted, they must agree, and either one implies that
        * an adaptation folder is what is being created.
        local adaptation = upper(trim("`adaptation'"))
        if ("`adaptation'"!="" & "`collection'"!="" & "`adaptation'"!="`collection'") {
            di as err `"{p}adaptation(`adaptation') and collection(`collection') name the same thing -- position 8 of the vintage folder -- and disagree. Give one.{p_end}"'
            exit 198
        }
        if ("`collection'"=="") local collection "`adaptation'"
        if ("`collection'"!="") {
            if ("`kind'"!="") & (lower(trim("`kind'"))!="adaptation") {
                di as err "adaptation()/collection() contradicts kind(`kind')."
                exit 198
            }
            local kind "adaptation"
        }
        if ("`kind'"=="") local kind = cond("`collection'"!="", "adaptation", "master")
        local kind = lower(trim("`kind'"))
        if ("`kind'"=="adaptation") & ("`collection'"=="") {
            di as err "kind(adaptation) requires collection()."
            exit 198
        }

        local svyfld "`country'_`year'_`survey'"
        local svydir "`root'/`country'/`svyfld'"

        * ---- which vintage number -------------------------------------------
        * A vintage being CREATED defaults to -next-; a vintage being REFERENCED
        * defaults to -latest-. The two cases sit side by side in one command:
        *
        *   master folder      vm is the vintage being created   -> next
        *   adaptation folder  vm names the master being adapted -> latest
        *                      va is the vintage being created   -> next
        *
        * Defaulting a folder you are about to create to -latest- would point
        * mkdir at an already-published vintage, and a published master is
        * immutable: "when a new version comes, the previous one(s) must be kept
        * too" (Annex 1). Both keywords stay available, so vm(latest) is how you
        * deliberately backfill a subfolder into an existing vintage.
        local vm_auto = ("`vm'"=="")
        local va_auto = ("`va'"=="")
        if ("`vm'"=="") local vm = cond("`kind'"=="adaptation", "latest", "next")
        if ("`va'"=="") local va "next"

        _dtlb_create_vres, dir("`svydir'") prefix("`svyfld'_v") suffix("_M") value("`vm'")
        local master_version "`r(v)'"

        if ("`kind'"=="adaptation") {
            _dtlb_create_vres, dir("`svydir'") value("`va'") ///
                prefix("`svyfld'_`master_version'_M_v") suffix("_A_`collection'")
            local adaptation_version "`r(v)'"

            * ---- the one genuinely ambiguous case ----------------------------
            * Adaptations are numbered WITHIN a master, so "the next ECAPOV" is
            * only well defined once you know which master. When this adaptation
            * already exists under a DIFFERENT master from the one vm() resolved
            * to, defaulting silently starts a second lineage at v01 next to an
            * existing v03 -- which reads as a duplicate and is very hard to
            * notice later.
            *
            * It stops rather than prompts. A modal prompt cannot be answered by
            * the conformance suite or by a deposit script, and this command has
            * to run unattended; a refusal that names the candidates works in
            * batch and interactively, and leaves the reasoning in the log.
            * The candidates are clickable, which is this package's existing
            * idiom for "choose one of these" (see _foldernav, datalib_explorer).
            if (`vm_auto') & (`va_auto') {
                _dtlb_create_amast, dir("`svydir'") svyfld("`svyfld'") collection("`collection'")
                local carriers "`r(masters)'"
                local others : list carriers - master_version
                local others = trim("`others'")
                if ("`others'"!="") {
                    di as err `"{p}{bf:`collection'} adaptations already exist under a different master: {bf:`others'}. This call would resolve to {bf:`master_version'} and create {bf:`adaptation_version'} there, starting a second numbering beside the existing one.{p_end}"'
                    di as err `"{p}Adaptation vintages are numbered within a master, so say which master you mean:{p_end}"'
                    foreach mv of local carriers {
                        _dtlb_create_vres, dir("`svydir'") value("next") ///
                            prefix("`svyfld'_`mv'_M_v") suffix("_A_`collection'")
                        local nxt "`r(v)'"
                        di as err `"{p 8 8 2}{stata datalib_create, country(`country') year(`year') survey(`survey') adaptation(`collection') vm(`mv') va(`nxt') create: continue `mv' -> `nxt'}{p_end}"'
                    }
                    _dtlb_create_vres, dir("`svydir'") value("next") ///
                        prefix("`svyfld'_`master_version'_M_v") suffix("_A_`collection'")
                    di as err `"{p 8 8 2}{stata datalib_create, country(`country') year(`year') survey(`survey') adaptation(`collection') vm(`master_version') va(`r(v)') create: start a new lineage under `master_version'}{p_end}"'
                    exit 198
                }
            }
        }
        if ("`kind'"=="adaptation") local vfolder "`svyfld'_`master_version'_M_`adaptation_version'_A_`collection'"
        else                        local vfolder "`svyfld'_`master_version'_M"
        local base "`root'/`country'/`svyfld'/`vfolder'"

        mata: st_local("existed", strofreal(direxists(st_local("base"))))

        * ---- the folder plan -------------------------------------------------
        * The plan is DATA, not code. It was a single hard-coded literal, which
        * is why the three Doc/ subfolders specified in the 2014 source note
        * (Annex 1, ECAPOV Harmonization Guideline) were never created by any
        * version of this command.
        *
        *   default   the documented convention (README, Data Organization)
        *   ihsn2014  Annex 1 verbatim: no Data/R, no Data/SPSS, and the
        *             adaptation keeps its harmonised files in Data/Harmonized
        *   minimal   Data/ + Doc/ + Programs/ only
        *
        * data() and doc() vary one axis of the chosen plan.
        if ("`plan'"=="") local plan "default"
        local plan = lower(trim("`plan'"))

        * The plan names LEAVES, not paths: the Data/, Doc/ and Programs/
        * parents are structural and always created. That is what lets data()
        * and doc() vary one axis without restating the whole tree, and it
        * stops a caller passing a path where a folder name belongs.
        if ("`plan'"=="default") {
            local p_data "Original Stata SPSS R Other"
            local p_doc  "Questionnaires Reports Technical"
        }
        else if ("`plan'"=="ihsn2014") {
            local p_data "Original Stata Other"
            local p_doc  "Questionnaires Reports Technical"
            * Annex 1 gives the adaptation a different Data/ and a bare Doc/.
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

        * data() and doc() override ONE axis each, so plan(ihsn2014) data(Original
        * Stata SPSS) is Annex 1's tree with SPSS promoted -- composable, rather
        * than restating eleven folders to change one. An override is recorded as
        * a deviation: a convention that can be departed from without leaving a
        * trace is not a convention.
        local deviation 0
        if (`"`data'"'!="") {
            local p_data `"`data'"'
            local deviation 1
        }
        if (`"`doc'"'!="") {
            local p_doc `"`doc'"'
            local deviation 1
        }

        * A folder name is a single leaf token. Rejecting separators and ..
        * matters more than it looks: the root is usually a network share, so a
        * name carrying a path would write outside the vintage folder.
        foreach nm of local p_data {
            _dtlb_create_leafok `"`nm'"'
        }
        foreach nm of local p_doc {
            _dtlb_create_leafok `"`nm'"'
        }

        local subs `""Data""'
        foreach nm of local p_data {
            local subs `"`subs' "Data/`nm'""'
        }
        local subs `"`subs' "Doc""'
        foreach nm of local p_doc {
            local subs `"`subs' "Doc/`nm'""'
        }
        local subs `"`subs' "Programs""'

        * ---- placeholders ----------------------------------------------------
        * Deliberately NOT called .gitkeep by default: a vintage folder on Z:
        * is not a git working tree, and nothing there is being kept for git.
        * The reason to write one is that robocopy (which the Z: sync toolbox in
        * scripts/ps uses) does not carry empty directories without /E, and an
        * empty Doc/Technical/ is a claim -- "we looked, there is none" -- that
        * should survive a sync. Name it .gitkeep only for a tree that really is
        * in git, such as the committed test fixtures.
        if ("`placeholdername'"!="") local placeholder "placeholder"
        if ("`placeholdername'"=="") local placeholdername ".datalib-keep"

        if ("`create'"!="") {
            capture mkdir "`root'/`country'"
            capture mkdir "`root'/`country'/`svyfld'"
            capture mkdir "`base'"
            * Every mkdir is captured because "already exists" is not an error
            * here -- but that also swallows an unreachable root, a read-only
            * share and a name the filesystem rejects, so the command reported
            * success having written nothing. Confirm the vintage folder rather
            * than infer it: -latest-/-next- resolve by reading this tree back,
            * so a silent failure here mis-numbers every later call.
            mata: st_local("made", strofreal(direxists(st_local("base"))))
            if ("`made'"!="1") {
                di as err `"{p}could not create {bf:`base'}. Check that {bf:`root'} exists and is writable.{p_end}"'
                exit 601
            }
            foreach s in `subs' {
                capture mkdir "`base'/`s'"
                if ("`placeholder'"!="") {
                    capture confirm file "`base'/`s'/`placeholdername'"
                    if (_rc) {
                        tempname ph
                        capture file open `ph' using "`base'/`s'/`placeholdername'", write text replace
                        if (_rc==0) {
                            file write `ph' "datalib: this folder is part of the vintage structure and is intentionally kept, empty or not." _n
                            file close `ph'
                        }
                    }
                }
            }
            return local created = cond("`existed'"=="1", "0", "1")
        }
        else {
            return local created "0"
        }

        return local plan        "`plan'"
        return local subfolders  `"`subs'"'
        return scalar deviation = `deviation'

        return local existed        "`existed'"
        return local root           "`root'"
        return local survey_folder  "`svyfld'"
        return local vintage_folder "`vfolder'"
        return local path           "`base'"
        return local data_stata     "`base'/Data/Stata"
        return local data_original  "`base'/Data/Original"
        return local data_r         "`base'/Data/R"
        return local doc            "`base'/Doc"
        return local programs       "`base'/Programs"
    }

end

*******************************************************
* Leaf-name guard. A subfolder name is one token: no path separators, no
* parent references, not empty. The library root is normally a network
* share, so a name carrying a separator would create folders outside the
* vintage folder entirely -- silently, because every mkdir here is captured.
*******************************************************
capture program drop _dtlb_create_leafok
program define _dtlb_create_leafok
    version 15
    args nm
    local bad = 0
    if (strpos(`"`nm'"', "/")  > 0) local bad 1
    if (strpos(`"`nm'"', "\")  > 0) local bad 1
    if (strpos(`"`nm'"', "..") > 0) local bad 1
    if (trim(`"`nm'"') == "")       local bad 1
    if (`bad') {
        di as err `"{p}{bf:`nm'} is not a usable subfolder name. data() and doc() take plain folder names separated by spaces -- for example {bf:data(Original Stata SPSS)} -- not paths.{p_end}"'
        exit 198
    }
end

*******************************************************
* Resolve a vintage number: an explicit value, or the keyword -latest- or
* -next- read off the disk.
*
* prefix/suffix rather than a glob, because the number has to be EXTRACTED,
* not merely matched: the vintage is whatever sits between them. -: dir-
* lowercases directory names on Windows, so every comparison is done in
* upper case -- matching the mixed-case name as returned would find nothing
* and silently answer v01, creating a second "first" vintage beside an
* existing one.
*******************************************************
capture program drop _dtlb_create_vres
program define _dtlb_create_vres, rclass
    version 15
    syntax , DIR(string) PREfix(string) SUFfix(string) VALue(string)

    local val = lower(trim("`value'"))

    if !inlist("`val'","latest","next") {
        if (substr("`val'",1,1)=="v") local val = substr("`val'",2,.)
        capture confirm integer number `val'
        if _rc {
            di as err `"{p}vm() and va() take a vintage number such as {bf:01} or {bf:v01}, or the keyword {bf:latest} or {bf:next}. You gave {bf:`value'}.{p_end}"'
            exit 198
        }
        local nn : display %02.0f `val'
        return local v "v`nn'"
        exit
    }

    local PRE = upper("`prefix'")
    local SUF = upper("`suffix'")
    local lp  = length("`PRE'")
    local ls  = length("`SUF'")

    local max = 0
    capture local names : dir "`dir'" dirs "*"
    foreach nm of local names {
        local NM = upper(`"`nm'"')
        local ln = length("`NM'")
        if (`ln' <= `lp' + `ls')                        continue
        if (substr("`NM'",1,`lp') != "`PRE'")           continue
        if (substr("`NM'",`ln'-`ls'+1,`ls') != "`SUF'") continue
        local mid = substr("`NM'",`lp'+1,`ln'-`lp'-`ls')
        capture confirm integer number `mid'
        if (_rc) continue
        if (real("`mid'") > `max') local max = real("`mid'")
    }

    if ("`val'"=="latest") {
        * Nothing on disk yet: the only sane "latest" is the first one.
        local n = cond(`max'==0, 1, `max')
    }
    else {
        local n = `max' + 1
    }
    local nn : display %02.0f `n'
    return local v     "v`nn'"
    return scalar max = `max'
end

*******************************************************
* Which masters already carry a given adaptation name. Returns the master
* vintage tokens (v01 v02 ...) in r(masters).
*******************************************************
capture program drop _dtlb_create_amast
program define _dtlb_create_amast, rclass
    version 15
    syntax , DIR(string) SVYfld(string) COLlection(string)

    local SV  = upper("`svyfld'")
    local CL  = upper("`collection'")
    local SUF = "_A_`CL'"
    local ls  = length("`SUF'")
    local lsv = length("`SV'")

    local out ""
    capture local names : dir "`dir'" dirs "*"
    foreach nm of local names {
        local NM = upper(`"`nm'"')
        local ln = length("`NM'")
        if (`ln' <= `lsv' + `ls')                       continue
        if (substr("`NM'",1,`lsv'+1) != "`SV'_")        continue
        if (substr("`NM'",`ln'-`ls'+1,`ls') != "`SUF'") continue
        * <SV>_vMM_M_vNN_A_<CL> : the master token is what precedes _M_.
        local rest = substr("`NM'",`lsv'+2,`ln'-`lsv'-1-`ls')
        local p = strpos("`rest'","_M_")
        if (`p'<2) continue
        local mv = substr("`rest'",1,`p'-1)
        if (substr("`mv'",1,1)!="V") continue
        local dd = substr("`mv'",2,.)
        capture confirm integer number `dd'
        if (_rc) continue
        * -vres- returns lowercase vNN; match that shape so the caller's
        * -list carriers - master_version- actually subtracts.
        local nn : display %02.0f real("`dd'")
        local mv "v`nn'"
        if (strpos(" `out' "," `mv' ")==0) local out "`out' `mv'"
    }
    return local masters = trim("`out'")
end
