{
    print "farkos 1.1.0".

    local pack is "0:/p/".
    local home is "0:/n/" + ship:name + "/".
    local path is list(home, home + "../", pack).

    local pending_modules is stack().
    local module_values is lex().

    function st {
        parameter data_file.

        if homeconnection:isconnected {
            copypath(data_file, home+data_file).
        }
    }

    function ev {
        parameter message.

        hudtext(message,5,2,24,WHITE,true).
    }

    module_values:add("farkos", lex("st",st@,"ev",ev@)).

    global import is {
        parameter module_name.

        if imported(module_name) {
            return module_values[module_name].
        }

        try_copy_from_path(module_name).
        try_import_from_local(module_name).
        return module_values[module_name].
    }.

    global export is {
        parameter module_value.

        local module_name is module_being_imported().
        module_values:add(module_name, module_value).
    }.

    function module_being_imported {
        return pending_modules:pop().
    }

    function imported { parameter module_name.
        return module_values:haskey(module_name).
    }

    function try_copy_from_path {
        parameter module_name.

        if not homeconnection:isconnected return.
        for folder in path {
            local copy_from is folder + module_name.
            if exists(copy_from) {
                compile copy_from+".ks" to copy_from+".ksm".
                copypath(copy_from+".ksm", "").
                return.
            }
        }
    }

    function try_import_from_local {
        parameter module_name.

        if exists(module_name) {
            pending_modules:push(module_name).
            runpath(module_name).
        }
    }
}