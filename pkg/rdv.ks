{
    parameter rdv is lex(). // RDV package: rendezvous

    local ctrl is import("ctrl").
    local memo is import("memo").
    local predict is import("predict").
    local mnv is import("mnv").
    local nv is import("nv").
    local dbg is import("dbg").

    rdv:add("node", {

        until not hasnode { remove nextnode. wait 0. }

        local t2 is nv:get("xfer/final").
        local dt is t2 - time:seconds.
        if dt < 60 return 0.

        local r1 is predict:pos(t2, target).
        local r2 is predict:pos(t2, ship).

        local v1 is predict:vel(t2, target).
        local v2 is predict:vel(t2, ship).
        local dv is v1 - v2.
        mnv:schedule_dv_at_t(dv, t2).

        dbg:pv("rdv node dt", dt).
        dbg:pv("rdv node dv", dv).
        dbg:pv("rdv dist", r2-r1).

        return 0. }).

    rdv:add("coarse", { parameter targ is target.
        if abort return 0.

        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        local Tf is nv:get("xfer/final").
        local stop_warp_at is Tf - 60.
        local wait_for is stop_warp_at - time:seconds.

        if wait_for>30 {
            lock steering to facing.
            lock throttle to 0.
            wait 3.
            warpto(stop_warp_at).
            return 1. }

        if wait_for>0 {
            lock steering to facing.
            lock throttle to 0.
            return min(1, wait_for). }

        // Coarse Approach Maneuver
        //
        // Consider a local coordinate system with
        // a zero plane perpendicular to our prograde
        // velocity, which passes through the target.
        //
        // Thrust to bring our velocity relative to that
        // plane to zero when at (margin) meters before
        // intersecting the plane.
        //
        // Stopping Distance formula:
        //      cmd_X = cmd_V^2 / 2 cmd_A
        // Pick an acceleration. Work out the distance,
        // and set the throttle (or not) based on cmd_X and
        // our current distance.

        local margin is 20.

        local dir is prograde:vector.                               // pv("dir", dir).

        local t_p is target:position.                               // pv("t_p", t_p).
        local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
        local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).

        // if we descended, ship are overtaking. Xc and Vc are positive.
        // if we ascended, target is overtaking. Xc and Vc are negative.

        local Xc is vdot(t_p, dir).                     // pv("Xc", xc). // distance available to stop
        local Vc is vdot(s_v - t_v, dir).               // pv("Vc", Vc). // speed toward the stopping point

        if Xc > 0 {
            lock steering to retrograde. }
        else {
            set Xc to -Xc.      // pv("Xc", xc).
            set Vc to -Vc.      // pv("Vc", Vc).
            lock steering to prograde. }

        set Xc to Xc - margin.  // pv("Vc", Vc).

        if Vc<=0 or Xc<=0 {
            lock throttle to 0.
            return 0. }

        local cmd_A is availablethrust / ship:mass.                 // available acceleration
        if cmd_A=0 return 1/100.                                    // staging. deal with it.
        local cmd_X is Vc^2 / (2*cmd_A).                                // minimum stopping distance.

        if Xc < cmd_X {// we overshot.
            return 0. }

        local Xr is cmd_X / Xc.
        if throttle=0 {
            if Xr<0.90 {
                // wait until we are closer.
                lock throttle to 0.
                return 1/100. } }

        if Xr < 0.01 {
            lock throttle to 0.
            return 0. }

        lock throttle to clamp(0,1,Xr).
        return 1/100. }).

    local holding_position is false.
    rdv:add("fine", { parameter targ is target.
        if abort return 0.
        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        local dv is memo:getter({

            if not hastarget return V(0,0,0).

            local t_p_raw is target:position.
            // OFFSET THE AIM POINT 100m toward the body,
            // so we do not bulls-eye the vessel on our
            // way in, if we overshoot.
            local t_p is t_p_raw - 100*t_p_raw:normalized.
            local d_p is t_p:mag.

            local t_v is target:velocity:orbit.
            local s_v is ship:velocity:orbit.
            local r_v is t_v - s_v.

            if holding_position {
                // when holding, stop holding if
                // we drift 100 meters away or if our
                // relative speed hits 0.1 m/s.
                if d_p < 100 and r_v:mag < 1.0 {
                    return V(0,0,0). }
                print "rdv:fine starting maneuver.".
                set holding_position to false. }

            if d_p < 40 and r_v:mag < 0.01 {
                // when close and slow, hold position.
                set holding_position to true.
                print "rdv:fine holding position.".
                return V(0,0,0). }

            if d_p < 30 {
                // when close but not slow,
                // burn to cancel the velocity.
                return r_v. }

            // not close enough. burn to set velocity
            // to close at a controlled rate.
            //
            // NOTE: once we accelerate to this rate,
            // we need to FLIP THE ROCKET AROUND
            // to be able to decelerate.

            local cmd_X is d_p - 20.
            local cmd_A is availablethrust * 0.30 / ship:mass.
            local cmd_V is sqrt(2*cmd_A*cmd_X).
            return r_v + t_p:normalized*cmd_V. }).

        ctrl:dv(dv, 1, 1, 15).

        return 1. }). }