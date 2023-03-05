{
    parameter rdv is lex(). // RDV package: rendezvous

    local ctrl is import("ctrl").
    local memo is import("memo").
    local predict is import("predict").
    local mnv is import("mnv").
    local targ is import("targ").
    local nv is import("nv").
    local io is import("io").
    local dbg is import("dbg").

    local holding_position is false.

    rdv:add("node", {                                               // place maneuver node at xfer/final

        until not hasnode { remove nextnode. wait 0. }

        local t2 is nv:get("xfer/final").
        local dt is t2 - time:seconds.
        if dt < 60 return 0.

        local r1 is targ:standoff(t2). // predict:pos(t2, target).
        local r2 is predict:pos(t2, ship).

        local v1 is predict:vel(t2, target).
        local v2 is predict:vel(t2, ship).
        local dv is v1 - v2.
        mnv:schedule_dv_at_t(dv, t2).

        // dbg:pv("rdv node dt", dt).
        // dbg:pv("rdv node dv", dv).
        // dbg:pv("rdv dist", r2-r1).

        return 0. }).

    rdv:add("coarse", {                                             // coarse rendezvous from very far away
        parameter targ is target.
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

        local r_p is targ:standoff(time:seconds).
        local t_p is r_p+body:position.                               // pv("t_p", t_p).
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

    rdv:add("near", {                   // engine based approach dist <= TSD and speed<=1 m/s
        if abort return 0.
        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        local standoff_distance to targ:standoff_distance.
        set targ:parking_distance to standoff_distance.
        targ:draw_parking().

        local dv is memo:getter({

            if not hastarget return V(0,0,0).

            // t_p is from ship to parking far enough from the target
            // to allow "LF Engine Safe" maneuvering.

            local t_p is targ:park_from_ship().
            local d_p is t_p:mag.

            local t_v is target:velocity:orbit.
            local s_v is ship:velocity:orbit.
            local r_v is t_v - s_v.

            if holding_position {
                // when holding, stop holding if
                // we drift standoff_distance/2 meters away from parking or if our
                // relative speed hits 5 m/s.
                if d_p < 0.50*standoff_distance and r_v:mag < 5.0 {
                    return V(0,0,0). }
                print "rdv:near out of position.".
                set holding_position to false. }

            if d_p < 0.20*standoff_distance and r_v:mag < 1.0 {
                // when slow and within 20% of standoff distance from standoff, hold position.
                set holding_position to true.
                print "rdv:near in position.".
                return V(0,0,0). }

            if d_p < 0.40*standoff_distance {
                // when moving fast within 40% of standoff distance from parking,
                // burn to cancel the velocity.
                return r_v. }

            // not close enough. burn to set velocity
            // to close at a controlled rate based on
            // the stopping distance equation, using
            // a distance that is reduced by 10% of the
            // standoff distance.
            //
            // NOTE: once we accelerate to this rate,
            // we need to FLIP THE ROCKET AROUND
            // to be able to decelerate.

            local cmd_X is d_p - 0.10*standoff_distance.
            local cmd_A is availablethrust * 0.10 / ship:mass.
            local cmd_V is sqrt(2*cmd_A*cmd_X).
            return r_v + t_p:normalized*cmd_V. }).


        ctrl:dv(dv, 1, 1, 15).

        if holding_position {
            io:say("This is Fine.", false).
            ctrl:dv(V(0,0,0),1,1,5).
            clearvecdraws().
            set fine_drawn_timeout to 0.
            return 0. }

        return 5. }).

    // TODO update rdv:fine from rdv:near.
    rdv:add("fine", {                   // entirely engine based rescue fine control and posing
        if abort return 0.
        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        local standoff_distance is targ:standoff_distance.

        local dv is memo:getter({

            if not hastarget return V(0,0,0).

            // t_p is from ship to the target standoff point.
            local body_to_target is target:position-body:position.
            local standoff_vector is body_to_target:normalized*standoff_distance.

            // we can use a radius vector above, since the NORMALIZED vector
            // will not be rotating, but when computing and subtracting positions,
            // avoid involving radius vectors.

            local t_p is target:position - standoff_vector.
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

            if d_p < 40 and r_v:mag < 0.02 {
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

            local cmd_X is d_p - 10.
            local cmd_A is availablethrust * 0.10 / ship:mass.
            local cmd_V is sqrt(2*cmd_A*cmd_X).
            return r_v + t_p:normalized*cmd_V. }).

        ctrl:dv(dv, 1, 1, 15).

        if dv():mag=0 io:say("This is Fine.", false).

        return 5. }).

    rdv:add("rcs_5m", {
        if abort return 0.
        if not hastarget return 0.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
        if kuniverse:timewarp:rate>1 {
            kuniverse:timewarp:cancelwarp().
            return 1/10. }

        set targ:parking_distance to 5.

        // SURPRISE: target:orbit:position <> target:position
        // dbg:pv("      target:position", target:position).
        // dbg:pv("target:orbit:position", target:orbit:position).
        // dbg:pv("  targ:orbit:position", targ:orbit:position).

        if targ:park_from_ship():mag>(2*targ:parking_distance) {
            io:say("Approacing to "+targ:parking_distance+" m.", false).
            io:say("Please be patient.", false). }
        else {
            io:say("Holding "+targ:parking_distance+" m from Target.", false). }
        ctrl:rcs_dx(targ:park_from_ship).
        targ:draw_parking().
        return 5. }).

}