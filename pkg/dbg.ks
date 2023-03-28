@LAZYGLOBAL off.
{   parameter dbg. // debug package.

    dbg:add("term", {
        parameter w is terminal:width.
        parameter h is terminal:height.
        set terminal:height to h.
        set terminal:width to w.

        // TERMINAL:WIDTH               terminal width in characters
        // TERMINAL:HEIGHT              terminal height in characters
        // TERMINAL:REVERSE             swap foreground and background colors
        // TERMINAL:VISUALBEEP          turn beeps into screen flashes
        // TERMINAL:BRIGHTNESS          adjust brightness [0..1]
        // TERMINAL:CHARHEIGHT          height of a character in pixels
        // TERMINAL:CHARWIDTH           width of a character in pixels
        // TERMINAL:INPUT               object for obtaining "raw-mode" input from terminal
        //
        // RESIZEWATCHERS
        //
        // HASSUFFIX INHERITANCE ISSERIALIZABLE ISTYPE SUFFIXNAMES TOSTRING TYPENAME

        if career():candoactions
            core:doAction("open terminal", true). }).

    local pr_d is lex(      // map typename to formatter
        "Boolean",      { parameter value.
            return choose "TRUE" if value else "FALSE". },
        "String",       { parameter value.
            return char(34)+value+char(34). },
        "Scalar",       { parameter value.
            return round(value, 3). },
        "List",         { parameter value.
            local ret is list().
            for e in value
                ret:add(dbg:pr(e)).
            return "["+ret:join(" ")+"]". },
        "ListValue`1",         { parameter value.
            local ret is list().
            for e in value
                ret:add(dbg:pr(e)).
            return "["+ret:join(" ")+"]". },
        "Lexicon",       { parameter value.
            local ret is list().
            local nl is "". // char(10).
            local nlin is " ". // nl+"  ".
            for k in value:keys
                ret:add(dbg:pr(k)+" => "+dbg:pr(value[k])).
            return "LEX{"+nlin+ret:join(","+nlin)+nl+"}". },
        "Vector",       { parameter value.
            local n is value:normalized.
            return dbg:pr(value:mag)+"*"+dbg:pr(list(n:x, n:y, n:z)). },
        "Direction",    { parameter value.
            return "[y="+dbg:pr(value:yaw)
                +" p="+dbg:pr(value:pitch)
                +" r="+dbg:pr(value:roll)+"]". },
        "TimeSpan",     { parameter value.
            local ret is list().
            if value:year>0 ret:add(value:year+"y").
            if value:day>0 ret:add(value:day+"d").
            if value:hour>0 ret:add(value:hour+"h").
            if value:minute>0 ret:add(value:minute+"m").
            local sfff is value:second + round(value:seconds - floor(value:seconds), 3).
            ret:add(sfff+"s"). return ret:join(" "). },
        "UserDelegate", { parameter value. return "@"+dbg:pr(value()). } ).

    dbg:add("pr", { parameter value.            // useful printable representation
        local t is value:typename.
        if pr_d:haskey(t) return pr_d[t](value).
        return "<"+value:typename+"> "+value:tostring. }).

    dbg:add("pv", { parameter name, value.      // print name and representation of value
        print name+": "+dbg:pr(value). }).
}
