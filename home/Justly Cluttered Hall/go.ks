say("Justly Cluttered Hall").
say("Development Platform").

clearguis().

loadfile("debug").
loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("visviva").
loadfile("hillclimb").
loadfile("maneuver").
loadfile("intercept").
loadfile("rendezvous").
loadfile("mission_target").
loadfile("task").
loadfile("mun_retro").
//
// Development Workhorse
//
// This mission enters a low kerbin orbit
// then waits for the flight engineer to direct
// further operations.
//
lock steering to facing.
lock throttle to 0.
persist_get("launch_azimuth", 90, true).
persist_get("launch_altitude", 120000, true).

//
// Development Workhorse
//
add_task("Circularize Here",
    { return true. },
    { },
    { return phase_circ(). },
    { }).

add_task("Execute Node",
    { return HASNODE. },
    { },
    { return maneuver:step(). },
    { }).

add_task("Match Inclination",
    { return HASTARGET. },
    { mission_export_target(). },
    { return phase_match_incl(). },
    { }).

add_task("Plan Intercept",
    { return HASTARGET. },
    { mission_export_target(). },
    { return plan_intercept(). },
    { }).

add_task("Plan Correction",
    { return HASTARGET and persist_has("xfer_final_time"). },
    { mission_export_target(). persist_put("xfer_corr_time", time:seconds + 60). },
    { return plan_correction(). },
    { }).

add_task("Coarse Approach",
    { return HASTARGET. },
    { mission_export_target(). },
    { return coarse_approach(). },
    { }).

add_task("Fine Approach",
    { return HASTARGET. },
    { mission_export_target(). },
    { return fine_approach(). },
    { }).

add_task("Mun Retro",
    mun_retro_cond@,
    mun_retro_start@,
    mun_retro_step@,
    mun_retro_stop@).

function process_actions {
    // ABORT returns us from orbit, whatever we are doing.
   if ABORT {
        say("Workhorse: aborting mission.").
        // cancel curent actions.
        say("STOP "+action_name(act_num)). action_stop(act_num).
        set act_num to 0.
        rcs on. sas off.
        lock throttle to 0.
        lock steering to facing.
        return 0.
    }

    if action_cond(act_num) {
        local dv is action_step(act_num).
        if dv>0 return dv.
    }

    say("STOP "+action_name(act_num)).
    action_stop(act_num).
    set act_num to 0.
    action_start(act_num).
    return 1.
}
//
mission_bg(bg_stager@).                 // Start the auto-stager running in the background.
mission_bg(bg_rcs@).                    // Start RCS-enable background task.
//
// Mission Plan
//
mission_add(LIST(
    "COUNTDOWN",    phase_countdown@,   // initiate unmanned flight.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    //
    // In READY orbit. Set up for semi-automatic commanding.
    //
    "READY",        task_step@,
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
task_gui_show().
mission_fg().
wait until false.