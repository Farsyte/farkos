{   parameter go is lex(). // default GO script.
    local io is import("io").

    go:add("go", {
        io:say(LIST(
            "No 'GO' package found",
            "for "+ship:name+",",
            "releasing control.")).
    }).
}
