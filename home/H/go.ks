@LAZYGLOBAL off.
{   parameter _. // default GO script for "H" series vessels.
    local std is import("std").
    local io is import("io").

    _:add("go", {               // control script for a new H series mission.
        io:say(LIST(
            "Hello "+ship:name,
            "You are a H series vessel",
            "with no 'GO' script,",
            "releasing control.")). }). }