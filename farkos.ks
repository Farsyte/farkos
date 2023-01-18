{
    local farkos is lex(
        "st",st@,
        "ev",ev@,
        "term", term@,
        "error", error@,
        "debug", debug@,
        "panic",panic@).

    // Add methods here that SHOULD HAVE BEEN
    // part of the standard kOS library.

    // clamp(lo, hi, val): clip val to be within lo..hi inclusive range.
    global clamp is { parameter lo, hi, val.
        return max(lo, min(hi, val)).
    }.

    local pack is "0:/p/".
    local home is "0:/n/" + ship:name + "/".
    local path is list(home, home + "../", pack).

    local pending_modules is stack().
    local module_values is lex("farkos", farkos).

    // term(h,w): open the console terminal.
    // optional parameters can be used to set the size.
    function term {
        parameter h is terminal:height.
        parameter w is terminal:width.
        set terminal:height to h.
        set terminal:width to w.
        if career():candoactions
            core:doAction("open terminal", true).
    }

    // error(m): Report an error.
    // This opens a terminal, paints the message onto
    // the hud at top-dead-center and large, and also
    // prints it into the terminal.
    function error { parameter m.
        term().
        hudtext(m,5,2,32,RED,true).
    }

    // pathfind(name): find name in path.
    // returns the directory, or "" if it is not found.
    function pathfind { parameter name.
        for folder in path {
            local filepath is folder + name.
            if exists(filepath) {
                return folder.
            }
        }
        error("missing from path: "+name).
        return "".
    }

    // source(dir,name): path to source file for module found in the path.
    function source { parameter dir, module.
        return dir+module+".ks".
    }

    // object(dir,name): path to object file for module found in the path.
    function object { parameter dir, name.
        return "0:/ksm/"+name+".ksm".
    }

    // trycompile(src, obj): attempt to compile src into obj.
    // returns true if obj is created. if it is not, an error
    // is displayed and it returns false.
    function trycompile { parameter src, obj.
        deletepath(obj).
        compile src to obj.
        if exists(obj) return true.
        error("compile "+src+" to "+obj+" FAILED.").
        return false.
    }

    // trycopy(src, dst): attempt to copy src to dst.
    // does nothing if asked to copy a file onto itself.
    // deletes dst before starting. returns true if dst
    // was successfully created. If it was not, shows
    // an error message and returns false.
    // If the source does not exist, shows an error message
    // and returns false.
    function trycopy { parameter src, dst.
        if src = dst return true.
        if exists(dst) deletepath(dst).
        if not exists(src) { error("trycopy: no source at "+src). return false. }
        copypath(src, dst).
        if exists(dst) return true.
        error("copypath "+src+" to "+dst+" FAILED.").
        return false.
    }

    // tryupdate(name): try to obtain updated module of this name.
    // returns true if the source was found in the archive, if the
    // compilation was successful, and the object is successfully
    // copied to the local volume.
    function tryupdate { parameter name.
        local dir is pathfind(name).
        if dir = "" return false.
        local src is source(dir, name).
        //return trycopy(src, name). // uncomment this for better debugging.
        local obj is object(dir, name).
        return trycompile(src, obj) and trycopy(obj, name).
    }

    // tryimport(name): try to import module name from local storage.
    // caller must assure the module is present. Returns true if the
    // module exported a value. If not, it shows an error message
    // and returns false.
    function tryimport { parameter name.
        pending_modules:push(name).
        runpath(name).
        if module_values:haskey(name) return true.
        error("module did not export self: " + name).
        return false.
    }

    // debug(e,h,w): open the terminal and pause KSP. When unpaused,
    // wait another five seconds before returning to allow the
    // flight engineer to interrupt the code.
    // Required 1st parameter is a message to show with error().
    // Optional 2nd parameter is terminal height.
    // Optional 3rd parameter is terminal width.
    function debug {
        parameter e.
        parameter h is terminal:height.
        parameter w is terminal:width.

        term(h,w).
        farkos:error(e).
        kuniverse:pause().
        panic(e).
    }

    // panic(e,h,w): Display an error and reboot.
    // Provides a brief window for engineer to interrupt.
    // Required 1st parameter is a message to show with error().
    // Optional 2nd parameter is terminal height.
    // Optional 3rd parameter is terminal width.
    function panic {
        parameter e.
        parameter h is terminal:height.
        parameter w is terminal:width.

        term(h,w).
        farkos:error(e).
        farkos:error("Rebooting in 5 seconds.").
        wait 5.
        REBOOT.
    }

    global import is { parameter name.
        if module_values:haskey(name)
            return module_values[name].
        until tryupdate(name) { debug("import: copy failed."). }
        until tryimport(name) { debug("import: exec failed."). }
        return module_values[name].
    }.

    global export is { parameter value.
        local name is pending_modules:pop().
        set module_values[name] to value.
    }.

    // st(name): store the named file to the home archive.
    // returns true if the copy was successful.
    function st {
        parameter name.
        return homeconnection:isconnected
            and trycopy(name, home+name).
    }

    // ev(name): log an event message.
    // draws the message onto the HUD, top dead center, in white.
    // Also echoes it to the console terminal, unless the optional
    // second parameter is set to true.
    function ev {
        parameter message, echo is true.
        hudtext(message,5,2,24,WHITE,echo).
    }
}