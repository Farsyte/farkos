@LAZYGLOBAL off.
{   parameter _. // GO script for "H/02"

    local mission is import("mission").
    local phase is import("phase").
    local hover is import("hover").
    local radar is import("radar").
    local io is import("io").
    local dbg is import("dbg").

    _:add("go", {               // go high, use hover to land.
        io:say(LIST(
            "Hello "+ship:name,
            "Hoverglide time!")).

        radar:cal(0).
        local ap0 is apoapsis.

        print "zero point is:".
        print "  alt:radar = "+alt:radar.
        print "  altitude = "+altitude.
        print "  apoapsis = "+apoapsis.

        wait until availablethrust>0.
        local s is stage:number.

        mission:bg(phase:autostager).

        lock steering to lookdirup(up:vector, facing:topvector).
        lock throttle to 1.

        wait until stage:number < s.
        lock throttle to 0.
        wait until verticalspeed<0.
        print "start from "+radar:alt().

        unlock steering.
        sas on.

        local h_wait is 25.
        print "  descending to radar:alt="+h_wait+" m".
        until radar:alt()<h_wait+5 {
            set throttle to hover:hold(h_wait).
            wait 0. }
        local hover_until is time:seconds+10.
        print "  holding radar:alt="+h_wait+" m".
        until time:seconds>hover_until {
            set throttle to hover:hold(h_wait).
            wait 0. }

        // now descend at 5 m/s to altitude zero.

        local v is 5.
        local h is radar:alt().
        local descend_until to time:seconds + h/v.
        print "  descending from radar:alt="+round(h,1)+" m at "+v+" m/s".
        until descend_until < time:seconds {
            set h to (descend_until-time:seconds)*v.
            set throttle to hover:hold(h, -v).
            wait 0. }

        print "  shutdown.".
        set throttle to 0.
        wait until false. }). }