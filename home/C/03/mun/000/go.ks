@LAZYGLOBAL off.
{   parameter go. // GO script for "C/03/mun/000/t/h/i/ω/Ω" stacks.

    local nv is import("nv").
    local goal is import("goal").
    local targ is import("targ").
    local io is import("io").
    local dbg is import("dbg").
    local mission is import("mission").
    local match is import("match").
    local phase is import("phase").
    local plan is import("plan").
    local ctrl is import("ctrl").
    local visviva is import("visviva").

    // Satellite C/03/mun/000/t/h/i/ω/Ω is the lead element.
    // Satellite C/03/mun/ddd/t/h/i/ω/Ω forms on it, ddd degrees ahead.
    //
    // t=0.44 gives a 1,642,000km altitude over mun
    // which has a 200,000km radius.
    // mun rotation period is 138984 seconds
    // or 6d 2h 36m 24s
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

    nv:put("launch_altitude", 81000).
    nv:put("launch_azimuth", goal:az).
    nv:put("launch_pitchover", 5).

    io:say(ship:name).
    // io:say("launch azimuth: " + dbg:pr(goal:az)+" deg.").
    // io:say("assigned period: " + dbg:pr(TimeSpan(goal:t))).
    // io:say("assigned periapsis: " + dbg:pr(goal:pe/1000.0)+" km.").
    // io:say("assigned apoapsis: " + dbg:pr(goal:ap/1000.0)+" km.").
    // io:say("assigned angle of periapsis: " + dbg:pr(goal:aop)).

    mission:do(list(

        {   // start with the destination body as target.
            // DO NOT do this during reboots (thinking ahead
            // to followers who need to shift target from the
            // body to the lead vessel).
            set target to goal:b.
            targ:save().
            return 0. },

        "PADHOLD", match:asc,
        "COUNTDOWN", phase:countdown,
        "Launch", phase:launch,
        "Ascent", phase:ascent,
        "Coast", phase:coast,
                {   // switch to the map view.
                    // too bad we can't set the FOCUS from here.
                    set mapview to true. return 0. },
        "Circularize", plan:circ_ap, plan:go, phase:circ,
                {   // turn on lights which also extends the radio dishes.
                    lights on. return 0. },
        "Match Inclination", plan:match_incl, plan:go,

        "Mun Xfer Inject", plan:xfer, plan:go,

        // The C/03/mun configuration has enough Delta-V in its stage zero
        // to handle transfer correction and all of the maneuvering at Mun.
        "LIGHTEN", phase:lighten,

        {   // conserve Monopropellant: do not allow RCS usage
            // from here on, until we arrive on station; when
            // peeled down to Stage Zero, we do not need RCS
            // to control our attitude.
            set phase:force_rcs_on to 0.
            set phase:force_rcs_off to 1.
            rcs off.
            return 0. },

        "Mun Xfer Correct", plan:corr, plan:go,

        "Coast to Mun", phase:await_soi:bind(goal:b:name),

        // yank us into an orbit at PE so we do not leave
        // the SOI of the target body.
        "Mun Orbit", plan:circ_pe, plan:go, phase:circ,

        // The C/03/mun/000 mission completely ignores the requested inclination,
        // longitude of ascending node, and argument of periapsis. It just pushes
        // itself into an orbit with the specified PE and AP.

        "CORRECT_FIRST", plan:adj_at_pe:bind(goal:pe), plan:go,
        "CORRECT_AT_PE", plan:adj_at_pe:bind(goal:ap), plan:go,
        "CORRECT_AT_AP", plan:adj_at_ap:bind(goal:pe), plan:go,
        "CORRECT_AT_MD", plan:adj_at_md:bind(goal:pe, goal:ap), plan:go,
        "TUNE_AP_PE", phase:ap_pe:bind(goal:ap, goal:pe),

        // The check-flight arrived at HOLD with 1120 m/s of Delta-V remaining
        // for the main engine, and only having used 0.2 of its 80 monoprop.

        "HOLD", {
            if not lights lights on.

            local te is abs(orbit:period - goal:t).
            local fe is vang(V(0,1,0),ship:facing:forevector).
            local ue is vang(V(1,0,0),ship:facing:upvector).

            local te_ok is 1.
            local fe_ok is 1.
            local ue_ok is 1/10.

            io:say(ship:name, false).

            // if our period is not good enough, continuously adjust
            // to have the correct PE and AP.
            //
            // this propritizes "have the right SMA" massivly over
            // trying to efficiently transition to a different orbit.
            //
            // BUT: top priority actually goes to proper attitude.
            // If our forward or upward vectors are off by one degree,
            // then we shut down and get into the right pose.

            // Priority One: If our forward or upward vectors are not
            // within one degree of the desired attitude, spend this
            // maintainance cycle correcting our attitude without RCS.
            //
            // Priority Two: if our attitude is correct, but our period
            // is not correct, then use RCS jets to apply translation to
            // fix our period in a way that draws PE and AP toward their
            // nominal values.
            //
            // Priority Three: if our period is close enough, then set the
            // autopilot to hold our desired attitude.
            //
            // Priorities One and Three share code.

            if fe<=fe_ok and ue<=ue_ok and abs(te)>te_ok {
                io:say("Fix Period Error: "+dbg:pr(TimeSpan(te)), false).

                // Priority Two is more complicated: we want to use RCS jets
                // to provide fine control over our velocity, to reduce the
                // error in our period, while sneaking AP and PE back toward
                // their assigned values.
                //
                // When our period is correct, the value of having exact AP
                // and PE values is not high enough for us to spend RCS fuel.

                local r0 is body:radius.
                local r_pe is r0 + goal:pe.
                local r_ap is r0 + goal:ap.

                set phase:force_rcs_on to 1.
                set phase:force_rcs_off to 0.
                sas off. rcs on.

                ctrl:rcs_dv({
                    if abs(orbit:period - goal:t) <= te_ok return V(0,0,0).
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
                    return desired_velocity - velocity:orbit. }).

                return 5. }

            if fe>fe_ok io:say("Fix Facing Error "+dbg:pr(fe)).
            else if ue>ue_ok io:say("Fix Roll Error "+dbg:pr(ue)).
            else io:say("Hold Attitude and Period", false).

            set ship:control:neutralize to true.
            set phase:force_rcs_on to 0.
            set phase:force_rcs_off to 1.
            sas off. rcs off.
            lock throttle to 0.
            lock steering to lookdirup(V(0,1,0),V(1,0,0)).

            // maintainance cycles to adjust attitude last five seconds.
            return 5. } )).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }).

}