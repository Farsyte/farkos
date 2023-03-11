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

    mnv:add("update_dv_at_t", {     // update maneuver for dv at time t
        parameter n.                // node to update.
        parameter dv.               // Body-rel change in velocity
        parameter t.                // universal time to apply change.

        local pos_t is predict:pos(t, ship).
        local vel_t is predict:vel(t, ship).

        local basis_p is vel_t:normalized.
        local basis_n is vcrs(vel_t, pos_t):normalized.
        local basis_r is vcrs(basis_n, basis_p).

        set n:time to t.
        set n:radialout to vdot(basis_r, dv).
        set n:normal to vdot(basis_n, dv).
        set n:prograde to vdot(basis_p, dv).
        add n. wait 0. return n. }).

    mnv:add("schedule_dv_at_t", {   // create maneuver for dv at time t
        parameter dv.               // Body-rel change in velocity
        parameter t.                // universal time to apply change.

        local pos_t is predict:pos(t, ship).
        local vel_t is predict:vel(t, ship).

        local basis_p is vel_t:normalized.
        local basis_n is vcrs(vel_t, pos_t):normalized.
        local basis_r is vcrs(basis_n, basis_p).

        local n is node(t, vdot(basis_r, dv), vdot(basis_n, dv), vdot(basis_p, dv)).
        add n. wait 0. return n. }).

    local saved_maneuver_direction is V(0,0,0).
    mnv:add("step", {         // maneuver step computation for right now
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

        // If we currently have no available thrust,
        // but if there is still Delta-V available
        // on the vessel, stall briefly to allow the
        // auto-stager to finish its job.
        if availablethrust=0 and ship:deltav:current>0
            return 1/10.

        local bv is n:burnvector.
        local waittime is n:eta - mnv:time(bv:mag)/2.
        local starttime is time:seconds + waittime.
        local good_enough is nv:get("mnv/step/good_enough", 0.001).

        if waittime>0                               // until nominal time is reached,
            set saved_maneuver_direction to bv.     // continuously update saved direction.

        local dv is {
            if not hasnode return V(0,0,0).         // node cancelled
            if nextnode<>n return V(0,0,0).         // node replaced
            local bv is n:burnvector.
            if bv*saved_maneuver_direction<=0       // complete if deltav has rotated more than 90 degrees.
                return V(0,0,0).

            if time:seconds<starttime               // before start, hold burn attitude.
                return bv:normalized/10000.
            if availablethrust=0                    // during stating, hold burn attitude.
                return bv:normalized/10000.

            local dt is bv:mag*ship:mass/availablethrust.
            if dt < good_enough                     // complete if remaining burn time is very small.
                return V(0,0,0).
            return bv. }.

        if dv():mag=0 {
            ctrl:dv(V(0,0,0),1,1,5).
            if hasnode remove nextnode.
            return -10. }

        ctrl:dv(dv,1,1,5).

        if waittime > 60 {
            if vang(steering:vector, facing:vector) < 5 {
                warpto(starttime-30). }
            return 1. }

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
