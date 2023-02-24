@LAZYGLOBAL off.
{   parameter _. // default GO script for "X" series vessels.
    local std is import("std").
    local io is import("io").

    _:add("go", {               // control script for a new X series mission.
        io:say(LIST(
            "Hello "+ship:name,
            "You are an X series vessel",
            "with no 'GO' script,",
            "releasing control.")). }). }