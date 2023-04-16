@LAZYGLOBAL off.
{   parameter mnv is lex(). // Maneuver Node Execution

    local nv is import("nv").
    local predict is import("predict").
    local memo is import("memo").
    local ctrl is import("ctrl").
    local dbg is import("dbg").

    //
    // This package is derived from:
    //
    // Maneuver Library v0.1.0
    // Kevin Gisi
    // http://youtube.com/gisikw
    //
    // forked from hhis version 0.1.0 of that package,
    // as seen in Episode 039 and recorded in Github
    // at https://github.com/gisikw/ksprogramming.git
    // in episodes/e039/mnv.v0.1.0.ks
    //
    // This code has evolved a bit since then.

    local e is constant:e.
    local G0 is constant:G0. // converion factor for Isp

    // there is some data we want to sample just as
    // we start the burn.
    local mnv_step_last_call is 0.
    local mnv_step_preroll is true.

    local function never { return false. }

    local mnv_step_initial_burn is V(0,0,0).
    local mnv_step_final_time is 0.
    local mnv_step_start_time is 0.

    mnv:add("step", {         // maneuver step computation for right now
        parameter abort_callback is never@.

        // mnv:step(abort_fd) implements the brief step function that
        // updates controls to best match the next maneuver node, with
        // each call returning promptly. This essentally has several
        // phases of operation with a few things that happen on each call.

        // First, the parameter is an optional condition that is tested
        // inside the innermost code, which cuts throttle to zero and
        // ends the operation if it returns true.

        // On any call, if ABORT is active or there is no maneuver node,
        // this function returns immediately. The code that cancels the
        // throttle and steering when we have no node is a recent addition.
        // TODO make sure this works. It is not tested as I type this comment.

        if abort {
            // print "mnv:step done, abort switch is on.".
            return 0. }

        if not hasnode {
            // print "mnv:step done, maneuver node is missing.".
            ctrl:dv(V(0,0,0),1,1,5).
            return 0. }

        // If we are in timewarp, or timewarp is not settled,
        // then take no action for another second. This will be
        // exercised when we are doing a WARPTO to advance to
        // near the starting time.
        //
        // If the flight engineer engages timewarp, and does not
        // cancel it, we will miss the maneuver node. It is the
        // responsibility of the flight engineer to not over-warp
        // if they still want to execute the maneuver.

        if kuniverse:timewarp:rate>1 return 1.
        if not kuniverse:timewarp:issettled return 1.

        // If we currently have no available thrust,
        // but if there is still Delta-V available
        // on the vessel, stall briefly to allow the
        // auto-stager to finish its job.

        if availablethrust=0 and ship:deltav:current>0
            return 1/10.

        // Currently the sequencer does not make it apparent when
        // this is a "first" call to a step or a repeated call, so
        // we use a heuristic: if it has been more than a small time
        // since our last call, then this is an initial call for
        // this maneuver node, and we set a "preroll" flag to modify
        // later behavior.

        local t is time:seconds.
        local since_last_call is t - mnv_step_last_call.
        set mnv_step_last_call to t.
        if (since_last_call > 10)
            set mnv_step_preroll to true.


        // Every time through here, fetch the node, sample the
        // burn vector, and retrieve our termination threshold.

        local n is nextnode.
        local bv is n:burnvector.
        local good_enough is nv:get("mnv/step/good_enough", 0.001).

        if (mnv_step_preroll) {

            // Some of our logic will be based on information that must
            // be decided just before we start the burn: the initial
            // burn vector, the burn start time, and the burn end time.
            //
            // Sample and compute this every call during the preroll.

            local burntime is mnv:time(bv:mag).
            local waittime is n:eta - burntime/2 - 1.5.

            set mnv_step_initial_burn to bv.
            set mnv_step_start_time to time:seconds + waittime.
            set mnv_step_final_time to mnv_step_start_time + burntime + 60.
        }

        // preroll or not, compute the time until the start. As we pass the
        // start time computed above, turn off preroll, because it is time to
        // start actually burning.

        local waittime is mnv_step_start_time - time:seconds.
        if waittime < 0
            set mnv_step_preroll to false.

        // DV is a function delegate that computes our actual
        // desired burn vector. While this is nominally the
        // burn vector from the maneuver node, we replace it with
        // a zero vector or a very short vector in the right
        // direction as noted below.

        local dv is {

            // If the abort callback returns true, or if the maneuver
            // node is removed, or the node is changed, or the burn vector
            // direction changed by more than 90 degrees, or the current
            // time is after our computed final time, then return V(0,0,0)
            // to cut the throttle and return to the idle pose.

            if abort_callback() return V(0,0,0).
            if not hasnode return V(0,0,0).         // node cancelled
            if nextnode<>n return V(0,0,0).         // node replaced
            local bv is n:burnvector.
            if bv*mnv_step_initial_burn<=0          // do not chase the burn direction.
                return V(0,0,0).
            if time:seconds>mnv_step_final_time     // do not keep burning forever.
                return V(0,0,0).

            // If the start time is still in the future, or if we currently
            // have no available thrust, return a tiny vector indicating no thrust
            // but in the right direction to get us pointed properly.

            if time:seconds<mnv_step_start_time     // before start, hold burn attitude.
                return bv:normalized/10000.
            if availablethrust=0                    // during staging, hold burn attitude.
                return bv:normalized/10000.

            // Compute how long we would have to burn at full thrust to accomplish
            // the required Delta V. Our "good enough" is expressed in terms of
            // full-throttle-seconds; this is intended to have us cut throttle if
            // we expect we would overshoot the burn.

            local dt is bv:mag*ship:mass/availablethrust.
            if dt < good_enough                     // complete if remaining burn time is very small.
                return V(0,0,0).

            // If we get past all those checks, then the desired Delta-V is just
            // the current burn vector from the maneuver node, which KSP and/or k-OS
            // is updating based on what we have burned so far.

            return bv. }.

        // Back in the code executing during the step. Call the DV delegate, and if
        // it returns a zero length vector, we are done. Cut throttle, point in the
        // neutral pose, remove the maneuver node if we still have one. Also we can
        // clear out the "we ran the step" at this point, so a new node popping up
        // very quickly will get the preroll logic run.
        //
        // Provide a 10 second delay as we exit, which should be long enough to get
        // into our idle pose, which is how we signal to the flight engineer that the
        // node is complete, in addition to all the other indications.

        if dv():mag=0 {
            // print "mnv:step done, dv() returned V(0,0,0).".
            // print "deadman margin: " + (mnv_step_final_time-time:seconds).
            set mnv_step_final_time to 0.
            ctrl:dv(V(0,0,0),1,1,5).
            if hasnode remove nextnode.
            return -10. }

        // ok, so we have our DV delegate and we are not done, so we hand it off
        // to the CTRL package, which will arrange to call DV every time the cooked
        // control wants a steering value.

        ctrl:dv(dv,1,1,5).

        // Now, with all that set up: if we have more than a minute until we
        // want to to start the burn, use WARPTO. But first, if timewarp is
        // still in PHYSICS mode, switch to RAILS, because we never use
        // maneuver nodes inside the atmosphere. Have warpto stop 30 seconds
        // before the burn time. We assume that, while burn time might change,
        // it will not cause the burn to start before then.

        if waittime > 60 {
            if vang(steering:vector, facing:vector) < 5 {

                if kuniverse:timewarp:mode = "PHYSICS" {
                    set kuniverse:timewarp:mode to "RAILS".
                    return 1.
                }

                warpto(mnv_step_start_time-30). }
            return 1. }

        // More than two seconds? call us back in a second.
        if waittime > 2
            return 1.

        // still time to wait? wait for the fraction of a second.
        if waittime > 0
            return waittime.

        // Everything is set up. The step itself does not
        // need to run frequently as the inner control loop
        // is handled by CTRL:DV and the DV delegate.

        return 5. }).

    // mnv:EXEC(autowarp)
    //   autowarp         if true, autowarp to the node.
    //
    // The mnv:EXEC method performs the burn described in the next
    // mnv node. Essentially, steer parallel to the direction
    // of thrust in the node, and maintain an appropriate throttle
    // until the remaining burn vector no longer has any component
    // in the direction of the original.
    //
    mnv:add("exec", {
        parameter autowarp is false.

        if abort return.
        if not hasnode return.

        local n is nextnode.
        local dv is n:burnvector.

        local mnv_step_start_time is time:seconds + n:eta - mnv:time(dv:mag)/2.
        lock steering to n:burnvector.

        if autowarp { warpto(mnv_step_start_time - 30). }

        wait until time:seconds >= mnv_step_start_time or abort.
        lock throttle to sqrt(max(0,min(1,mnv:time(n:burnvector:mag)))).

        wait until vdot(n:burnvector, dv) < 0 or abort.
        lock throttle to 0.
        unlock steering.
        remove nextnode.
        wait 0. }).

    mnv:add("v_e", {          // compute aggregate exhaust velocity
        local F is availablethrust.
        if F=0 return 0.
        local all_engines is list().
        list engines in all_engines.
        local den is 0.
        for en in all_engines if en:ignition and not en:flameout {
            if en:isp>0
                set den to den + en:availablethrust / en:isp. }
        if den=0 return 0.
        return G0 * F / den. }).

    mnv:add("time", {         // compute maneuver time.
        parameter dV.

        // TODO: we might stage during the maneuver node burn!
        //
        // Compare the DV of the burn with the DV remaining in
        // the current stage. If we can do it in this stage,
        // the current code is right.
        //
        // Otherwise, add up
        // - the DT for the DV available in this stage
        // - padding for the time to stage
        // - time for the remaining DV using the ship
        //   after this stage is staged away.
        // This will require working out F, V_e and M0
        // for the ship *after* we stage to ignite the
        // next set of engines.

        local F is availablethrust.
        local v_e is mnv:v_e().
        local M0 is ship:mass.

        if F=0 or v_e=0 return 0.   // staging.

        return M0 * (1 - e^(-dV/v_e)) * v_e / F. }).
}
