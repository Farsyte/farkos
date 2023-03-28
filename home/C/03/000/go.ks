@LAZYGLOBAL off.
{   parameter go. // default GO script for "C/03/a" satellite constellation leader.

    local io is import("io").
    local nv is import("nv").
    local ctrl is import("ctrl").
    local dbg is import("dbg").
    local mission is import("mission").
    local visviva is import("visviva").
    local phase is import("phase").
    local plan is import("plan").
    local mnv is import("mnv").

    local goal is import("goal").

    local r0 is body:radius.
    local target_sma is goal:sma.
    local target_alt is target_sma + r0.
    local target_period is goal:period.

    nv:put("launch_altitude", target_sma+1000).
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
                if apoapsis<target_alt+500 {
                    lock throttle to 1/10.
                    return 1/10.
                } else {
                    lock throttle to 0.
                    return 0. } },

            {   // extend the antennae.
                lights on. return 0. },

            "CIRC", plan:circ_at:bind(target_alt), plan:go,

            "HOLD", {
                if not lights lights on.

                dbg:pv("observed period: ", TimeSpan(orbit:period)).
                dbg:pv("assigned period: ", TimeSpan(target_period)).
                dbg:pv("period error: ", TimeSpan(orbit:period - target_period)).

                if abs(orbit:period - target_period) > 0.1 {

                // this will not only try to fix our sma,
                // but also minimizes our eccentricity.

                    ctrl:rcs_dv({
                        if abs(orbit:period - target_period) < 0.1 return V(0,0,0).
                        local obs_v is ship:velocity:orbit.
                        local r1 is r0 + altitude.
                        local r2 is target_sma * 2 - r1.
                        local des_s is visviva:v(r1, r1, r2).
                        // would be sqrt(mu/target_sma) if our sma were perfect.
                        local des_v is vxcl(body:position, obs_v):normalized*des_s.
                        local dv is des_v - obs_v.
                        return dv. }).

                } else {
                    set ship:control:neutralize to true.
                    set phase:force_rcs_on to 0.
                    sas off. rcs off.
                    lock throttle to 0.
                    lock steering to lookdirup(V(0,1,0),V(1,0,0)).
                }

                return 5.
            })).

        mission:bg(phase:autostager).
        mission:fg(). }).

}
