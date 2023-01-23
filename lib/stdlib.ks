local libdir is "0:/lib/".
local homedir is "0:/home/" + ship:name + "/".
local dirpath is list(homedir, homedir + "../", libdir).
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
    runpath(updatefile(filename)).
}