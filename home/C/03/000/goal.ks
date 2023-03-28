@LAZYGLOBAL off.
{   parameter goal. // configure goals for this vessel.

    local io is import("io").
    local dbg is import("dbg").

    // This GOAL script is the goal for the ANCHOR satellite,
    // which is responsible for maintaining the SMA that the
    // other satellites will match.
    //
    // Constellation C/03/* is approximately kerbosynchronous.

    local b is body("Kerbin").

    local mu is b:mu.
    local t is b:rotationperiod.
    local pi is constant:pi.

    local a is (mu * (t/(2*pi))^2)^(1/3).

    goal:add("period", t).
    goal:add("sma", a). }
