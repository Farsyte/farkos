@LAZYGLOBAL off.
{   parameter goal. // configure goals for this vessel.

    local pi is constant:pi.

    // This GOAL script is the goal for the ANCHOR satellite,
    // which is responsible for maintaining the SMA that the
    // other satellites will match.
    //
    // Constellation C/03/* is approximately kerbosynchronous
    // if no change is indicated in the name.
    //
    // The current convention is that we specify
    //    C/03/mun/phase/t/h/i/ω/Ω
    //
    // where
    //   t = orbital period (multiple of body:period)
    //   h = altitude of either ap or pe
    //   i = approximate assigned inclination
    //   ω = argument of periapsis
    //   Ω = longitude of the ascending node (NOT YET IMPLEMENTED)

    local na is ship:name:split("/").

    // This may in fact be the beginning of a more generic
    // service to parse mission parameters from the vessel name.

    local function ns { parameter def.
        if na:length < 1 return def.
        local result is na[0].
        na:remove(0).
        return result.
    }

    local function nn { parameter def.
        if na:length < 1 return def.
        local nsval is na[0].
        na:remove(0).
        local ns0 is nsval:toscalar(0).
        local ns1 is nsval:toscalar(1).
        if ns0 = ns1 return ns0.
        return def.
    }

    local consist_major is ns("C").
    local consist_minor is nn(3).
    local b is body(ns("mun")).

    local phase is nn(0).

    // 3rd component of name adjusts orbital period.
    local t is nn(1)*b:rotationperiod.

    // compute semi-major axis.
    local a is (b:mu * (t/(2*pi))^2)^(1/3).

    // 4th component of name adjusts either AP or PE.
    local h1 is nn(a-b:radius).
    local h2 is 2*a - 2*b:radius - h1.

    // 5th component of name adjusts inclination.
    local inc is nn(0).

    // 6th component is argument of periapsis,
    // which could be a number or the string "any".
    local aop is nn("any").

    // 7th component is longitude of ascending node.

    local lan is nn("any").

    // NOTE: orbital data above are for the final
    // orbit around the destination body. Launch data
    // reflect our need to get to that body.

    set target to b.
    local bo is target:orbit.
    local boi is bo:inclination.

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

    goal:add("b", b).               // destination body name
    goal:add("az", 90 - boi).       // assigned launch azimuth
    goal:add("pe", min(h1,h2)).     // assigned PE altitude
    goal:add("ap", max(h1,h2)).     // assigned AP altitude
    goal:add("aop", aop).           // assigned argument of periapsis
    goal:add("t", t).               // assigned orbit period
    goal:add("a", a).               // assigned orbit SMA
}
