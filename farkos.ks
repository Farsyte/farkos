{
    print "farkos 1.1.0".

    local pack is "0:/p/".
    local home is "0:/n/" + ship:name + "/".
    local path is list(home, home + "../", pack).

    local pending_modules is stack().
    local module_values is lex().

    local module_being_imported is {
        return pending_modules:pop().
    }.

    local imported is { parameter module_name.
        return module_values:haskey(module_name).
    }.

    local try_copy_from_path is {
        parameter module_name.

        if not homeconnection:isconnected return.
        for folder in path {
            local copy_from is folder + module_name.
            if exists(copy_from) {
                local object_folder is "0:/ksm/".
                local object_file is object_folder+module_name+".ksm".
                compile copy_from+".ks" to object_file.
                copypath(object_file, "").
                return.
            }
        }
    }.

    local try_import_from_local is {
        parameter module_name.

        if exists(module_name) {
            pending_modules:push(module_name).
            runpath(module_name).
        }
    }.

    local st is {
        parameter data_file.

        if homeconnection:isconnected {
            copypath(data_file, home+data_file).
        }
    }.

    local ev is {
        parameter message.

        hudtext(message,5,2,24,WHITE,true).
    }.

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

    module_values:add("farkos", lex("st",st,"ev",ev)).
}