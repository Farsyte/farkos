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
        //
        // mnv:step() is intended to provide the same results
        // as mnv:exec() but with control inverted: where mnv:exec()
        // blocks until complete, mnv:step() does one step and returns.
        //
        if abort {
            // print "mnv:step done, abort switch is on.".
            return 0. }
        if not hasnode {
            // print "mnv:step done, maneuver node is missing.".
            return 0. }
        if kuniverse:timewarp:rate>1 return 1.
        if not kuniverse:timewarp:issettled return 1.

        local n is nextnode.

        // If we currently have no available thrust,
        // but if there is still Delta-V available
        // on the vessel, stall briefly to allow the
        // auto-stager to finish its job.
        if availablethrust=0 and ship:deltav:current>0
            return 1/10.

        local bv is n:burnvector.
        local good_enough is nv:get("mnv/step/good_enough", 0.001).

        // if we have not called mnv:step in the last 10 seconds,
        // then presume this is an initial call.
        local t is time:seconds.
        local since_last_call is t - mnv_step_last_call.
        set mnv_step_last_call to t.

        if (since_last_call > 10)
            set mnv_step_preroll to true.

        if (mnv_step_preroll) {

            local burntime is mnv:time(bv:mag).
            local waittime is n:eta - burntime/2 - 1.5.

            set mnv_step_initial_burn to bv.
            set mnv_step_start_time to time:seconds + waittime.
            set mnv_step_final_time to mnv_step_start_time + burntime + 60.
        }

        local waittime is mnv_step_start_time - time:seconds.
        if waittime < 0
            set mnv_step_preroll to false.

        local dv is {
            if abort_callback() return V(0,0,0).
            if not hasnode return V(0,0,0).         // node cancelled
            if nextnode<>n return V(0,0,0).         // node replaced
            local bv is n:burnvector.
            if bv*mnv_step_initial_burn<=0          // do not chase the burn direction.
                return V(0,0,0).
            if time:seconds>mnv_step_final_time     // do not keep burning forever.
                return V(0,0,0).

            if time:seconds<mnv_step_start_time     // before start, hold burn attitude.
                return bv:normalized/10000.
            if availablethrust=0                    // during staging, hold burn attitude.
                return bv:normalized/10000.

            local dt is bv:mag*ship:mass/availablethrust.
            if dt < good_enough                     // complete if remaining burn time is very small.
                return V(0,0,0).
            return bv. }.

        if dv():mag=0 {
            // print "mnv:step done, dv() returned V(0,0,0).".
            // print "deadman margin: " + (mnv_step_final_time-time:seconds).
            set mnv_step_final_time to 0.
            ctrl:dv(V(0,0,0),1,1,5).
            if hasnode remove nextnode.
            return -10. }

        ctrl:dv(dv,1,1,5).

        if waittime > 60 {
            if vang(steering:vector, facing:vector) < 5 {

                if kuniverse:timewarp:mode = "PHYSICS" {
                    set kuniverse:timewarp:mode to "RAILS".
                    return 1.
                }

                warpto(mnv_step_start_time-30). }
            return 1. }

        if waittime > 2
            return 1.
        if waittime > 0
            return waittime.
        return 1/1000. }).

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
