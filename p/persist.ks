{
    local farkos is import("farkos").

    local persist is lex(
        "sync", sync@,
        "set", set@,
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

    // persist:set(name, value) -- set persisted value of name

    function set {
        parameter name, value.

        set persisted[name] to value.

        // persisted:add(name, value).
        sync().

        return value.
    }

    // persist:has(name) -- determine if name has a persisted value.

    function has {
        parameter name.

        return persisted:haskey(name).
    }

    // persist:get(name, default, doset) -- return persisted value for name.
    // the optional default argument is the value to return if the name
    // is not persisted; if unspecified, and no value is present, this
    // method will return zero. if the optional third parameter is set
    // to true, and no value is stored, the default will be persisted.

    function get {
        parameter name, default is 0, doset is false.

        if has(name) return persisted[name].
        if doset set persisted[name] to default.
        return default.
    }

}