@LAZYGLOBAL off.
{   parameter nv is lex(). // nonvolatile storage.

    local nvram is lex().
    local quot is char(34).

    // Nonvolatile storage: data that survives a reboot.
    //
    // Observation: storage capacity used only counts the contents
    // of the files, so directories and long filenames are free.
    //
    // Chosen approach: use the name of the nonvolatile as the filename,
    // and store a "serialized" value.
    //
    // Naming Notes:
    //   currently, the name provided by the caller is exactly the name
    //   used in storage, so "target/orbit/inclination" is a valid name
    //   for a nonvolatile item. This also means that you can not have
    //   that item, and also have "target" as an item, because "target"
    //   is a directory in storage. This may change.
    //
    //   Also note, this means that if you nv:clr("target") then all
    //   of the items in the "target/" directory in storage will be
    //   erased. Currently, these are not erased from the lexicon
    //   that memoizes the values we know about this boot, which means
    //   we do need an exists() call to see if an item exists in
    //   storage before we can consider using the value in the lexicon.
    //
    // Simple serialization:
    //   prepend a '"' to a string to serialize it.
    //   encode a Body by encoding its name and prepending a "B"
    //   encode a Vessel by encoding its name and prepending a "V"
    //   just use the :tostring suffix for anything else
    //
    // Deserialization:
    //   Check the first character.
    //   if it is '"' then the result is the rest of the string.
    //   if it is 'B' then the rest is the name of the body
    //   if it is 'V' then the rest is the name of the vessel
    //   otherwise convert the string to a numerical value.
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

    local nv_enc_t is lex(                      // map type name to encoder
        "Scalar", { parameter val. return val:tostring. },
        "String", { parameter val. return quot+val. },
        "Vessel", { parameter val. return "V"+val:name. },
        "Body", { parameter val. return "B"+val:name. }).

    function nv_enc { parameter val.            // encode value for NV storage.
        local t is val:typename.
        return nv_enc_t[t](val). }

    function nv_dec { parameter s.              // decode value from NV storage.
        if s[0]=quot return s:remove(0,1).
        if s[0]="V" return vessel(s:remove(0,1)).
        if s[0]="B" return body(s:remove(0,1)).
        return s:tonumber(0). }

    local nv_read is { parameter name.          // read and deserialize data from file
        // benefit from memoization of known values as much as possible:
        // if the value is memoized, use it, rather than reading the file.
        if nvram:haskey(name) return nvram[name].
        local enc is nv_open(name):readall:string.
        local data is nv_dec(enc).
        set nvram[name] to data.
        return data. }.

    local nv_write is { parameter name, value.  // serialize value and write to file
        set value to eval(value).
        set nvram[name] to value.
        local enc to nv_enc(value).
        nv_creat(name):write(enc).
        return value. }.

    nv:add("get", { parameter name.             // get the value of the named nonvolatile.
        parameter default is 0.                 // default value to use if not set
        parameter commit is false.              // store the default if not set

        // Common case is that we have a value stored. If we do,
        // go get it. (memoization of the value is managed in nv_read).

        if nv:has(name) return nv_read(name).

        // If no value was stored, then use the default value,
        // which will be zero if it was not provided.
        // If the default value provided is a Delegate,
        // then call the delegate; this is useful when constructing
        // the default is relatively expensive, since this only
        // happens when necessary.

        set default to eval(default).

        // The optional third parameter, if set to true, causes
        // us to commit the default value we used back to the
        // nonvolatile storage.
        // memoization is updated in nv_write.

        if commit nv_write(name, default).
        return default. }).

    nv:add("has", { parameter name.             // see if this named nonvolatile is set
        return exists(name). }).

    nv:add("is", { parameter name, value.       // is this named nonvolatile set to this value?
        if not nv:has(name) return false.
        set value to eval(value).
        local stored is nv:get(name).
        return value:typename=stored:typename and value=stored. }).

    nv:add("put", { parameter name, data.       // store data in named nonvolatile.
        set data to eval(data).
        // it is worth a little time spent here to avoid
        // the longer process of encoding and writing the data
        // if the value has not actually changed.
        if not nv:is(name, data)                // elide the "not changed" case.
            nv_write(name, data).
        return data. }).

    nv:add("clr", { parameter name.             // erase the named nonvolatile.

        // it is perfectly OK to carry around stale data in the lexicon,
        // we do not need to remove (name) from it. This is important
        // especilaly in the case where (name) is a whole tree of related
        // data, such as target/orbit/<many things>.
        //
        // All we need to do is make (name) not exist in storage.

        if exists(name) deletepath(name). }).

}
