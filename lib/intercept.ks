loadfile("debug").
loadfile("predict").
loadfile("visviva").
loadfile("hillclimb").

local burn_steps is list(30, 10, 3, 1, 0.3, 0.1, 0.03, 0.01).

function plan_intercept {    // build MANEUVER to enter Hohmann toward Targ
    parameter targ is target.
    local pi is constant:pi.

    // Operation does not coexist with existing maneuver nodes.
    until not hasnode { remove nextnode. wait 0. }

    // Operation is UNDEFINED if the target is not in orbit around
    // the same body as the ship.

    local t1 is time:seconds + 300.             // First trial hohmann starts in five minutes,
    local r2 is body:radius + targ:apoapsis.    // and ends at the the target apoapsis altitude.

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

    {   // Create a node and tune it's Prograde DV.
        // Using HILLCLIMB for this is overkill, but
        // it is easy to set up and works well.

        local r1 is predict_pos(t1, ship):mag.
        local r2 is predict_pos(t2, targ):mag.
        local dv is visviva_v(r1, r2) - predict_vel(t1, ship):mag.

        hillclimb:seeks(list(dv),
            {   parameter burn. set mnv:prograde to burn[0]. wait 0.
                return -predict_pos_err(t2, targ). }, burn_steps). }

    {   // persist timestamps for xfer start, final, and corr.
        local n is nextnode.
        local o is n:orbit.

        local t1 is time:seconds + n:eta.
        persist_put("xfer_start_time", t1).

        local t2 is t1 + o:period/2.
        persist_put("xfer_final_time", t2).

        // the best time to make the correction will depend
        // on the correction. buring sooner makes for smaller
        // burns that need more precision. burning later means
        // more thrust to get the same result, but similar errors
        // will perturb the result less.
        //
        // maybe think in terms of a succession of corrections?

        local tc is (t1+t2)/2.
        persist_put("xfer_corr_time", tc). }

    return 0. }

function plan_correction {    // build MANEUVER to enter Hohmann toward Targ
    parameter targ is target.
    //
    // xfer_corr_time is when to burn. It must be persisted,
    // and must be far enough in the future to allow
    // planning the burn and pointing the burn direction.
    local T0 is persist_get("xfer_corr_time").
    if T0 < time:seconds+60 {
        say("plan_intercept: node time too close.").
        return 0.
    }
    //
    // xfer_final_time is when to arrive. It must be persisted,
    // and must be far enough in the future from the above
    // to allow the burn to be useful..
    local Tf is persist_get("xfer_final_time").
    if Tf < T0+60 {
        say("plan_intercept: meet time too close.").
        return 0.
    }
    //
    // This does not play well with existing nodes.
    until not hasnode { remove nextnode. wait 0. }
    //
    // Build the node we will adjust.
    add node(T0, 0, 0, 0). wait 0.
    //
    hillclimb:seeks(list(0, 0, 0), { parameter burn.
        set nextnode:prograde to burn[0].
        set nextnode:radialout to burn[1].
        set nextnode:normal to burn[2]. wait 0.
        return -predict_pos_err(Tf, mission_target). }, burn_steps).

    return 0. }
