{
    local farkos is import("farkos").

    local persist is lex(
        "sync", sync@,
        "put", put@, "set", put@, // "set" deprecated, use "put"
        "clr", clr@,
        "has", has@,
        "get", get@).
    export(persist).

    local filename is "persist.json".

    local persisted is choose readjson(filename) if exists(filename) else lex().

    //    Allow modules to have data that persists across reboots.
    //    Using a value that is not SERIALIZABLE is a coding error,
    //    and may cause the kOS program to crash.

    // persist:sync - store persisted data to vessel storage.

    function sync {
        writejson(persisted, filename).
    }

    // persist:put(name, value) -- put persisted value of name

    function put {
        parameter name, value.

        set persisted[name] to value.
        persist:sync().

        return value.
    }

    // persist:clr(name) -- remove persisted value of name
    function clr {
        parameter name.
        persisted:remove(name).
        persist:sync().
    }

    // persist:has(name) -- determine if name has a persisted value.

    function has {
        parameter name.

        return persisted:haskey(name).
    }

    // persist:get(name, default, doset) -- return persisted value for name.
    // the optional default argument is the value to return if the name
    // is not persisted; if unspecified, and no value is present, this
    // method will return zero. if the optional third parameter is put
    // to true, and no value is stored, the default will be persisted.

    function get {
        parameter name, default is 0, doset is false.

        if persist:has(name) return persisted[name].
        if doset return persist:put(name, default).
        return default.
    }

}