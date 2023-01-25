// STDLIB REFACTOR 1
// Motivations:
// - I want to write software in a readable form
// - this sometimes means that KS files grow large
// - this means KSM files also grow
// - adding code to a package may risk older missions
// - also, the "persisted" file grows to hold state.
//
// Changes in behavior:
// - do not write KSM files to vessel storage.
// - just run the KS files from the archive


// "environment" variables.

global libdir is "0:/lib/".
global homedir is "0:/home/" + ship:name + "/".
global dirpath is list(homedir, homedir + "../", libdir).

local package_ran is UniqueSet().

function clamp { parameter lo, hi, val.
    return max(lo,min(hi,val)).
}

function say {
    parameter message.
    parameter do_echo is true.
    if message:istype("List") for m in message say(m, do_echo).
    else hudtext(message,5,2,24,WHITE,do_echo).
}

function pathdir { parameter filename.
    for dir in dirpath if exists(dir+filename) return dir.
    return "".
}

function findfile { parameter filename.
    return pathdir(filename)+filename.
}

function loadfile { parameter filename.
    if package_ran:contains(filename) return.
    set filename to findfile(filename).
    if exists(filename) {
        package_ran:add(filename).
        runpath(filename).
    } else say("loadfile: no "+filename).
}