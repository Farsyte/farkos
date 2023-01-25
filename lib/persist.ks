// PERSIST refactor 1
// each time we change the persisted value of a name,
// append a line to the persisted script.
//
// Benefits:
// - less time spent deleting and rewriting the whole file
// - less risk of a reboot WHILE doing the above
//
// Risk:
// - rapidly changing peristed values fill local storage

local persist_lexi is lex().
local persist_disk is "persistent.ks".
local persist_disk_lines is 0.

// PERSIST package: remember values across a reboot.
//
// Persisted values are saved in a "persisted.ks"
// script on the vessel. This script is run once
// if it is seen. As values are changed, we rewrite
// it so that we can restore values after boot.

// PERSIST_HAS: true if name has a value persisted.

function persist_has { parameter name.
    return persist_lexi:haskey(name).
}

// PERSIST_IS: true if name has this value persisted.
// called from mission code that uses the name.

function persist_is { parameter name, value.
    return persist_has(name) and persist_lexi[name]=value.
}

// PERSIST_PUT: remember that this name has this value.
// called from mission code to update the value of a name.

function persist_put { parameter name, value.
    if not persist_is(name, value)
        persist_disk_add(name, value).
}

// PERSIST_CLR: forget what value this name had.

function persist_clr { parameter name.
    if persist_has(name)
        persist_disk_clr(name).
}

// PERSIST_GET: recall the persisted value of name.
// If there is no value persisted, return the default.
// If returning the default and commit is true,
// store this default value as the persisted value.

function persist_get { parameter name, default is 0, commit is false.
    if persist_has(name) return persist_lexi[name].
    if commit persist_disk_add(name, default).
    return default.
}

// P_ADD: [INTERNAL] set in-memory copy of persisted data.
// must be global because the persisted value script calls it.

function p_add { parameter name, value.
    set persist_lexi[name] to value.
}

// PERSIST_DISK_ADD: [INTERNAL] update persisted value which has changed
// please use persist_put, as each call to this method increases the
// use of local storage.
function persist_disk_add { parameter name, value.
    p_add(name, value).
    log "p_add("+quote(name)+", "+quote(value)+")." to persist_disk.
    set persist_disk_lines to persist_disk_lines + 1.
}

// P_DEL: [INTERNAL] clear in-memory copy of persisted data.
// must be global because the persisted value script calls it.

function p_del { parameter name.
    persist_lexi:delete(name).
}

// PERSIST_DISK_CLR: [INTERNAL] update persisted value which has changed
// please use persist_put, as each call to this method increases the
// use of local storage.

function persist_disk_clr { parameter name.
    p_del(name).
    log "p_del("+quote(name)+")." to persist_disk.
    set persist_disk_lines to persist_disk_lines + 1.
}

// QUOTE: quote the value if it is a string.

function quote { parameter v.
    if v:istype("Scalar") return v.
    if v:istype("String") return char(34)+v+char(34).
    return v.
}

// PERSIST_DISK_REWRITE: compact the persisted data store.

function persist_disk_rewrite {
    if exists(persist_disk)
        deletepath(persist_disk).
    set persist_disk_lines to 0.
    for k in persist_lexi:keys
        persist_disk_add(k, persist_lexi[k]).
}

// Actions taken during load of this package:
// - read the persisted data store
// - rewrite it with one line per persisted name.

if exists(persist_disk) {
    runpath(persist_disk).
    // persist_disk_rewrite().
}
