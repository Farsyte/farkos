@LAZYGLOBAL off.
{   parameter goal. // configure goals for this vessel.

    local pi is constant:pi.

    local b is body("Kerbin").

    // This GOAL script is the goal for the ANCHOR satellite,
    // which is responsible for maintaining the SMA that the
    // other satellites will match.
    //
    // Constellation C/03/* is approximately kerbosynchronous
    // if no change is indicated in the name.
    //
    // The current convention is that we specify
    //    C/03/phase/t/h/i
    //
    // where
    //   t = orbital period (multiple of body:period)
    //   h = altitude of either ap or pe
    //   i = approximate assigned inclination
    //

    local na is ship:name:split("/").

    // 3rd component of name adjusts orbital period.
    local t is choose na[3]:toscalar(1)*b:rotationperiod if na:length > 3 else b:rotationperiod.

    // compute semi-major axis.
    local a is (b:mu * (t/(2*pi))^2)^(1/3).

    // 4th component of name adjusts either AP or PE.
    local h1 is choose na[4]:toscalar(a-b:radius) if na:length > 4 else a-b:radius.
    local h2 is 2*a - 2*b:radius - h1.

    // 5th component of name adjusts inclination.
    local i is choose na[5]:toscalar(0) if na:length > 5 else 0.

    // 6th component is argument of periapsis.
    local aop is choose scalar_or_not(na[6], "any") if na:length > 6 else "any".

    // TODO improve selection of launch azimuth.

    // TODO argument of periapsis
    // control AOP by launching to a circular orbit,
    // then adjusting AP or PE at the appropriate time,
    // if AP <> PE and AOP is specfiied.

    // Needed for Kolniya orbits, highly inclined and
    // highly eccentric orbits where the periapsis is
    // at the most northern or southern point.

    // Historical note. Molniya orbits classically had
    // an inclination of 63.4 degrees and AOP of 270 degrees,
    // for a siderial period of just over half a siderial day.

    // TODO longitude of ascending node
    // control LAN by selecting the correct launch time,
    // if INC nonzero and LAN specified.

    goal:add("az", 90 - i).         // assigned launch azimuth
    goal:add("pe", min(h1,h2)).     // assigned PE altitude
    goal:add("ap", max(h1,h2)).     // assigned AP altitude
    goal:add("aop", aop).           // assigned argument of periapsis
    goal:add("t", t).               // assigned orbit period
    goal:add("a", a).               // assigned orbit SMA

    function scalar_or_not { parameter val, def.
        local v0 is val:toscalar(0).
        local v1 is val:toscalar(1).
        return choose v0 if v0=v1 else def.
    }

}
