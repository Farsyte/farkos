@LAZYGLOBAL off.
{   parameter go. // GO script for "C/03/minmus/000/t/h/i/ω/Ω" stacks.

    local nv is import("nv").
    local goal is import("goal").
    local targ is import("targ").
    local io is import("io").
    local dbg is import("dbg").
    local mission is import("mission").
    local match is import("match").
    local phase is import("phase").
    local plan is import("plan").
    local mnv is import("mnv").
    local ctrl is import("ctrl").
    local visviva is import("visviva").
    local predict is import("predict").

    // Satellite C/03/minmus/000/t/h/i/ω/Ω is the lead element.
    // Satellite C/03/minmus/ddd/t/h/i/ω/Ω forms on it, ddd degrees ahead.
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

    nv:put("launch_altitude", 81000).
    nv:put("launch_azimuth", goal:az).
    nv:put("launch_pitchover", 5).

    io:say(ship:name).
    // io:say("launch azimuth: " + dbg:pr(goal:az)+" deg.").
    // io:say("assigned period: " + dbg:pr(TimeSpan(goal:t))).
    // io:say("assigned periapsis: " + dbg:pr(goal:pe/1000.0)+" km.").
    // io:say("assigned apoapsis: " + dbg:pr(goal:ap/1000.0)+" km.").
    // io:say("assigned angle of periapsis: " + dbg:pr(goal:aop)).

    local abort_ap_threshold is 0.
    local mnv_abort is

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

        "SOI Xfer Inject", plan:xfer, // plan:go,

        // EXPERIMENTAL: stash the the apoapsis of the orbit that the
        // maneuver node should leave us in. Then, if our actual apoapsis
        // exceeds that value, immediately cut throttle. This uses the
        // new "abort callback" mechanism in mnv:step.

        {   nv:put("abort_ap_threshold", nextnode:orbit:apoapsis).
            dbg:pv("abort_ap_threshold", nv:get("abort_ap_threshold")).
            return 0. },

        mnv:step:bind({
            local abort_ap_threshold is nv:get("abort_ap_threshold").
            return abort_ap_threshold>0 and apoapsis>abort_ap_threshold. }),

        {   nv:clr("abort_ap_threshold"). return 0. },

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

        "Coast to Assigned SOI", phase:await_soi:bind(goal:b:name),

        // yank us into an orbit at PE so we do not leave
        // the SOI of the target body.
        "Orbit in SOI", plan:circ_pe, plan:go, phase:circ,

        // Execute a plane-change to get into an orbit in the plane of
        // the ecliptic (Y=0).

        "Plane Change", {
            // we want to enter a specific orbit. Construct it here.
            local lan is goal:lan.
            // TODO if LAN is "any" then pick a LAN that minimizes our correction burn.
            if lan:istype("String") set lan to 0.
            local aop is goal:aop.
            // TODO if AOP is "any" then pick a AOP that minimizes our correction burn.
            if aop:istype("String") set aop to 0.
            local o is createorbit(goal:i, goal:e, goal:a, lan, aop, 0, 0, goal:b:name).
            targ:save(o).
            return plan:match_incl(). }, plan:go,

        "CORRECT_FIRST", plan:adj_at_pe:bind(goal:pe), plan:go,
        "CORRECT_AT_PE", plan:adj_at_pe:bind(goal:ap), plan:go,
        "CORRECT_AT_AP", plan:adj_at_ap:bind(goal:pe), plan:go,
        "CORRECT_AT_MD", plan:adj_at_md:bind(goal:pe, goal:ap), plan:go,
        "TUNE_AP_PE", phase:ap_pe:bind(goal:ap, goal:pe),

        // The check-flight arrived at HOLD with 1120 m/s of Delta-V remaining
        // for the main engine, and only having used 0.2 of its 80 monoprop.

        "HOLD", {

            io:say(ship:name, false).

            local o is targ:orbit().

            local assigned_period is goal:t.
            local assigned_majoraxis is 2*goal:a.

            // Stationkeeping Priorities
            // 1. maintain attitude.
            // 2. maintain semi-major axis length.
            // 3. minimize eccentricity
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