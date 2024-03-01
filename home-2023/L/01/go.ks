@LAZYGLOBAL off.
{   parameter go. // default GO script for "L/01" LandSCAN mission.

    local io is import("io").
    local dbg is import("dbg").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local match is import("match").
    local targ is import("targ").
    local mnv is import("mnv").

    local goal is import("goal").

    // synthesize a target orbit from the goal.
    set target to "". wait 0. targ:clr(). targ:restore().
    targ:resize(goal:periapsis, goal:apoapsis).
    targ:incline(goal:inclination).

    local target_orbit is targ:orbit().
    // dbg:pv("target_orbit", target_orbit).

    local orbit_altitude is nv:get("launch_altitude", goal:apoapsis, true).
    local launch_azimuth is nv:get("launch_azimuth", 0, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, true).

    go:add("go", {
        io:say(LIST(
            "Booting "+ship:name,
            "Satellite in specified orbit",
            "  periapsis: "+goal:periapsis,
            "  apoapsis: "+goal:apoapsis,
            "  inclination: "+goal:inclination)).

        nv:put("hold/periapsis", goal:periapsis).
        nv:put("hold/apoapsis", goal:apoapsis).
        nv:put("hold/inclination", goal:inclination).

        mission:do(list(
            "COUNTDOWN", phase:countdown,
            "LAUNCH", phase:launch,
            "ASCENT", phase:ascent,

            {   // tap the brakes to jettison the shroud.
                toggle brakes. wait 1. toggle brakes. return 0. },

            "LIGHTEN", phase:lighten,

            {   // make sure apoapsis is high enough.
                // then burn prograde a bit.
                lock steering to prograde.
                if apoapsis<goal:periapsis {
                    lock throttle to 1/10.
                    return 1/10.
                } else {
                    lock throttle to 0.
                    return 0. } },

            "COAST", phase:coast,
            "CIRC", phase:circ,

            "POSE", {               // LandSCAN pose is NOSE DOWN.
                lock throttle to 0.
                lock steering to lookdirup(body:position, facing:upvector).

                if abort return 0.
                else if ship:angularvel:mag>0.1                         return 5.
                else if 4<vang(facing:forevector, steering:forevector)  return 5.
                else if 4<vang(facing:topvector, steering:topvector)    return 5.
                return 0. },

            {   // extend all the bits and start the scan.
                lights on. return 0. },

            "HOLD", {               // LandSCAN pose is NOSE DOWN.
                lock throttle to 0.
                lock steering to lookdirup(V(0,1,0), V(1,0,0)).
                return 5. } )).

        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }
