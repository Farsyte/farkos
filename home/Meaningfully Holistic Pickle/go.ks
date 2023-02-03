say("Meaningfully Holistic Pickle").
say("Orbital Rescue Mission").

loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("rescue").
loadfile("visviva").
loadfile("hillclimb").
loadfile("maneuver").
loadfile("debug").
//
// State prediction in BODY-RAW coordinates
local ship_pos_at is {         // predict Body->Ship vector at time t
    parameter t.
    return positionat(ship, t) - body:position. }.
local ship_vel_at is {         // predict Body-relative Ship velocity at time t
    parameter t.
    return velocityat(ship, t):orbit. }.
local targ_pos_at is {         // predict Body->Target vector at time t
    parameter t.
    return positionat(target, t) - body:position. }.
local targ_vel_at is {         // predict Body-relative Target velocity at time t
    parameter t.
    return velocityat(target, t):orbit. }.
//
// HILLCLIMB support
local burn_into_hohmann is {
    parameter t0, r1, r2.
    return list(t0, visviva_v(r1, r2) - visviva_v(r1)). }.
local set_burn is {         // set the maneuver node to the burn state given.
    parameter burn.
    if not hasnode add node(time:seconds+30, 0, 0, 0).
    local n1 is nextnode.
    if burn:length > 0 and fp_differs(n1:time, burn[0]) set n1:time to burn[0].
    if burn:length > 1 and fp_differs(n1:prograde, burn[1]) set n1:prograde to burn[1].
    if burn:length > 2 and fp_differs(n1:radialout, burn[2]) set n1:radialout to burn[2].
    if burn:length > 3 and fp_differs(n1:normal, burn[3]) set n1:normal to burn[3].
    wait 0. return burn. }.
local hillclimb_loop is {
    parameter burn, fitness_fn, step_sizes.
    for step_size in step_sizes
        set burn to hillclimb:seek(burn, fitness_fn, step_size).
    return set_burn(burn). }.
local hillclimb_burn is {
    parameter burn, fitness_fn, step_sizes.
    set burn to hillclimb_loop(burn, fitness_fn, step_sizes).
    return burn. }.
local get_xfer_final_time is {
    if persist_has("xfer_final_time")
        return persist_get("xfer_final_time").
    local n1 is nextnode.
    local xo is n1:orbit.
    local tf is time:seconds+n1:eta+xo:period/2.
    return tf. }.
local ship_targ_error_at is {
    parameter tf.
    local sp is ship_pos_at(tf).
    local tp is targ_pos_at(tf).
    local pe is (tp-sp):mag.
    return pe. }.
local burn_fitness_fn is {       // fitness, for hillclimbing. More positive is better.
    parameter burn.
    set_burn(burn).
    local tf is get_xfer_final_time().
    return -round(ship_targ_error_at(tf),1). }.
//
local pi is constant:pi.
//
{   // Rescue Target Selection
    set target to persist_get("rescue_target", "").
    global rescue_target is target.
    global rescue_orbit is rescue_target:orbit.
    global rescue_alt is (rescue_orbit:periapsis + rescue_orbit:apoapsis) / 2.
    say("Rescue Target: "+rescue_target:name). }
{   // Set parameters for MATCH package.
    persist_put("match_peri", rescue_orbit:periapsis).
    persist_put("match_apo", rescue_orbit:apoapsis).
    persist_put("match_inc", rescue_orbit:inclination).
    persist_put("match_lan", rescue_orbit:lan). }
{   // Set parameters for LAUNCH phases
    persist_put("launch_azimuth", 90-rescue_orbit:inclination).
    persist_put("launch_altitude",
        choose 250000 if rescue_alt < 180000 else 120000). }
