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
    if mission_sma:apoapsis < 180000 return 250000.
    else return 120000. }, true).
//
mission_bg(bg_stager@).                 // Start the auto-stager running in the background.
//
function mission_abort {
    parameter m.
    say(m).
    say("ABORT MISSION.").
    abort on.
    return 0. }
//
function plan_xfer {    // construct initial transfer maneuver
    if abort return 0.
    lock throttle to 0.
    lock steering to facing.
    if not hastarget set target to mission_target.

    persist_put("phase_plan_xfer", mission_phase()).

    // plan an intercept to the mission target.
    // (persists the xfer_*_time values)
    plan_intercept(mission_target).
    //
    return 0. }

function plan_corr {    // plan a mid-course correction.
    if abort return 0.
    lock throttle to 0.
    lock steering to facing.
    if not hastarget set target to mission_target.

    return plan_correction(mission_target). }

// hang out in this phase until we are near
function wait_near {
    if abort return 0.
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if not hastarget set target to mission_target.

    lock throttle to 0.
    lock steering to retrograde.

    local Tf is persist_get("xfer_final_time").
    local stop_warp_at is Tf - 30.
    local wait_for is stop_warp_at - time:seconds.

    // print "wait_for = "+wait_for.

    if wait_for<=0 return 0.
    if wait_for<30 return wait_for.
    wait 3.
    warpto(stop_warp_at).
    return wait_for. }

function approach {
    if abort return 0.
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if not hastarget set target to mission_target.

    lock steering to retrograde.

    // pv("","").
    local dir is prograde:vector.                               // pv("dir", dir).

    local t_p is target:position.                               // pv("t_p", t_p).
    local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
    local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).

    // bias the result by 20m so we stop short of hitting the target,
    // if we happen to be that well lined up.
    local d is vdot(t_p, dir) - 20.                             // pv("d", d).
    local v is vdot(s_v - t_v, dir).                            // pv("v", v).

    {   // Plan to burn at a constant acceleration A, such that
        // the burn reduces our position and velocity to zero at some
        // future time T=0. Solve for that acceleration A and
        // for the T for right now which will be negaitive.
        //     V = A T                   X = A T^2 / 2
        // Solve for time by eliminating A from the X equation:
        //     A = V / T                 X = (V/T) T^2 2 = V T/2
        //     T = 2 X / V
        // Compute T, then compute A as seen above.
    }
    local p_dist is d.                                          // pv("p_dist", p_dist).
    local p_rate is v.                                          // pv("p_rate", p_rate).

    // computed time until X=0 V=0 at constant A
    // NOTE: once things are nearly linear, and
    // until we start thrusting, b_time will go down
    // twice as fast as time is progressing.

    local b_time is 2*p_dist/p_rate.                            // pv("b_time", b_time).

    if b_time < 0 {
        // print "target is behind us.".
        set throttle to 0.
        return 0. }

    // b_accel: the required acceleration
    local b_accel is p_rate/b_time.                             // pv("b_accel", b_accel).

    // b_force: the required force
    local b_force is b_accel*ship:mass.                         // pv("b_force", b_force).

    // desired throttle command
    local b_throt is b_force/availablethrust.                   // pv("b_throt", b_throt).

    if throttle>0 or b_throt>0.5
        set throttle to b_throt.

    if throttle=0 and b_throt<0.2
        return 1.

    return 1/100. }

local holding_for_rescue is false.
function rescue {
    if abort {
        lock steering to retrograde.
        lock throttle to 0.
        // wait 1.
        // say(LIST("Home Again,","Home Again,","Jiggity-Jig.")).
        wait 3.
        return 0. }
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if not hastarget set target to mission_target.

    local k_t is 2.                     // TODO make tunable, find good value.
    local max_facing_error is 15.        // TODO make tunable, find good value.

    // pv("","").
    local s_p is -body:position.                                // pv("s_p", s_p).
    local t_p is target:position.                               // pv("t_p", t_p).
    local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
    local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).
    local r_v is t_v - s_v.                                     // pv(_v", r_v).

    // if we are already in the rescue pose,
    // do not change pose unless we are more than 100m
    // from the target or our relative velocity
    // exceeds 1.0 m/s.

    if holding_for_rescue {
        if t_p:mag < 100 and r_v:mag < 1.0 {
            lock steering to lookdirup(body:north:vector, -s_p:normalized).
            lock throttle to 0.
            say("Activate ABORT to return home.", false).
            return 5. }
        set holding_for_rescue to false. }

    // if we are within 20m of the target and our
    // speed is within 0.01 m/s of the target, then
    // enter the rescule pose.
    if t_p:mag < 20 and r_v:mag < 0.01 {
        set holding_for_rescue to true.
        lock steering to lookdirup(body:north:vector, -s_p:normalized).
        lock throttle to 0.
        return 1. }

    // if more than 15 m from the target,
    // match a velocity toward the target
    // of 1 m/s per 15 m of distance.

    if t_p:mag > 15
        set r_v to r_v + t_p/15.

    set steering to lookdirup(r_v, facing:topvector).

    local desired_delta_v to r_v:mag.                           // pv("desired_delta_v", desired_delta_v).
    if desired_delta_v < 0.01 { set throttle to 0. return 1. }
    local desired_accel to desired_delta_v * 2.                 // pv("desired_accel", desired_accel).
    local desired_force is ship:mass * desired_accel.           // pv("desired_force", desired_force).
    local desired_throttle is desired_force / availablethrust.  // pv("desired_throttle", desired_throttle).
    local clamped_throttle is clamp(0,1,desired_throttle).      // pv("clamped_throttle", clamped_throttle).

    local facing_error is vang(facing:vector,steering:vector).  // pv("facing_error", facing_error).
    local fefac is facing_error/max_facing_error.               // pv("fefac", fefac).
    local facing_error_factor is clamp(0,1,1-fefac).            // pv("facing_error_factor", facing_error_factor).

    set throttle to clamp(0,1,facing_error_factor*clamped_throttle).

    return 1/100. }

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
    "MATCH_INCL",   phase_match_incl@,  // match inclination of rescue target
    "PLAN_XFER",    plan_xfer@,         // create maneuver node for starting transfer.
    "EXEC_XFER",    maneuver:step@,     // execute the maneuver to inject into the transfer orbit.
    "PLAN_CORR",    plan_corr@,         // plan mid-transfer correction
    "EXEC_CORR",    maneuver:step@,     // execute the mid-transfer correction.
    { set mapview to false. },
    "WAIT_NEAR",    wait_near@,         // wait (or warp) until time to rendezvous
    "APPROACH",     approach@,          // come to a stop near the target
    "RESCUE",       rescue@,            // maintain position near target
    //
    // Normal deorbit, descent, and landing process.
    //
    { abort off. return 0. },
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