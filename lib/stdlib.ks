global libdir is "0:/lib/".
global homedir is "0:/home/" + ship:name + "/".
global dirpath is list(homedir, homedir + "../", libdir).
local package_ran is UniqueSet().
function clamp { parameter lo, hi, val.
    if val > hi set val to hi.
    if val < lo set val to lo.
    return val.
}
function say {
    parameter message.
    parameter do_echo is true.
    if message:istype("List") for m in message say(m, do_echo).
    else hudtext(message,5,2,24,WHITE,do_echo).
}
function findfile { parameter filename.
    if not homeconnection:isconnected return filename.
    for dir in dirpath if exists(dir+filename) return dir+filename.
    return filename.
}
function updatefile { parameter filename.
    local source is findfile(filename+".ks").
    local object is filename+".ksm".
    compile source to object.
    return object.
}
function loadfile { parameter filename.
    if package_ran:contains(filename) return.
    package_ran:add(filename).
    runpath(updatefile(filename)).
}