//
mission_bg(bg_stager@).                 // Start the auto-stager running in the background.
//
function rescue_abort {
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
    if not hastarget set target to rescue_target.

    persist_put("phase_plan_xfer", mission_phase()).

    set target to rescue_target.        // assure target is selected
    set targ to target.                 // cache the target Vessel or Body object

    // Operation is UNDEFINED if the target is not in orbit around
    // the same body as the ship.

    local mu is body:mu.
    local r0 is body:radius.

    // we want to create the initial transfer as a "broad stroke"
    // to go from our orbit to the target orbit, then find the
    // approximate start time that roughly matches the target at
    // the end, then iterate the math so ending time and radius
    // converge properly.

    // Start with a transfer in five minutes,
    // which ends at the rescue orbit's semi-major axis.
    // Set up locals that will be updated by trial_xfer.

    local Xfer_T0 is time:seconds + 300.
    local Xfer_RF is r0 + rescue_alt.
    //
    // Hohmann Related Computations
    //
    // We will need to recompute the locals set to 0 above for
    // a large number of starting conditions. Having a function
    // to do it avoids the namespace oddities around LOCK, and
    // the awkward code I ended up with when I used a ton of
    // function delegates.
    //
    local Xfer_R0 is 0.         // Xfer start radius
    local Xfer_TF is 0.         // final time for transfer
    local Curr_E is 0.          // most recent computed error
    //
    {   // Find a feasible starting point for hillclimbing.
        // Needs to start where hillclimbing will not try
        // to climb back before the current time.
        //
        function trial_xfer {       // run the numbers for Xfer_T0 and Xfer_RF
            // pv("-- xfer at ", Xfer_T0).
            //
            local Ship_P0 is ship_pos_at(Xfer_T0).                  // Body->Ship vector at T0
            set   Xfer_R0 to Ship_P0:mag.       // pv("Xfer_R0", Xfer_R0). // Xfer start radius
            //
            local Xfer_A  is (Xfer_R0+Xfer_RF)/2.                   // Xfer semi-major axis
            local Xfer_T  is pi*sqrt(Xfer_A^3/mu).                  // Xfer transfer time
            set   Xfer_TF to Xfer_T0 + Xfer_T.  // pv("Xfer_TF", Xfer_TF). // final time for transfer
            //
            local Ship_PF is -Ship_P0:normalized*Xfer_RF.                // Body->Ship vector at TF
            local Targ_PF is targ_pos_at(Xfer_TF).                  // Body->Targ vector at TF
            local Error_P is Targ_PF-Ship_PF.   // pv("Error_P", Error_P).
            set   Curr_E  to Error_P:mag.       // pv("Curr_E", Curr_E). // Targ->Ship vector at TF
            return Curr_E. }
        //
        local Xfer_dt_try is {                      // evaluate transfer dt seconds later than last try
            parameter dt.
            set Xfer_T0 to Xfer_T0 + dt.
            return trial_xfer(). }.
        local Xfer_dt_until_better is {             // move forward past a minimum
            parameter dt.
            local Prev_E is Curr_E.
            return Xfer_dt_try(dt) < Prev_E. }.
        local Xfer_dt_until_worse is {              // move forward past a maximum
            parameter dt.
            local Prev_E is Curr_E.
            return Xfer_dt_try(dt) > Prev_E. }.
        //
        // Increase T0 by big jumps until we are beyond a maximum.
        until Xfer_dt_until_better(300) { }
        // Increase T0 by big jumps until we are beyond a minimum.
        until Xfer_dt_until_worse(300) { }
        //
        {   // Tune Start Time to best match the target.
            // Using HILLCLIMB for this is overkill, but
            // it is easy to set up and works well.
            local burn is list(Xfer_T0).
            function burn_fit { parameter burn.
                set Xfer_T0 to burn[0].
                return -trial_xfer(). }
            for step_size in list(30, 10, 3, 1, 0.3, 0.1, 0.03, 0.01)
                set burn to hillclimb:seek(burn, burn_fit@, step_size).
            set Xfer_T0 to burn[0]. } }
    //
    {   // Create a node and tune it's Prograde DV.
        // Using HILLCLIMB for this is overkill, but
        // it is easy to set up and works well.
        local Xfer_R1 is ship_pos_at(Xfer_T0):mag.
        local Xfer_R2 is targ_pos_at(Xfer_TF):mag.
        local Xfer_DV is visviva_v(Xfer_R1, Xfer_R2) - ship_vel_at(Xfer_T0):mag.
        function burn_fit { parameter burn.
            set nextnode:prograde to burn[0].
            wait 0. return -ship_targ_error_at(Xfer_TF). }
        until not hasnode { remove nextnode. wait 0. }
        add node(Xfer_T0, 0, 0, 0). wait 0.
        set burn to list(Xfer_DV).
        for step_size in list(30, 10, 3, 1, 0.3, 0.1, 0.03, 0.01)
            set burn to hillclimb:seek(burn, burn_fit@,  step_size).
        // MUST call burn_fit to assure this burn is in the maneuver node.
        set Curr_E to burn_fit(burn).
        print "Curr_E for intercept insertion burn: "+round(Curr_E,1).}
    //
    {   // persist timestamps for xfer start, final, and corr
        local n is nextnode.
        local o is n:orbit.
        local Xfer_T0 is time:seconds + n:eta.
        local Xfer_TF is Xfer_T0 + o:period/2.
        persist_put("xfer_start_time", Xfer_T0).
        persist_put("xfer_final_time", Xfer_TF).
        persist_put("xfer_corr_time", (Xfer_T0+Xfer_TF)/2). }
    //
    return 0. }
