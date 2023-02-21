local pkg is lex().

local home is "0:/home/" + ship:name + "/".
local pkgd is "0:/pkg/".
local path is list(home, home + "../", pkgd).

function clamp { parameter lo, hi, v.
    if v<lo return lo.
    if v>hi return hi.
    return v. }

function import { parameter n.          // import the named package.
    if pkg:haskey(n) return pkg[n].
    local ret is lex().
    pkg:add(n, ret).
    for d in path if exists(d+n) {
        runpath(d+n, ret). return ret. }
    print "import: missing "+n.
    return ret. }

function eval { parameter v.           // resolve lazy evaluations.
    until not v:istype("Delegate")
        set v to v:call().
    return v.
}

function ua { parameter ang. // map ang into the 0..360 range.
    return mod(360+mod(ang, 360),360).
}

function sa { parameter ang. // map ang into the -180..+180 range
    set ang to mod(ang, 360).
    if ang < 180 set ang to ang + 180.
    if ang > 180 set ang to ang - 180.
    return ang.
}

function sgn { parameter v.
    if v>0 return 1.
    if v<0 return -1.
    return 0.
}

function assert { parameter cond.
    return choose 0 if cond else 1/0.
}

global nothing is { }.
global always is { return true. }.
global zero is { return 0. }.
