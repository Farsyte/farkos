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

local pi is constant:pi.
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
function plan_xfer {                    // construct initial transfer maneuver

    if not rcs {
        say("activate RCS to continue.", false).
        return 5.
    }
    rcs off.

    persist_put("phase_plan_xfer", mission_phase()).

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
    local Ship_P0 is {                  // Body->Ship vector at T0
        local ret is positionat(ship, Xfer_T0) - body:position.
        return ret. }.
    local Xfer_R0 is {                  // Xfer start radius
        local ret is Ship_P0():mag.
        return ret. }.
    local Xfer_A is {                   // Xfer semi-major axis
        local ret is (Xfer_R0()+Xfer_RF)/2.
        return ret. }.
    local Xfer_T is {                   // Xfer transfer time
        local ret is pi*sqrt(Xfer_A()^3/mu).
        return ret. }.
    local Xfer_TF is {                  // final time for transfer
        local ret is Xfer_T0 + Xfer_T().
        return ret. }.
    local Ship_PF is {                  // Body->Ship vector at TF
        local ret is -Ship_P0():normalized*Xfer_RF.
        return ret. }.
    local Targ_PF is {                  // Body->Targ vector at TF
        local ret is positionat(targ, Xfer_TF()) - body:position.
        return ret. }.
    local Error_PF is {                 // Targ->Ship vector at TF
        local tpf is Targ_PF().
        local spf is Ship_PF().
        // FOR DEBUG show me angles and Targ_VF
        local ang is vang(tpf, spf).
        local ret is tpf - spf.
        return ret. }.
    // DEV NOTE: can peek at the initial transfer here.
    local Curr_E is Error_PF():mag.
    local Prev_E is 0.
    local Xfer_Tune is {                // transfer tuning function.
        parameter done.                 // delegate: when to stop
        until done() { } }.
    local Xfer_dt_try is { parameter dt.
        set Prev_E to Curr_E.           // previous error, for comparison.
        set Prev_T0 to Xfer_T0.         // previous time, for rewind.
        set Xfer_T0 to Xfer_T0 + dt.
        set Curr_E to Error_PF():mag.                                           }.
    local Xfer_dt_rew is {
        set Xfer_T0 to Prev_T0.
        Xfer_dt_try(0).                                                         }.
    local Xfer_dt_until_better is { parameter dt. Xfer_dt_try(dt). return Curr_E < Prev_E. }.
    local Xfer_dt_until_worse is { parameter dt. Xfer_dt_try(dt). return Curr_E > Prev_E. }.
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
    // BURN VECTOR: (time, prograde, radial, normal)
    //
    // HILLCLIMB to get the best prograde burn.
    //
    // Buring NORMAL when we are 180 degrees away is massively inefficient.
    // The code is set up here so that if the list does not have a 4th
    // element, then we do not try to burn normal.
    //
    // I want to see how well we can do with just a prograde burn.
    //
    function initial_burn {     // construct the initial list defining the burn.
        local r1 is Xfer_R0().
        local r2 is Xfer_HF.
        local Xfer_S0 is visviva_v(r1, r2).
        local Xfer_dV is xfer_S0 - visviva_v(r1).
        // if we add a 3rd value, we hillclimb the radial burn as well.
        // if we add a 4th value, we hillclimb the normal burn as well.
        return list(Xfer_T0, Xfer_dV).
        } local burn is initial_burn.

    {   // create the initial maneuver node.
        // note that all of its parameters will get rewritten.
        add node(time:seconds+300, 0, 0, 0).
        wait 0. }

    local set_burn is {         // set the maneuver node to the burn state given.
        parameter burn.
        local n1 is nextnode.
        if burn:length > 0 and fp_differs(n1:time, burn[0]) set n1:time to burn[0].
        if burn:length > 1 and fp_differs(n1:prograde, burn[1]) set n1:prograde to burn[1].
        if burn:length > 2 and fp_differs(n1:radialout, burn[2]) set n1:radialout to burn[2].
        if burn:length > 3 and fp_differs(n1:normal, burn[3]) set n1:normal to burn[3].
        wait 0.  }.
    local eval_count is 0.
    local fitness_fn is {       // fitness, for hillclimbing. More positive is better.
        parameter burn.
        set_burn(burn).
        local n1 is nextnode.
        local xo is n1:orbit.
        local tf is time:seconds+n1:eta+xo:period/2.
        local sp is positionat(ship, tf) - body:position.
        local tp is positionat(targ, tf) - body:position.
        local pe is (tp-sp):mag.
        set eval_count to eval_count + 1.
        return -pe. }.

    print "initial fitness="+fitness_fn(burn)+", burn=["+burn:join(" ")+"]".

    local step_size is 300.
    until step_size < 0.01 {    // hillclimb for smaller and smaller step sizes.
        set step_size to step_size / 10.
        set burn to hillclimb:seek(burn, fitness_fn, step_size).
        set_burn(burn).
        print "step_size="+step_size+", fitness="+fitness_fn(burn)+", burn=["+burn:join(" ")+"]". }
    print "final fitness="+fitness_fn(burn)+", burn=["+burn:join(" ")+"]".
    print "evaluated "+eval_count+" burn vectors.".
    return 0. }
function exec_xfer { // execute the maneuver to get into the transfer orbit.
    if not rcs {
        say("activate RCS to continue.", false).
        return 5.
    }
    rcs off.

    // if the node is missing, rebuild it.
    if not hasnode {
        mission_jump(persist_get("phase_plan_xfer", mission_phase()-2)).
        return 0.
    }
    local n is nextnode.
    local o is n:orbit.
    local Xfer_T0 is time:seconds + n:eta.
    local Xfer_TF is Xfer_T0 + o:period/2.
    persist_put("xfer_start_time", Xfer_T0).
    persist_put("xfer_final_time", Xfer_TF).
    persist_put("xfer_corr_time", (Xfer_T0+Xfer_TF)/2).
    print "mnv_time: "+maneuver:time(n:deltav:mag).
    print "mnv_eta: "+TimeSpan(n:eta):full.
    print "triggering mnv_exec.".
    maneuver:exec(true).
    print "maneuver:exec complete.".
    return 0.
}
function plan_corr {                    // plan a mid-course correction.
    local xfer_start_time is persist_get("xfer_start_time").
    local xfer_final_time is persist_get("xfer_final_time").
    local xfer_corr_time is persist_get("xfer_corr_time").
    // if we overshot, we may need to re-circularize at the ready orbit.
    say("TBD: plan mid-transfer correction").
    say("ETA: "+round(xfer_corr_time - time:seconds, 1)).
    return 5. }
function exec_corr {                    // plan a mid-course correction.
    // if we overshot, we may need to re-circularize at the ready orbit.
    say("TBD: exec mid-transfer correction").
    return 5. }
//
// Mission Plan
//
mission_add(LIST(
    "PADHOLD",      phase_match_lan@,   // PADHOLD until we can match target ascending node.
    "COUNTDOWN",    phase_countdown@,    // initiate unmanned flight.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    "MATCH_INCL",   phase_match_incl@,  // match inclination of rescue target
    "PLAN_XFER",    plan_xfer@,         // create maneuver node for starting transfer.
    "EXEC_XFER",    exec_xfer@,         // execute the maneuver to inject into the transfer orbit.
    "PLAN_CORR",    plan_corr@,         // plan mid-transfer correction
    "EXEC_CORR",    exec_corr@,         // execute the mid-transfer correction.
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