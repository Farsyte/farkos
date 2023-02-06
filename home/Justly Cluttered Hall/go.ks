say("Justly Cluttered Hall").
say("Development Platform").

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

// Use RCS, in space, when our attitude differs from our
// steering direction, or our angular rate is large.
local rcs_check_time is time:seconds.
when time:seconds > rcs_check_time then {
    set rcs_check_time to time:seconds + 1.
    if altitude < body:atm:height                           rcs off.
    else if ship:angularvel:mag>0.2                         rcs on.
    else if 5<vang(facing:forevector, steering:forevector)  rcs on.
    else if 5<vang(facing:topvector, steering:topvector)    rcs on.
    else                                                    rcs off.
    return true.
}
//
// Development Workhorse
//
local act_list is list().
local act_num is 0.

function action_ent   { parameter e, i.
    local v is act_list[i][e].
    if v:istype("Delegate") return v:call. return v. }

function action_name  { parameter i. return action_ent(0,i). }
function action_cond  { parameter i. return action_ent(1,i). }
function action_start { parameter i. return action_ent(2,i). }
function action_step  { parameter i. return action_ent(3,i). }
function action_stop  { parameter i. return action_ent(4,i). }

function add_action { parameter name, cond, start, step, stop.
    act_list:add(list(name, cond, start, step, stop)). }

add_action("Ready for Action", true, phase_pose@, {
    for i in range(1, act_list:length) if action_cond(i) {
        say("START "+action_name(i), false).
        action_start(i). set act_num to i. break. }
    return 1. }, { }).

on AG1 { print "AG1 is now " + AG1. return true. }.
add_action("AG1: execute maneuver node",
    {   return AG1 and HASNODE. },
    {   },
    maneuver:step@,
    {   AG1 off. }).

on AG2 { print "AG2 is now " + AG2. return true. }.
add_action("AG2: match inclination",
    {   return AG2 and HASTARGET. },
    mission_export_target@,
    phase_match_incl@,
    {   AG2 off. }).

on AG3 { print "AG3 is now " + AG3. return true. }.
add_action("AG3: plan intercept",
    {   return AG3 and HASTARGET. },
    mission_export_target@,
    plan_intercept@,
    {   AG3 off. }).

on AG4 { print "AG4 is now " + AG4. return true. }.
add_action("AG4: plan correction",
    {   return AG4 and HASTARGET. },
    mission_export_target@,
    plan_correction@,
    {   AG4 off. }).

on AG5 { print "AG5 is now " + AG5. return true. }.
add_action("AG5: coarse approach",
    {   return AG5 and HASTARGET. },
    mission_export_target@,
    coarse_approach@,
    {   AG5 off. }).

on AG6 { print "AG6 is now " + AG6. return true. }.
add_action("AG6: fine approach",
    {   return AG6 and HASTARGET. },
    mission_export_target@,
    fine_approach@,
    {   AG6 off. }).

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
    "READY",        process_actions@,
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