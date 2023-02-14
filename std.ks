local pkg is lex().

local home is "0:/home/" + ship:name + "/".
local pkgd is "0:/pkg/".
local path is list(home, home + "../", pkgd).

// global IMPORT(n) imports package n
function import { parameter n.
    if pkg:haskey(n) return pkg[n].
    local ret is lex().
    pkg:add(n, ret).
    for d in path if exists(d+n) {
        runpath(d+n, ret). return ret. }
    print "import: missing "+n.
    return ret.
}