function plan_corr {    // plan a mid-course correction.
    if abort return 0.
    lock throttle to 0.
    lock steering to facing.
    if not hastarget set target to rescue_target.
    //
    local Xfer_TF is persist_get("xfer_final_time").
    local Corr_T0 is persist_get("xfer_corr_time").
    //
    if Xfer_TF < time:seconds+10    // check for overshoot.
        return rescue_abort("overshot allowable planning time").
    //
    until not hasnode { remove nextnode. wait 0. }
    add node(Corr_T0, 0, 0, 0). wait 0.
    set burn to list(0, 0, 0).
    //
    function burn_fit { parameter burn.
        set nextnode:prograde to burn[0].
        set nextnode:radialout to burn[1].
        set nextnode:normal to burn[2].
        wait 0. return -ship_targ_error_at(Xfer_TF). }
    //
    for step_size in list(30, 10, 3, 1, 0.3, 0.1, 0.03, 0.01)
        set burn to hillclimb:seek(burn, burn_fit@,  step_size).
    set Curr_E to burn_fit(burn).
    print "Curr_E for intercept correction burn: "+round(Curr_E,1).
    return 0. }
function wait_near {
    if abort return 0.
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if not hastarget set target to rescue_target.

    lock throttle to 0.
    lock steering to retrograde.

    local Xfer_TF is persist_get("xfer_final_time").
    local stop_warp_at is Xfer_TF - 30.
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
    if not hastarget set target to rescue_target.

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
    if not hastarget set target to rescue_target.

    local k_t is 2.                     // TODO make tunable, find good value.
    local max_facing_error is 15.        // TODO make tunable, find good value.

    // pv("","").
    local t_p is target:position.                               // pv("t_p", t_p).
    local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
    local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).
    local r_v is t_v - s_v.                                     // pv("r_v", r_v).

    // if we are already in the rescue pose,
    // do not change pose unless we are more than 100m
    // from the target or our relative velocity
    // exceeds 1.0 m/s.

    if holding_for_rescue {
        if t_p:mag < 100 and r_v:mag < 1.0 {
            lock steering to lookdirup(body:north:vector, t_p:normalized).
            lock throttle to 0.
            say("Activate ABORT to return home.", false).
            return 5. }
        set holding_for_rescue to false. }

    // if we are within 20m of the target and our
    // speed is within 0.01 m/s of the target, then
    // enter the rescule pose.
    if t_p:mag < 20 and r_v:mag < 0.01 {
        set holding_for_rescue to true.
        lock steering to lookdirup(body:north:vector, t_p:normalized).
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