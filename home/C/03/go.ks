@LAZYGLOBAL off.
{   parameter go. // default GO script for "C/03" satellite constellation.

    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local match is import("match").
    local mnv is import("mnv").

    local goal is import("goal").

    set target to goal:lead.
    set t to target.
    set o to target:orbit.
    set pe to o:periapsis.
    set ap to o:apoapsis.
    set inc to o:inclination.
    set h to (pe + ap) / 2.
    set b to o:body.
    set r0 to b:radius.
    set a to r0 + h.


    go:add("go", {               // control script for a new X series mission.
        io:say(LIST(
            "Booting "+ship:name,
            "Satellite in specified orbit",
            "  periapsis: "+pe,
            "  apoapsis: "+ap,
            "  inclination: "+inc)).

        nv:put("launch_altitude", h).
        nv:put("launch_azimuth", 90 - inc).
        nv:put("launch_pitchover", 3).

        nv:put("hold/periapsis", pe).
        nv:put("hold/apoapsis", ap).
        nv:put("hold/inclination", inc).

        mission:do(list(
            "COUNTDOWN", phase:countdown,
            "LAUNCH", phase:launch,
            "ASCENT", phase:ascent,
            "LIGHTEN", phase:lighten,
            {   // extend the antennae.
                lights on. return 0. },
            "CIRC", phase:plan_circ, mnv:step,
            "PLANE", match:plan_incl, mnv:step,

            "HOLD", {
                io:say("TBD: Stationkeeping", false).
                return 5. })).

        mission:bg(phase:autostager).
        mission:fg(). }). }
