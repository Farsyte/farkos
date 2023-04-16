@LAZYGLOBAL off.
{   parameter dbg. // debug package.

    dbg:add("term", {
        parameter w is terminal:width.
        parameter h is terminal:height.
        // dbg:term(w,h) opens the Console and, if the optional width and height
        // are provided, sets its size.
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
            // Too simple.
            return choose "TRUE" if value else "FALSE". },
        "String",       { parameter value.
            // REALLY SIMPLE. A more complete version would sanitize
            // the value to make the output match a string literal with
            // the provided value.
            return char(34)+value+char(34). },
        "Scalar",       { parameter value.
            // For debug, all scalars are rounded to the nearest 0.001
            return round(value, 3). },
        "List",         { parameter value.
            // Render lists as bracketed comma separated renderings of
            // each element. No attempt is made to break it across lines.
            local ret is list().
            for e in value
                ret:add(dbg:pr(e)).
            return "["+ret:join(" ")+"]". },
        "ListValue`1",         { parameter value.
            // in at least one case, I had a thing with type <ListValue`1>
            // so this is temporary. Better: if the type is not found,
            // scan the keys to see if we are a subtype. not yet written.
            local ret is list().
            for e in value
                ret:add(dbg:pr(e)).
            return "["+ret:join(" ")+"]". },
        "Lexicon",       { parameter value.
            // render lexicons as "{key} => {value}" separated by
            // commas and enclosed in "LEX{}". No attempt is made
            // to break long lines.
            local ret is list().
            local nl is "". // char(10).
            local nlin is " ". // nl+"  ".
            for k in value:keys
                ret:add(dbg:pr(k)+" => "+dbg:pr(value[k])).
            return "LEX{"+nlin+ret:join(","+nlin)+nl+"}". },
        "Vector",       { parameter value.
            // VECTORS: display as "{mag}*[{x},{y},{z}]" because often
            // when debugging I am more interested in magnitude or
            // direction alone than in the actual total.
            local n is value:normalized.
            return dbg:pr(value:mag)+"*"+dbg:pr(list(n:x, n:y, n:z)). },
        "Direction",    { parameter value.
            // DIRECTION: render as "[y={y} p={p} r={r}]" using Yaw,
            // Pitch, and Roll. Too bad I can't convert Direction to a
            // real Quaternion easily!
            return "[y="+dbg:pr(value:yaw)
                +" p="+dbg:pr(value:pitch)
                +" r="+dbg:pr(value:roll)+"]". },
        "TimeSpan",     { parameter value.
            // TIME: break out year, day, hour, minute, second, and fraction.
            // Discard zero values for all but seconds.
            local ret is list().
            if value:year>0 ret:add(value:year+"y").
            if value:day>0 ret:add(value:day+"d").
            if value:hour>0 ret:add(value:hour+"h").
            if value:minute>0 ret:add(value:minute+"m").
            local sfff is value:second + round(value:seconds - floor(value:seconds), 3).
            ret:add(sfff+"s"). return ret:join(" "). },
        "UserDelegate", { parameter value.
            // DELEGATE: evaluate it, and render the value,
            // prefixed with an "@" to indicate we are indirect here.
            return "@"+dbg:pr(value()). } ).

    dbg:add("pr", { parameter value.            // useful printable representation
        // dbg:pr(value) converts the value to a debug string
        // using the converters above. If there is no converter
        // for the type of the value, use "<{type}> {tostring}"
        // to allow me to do someting smart.
        // TODO if the type is not found, look for one that works?
        local t is value:typename.
        if pr_d:haskey(t) return pr_d[t](value).
        return "<"+value:typename+"> "+value:tostring. }).

    dbg:add("pv", { parameter name, value.      // print name and representation of value
        // Convert the value to a debug string, then print the
        // name and value to the console.
        print name+": "+dbg:pr(value). }).
}
