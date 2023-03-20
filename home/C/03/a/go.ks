@LAZYGLOBAL off.
{   parameter go. // default GO script for "C/03/a" satellite constellation leader.

    local io is import("io").
    local nv is import("nv").
    local dbg is import("dbg").
    local mission is import("mission").
    local phase is import("phase").
    local plan is import("plan").
    local mnv is import("mnv").

    local goal is import("goal").

    nv:put("launch_altitude", goal:altitude+1000).
    nv:put("launch_azimuth", 90).
    nv:put("launch_pitchover", 3).

    // The idea is that C/03/a will establish the orbit for the constellation,
    // and C/03/b and subsequent launches will settle into the same orbit at
    // a managed phase offset. If C/03/a does any maneuvering once the other
    // satellites are in place, each and every one of them will have to make
    // adjustments, so once we are in place, our only control is to maintain
    // our fixed attitude within the hopefully on-rails orbit.

    go:add("go", {

        mission:do(list(
            "COUNTDOWN", phase:countdown,
            "LAUNCH", phase:launch,
            "ASCENT", phase:ascent,
            "LIGHTEN", phase:lighten,

            {   // make sure apoapsis is beyond target altitude
                lock steering to prograde.
                if apoapsis<goal:altitude+500 {
                    lock throttle to 1/10.
                    return 1/10.
                } else {
                    lock throttle to 0.
                    return 0. } },

            {   // extend the antennae.
                lights on. return 0. },

            "CIRC", plan:circ_at:bind(goal:altitude), plan:go,

            // we are only ROUGHLY kerbosynchronous.
            // the other satellites will form on us.

            "HOLD", {
                unlock throttle.
                lock steering to lookdirup(V(0,1,0),V(1,0,0)).
                if not lights lights on. return 5. })).

        mission:bg(phase:autostager).
        mission:fg(). }).

}
