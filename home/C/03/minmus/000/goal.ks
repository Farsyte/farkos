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
    //    C/03/minmus/phase/t/h/i/ω/Ω
    //
    // where
    //   t = orbital period (multiple of body:period)
    //   h = altitude of either ap or pe
    //   i = approximate assigned inclination
    //   ω = argument of periapsis
    //   Ω = longitude of the ascending node (NOT YET IMPLEMENTED)

    local na is ship:name:split("/").

    // This may in fact be the beginning of sma more generic
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
    local b is ns("minmus").
    set target to b.
    set b to target.
    local bo is target:orbit.
    local boi is bo:inclination.
    local r0 is b:radius.

    local phase is nn(0).

    // 3rd component of name adjusts orbital period.
    local t is nn(1)*b:rotationperiod.

    // compute semi-major axis.
    local sma is (b:mu * (t/(2*pi))^2)^(1/3).

    // 4th component of name adjusts either AP or PE.
    local h1 is nn(sma-r0).
    local h2 is 2*sma - 2*r0 - h1.

    // 5th component of name adjusts inclination.
    local inc is nn(0).

    // 6th component is argument of periapsis,
    // which could be a number or the string "any".
    local aop is nn("any").

    // 7th component is longitude of ascending node.
    // which could be a number or the string "any".
    local lan is nn("any").

    local pe is min(h1, h2).
    local ap is max(h1, h2).
    local r_pe is r0 + pe.
    local r_ap is r0 + ap.
    local ecc is (r_ap - r_pe) / (r_ap + r_pe).

    goal:add("b", b).               // destination body name
    goal:add("t", t).               // assigned orbit period

    goal:add("pe", pe).             // assigned PE altitude
    goal:add("ap", ap).             // assigned AP altitude

    goal:add("i", inc).             // orbital inclination
    goal:add("e", ecc).             // eccentricity
    goal:add("a", sma).             // assigned orbit SMA
    goal:add("lan", lan).           // assigned orbit Ω (longitude of ascending node)
    goal:add("aop", aop).           // assigned orbit ω (argument of periapsis)

    // there is no goal for mean anomaly at epoch
    // there is no goal for epoch of orbit

    // NOTE: orbital data above are for the final
    // orbit around the destination body. Launch data
    // reflect our need to get to that body.
    //
    // the calling script picks the launch altitude.

    goal:add("az", 90 - boi).       // assigned launch azimuth
}
