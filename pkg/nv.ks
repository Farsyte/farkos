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

    // local NV_OPEN(name): open file at path name, create if it does not exist.
    local nv_open is { parameter name.
        if exists(name) return open(name).
        return create(name).
    }.

    // local NV_CREAT(name): create file at name. discard old content if it exists.
    local nv_creat is { parameter name.
        if not exists(name) return create(name).
        local f is open(name).
        f:clear().
        return f.
    }.

    // local NV_READ(name): read named nonvolatile data, deserialize it.
    local nv_read is { parameter name.
        local enc is nv_open(name):readall:string.
        set data to choose enc:remove(0,1) if enc[0]=q else enc:tonumber(0).
        nvram:add(name, data).
        return data.
    }.

    // local NV_WRITE(name, value): serialize value and write it to named nonvolatile
    local nv_write is { parameter name, value.
        set nvram[name] to value.
        local enc is choose q+value if value:istype("String") else value:tostring.
        nv_creat(name):write(enc).
        return value.
    }.

    // exported GET(name[,default[,commit]]): get the value of a named nonvolatile.
    // If no value stored, return the default.
    // Store the default if commit is requested and default is used.
    nv:add("get", { parameter name, default is 0, commit is false.
        if nvram:haskey(name) return nvram[name].
        if exists(name) return nv_read(name).
        if commit nv_write(name, default).
        return default.
    }).

    // exported HAS(name): return true if data is stored for named nonvolatile
    nv:add("has", { parameter name.
        return nvram:haskey(name) or exists(name).
    }).

    // exported IS(name): return true if the value of a named nonvolatile is this value.
    nv:add("is", { parameter name, value.
        if not nv:has(name) return false.
        local stored is nv:get(name).
        return value:typename=stored:typename and value=stored.
    }).

    // exported PUT(name, value): set the named nonvolatile to the given value.
    nv:add("put", { parameter name, data.
        if nv:is(name, data) return data.
        return nv_write(name, data).
    }).

    // exported CLR(name): remove any value stored for the named nonvolatile.
    nv:add("clr", { parameter name.
        nvram:remove(name).
        if exists(name) deletepath(name).
    }).
}
