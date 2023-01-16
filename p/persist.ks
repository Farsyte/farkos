{
    local farkos is import("farkos").

    local persist is lex(
        "sync", sync@,
        "set", set@,
        "has", has@,
        "get", get@,
        "reset", reset@).
    export(persist).

    local filename is "persist.json".

    local persisted is choose readjson(filename) if exists(filename) else lex().

    // completely reset all persisted data.
    function reset {
        persisted:clear().
        delete(filename).
    }

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
    }

    // persist:has(name) -- determine if name has a persisted value.

    function has {
        parameter name.

        return persisted:haskey(name).
    }

    // persist:get(name, default) -- return persisted value for name.
    // the optional default argument is the value to return if the name
    // is not persisted; if unspecified, and no value is stored, this
    // method will return zero.

    function get {
        parameter name, default is 0.

        return choose persisted[name] if has(name) else default.
    }

}