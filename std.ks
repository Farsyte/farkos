@LAZYGLOBAL off.                        // Standard Library: GLOBAL things for FarKOS packages.

{   // clean-up steps taken at every boot
    wait until ship:unpacked.
    clearvecdraws().
    clearscreen. }

global nothing is { }.
global always is { return true. }.
global zero is { return 0. }.

local package_registry is lex().        // map name to package lexicon

{   // global package_path, vessel_home.
    global package_path is list().
    global vessel_home is "0:/home/".
    package_path:add("0:/pkg/").
    for d in ship:name:split("-") {
        set vessel_home to vessel_home + d + "/".
        package_path:insert(0,vessel_home). } }

function clamp { parameter lo, hi, val.
    if val<lo return lo.
    if val>hi return hi.
    return val. }

function import { parameter n.          // import the named package.
    if package_registry:haskey(n) return package_registry[n].
    local ret is lex().
    package_registry:add(n, ret).
    local d is "".
    for d in package_path {
        local ks is d+n+".ks".
        if exists(ks) {
            runpath(ks, ret). return ret. } }
print "import: missing "+n.
    return ret. }

function eval { parameter val.          // resolve lazy evaluations.
    until not val:istype("Delegate")
        set val to val:call().
    return val. }

function ua { parameter ang.            // maintain 0 ≤ θ < 360
    return mod(360+mod(ang, 360),360). }

function sa { parameter ang.            // maintain -180 ≤ θ ≤ +180
    if ang < 0 return -sa(-ang).
    set ang to mod(ang, 360).
    if ang > 180 set ang to ang - 360.
    return ang. }

function sgn { parameter val.           // discard magnitude, keep sign
    if val>0 return 1.
    if val<0 return -1.
    return val. }                       // note: sgn(NaN) is NaN.

function assert { parameter cond.       // crash with traceback if condition false
    return choose 0 if cond else 1/0. } // note: unsafe(assert(false)) returns Inf.

function unsafe { parameter this.       // execute delegate allowing use of NaN
    local saved_safe is Config:SAFE.
    set Config:SAFE to false.
    local result is eval(this).
    set Config:SAFE to saved_safe.
    return result. }

function safe_sqrt { parameter val.     // sqrt(x) that returns 0 if x<0
    return sqrt(max(0,val)). }          // useful when x is only negative due to numerical errors
