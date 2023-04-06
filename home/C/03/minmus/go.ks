@LAZYGLOBAL off.
{   parameter go. // GO script for "C/03/minmus/ddd/t/h/i/ω/Ω" stacksm, ddd != 000

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

    // Satellite C/03/minmus/000/t/h/i/ω/Ω is the lead element.
    // Satellite C/03/minmus/ddd/t/h/i/ω/Ω forms on it, ddd degrees ahead.
    //
    // The first test flight put the initial Minmus PE at about 1.93 Mm,
    // requiring about 200 m/s to circularize.
    //
    // Test flight using T=1 plans a 12.3 m/s burn to transition to
    // the target 360 km orbit, and another 18.6 m/s to circularize;
    // the final orbit has a period of 1d 5h 14m 49.33s.
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

        "SOI Xfer Inject", plan:xfer, plan:go,

        // The C/03/minmus configuration has enough Delta-V in its stage zero
        // to handle transfer correction and all of the maneuvering at Minmus,
        // which could include a complete 180-degree plane change.
        "LIGHTEN", phase:lighten,

        {   // conserve Monopropellant: do not allow RCS usage
            // from here on, until we arrive on station; when
            // peeled down to Stage Zero, we do not need RCS
            // to control our attitude.
            set phase:force_rcs_on to 0.
            set phase:force_rcs_off to 1.
            rcs off.
            return 0. },

        "SOI Xfer Correct", plan:corr, plan:go,

        "Coast to Assigned SOI", phase:await_soi:bind(target_body:name),

        // yank us into an orbit at PE so we do not leave
        // the SOI of the target body.
        "Orbit in SOI", plan:circ_pe, plan:go, phase:circ,

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

        // Plan to circularize at our next periapsis, which the mission
        // plan knows will be our assigned orbit.

        "CIRC", plan:circ_pe, plan:go,

        "HOLD", {

            io:say(ship:name, false).

            if not lights lights on.

            set target to target_ship.
            targ:save().
            local o is target_ship:orbit.

            local assigned_period is o:period.
            local assigned_majoraxis is 2*o:semimajoraxis.

            // Stationkeeping Priorities
            // 1. maintain attitude.
            // 2. maintain semi-major axis length matching lead element.
            // 3. minimize eccentricity
            //
            // We do not (yet) attempt to adjust our period to creep back
            // into our assigned phase offset. The current assumption is
            // that, if we are so far out of position that the constellation
            // is not functioning, we simply launch a replacement for our
            // vacated position, and decommission the errant satellite.
            //
            // desired attitude is with long axis parallel to angular
            // momentum vector of orbit, and rolled so that "up" is
            // pointing as close to the solar prime vector as allowed
            // by our long axis orientation.
            //
            // If our attitude is incorrect, disable RCS
            // and use reaction wheels to fix attitude.
            //
            // If attitude is correct but our orbital period
            // has too much error, use RCS translational control
            // to make our velocity more like the horizontal velocity
            // that, at our current altitude, has the right period.
            //
            // If attitude and period are correct, idle in the code
            // that maintains attitude with RCS off.
            //
            // TODO work out why, when we come out of timewarp, we
            // suddenly have a big roll error.

            if not lights lights on.

            local te_ok is 1.       // period error max 1000 ms
            local fe_ok is 1.       // facing forward error max 1 degree
            local ue_ok is 1.       // facing upward error max 1 degree

            local attitude_ok_dbg is false.
            local function attitude_ok {
                local hdir is vcrs(velocity:orbit,-body:position):normalized.
                local fe is vang(hdir,ship:facing:forevector).
                if attitude_ok_dbg and fe>fe_ok dbg:pv("fe", fe).
                local pvec is vxcl(hdir,solarprimevector):normalized.
                local ue is vang(pvec,ship:facing:upvector).
                if attitude_ok_dbg and ue>ue_ok dbg:pv("ue", ue).
                set attitude_ok_dbg to false.
                return fe<=fe_ok and ue<=ue_ok. }

            local orbit_ok_dbg is false.
            local function orbit_ok {
                local te is abs(orbit:period - assigned_period).
                if orbit_ok_dbg and te>te_ok dbg:pv("te", te).
                set orbit_ok_dbg to false.
                return te<=te_ok. }

            if attitude_ok() and not orbit_ok() {
                io:say("Maintain Orbit", false).

                set phase:force_rcs_on to 1.
                set phase:force_rcs_off to 0.
                sas off. rcs on.

                ctrl:rcs_dv({
                    if orbit_ok() return V(0,0,0).
                    local r_now is body:position:mag.
                    local r_opp is assigned_majoraxis-r_now.
                    local desired_lateral_speed is visviva:v(r_now, r_now, r_opp).
                    // our desired lateral direction is perpendicular to the
                    // radial vector, and also perpendicular to the Y axis, which
                    // will tend to keep us in the equatorial (X-Z) plane.
                    local hdir is vcrs(velocity:orbit,-body:position):normalized.
                    local lateral_direction is vcrs(body:position, hdir).
                    if lateral_direction * velocity:orbit < 0
                        set lateral_direction to -lateral_direction.
                    // local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
                    local desired_velocity is lateral_direction:normalized * desired_lateral_speed.
                    return desired_velocity - velocity:orbit. }).

                return 5. }

            io:say("Maintain Attitude", false).
            local hdir is vcrs(velocity:orbit,-body:position):normalized.
            local pvec is vxcl(hdir,solarprimevector):normalized.
            set ship:control:neutralize to true.
            set phase:force_rcs_on to 0.
            set phase:force_rcs_off to 1.
            sas off. rcs off.
            lock throttle to 0.
            lock steering to lookdirup(hdir,pvec).

            // maintainance cycles to adjust attitude last five seconds.
            return 5. } )).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }).

}