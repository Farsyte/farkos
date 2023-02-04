say("Justly Cluttered Hall").
say("Development Platform").

loadfile("debug").
loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("visviva").
loadfile("hillclimb").
loadfile("maneuver").
//
// Development Workhorse
//
// This mission enters a low kerbin orbit
// then waits for the flight engineer to direct
// further operations.
//
// RCS is enabled during ascent coast, and any
// reboot after that point will turn it back on.
//
persist_get("launch_azimuth", 90, true).
persist_get("launch_altitude", 120000, true).
set rcs to persist_get("rcs_state", false, true).
//
// Workhorse Commanding
//
function workhorse_actions {

    // Action: ABORT
    // return from orbit.
    // Note that abort will open the fuel drains.
    // if abort return 0.

    // Enter the "selfie pose" and display a HUD
    // message that we are ready to act.
    //
    phase_pose().
    say("Ready for Action.").
    return 5. }
//
mission_bg(bg_stager@).                 // Start the auto-stager running in the background.
//
// Mission Plan
//
mission_add(LIST(
    "COUNTDOWN",    phase_countdown@,   // initiate unmanned flight.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    {   // Turn on RCS for the rest of the mission.
        RCS on.
        persist_put("rcs_state", true).
        return 0. },
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    //
    // In READY orbit. Set up for semi-automatic commanding.
    //
    workhorse_actions@,
    //
    // Normal deorbit, descent, and landing process.
    //
    "DEORBIT",      phase_deorbit@,     // until our periapsis is low enough, burn retrograde.
    { if altitude>body:atm:height { wait 3. set warp to 3. } return 0. },
    { if altitude>body:atm:height return 1. },
    { wait 3. set warp to 3. return 0. },
    "FALL",         phase_fall@,        // fall to half of the atmosphere height.
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