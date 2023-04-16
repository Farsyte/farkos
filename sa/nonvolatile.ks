@LAZYGLOBAL OFF.

// this code can be demonstrated via boot/sa.ks
// by setting the vessel name to demo/nonvolatile.

// Nonvolatile storage: value that survives a reboot.
//
// Because the built-in JSON stuff is way way way too verbose.
//
// Observation: storage capacity used only counts the contents
// of the files, so directories and long filenames are free.
//
// Design: one file in local storage for each stored item.
//
// Note: names are not case sensitive.
//
// Currently this package supports storing String and Scalar values.
// The current string encoding is '"' followed by the string.
// The current scalar encoding is whatever :TOSTRING returns.
// Operation is UNDEFINED if the value is neither String nor Scalar.
//
// TODO: #38 improve serialization of floating point value so it round-trips.

// select the prefix to use when encoding strings.

local quot is """".

// nv_enc(val): return the string encoding of the value.
// NOTE: floating point values may not perfectly round-trip.

local function nv_enc { parameter val.
    if val:istype("String")
        return quot+val.
    return val:tostring.
}

// nv_dec(enc): convert an encoded value back to the value.
// NOTE: floating point values may not perfectly round-trip.

local function nv_dec { parameter enc.
    if enc:startswith(quot)
        return enc:remove(0,quot:length).
    return enc:toscalar(0).
}

// nv_open(name): open the named file.
// Create it if it does not exist.

local function nv_open { parameter name.
    local f is open(name).
    if f:istype("Boolean") and not f
        set f to create(name).
    return f.
}

// nv_cache stores decoded values for names.
// NOTE: because nv_clr may clear many entries in storage,
// and clearing all matching entries in nv_cache takes time,
// we allow nv_cache to carry stale data, and just agree to
// not look at nv_cache until after checking exists(name).

local nv_cache is lex().

// nv_name(name): convert nonvolatile name to file name

local function nv_name { parameter name.
    // appending .nv assures that we can store values for
    // both "foo" and "foo/bar" as long as no smartalec
    // wants to store "foo" and "foo.nv/bar" ...
    return name + ".nv".
}

// nv_has(name): test to see if a value has been persisted for name.
global function nv_has { parameter name.
    if nv_cache:haskey[name] return true.
    local fn is nv_name(name).
    return exists(fn).
}

// nv_clr_dir(name): erase nonvolatiles under this name.
// that is, if name is "dest" this would clear out all the entries
// beginning "dest/" like "dest/ap" and "dest/pe".
global function nv_clr_dir { parameter name.

    // example that shows what should happen:
    //
    // starting condition is after these lines:
    //   nv_put("dest", 1).
    //   nv_put("dest/ap", 1).
    //   nv_put("dest/pe", 1).
    //
    // executing nv_clr_dir("dest") should erease dest/ap and dest/pe, but not dest.

    if exists(name) deletepath(name).

    local mat is name:tolower + "/".
    local keys is nv_cache:keys.
    local key is "".
    for key in keys
        if key:tolower:startswith(mat)
            nv_cache:remove(key).
}

// nv_clr(name): erase the named value from persisted storage.
global function nv_clr { parameter name.
    local fn is nv_name(name).
    if exists(fn) deletepath(fn).
    nv_cache:remove(name).
}

// nv_put(name, value): set the persisted value of name to value.
// update the cache, encode it as a string, and
// set the named storage to the encoded value.
//
// It is probably NOT SAFE to call nv_put from within a trigger
// for any data that is also updated from the main line.

global function nv_put { parameter name, value.

    // Avoid doing work if we know the value is not changing.
    //
    // Yes, "and" short-circuits. I want to very much emphasize
    // that each IF needs to pass before we even think about
    // evaluating the next one.

    if nv_cache:haskey(name)
        if value:typename=nv_cache[name]:typename
            if value=nv_cache[name]
                return value.
    set nv_cache[name] to value.

    local fn is nv_name(name).
    local enc to nv_enc(value).
    local f is nv_open(fn).
    f:clear().
    f:write(enc).
    return value.
}

// nv_get(name, def, commit): get the persisted value of the name.
// check the in-memory lexicon before looking at storage.
// if no persisted value is stored, use the def.
// if using the def and commit is set, store the def as the new value.
//
// caller may not want to always pay the cost to generate the def, so
// allow a Delegate to be passed; if we use the def, and it is a delegate,
// evalute the delegate and use its return value.

global function nv_get { parameter name, def is 0, commit is false.

    if nv_cache:haskey(name)
        return nv_cache[name].

    local fn is nv_name(name).
    if exists(fn) {
        local fo is nv_open(fn).
        local enc is fo:readall:string.
        local value is nv_dec(enc).
        set nv_cache[name] to value.
        return value.
    }

    if def:istype("Delegate") set def to def().
    if commit nv_put(name, def).
    return def.
}
