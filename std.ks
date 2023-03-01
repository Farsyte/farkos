@LAZYGLOBAL off.

local pkg is lex().

local home is "0:/home/" + ship:name + "/".
local pkgd is "0:/pkg/".
local dirs is list(home, home + "../", pkgd).

function clamp { parameter lo, hi, val.
    if val<lo return lo.
    if val>hi return hi.
    return val. }

function import { parameter n.          // import the named package.
    if pkg:haskey(n) return pkg[n].
    local ret is lex().
    pkg:add(n, ret).
    local d is "".
    for d in dirs if exists(d+n) {
        runpath(d+n, ret). return ret. }
    print "import: missing "+n.
    return ret. }

function eval { parameter val.           // resolve lazy evaluations.
    until not val:istype("Delegate")
        set val to val:call().
    return val. }

function ua { parameter ang. // map ang into the 0..360 range.
    return mod(360+mod(ang, 360),360). }

function sa { parameter ang. // map ang into the -180..+180 range
    set ang to mod(ang, 360).
    if ang < 180 set ang to ang + 180.
    if ang > 180 set ang to ang - 180.
    return ang. }

function sgn { parameter val.
    if val>0 return 1.
    if val<0 return -1.
    return 0. }

function assert { parameter cond.
    return choose 0 if cond else 1/0. }

function safe_sqrt { parameter val.
    return sqrt(max(0,val)). }

global nothing is { }.
global always is { return true. }.
global zero is { return 0. }.

wait until ship:unpacked.
