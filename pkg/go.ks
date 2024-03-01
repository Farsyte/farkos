@LAZYGLOBAL off.
{   parameter go is lex(). // default GO script.
    local hud is import("hud").

    go:add("go", {                              // default vessel control code
        // This is the last chance pick-up for running a GO script
        // for a vessel that does not have one, and one is not found
        // in any parent of its mission home.
        // Absent anything else, just print and display a good message
        // and release control to the flight engineer.
        hud:say(LIST(
            "No 'GO' package found",
            "for "+ship:name+",",
            "releasing control.")). }).
}
