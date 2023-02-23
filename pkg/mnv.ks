@LAZYGLOBAL off.
{   parameter mnv is lex(). // Maneuver Node Execution

    local nv is import("nv").

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
    // Changes:
    // - added attribution comment above
    // - added limited documentation of the API
    // - refactored for my IMPORT mechanism
    // - create and export mnv:step
    // - export mnv:time
    // - separate ISP computation out of mnv:time
    // - correct Isp computation for non-identical engines
    // - prefer using exhaust velocity over Isp
    // - compute aggregate exhaust velocity using g₀
    // - removed staging logic (see PHASES:BG_STAGER)

    local e is constant:e.
    local G0 is constant:G0. // converion factor for Isp

    mnv:add("step", {         // maneuver step computation for right now

        local good_enough is nv:get("mnv/step/good_enough", 0.01).
        local max_facing_error is nv:get("mnv/step/max_facing_error", 5).
        //
        // mnv:step() is intended to provide the same results
        // as mnv:exec() but with control inverted: where mnv:exec()
        // blocks until complete, mnv:step() does one step and returns.
        //
        if abort return 0.
        if not hasnode return 0.
        if kuniverse:timewarp:rate>1 return 1.
        if not kuniverse:timewarp:issettled return 1.

        local n is nextnode.
        local dv is n:burnvector.

        lock steering to lookdirup(n:burnvector, facing:upvector).

        local waittime is n:eta - mnv:time(dv:mag)/2.
        local starttime is time:seconds + waittime.

        if waittime > 60 {
            if throttle>0 {
                lock throttle to 0.
                return 1. }
            warpto(starttime-10).
            return 1. }

        if waittime>0 return min(1, waittime).

        local dt is mnv:time(n:burnvector:mag).

        if dt <= good_enough {          // termination condition.
            lock throttle to 0.
            lock steering to facing.
            remove nextnode.
            return 0. }

        local _throttle is {
            local desired_throttle is clamp(0,1,dt).
            local facing_error is vang(facing:vector,nextnode:burnvector).
            local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
            local th is clamp(0,1,facing_error_factor*desired_throttle).
            return th. }. lock throttle to _throttle().

        return 1. }).

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

        local starttime is time:seconds + n:eta - mnv:time(dv:mag)/2.
        lock steering to n:burnvector.

        if autowarp { warpto(starttime - 30). }

        wait until time:seconds >= starttime or abort.
        lock throttle to sqrt(max(0,min(1,mnv:time(n:burnvector:mag)))).

        wait until vdot(n:burnvector, dv) < 0 or abort.
        lock throttle to 0.
        unlock steering.
        remove nextnode.
        wait 0. }).

    mnv:add("v_e", {          // compute aggregate exhaust velocity
        local F is availablethrust.
        if F=0 return 0.
        list engines in all_engines.
        local den is 0.
        for en in all_engines if en:ignition and not en:flameout {
            if en:isp>0
                set den to den + en:availablethrust / en:isp. }
        if den=0 return 0.
        return G0 * F / den. }).

    mnv:add("time", {         // compute maneuver time.
        parameter dV.

        local F is availablethrust.
        local v_e is mnv:v_e().
        local M0 is ship:mass.

        if F=0 or v_e=0 return 0.   // staging.

        return M0 * (1 - e^(-dV/v_e)) * v_e / F. }).
}