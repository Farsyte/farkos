@LAZYGLOBAL off.
{   parameter go. // default GO script for "C" series vessels.

    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local plan is import("plan").

    local goal is import("goal").

    local orbit_altitude is nv:get("launch_altitude", goal:apoapsis, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, true).

    // Stack configuration C, by default,  does not have RCS.

    go:add("go", {               // control script for a new X series mission.
        io:say(LIST(
            "Booting "+ship:name,
            "Satellite in specified orbit",
            "  periapsis: "+goal:periapsis,
            "  apoapsis: "+goal:apoapsis)).

        nv:put("hold/periapsis", goal:periapsis).
        nv:put("hold/apoapsis", goal:apoapsis).

        mission:do(list(
            "COUNTDOWN", phase:countdown,
            "LAUNCH", phase:launch,
            "ASCENT", phase:ascent,
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

            {   // extend the antennae.
                lights on. return 0. },

            "COAST", phase:coast,
            "CIRC", phase:circ,
            "PLANE", plan:match_incl, plan:go,
            // TODO do we make "USE RCS" the default (after it is working)?
            "HOLD", { return max(1, phase:hold()). })).

        mission:bg(phase:autostager).
        mission:fg(). }). }
