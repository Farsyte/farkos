@LAZYGLOBAL off.
{   parameter go. // GO script for R/03 configuration: Rescue with RCS Approach

    local mission is import("mission").
    local targ is import("targ").
    local ctrl is import("ctrl").
    local plan is import("plan").
    local match is import("match").
    local phase is import("phase").
    local dbg is import("dbg").
    local nv is import("nv").
    local io is import("io").
    local rdv is import("rdv").

    local pi is constant:pi.
    local r0 is body:radius.
    local mu is body:mu.

    local function period_at_altitude { parameter h.
        local a is h + r0.
        return 2*pi*sqrt(a^3/mu). }

    local function reconfigure_launch {   // reconfigure ascent based on target

        // pick 80km or 240km altitude orbit based on
        // which one is better for matching target.
        local Pt is target:orbit:period.

        local Hl is 80000.
        local Pl is period_at_altitude(Hl).
        local Psl is (Pl*Pt)/abs(Pl-Pt).

        local Hh is 320000.
        local Ph is period_at_altitude(Hh).
        local Psh is (Ph*Pt)/abs(Ph-Pt).

        nv:put("launch_altitude", choose Hh if Psh<Psl else Hl).

        // set launch azimuth to target inclination. match:asc will
        // hold until we are under the ascending node, and ascent
        // will try to hold this azimuth, which places us fairly close
        // to the target orbital plane.
        nv:put("launch_azimuth", target:orbit:inclination).

        return 0. }

    mission:do(list(
        "TARGET", targ:wait, reconfigure_launch@,
        "PADHOLD", match:asc,
        "COUNTDOWN", phase:countdown,
        "LAUNCH", phase:launch,
        "ASCENT", phase:ascent,
        "COAST", phase:coast,

        { set mapview to true. return 0. },

        "CIRC", phase:circ,

        "PLANE", plan:match_incl, plan:go,

        // observed: we come to a nice pose, but jam so quickly
        // into lambert planning that we end up in a rapid roll.

        {   ctrl:dv(V(0,0,0),1,1,5). return -30. },

        // initial transfer is intended to place us on a trajectory
        // that ends at the projection of the target position onto
        // the current orbital plane.

        "TRANSFER",    plan:xfer,

        { nv:put("to/exec", mission:phase()+1). return 0. },

        {   // if the current stage has insufficient fuel, drop it.
            // this makes our computation of burn time of the next node
            // a bit more reliable, and means we do not have a few
            // seconds of "no thrust" at the beginning of the burn.
            if stage:number=0 return 0.
            if stage:deltav:vacuum>nextnode:deltav:mag return 0.
            if not stage:ready return 1.
            print "dropping stage "+stage:number+" early"
                +", only "+round(stage:deltav:vacuum)+" m/s remains.".
            stage. return 1. },

        plan:go,

        "CORRECT",    plan:corr,
        { if hasnode mission:jump(nv:get("to/exec")). return 0. },

        { set mapview to false. },

        // CONFIGURAION SPECIFIC. peel us down to just the "stage 2"
        // configuration if we still have the ascent engines attached.
        { if stage:number<3 return 0. if stage:ready stage. return 1. },

        "APP_PLAN",     rdv:node,            // get close enough rdv:fine can operate.
        "APP_BURN",     plan:go,

        "NEAR",         rdv:near,            // on main engine, approach within 100m and 1 m/s.
        "PAUSE",    {   phase:pose().
            if vang(steering:vector,facing:vector)>5 return 1.
            if ship:angularvel:mag>0.1 return 1.
            return -5. },
        "RESCUE",       rdv:rcs_5m,          // use RCS to approach to 10m

        // flight engineer will activate ABORT to return to Kerbin.

        {   // clean up after the rescue phase.
            ctrl:rcs_off().                 // remove the "keep RCS on" override.
            clearvecdraws().                // erase all the vectors we drew.
            return 0. },

        "DEORBIT", phase:deorbit,
        "AERO", phase:aero,
        "FALL", phase:fall,
        // "DECEL", phase:decel,
        "LIGHTEN", phase:lighten,
        "PSAFE", phase:psafe,
        "CHUTE", phase:chute,
        "LAND", phase:land,
        "PARK", phase:park)).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }