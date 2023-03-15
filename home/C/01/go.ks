@LAZYGLOBAL off.
{   parameter go. // default GO script for "C" series vessels.

    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local match is import("match").
    local targ is import("targ").
    local dbg is import("dbg").

    local goal is import("goal").

    // AP and PE must be given. INC is zero if not given.
    local goal_ap is goal:apoapsis.
    local goal_pe is goal:periapsis.
    local goal_alt is (goal_ap + goal_pe) / 2.
    local goal_inc is choose goal:inclination if goal:haskey("inclination") else 0.

    nv:put("launch_altitude", goal_alt).
    nv:put("launch_azimuth", 90-goal_inc).
    nv:put("launch_pitchover", 3).

    targ:resize(goal_pe, goal_ap).
    targ:incline(goal_inc).

    nv:put("hold/periapsis", goal_pe).
    nv:put("hold/apoapsis", goal_ap).

    // Stack configuration C/01 does not have RCS.
    // C/02 and beyond should.

    go:add("go", {               // control script for a new X series mission.
        io:say(LIST(
            "Booting "+ship:name,
            "Satellite in specified orbit",
            "  periapsis: "+goal_pe,
            "  apoapsis: "+goal_ap,
            "  inclination: "+goal_inc)).

        mission:do(list(
            "COUNTDOWN", phase:countdown,
            "LAUNCH", phase:launch,
            "ASCENT", phase:ascent,

            // everything from here onward is handled by the
            // station keeping engines (in stage 0), which
            // must start with enough fuel to circularize at
            // the destination, plus station-keeping.

            "LIGHTEN", phase:lighten,

            {   // if apoapsis is high enough,
                // then burn prograde a bit.
                lock steering to prograde.
                if apoapsis<goal_alt {
                    lock throttle to 1/10.
                    return 1/10.
                } else {
                    lock throttle to 0.
                    return 0. } },

            {   // extend the antennae.
                lights on. return 0. },

            "COAST", phase:coast,
            "CIRC", phase:circ,
            "PLANE", match:plan_incl, mnv:step,
            "HOLD", { return max(5, phase:hold()). })).

        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }
