@LAZYGLOBAL off.
{   parameter go. // GO script for "M/01" Mun Fly-by.

    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local lamb is import("lamb").
    local task is import("task").
    local targ is import("targ").
    local match is import("match").
    local mnv is import("mnv").
    local hill is import("hill").
    local rdv is import("rdv").
    local dbg is import("dbg").
    local ctrl is import("ctrl").

    local orbit_altitude is nv:get("launch_altitude", 80000, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, false).

    set TARGET to "Mun".

    local wait_for is { parameter name.
        if body:name = name {
            io:say("Arrived in "+name+" SOI.").
            kuniverse:timewarp:cancelwarp().
            ctrl:dv(V(0,0,0),1,1,5).
            return -15. }
        if not kuniverse:timewarp:issettled return 1/10.
        if kuniverse:timewarp:rate>1 return 5.
        ctrl:dv(V(0,0,0), 0, 0, 0).
        dbg:pv("wait_for "+name+" eta ", TimeSpan(eta:transition)).
        if eta:transition > 60 warpto(time:seconds + eta:transition - 30).
        if eta:transition > 10 return 5.
        return clamp(5, 15, eta:transition). }.

    local wait_for_mun is wait_for:bind("Mun").
    local wait_for_kerbin is wait_for:bind("Kerbin").

    mission:do(list(
        "PADHOLD", targ:wait, match:asc,
        "COUNTDOWN", phase:countdown,
        "Launch", phase:launch,
        "Ascent", phase:ascent,
        "Coast", phase:coast,
        {   set mapview to true. return 0. },
        "Circularize", phase:circ,
        "Match Inclination", match:plan_incl,
        "Mun Xfer Inject", lamb:plan_xfer, mnv:step,
        "Mun Xfer Correct", lamb:plan_corr, mnv:step,

        "Coast to Mun", wait_for:bind("Mun"),

        "Coast past Mun", wait_for:bind("Kerbin"),

        "DEORBIT", phase:deorbit,
        "AERO", phase:aero,
        "LIGHTEN", phase:lighten,
        "PSAFE", phase:psafe,
        {   set mapview to false. return 0. },
        "CHUTE", phase:chute,
        "LAND", phase:land,
        "PARK", phase:park)).

    go:add("go", {
        task:show().
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }