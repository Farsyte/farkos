say("Meaningfully Holistic Pickle").
say("Orbital Rescue Mission").

loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("rescue").
loadfile("visviva").
loadfile("hillclimb").
loadfile("maneuver").

term(132,66).

//
// State prediction in BODY-RAW coordinates
local ship_pos_at is {         // predict Body->Ship vector at time t
    parameter t.
    return positionat(ship, t) - body:position. }.
local ship_vel_at is {         // predict Body-relative Ship velocity at time t
    parameter t.
    return velocityat(ship, t). }.
local targ_pos_at is {         // predict Body->Target vector at time t
    parameter t.
    return positionat(target, t) - body:position. }.
local targ_vel_at is {         // predict Body-relative Target velocity at time t
    parameter t.
    return velocityat(target, t). }.
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
    wait 0.  }.
local hillclimb_loop is {
    parameter burn, fitness_fn, step_sizes.
    print "initial fitness="+fitness_fn(burn)+", burn=["+burn:join(" ")+"]".
    for step_size in step_sizes {
        set burn to hillclimb:seek(burn, fitness_fn, step_size).
        set_burn(burn).
        print "step_size="+step_size+", fitness="+fitness_fn(burn)+", burn=["+burn:join(" ")+"]". }
    print "final fitness="+fitness_fn(burn)+", burn=["+burn:join(" ")+"]". }.
local hillclimb_burn is {
    parameter burn, step_sizes.
    local eval_count is 0.
    local fitness_fn is {       // fitness, for hillclimbing. More positive is better.
        parameter burn.
        set_burn(burn).
        local n1 is nextnode.
        local xo is n1:orbit.
        local tf is persist_get("xfer_final_time", time:seconds+n1:eta+xo:period/2).
        local sp is ship_pos_at(tf).
        local tp is targ_pos_at(tf).
        local pe is (tp-sp):mag.
        set eval_count to eval_count + 1.
        return -pe. }.
    hillclimb_loop(burn, fitness_fn, step_sizes).
    print "evaluated "+eval_count+" burn vectors.". }.
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
    // alternately we might want to just deorbit since we
    // are not going to be carrying huge amounts of fuel.
    mission_jump(persist_get("rescue_retry_phase")).
    return 0. }
//
function plan_xfer {    // construct initial transfer maneuver
    lock throttle to 0.
    lock steering to prograde.

    if not rcs {
        say("activate RCS to continue.", false).
        return 5. }
    rcs off.

    persist_put("phase_plan_xfer", mission_phase()).
    persist_clr("xfer_start_time").
    persist_clr("xfer_final_time").
    persist_clr("xfer_corr_time").

    set target to rescue_target.        // assure target is selected
    set targ to target.                 // cache the target Vessel or Body object

    // Operation is UNDEFINED if the target is not in orbit around
    // the same body as the ship.

    local mu is body:mu.
    local r0 is body:radius.

    // This function does not play well with existing
    // planned maneuvers.
    until not hasnode { remove nextnode. wait 0. }

    // we want to create the initial transfer as a "broad stroke"
    // to go from our orbit to the target orbit, then find the
    // approximate start time that roughly matches the target at
    // the end, then iterate the math so ending time and radius
    // converge properly.

    // Start with a transfer in five minutes,
    // which ends at the rescue orbit's semi-major axis.

    local Xfer_T0 is time:seconds + 300.
    local Xfer_RF is r0 + rescue_alt.
    //
    // Hohmann Computation Related Functions
    local Ship_P0 is { return ship_pos_at(Xfer_T0). }.                          // Body->Ship vector at T0
    local Xfer_R0 is { return Ship_P0():mag. }.                                 // Xfer start radius
    local Xfer_A  is { return (Xfer_R0()+Xfer_RF)/2. }.                         // Xfer semi-major axis
    local Xfer_T  is { return pi*sqrt(Xfer_A()^3/mu). }.                        // Xfer transfer time
    local Xfer_TF is { return Xfer_T0 + Xfer_T(). }.                            // final time for transfer
    local Ship_PF is { return -Ship_P0():normalized*Xfer_RF. }.                 // Body->Ship vector at TF
    local Targ_PF is { return targ_pos_at(Xfer_TF()). }.                        // Body->Targ vector at TF
    //
    local Error_PF is { return Targ_PF() - Ship_PF(). }.                        // Targ->Ship vector at TF
    //
    local Curr_E is Error_PF():mag.
    local Prev_E is 0.
    local Xfer_Tune is {                // transfer tuning function.
        parameter done.                 // delegate: when to stop
        wait until done(). }.
    local Xfer_dt_try is {
        parameter dt.
        set Prev_E to Curr_E.           // previous error, for comparison.
        set Prev_T0 to Xfer_T0.         // previous time, for rewind.
        set Xfer_T0 to Xfer_T0 + dt.
        set Curr_E to Error_PF():mag. }.
    local Xfer_dt_rew is {
        set Xfer_T0 to Prev_T0.
        Xfer_dt_try(0). }.
    local Xfer_dt_until_better is {
          parameter dt.
          Xfer_dt_try(dt).
          return Curr_E < Prev_E. }.
    local Xfer_dt_until_worse is {
          parameter dt.
          Xfer_dt_try(dt).
          return Curr_E > Prev_E. }.
    //
    // Find the first feasible solution:
    {   // Increase T0 by big jumps until we are beyond a maximum.
        local dt is 300.
        Xfer_Tune(Xfer_dt_until_better:bind(dt)). }
    {   // Increase T0 by big jumps until we are beyond a minimum.
        local dt is 300.
        Xfer_Tune(Xfer_dt_until_worse:bind(dt)). }
    {   // Tune Xfer_T0 until we believe we have our best start time
        // within a small enough fraction of a second. This saves a
        // lot of time in HILLCLIMB later.
        local dt is 300.
        until abs(dt) < 1e-4 {
            set dt to -dt/10.
            Xfer_Tune(Xfer_dt_until_worse:bind(dt)).
            Xfer_dt_rew(). }                                                    }
    //
    hillclimb_burn(burn_into_hohmann(Xfer_T0, Xfer_R0(), Xfer_RF),
            list(30, 10, 3, 1, 0.3, 0.1, 0.03,0.01)).
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
    lock throttle to 0.
    lock steering to prograde.

    local xfer_start_time is persist_get("xfer_start_time").
    local xfer_final_time is persist_get("xfer_final_time").
    local xfer_corr_time is persist_get("xfer_corr_time").

    if xfer_final_time < time:seconds+10    // check for overshoot.
        return rescue_abort("overshot allowable planning time").

    if not rcs {                            // wait for RCS enable.
        say("activate RCS to continue.", false).
        return 5. }
    rcs off.

    hillclimb_burn(list(xfer_corr_time, 0, 0, 0),
        list(0.3, 0.1, 0.03, 0.01, 0.003)).
    return 0. }
function exec_node {    // execute the next maneuver node.
    lock throttle to 0.
    lock steering to prograde.

    // if the node is missing, rewind to our upward coast.
    if not hasnode
        return rescue_abort("maneuver node is missing").

    if not rcs {
        say("activate RCS to continue.", false).
        return 5.
    }
    rcs off.

    print "triggering mnv_exec.".
    maneuver:exec(true).
    print "maneuver:exec complete.".
    return 0. }
//
// Mission Plan
//
mission_add(LIST(
    "PADHOLD",      phase_match_lan@,   // PADHOLD until we can match target ascending node.
    "COUNTDOWN",    phase_countdown@,    // initiate unmanned flight.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    {   // set a rewind point to use when we have to retry.
        persist_put("rescue_retry_phase", mission_phase()). },
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    "MATCH_INCL",   phase_match_incl@,  // match inclination of rescue target
    "PLAN_XFER",    plan_xfer@,         // create maneuver node for starting transfer.
    "EXEC_XFER",    exec_node@,         // execute the maneuver to inject into the transfer orbit.
    "PLAN_CORR",    plan_corr@,         // plan mid-transfer correction
    "EXEC_CORR",    exec_node@,         // execute the mid-transfer correction.
    // TODO mid-transfer course correction
    // TODO match rescue target
    "TBD", {        // further steps are TBD.
        say("TBD", false). return 5. },
    "")).
//
// Now go do it.
//
mission_fg().
wait until false.