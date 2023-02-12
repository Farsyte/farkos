loadfile("debug").
loadfile("predict").
loadfile("visviva").
loadfile("hillclimb").

local burn_steps is list(30, 10, 3, 1, 0.3, 0.1, 0.03, 0.01).

function intercept_error {
    local Tf is persist_get("xfer_final_time").
    return predict_pos_err(Tf, mission_target). }

function plan_intercept {    // build MANEUVER to enter Hohmann toward Targ
    parameter targ is target.
    local pi is constant:pi.

    // Operation does not coexist with existing maneuver nodes.
    until not hasnode { remove nextnode. wait 0. }

    // Operation is UNDEFINED if the target is not in orbit around
    // the same body as the ship.

    local t1 is time:seconds + 300.             // First trial hohmann starts in five minutes,
    local r2 is body:radius + targ:apoapsis.    // and ends at the the target apoapsis altitude.

    local r1 is predict_pos(t1, ship):mag.
    local dv is visviva_v(r1, r2) - predict_vel(t1, ship):mag.

    // Track these data as we adjust the transfer:
    local t2 is 0.              // UT at the end of the transfer
    local e2 is 0.              // distance from ship to targ at t2.

    function eval_xfer {        // evaluate for (t1+=dt) and r2, return e2.
        parameter dt is 0.
        set t1 to t1 + dt.

        local p1 is predict_pos(t1, ship).
        local Xa is (p1:mag+r2)/2.
        set t2 to t1 + pi*sqrt(Xa^3/body:mu).
        local FPt is predict_pos(t2, targ).
        local FPs is -p1:normalized*r2.
        local FPe is FPs - FPt.
        return FPe:mag. }
    //
    set e2 to eval_xfer(0).
    //
    function trial_xfer {       // evaluate for (t1+=dt) and r2, return change in e2.
        parameter dt is 0.
        set eOld to e2.
        return eval_xfer(dt) - eOld. }

    // Find a feasible starting point for hillclimbing.
    //
    // Needs to start where hillclimbing will not try
    // to climb back before the current time, so push
    // the start time until past a maximum error, then
    // keep pushing until past a minimum error.
    //
    until trial_xfer(300) < 0.          // move forward past a maximum error
    until trial_xfer(300) > 0.          // move forward past a minimum error

    // Tune Start Time to best match the target.
    // Using HILLCLIMB for this is overkill, but
    // it is easy to set up and works well.
    hillclimb:seeks(list(t1), { parameter burn.
        set t1 to burn[0].
        return -eval_xfer(). }, burn_steps).

    // Create the node we will tune.
    local mnv is node(t1, 0, 0, 0). add mnv. wait 0.

    {   // Create a node and tune Prograde DV.
        // Using HILLCLIMB for this is overkill, but
        // it is easy to set up and works well.

        set r1 to predict_pos(t1, ship):mag.
        set r2 to predict_pos(t2, targ):mag.
        set dv to visviva_v(r1, r2) - predict_vel(t1, ship):mag.

        hillclimb:seeks(list(dv),
            {   parameter burn. set mnv:prograde to burn[0]. wait 0.
                return -predict_pos_err(t2, targ). }, burn_steps). }

    {   // Now tune both DV and Prograde together.
        hillclimb:seeks(list(nextnode:time, nextnode:prograde),
            {   parameter burn.
                set t1 to burn[0].
                set dv to burn[1].
                set mnv:time to t1.
                set mnv:prograde to dv. wait 0.
                set t2 to t1 + mnv:orbit:period/2.
                return -predict_pos_err(t2, targ). }, burn_steps). }

    {   // persist timestamps for xfer start, final, and corr.
        local n is nextnode.
        local o is n:orbit.

        local t1 is time:seconds + n:eta.
        persist_put("xfer_start_time", t1).

        local t2 is t1 + o:period/2.
        persist_put("xfer_final_time", t2). }

    return 0. }

function plan_correction {    // build MANEUVER to enter Hohmann toward Targ
    parameter targ is target.
    //
    // This does not play well with existing nodes.
    until not hasnode { remove nextnode. wait 0. }
    //
    // xfer_final_time is when to arrive. It must be persisted,
    // and must be far enough in the future from the above
    // to allow the burn to be useful..
    local Tf is persist_get("xfer_final_time").
    //
    // if our final position is within 100m, then
    // do not plan a maneuver node.
    local e is predict_pos_err(Tf, mission_target).
    if e < 100 {
        print "plan_correction: none needed, e is "+round(e,1).
        return 0. }
    //
    // Do not plan a correction if we are within
    // five minutes of the rendezvous.
    local dt is tF - time:seconds.
    if dt < 300 {
        print "plan_correction: none planned, arrival in "+round(dt,1).
        return 0. }
    //
    // Plan the correction to be 20% of the time between
    // now and the intercept time. We might perform several
    // corrections in the course of a long transit.
    local T0 is time:seconds + dt*0.20.
    //
    // Build the node we will adjust.
    add node(T0, 0, 0, 0). wait 0.
    //
    hillclimb:seeks(list(0, 0, 0), { parameter burn.
        set nextnode:prograde to burn[0].
        set nextnode:radialout to burn[1].
        set nextnode:normal to burn[2]. wait 0.
        return -predict_pos_err(Tf, mission_target). }, burn_steps).
    local e is predict_pos_err(Tf, mission_target).
    print "plan_correction: predicting final error is "+round(e,1).
    return 0. }
