{   parameter go. // default GO script for "X" series vessels.
    local io is import("io").
    go:add("go", {
        io:say(list(
            "Mission "+ship:name,
            "Gather some science,",
            "then recover the vessel.",
            "kOS releasing control.")).
    }).
}