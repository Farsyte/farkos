@LAZYGLOBAL off.
{   parameter go. // GO script for R (rescue) series missions.

    local mission is import("mission").
    local targ is import("targ").
    local match is import("match").
    local phase is import("phase").
    local dbg is import("dbg").
    local nv is import("nv").
    local io is import("io").
    local lamb is import("lamb").
    local mnv is import("mnv").
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
        "LAMB_XFER", lamb:plan_xfer, mnv:step,
        "LAMB_CORR", lamb:plan_corr, mnv:step,
        { set mapview to false. },
        "APPROACH",     rdv:coarse,          // come to a stop near the target
        "RESCUE",       rdv:fine,            // maintain position near target

        // rdv:fine holds position, velocity, and pose
        // until we activate the abort signal.

        "DEORBIT", phase:deorbit,
        "FALL", phase:fall,
        "DECEL", phase:decel,
        "LIGHTEN", phase:lighten,
        "PSAFE", phase:psafe,
        "CHUTE", phase:chute,
        "LAND", phase:land,
        "PARK", phase:park)).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }