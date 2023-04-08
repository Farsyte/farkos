@LAZYGLOBAL off.
{   parameter go. // default GO script for "C/03/000" satellite constellation leader.

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

    nv:put("launch_altitude", 81000).
    nv:put("launch_azimuth", goal:az).
    nv:put("launch_pitchover", 5).

    io:say(ship:name).
    io:say("launch azimuth: " + dbg:pr(goal:az)+" deg.").
    io:say("assigned period: " + dbg:pr(TimeSpan(goal:t))).
    io:say("assigned periapsis: " + dbg:pr(goal:pe/1000.0)+" km.").
    io:say("assigned apoapsis: " + dbg:pr(goal:ap/1000.0)+" km.").
    io:say("assigned angle of periapsis: " + dbg:pr(goal:aop)).

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
            "CIRC", plan:circ_ap, plan:go, phase:circ,

            {   if not lights lights on. return 0. },

            "APPROACH_AP", plan:approach_ap:bind(goal:aop, goal:ap), plan:go,

            "LIGHTEN", phase:lighten,

            "CORRECT_AP", plan:adj_at:bind((goal:ap+goal:pe)/2, goal:ap, goal:pe), plan:go,
            "CORRECT_PE", plan:adj_at:bind(goal:ap, goal:ap, goal:pe), plan:go,

            "TUNE_AP_PE", phase:ap_pe:bind(goal:ap, goal:pe),

            // TODO phase:ap_pe(ap, pe) similar to phase:circ?
            // or does the above get us close enough for the
            // RCS based position tuning to be good enough?

            "HOLD", {
                if not lights lights on.

                local te is abs(orbit:period - goal:t).
                io:say(ship:name, false).
                io:say("Holding position", false).
                io:say("Period error "+dbg:pr(TimeSpan(te)), false).

                dbg:pv("observed period: ", TimeSpan(orbit:period)).
                dbg:pv("assigned period: ", TimeSpan(goal:t)).
                dbg:pv("period error: ", TimeSpan(te)).


                if abs(te) > 0.1 {

                    local r0 is body:radius.
                    local r_pe is r0 + goal:pe.
                    local r_ap is r0 + goal:ap.

                    // if our period is not good enough, continuously adjust
                    // to have the correct PE and AP.
                    //
                    // this propritizes "have the right SMA" massivly over
                    // trying to efficiently transition to a different orbit.

                    ctrl:rcs_dv({
                        if abs(orbit:period - goal:t) < 0.1 return V(0,0,0).

                        local r_now is r0+altitude.
                        local desired_prograde_speed is visviva:v(r_now, r_ap, r_pe).
                        local ref_pe_speed is visviva:v(r_ap, r_ap, r_pe).
                        local desired_lateral_speed is ref_pe_speed * r_pe / r_now.
                        local desired_radial_speed is safe_sqrt(desired_prograde_speed^2 - desired_lateral_speed^2).
                        if (verticalspeed < 0) set desired_radial_speed to -desired_radial_speed.
                        local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
                        local radial_direction is -body:position:normalized.
                        local desired_velocity is lateral_direction*desired_lateral_speed
                            + radial_direction * desired_radial_speed.
                        return desired_velocity - velocity:orbit.
                         }).

                } else {
                    set ship:control:neutralize to true.
                    set phase:force_rcs_on to 0.
                    sas off. rcs off.
                    lock throttle to 0.
                    lock steering to lookdirup(V(0,1,0),V(1,0,0)).
                }

                return 30.
            })).

        mission:bg(phase:autostager).
        mission:fg(). }).

}
