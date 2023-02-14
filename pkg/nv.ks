{   parameter nv is lex(). // nonvolatile storage.

    local nvram is lex().
    local q is char(34).

    // Nonvolatile storage: data that survives a reboot.
    //
    // Observation: storage capacity used only counts the contents
    // of the files, so directories and long filenames are free.
    //
    // Chosen approach: use the name of the nonvolatile as the filename,
    // and store a "serialized" value.
    //
    // Simple serialization:
    //   prepend a char(34) to a string to serialize it.
    //   just use the :tostring suffix for anything else
    //
    // Deserialization:
    //   if the first character is char(34), the value is
    //   the remainder of the string. Otherwise, convert the
    //   string to a number to get the numerical value.
    //
    // TODO: #38 improve serialization of floating point data so it round-trips.

    local nv_open is { parameter name.          // open file at path name
        if exists(name) return open(name).      // create if it does not exist
        return create(name). }.

    local nv_creat is { parameter name.         // create file at path name
        if not exists(name) return create(name).
        local f is open(name).                  // clear preexisting content
        f:clear().
        return f. }.

    local nv_read is { parameter name.          // read and deserialize data from file
        local enc is nv_open(name):readall:string.
        set data to choose enc:remove(0,1) if enc[0]=q else enc:tonumber(0).
        nvram:add(name, data).
        return data. }.

    local nv_write is { parameter name, value.  // serialize value and write to file
        set nvram[name] to value.
        local enc is choose q+value if value:istype("String") else value:tostring.
        nv_creat(name):write(enc).
        return value. }.

    nv:add("get", { parameter name.             // get the value of the named nonvolatile.
        parameter default is 0.                 // default value to use if not set
        parameter commit is false.              // store the default if not set

        if nvram:haskey(name) return nvram[name].
        if exists(name) return nv_read(name).
        if commit nv_write(name, default).
        return default. }).

    nv:add("has", { parameter name.             // see if this named nonvolatile is set
        return nvram:haskey(name) or exists(name). }).

    nv:add("is", { parameter name, value.       // is this named nonvolatile set to this value?
        if not nv:has(name) return false.
        local stored is nv:get(name).
        return value:typename=stored:typename and value=stored. }).

    nv:add("put", { parameter name, data.       // store data in named nonvolatile.
        if not nv:is(name, data)                // elide the "not changed" case.
            nv_write(name, data). }).

    nv:add("clr", { parameter name.             // erase the named nonvolatile.
        nvram:remove(name).
        if exists(name) deletepath(name). }). }
