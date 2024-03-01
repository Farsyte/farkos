@LAZYGLOBAL off.
{   parameter go. // GO script for "X/01"
    local io is import("io").
    go:add("go", {
        io:say(list(
            "Mission "+ship:name,
            "Gather some science,",
            "then recover the vessel.",
            "kOS releasing control.")). }). }