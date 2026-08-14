*******************************************************
** _dl_require_stage: assert where the library root came from
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.1.0  2026-08-05
*******************************************************
* Backs -datalib_root, require()-. A do-file that must run against a named
* archive can say so in one line, instead of discovering on someone else's
* machine that it read a different library and produced differently-valued but
* identically-shaped output.
*
*   require(configured)  the root came from a stage the operator named:
*                        argument, global, env, config_generic, config_package
*   require(<stage>)     the root came from exactly that stage; several may be
*                        listed, space-separated
*
* An empty require() asserts nothing.
*******************************************************

capture program drop _dl_require_stage
program define _dl_require_stage

    version 15

    syntax , STAGE(string) [ REQUIRE(string) ]

    if (`"`require'"'=="") exit

    local want `"`require'"'
    if (trim(`"`require'"')=="configured") {
        local want "argument global env config_generic config_package"
    }

    local ok 0
    foreach w of local want {
        if ("`w'"=="`stage'") local ok 1
    }

    if (`ok'==0) {
        noi di as err `"{p}The datalib root resolved from stage {bf:`stage'}, but this script requires {bf:`require'}.{p_end}"'
        noi di as err `"{p}Name the library explicitly — {bf:datalib_root, root(}{it:path}{bf:) set} — or add a {bf:datalib:} key to your configuration block.{p_end}"'
        exit 198
    }

end
