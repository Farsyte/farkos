global persisted is lex().

local pfile is "persisted.ks".

if exists(pfile)  runpath(pfile).

// PERSIST: remember values across a reboot.
//
// Persisted values are saved in a "persisted.ks"
// script on the vessel. This script is run once
// if it is seen. As values are changed, we rewrite
// it so that we can restore values after boot.

// PERSIST_PUT: remember that this name has this value.

function persist_put { parameter name, value.
    set persisted[name] to value.
    persist_to_disk().
}

// PERSIST_CLR: forget what value this name had.

function persist_clr { parameter name.
    persisted:delete(name).
    persist_to_disk().
}

// PERSIST_GET: recall the persisted value of name.
// If it is not persisted, return the default.
// If returning the default and commit is true,
// store this default value as the persisted value.

function persist_get { parameter name, default is 0, commit is false.
    if persisted:haskey(name) return persisted[name].
    if commit return persist_put(name, default).
    return default.
}

function q { parameter v.
    if v:istype("String") set v to char(34)+v+char(34).
    return v.
}

// PERSIST_TO_DISK: record persisted values to vessel storage.

function persist_to_disk {
    if exists(pfile) deletepath(pfile).
    for k in persisted:keys
        log "set persisted["+q(k)+"] to "+q(persisted[k])+"." to pfile.
}
