

@LAZYGLOBAL off.
{   parameter go. // GO script for C/03/NNN configuration

    // Satellite C/03/000 is the lead element.
    // Satellite C/03/ddd forms on it, ddd degrees ahead.

    local mission is import("mission").
    local visviva is import("visviva").
    local targ is import("targ").
    local ctrl is import("ctrl").
    local plan is import("plan").
    local match is import("match").
    local phase is import("phase").
    local dbg is import("dbg").
    local nv is import("nv").
    local io is import("io").

    local pi is constant:pi.
    local r0 is body:radius.
    local mu is body:mu.

    // infer the name of the lead element and our phase offset
    // from our ship name.

    local name is ship:name.
    local nary is name:split("/").
    local nlen is nary:length.
    local nddd is nary[nlen-1].
    local lang is nddd:toscalar(0).

    set targ:phase_offset to lang.

    set nary[nlen-1] to "000".
    local lead is nary:join("/").

    set target to lead.
    targ:save().

    local target_sma is target:orbit:semimajoraxis.
    local target_altitude is target_sma - r0.
    local target_period is target:orbit:period.

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

        // NOTE: launch azimuth is set by match:asc (PADHOLD)
        // as part of its computation of the target orbital plane.

         return 0. }

    mission:do(list(

        "CONFIGURE", reconfigure_launch@,
        "PADHOLD", match:asc,
        "COUNTDOWN", phase:countdown,
        "LAUNCH", phase:launch,
        "ASCENT", phase:ascent,
        "COAST", phase:coast,

        {   // switch to map view for clarity.
            set mapview to true. return 0. },

        "CIRC", phase:circ,

        {   // extend the antennae, any time after leaving atmosphere.
            lights on. return 0. },

        "PLANE", plan:match_incl, plan:go,
        {   lock throttle to 0. lock steering to prograde. return -5. },
        "TRANSFER",     plan:xfer,
        {   nv:put("to/exec", mission:phase()). return 0. },
        plan:go,        phase:lighten,
        "CORRECT",      plan:corr,
        {   if hasnode mission:jump(nv:get("to/exec")). return 0. },

        "CIRC", plan:circ_at:bind(target_altitude), plan:go, phase:circ,

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

    go:add("go", {

        io:say(LIST(
            "Booting "+ship:name,
            "Satellite in constellation position",
            "  constellation leader: "+lead,
            "  assigned phase offset: "+lang)).

        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }