@LAZYGLOBAL off.
{   parameter go. // GO script for "C/03/mun/ddd/t/h/i/ω/Ω" stacksm, ddd != 000

    local nv is import("nv").
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

    // infer the name of the lead element and our phase offset
    // from our ship name.

    local name is ship:name.
    local nary is name:split("/").
    local nlen is nary:length.
    local nddd is nary[3].
    local lang is nddd:toscalar(0).

    set nary[3] to "000".
    local lead is nary:join("/").

    set target to lead.
    local target_ship is target.

    set target to target:orbit:body.
    local target_body is target.

    set target to "".
    targ:restore().     // restores persisted target, if there was one.

    // NOTE: setting phase_offset too soon will prevent us from
    // getting an actual transfer to the target body.
    // set targ:phase_offset to lang.      // TARG will now provide STANDOFF position at proper phase angle.

    nv:put("launch_altitude", 81000).
    nv:put("launch_azimuth", 90 - target_body:orbit:inclination).
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
            set target to target_body.
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

        "Coast to Mun", phase:await_soi:bind(target_body:name),

        // yank us into an orbit at PE so we do not leave
        // the SOI of the target body.
        "Mun Orbit", plan:circ_pe, plan:go, phase:circ,

        "Switch Target", {
            set target to target_ship.
            io:say("Set TARGET to " + target:name).
            targ:save().
            io:say("Set PHASE to " + lang).
            set targ:phase_offset to lang.      // TARG will now provide STANDOFF position at proper phase angle.
            return 0. },


        "PLANE", plan:match_incl,
        plan:go,
        {   lock throttle to 0. lock steering to prograde. return -5. },
        "TRANSFER",     plan:xfer,
        {   nv:put("to/exec", mission:phase()). return 0. },
        plan:go,        phase:lighten,
        "CORRECT",      plan:corr,
        {   if hasnode mission:jump(nv:get("to/exec")). return 0. },

        // TODO shift to executing the B2 burn from the last lambert solution?
        // TODO add support for eccentric orbits
        "CIRC", plan:circ_pe, plan:go,

        "HOLD", {
            if not lights lights on.

            local target_period is target_ship:orbit:period.
            local target_sma is target_ship:orbit:semimajoraxis.
            local r0 is target_ship:orbit:body:radius.
            local target_ap is target_ship:orbit:apoapsis.
            local target_pe is target_ship:orbit:periapsis.

            local te is abs(orbit:period - target_period).
            local fe is vang(V(0,1,0),ship:facing:forevector).
            local ue is vang(V(1,0,0),ship:facing:upvector).

            local te_ok is 1/10.
            local fe_ok is 1.
            local ue_ok is 1.

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
                local r_pe is r0 + target_pe.
                local r_ap is r0 + target_ap.

                set phase:force_rcs_on to 1.
                set phase:force_rcs_off to 0.
                sas off. rcs on.

                ctrl:rcs_dv({
                    if abs(orbit:period - target_period) <= te_ok return V(0,0,0).
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