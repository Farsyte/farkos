{   parameter _. // default GO script for "X" series vessels.

    local mission is import("mission").
    local phase is import("phase").
    local hover is import("hover").
    local radar is import("radar").
    local io is import("io").
    local dbg is import("dbg").

    _:add("go", {           // launch, hover higher then lower, then land.
        io:say(LIST(
            "Hello "+ship:name,
            "Hover time!")).

        radar:cal(0).
        local ap0 is apoapsis.

        print "zero point is:".
        print "  alt:radar = "+alt:radar.
        print "  altitude = "+altitude.
        print "  apoapsis = "+apoapsis.

        wait until availablethrust>0.

        mission:bg(phase:autostager).

        lock steering to lookdirup(up:vector, facing:topvector).
        lock throttle to 1.

        wait until apoapsis > ap0+100.
        lock throttle to 0.
        wait until verticalspeed<0.
        print "start from "+radar:alt().

        unlock steering.
        sas on.

        local h is 200.
        set hover_until to time:seconds+30.
        print "  seeking radar:alt="+h+" m".
        until time:seconds>hover_until {
            set throttle to hover:hold(h).
            wait 0. }

        set h to 50.
        set hover_until to time:seconds+30.
        print "  seeking radar:alt="+h+" m".
        until time:seconds>hover_until {
            set throttle to hover:hold(h).
            wait 0. }

        // now descend at 3 m/s to altitude zero.

        local v is 3.
        set h to radar:alt().
        set descend_until to time:seconds + h/v.
        print "  descending from radar:alt="+round(h,1)+" m at "+v+" m/s".
        until descend_until < time:seconds {
            set h to (descend_until-time:seconds)*v.
            set throttle to hover:hold(h, -v).
            wait 0. }

        print "  shutdown.".
        set throttle to 0.
        wait until false. }). }