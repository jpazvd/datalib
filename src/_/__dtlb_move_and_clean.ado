*******************************************************
* __dtlb_move_and_clean: copy every file from srcdir to dstdir; if
* `clean` is set, also remove the source files and (now empty)
* source directory. Without `clean`, the source files are left in
* place after the copy.
*
* Private to the datalib package.
*
* args:
*   srcdir    - source directory
*   dstdir    - destination directory
*   overwrite - if "overwrite", existing destination files are replaced;
*               otherwise the program refuses to clobber and exits 602.
*   clean     - if "clean", the source directory and its files are
*               removed once every file has been successfully copied;
*               otherwise both the source directory and its files are
*               left in place (the operation is a copy, not a move).
*
* The source directory is only removed if every file was copied
* successfully and `clean` was specified. On any copy failure the
* program exits with the first non-zero _rc it encountered.
*******************************************************
capture program drop __dtlb_move_and_clean
program define __dtlb_move_and_clean
    version 15
    args srcdir dstdir overwrite clean

    local files : dir "`srcdir'" files "*"
    local exitcode 0

    foreach f of local files {
        local src "`srcdir'/`f'"
        local dst "`dstdir'/`f'"

        if ("`overwrite'" == "overwrite") {
            cap copy "`src'" "`dst'", replace
            if (_rc != 0 & `exitcode' == 0) {
                local exitcode = _rc
                noi di as err "Could not copy `src' -> `dst' (_rc=" _rc ")."
            }
        }
        else {
            cap confirm file "`dst'"
            if (_rc == 0) {
                if (`exitcode' == 0) local exitcode 602
                noi di as err "Destination file already exists: `dst'. Specify overwrite to replace existing files."
            }
            else {
                cap copy "`src'" "`dst'"
                if (_rc != 0 & `exitcode' == 0) {
                    local exitcode = _rc
                    noi di as err "Could not copy `src' -> `dst' (_rc=" _rc ")."
                }
            }
        }
    }

    if (`exitcode' != 0) {
        noi di as err "Source directory not cleaned because one or more files were not copied."
        exit `exitcode'
    }

    if ("`clean'" == "clean") {
        __dtlb_rmdir "`srcdir'"
    }
end
