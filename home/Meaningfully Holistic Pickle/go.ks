say("Meaningfully Holistic Pickle").
say("Orbital Rescue Mission").

loadfile("intercept").

loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("rescue").
loadfile("visviva").
loadfile("predict").
loadfile("hillclimb").
loadfile("maneuver").
loadfile("intercept").
loadfile("rendezvous").
loadfile("debug").
//
local pi is constant:pi.
//
loadfile("mission_target").     // Rescue Target Selection
mission_pick_target().
//
// Set parameters for LAUNCH phases, if not already set.
persist_get("launch_azimuth",           // pick launch azimuth based on mission target orbit.
    90-mission_orbit:inclination, true).
persist_get("launch_altitude", {        // somewhat above or below the mission target.
    // we do not need to really be above or below the whole orbit, but
    // we do need to have a sufficiently different orbital period.
    local mission_sma is (mission_orbit:periapsis + mission_orbit:apoapsis) / 2.
    if mission_sma < 180000 return 250000.
    else return 80000. }, true).
//
mission_bg(bg_stager@).                 // Start the auto-stager running in the background.
mission_bg(bg_rcs@).                    // Start the auto-RCS-enable running in the background.
//
function mission_abort {
    parameter m.
    say(m).
    say("ABORT MISSION.").
    abort on.
    return 0. }
//
// Mission Plan
//
mission_add(LIST(
    "PADHOLD",      phase_match_lan@,   // PADHOLD until we can match target ascending node.
    "COUNTDOWN",    phase_countdown@,   // initiate unmanned flight.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    //
    // In READY orbit.
    //
    { set mapview to true. },
    //
    // REALIZATION: since we are launching with azimuth set to
    // the target inclination, we end up close enough to the target
    // orbital plane that our correction burn can fix any remaining
    // inclination problems.
    //
    // "MATCH_INCL",   phase_match_incl@,  // match inclination of rescue target
    "PLAN_XFER",    plan_intercept@,         // create maneuver node for starting transfer.
    { persist_put("phase_exec_node", mission_phase()). },
    "EXEC_NODE",    maneuver:step@,             // execute the maneuver to inject into the transfer orbit.
    "PLAN_CORR",    plan_correction@,           // plan mid-transfer correction
    { if hasnode mission_jump(persist_get("phase_exec_node")). return 0. },
    { set mapview to false. },
    "APPROACH",     coarse_approach@,          // come to a stop near the target
    "RESCUE",       fine_approach@,            // maintain position near target
    //
    // Normal deorbit, descent, and landing process.
    //
    { abort off. return 0. },
    "DEORBIT",      phase_deorbit@,     // until our periapsis is low enough, burn retrograde.
    "AERO",         phase_aero@,        // fall to half of the atmosphere height.
    "DECEL",        phase_decel@,       // decelerate to 1/4th of atmosphere height.
    "PSAFE",        phase_psafe@,       // fall until safe for parachutes
    { wait 3. set warp to 0. return 0. },
    "CHUTE",        phase_chute@,       // fall until safe for parachutes
    "GEAR",         phase_gear@,        // extend landing gear.
    "LAND",         phase_land@,        // until we stop descending, keep the nose pointed directly up.
    "PARK",         phase_park@,        // until the cows come home, keep the capsule upright.
    "")).
//
// Now go do it.
//
mission_fg().
wait until false.