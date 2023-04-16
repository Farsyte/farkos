{   parameter rdv is lex(). // RDV package: rendezvous

    // mission sequence steps relatiing to Rendezvous.

    local ctrl is import("ctrl").
    local memo is import("memo").
    local predict is import("predict").
    local plan is import("plan").
    local targ is import("targ").
    local nv is import("nv").
    local io is import("io").
    local dbg is import("dbg").

    local holding_position is false.

    rdv:add("node", {                                               // place maneuver node at xfer/final

        // rdv:nodd places a maneuver node at the "xfer/final" time,
        // with the Delta-V set to the burn that, if done in zero time,
        // would match our velocity with the target velocity.
        //
        // NOTE: this is for actual rendezvous, do not attempt to use
        // it when the standoff includes an orbital phase angle offset.

        until not hasnode { remove nextnode. wait 0. }

        local t2 is nv:get("xfer/final").
        local dt is t2 - time:seconds.
        if dt < 60 return 0.

        local v1 is predict:vel(t2, target).
        local v2 is predict:vel(t2, ship).
        local dv is v1 - v2.
        plan:dvt(dv, t2).

        return 0. }).

    rdv:add("coarse", {                                             // coarse rendezvous from very far away
        parameter targ is target.

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

        // move on to the next mission plan step if ABORT is set.
        if abort return 0.

        // If we are in timewarp or timewarp is not settled,
        // then just wait until we are back to normal.
        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        // If the rendezvous time is a long way away,
        // use WARPTO to get there in less real time;
        // if it is still in the future, ask the sequencer
        // to delay until the right time.

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

        local margin is 20.

        local dir is prograde:vector.

        local r_p is targ:standoff(time:seconds).
        local t_p is r_p+body:position.
        local t_v is target:velocity:orbit.
        local s_v is ship:velocity:orbit.

        // if we descended, ship are overtaking. Xc and Vc are positive.
        // if we ascended, target is overtaking. Xc and Vc are negative.

        local Xc is vdot(t_p, dir).                     // distance available to stop
        local Vc is vdot(s_v - t_v, dir).               // speed toward the stopping point

        // Pick the burn direction. This is likely to be a
        // fairly big burn, and we will correct later, so
        // burn exactly prograde or retrograde to get the
        // most orbital energy change possible.

        if Xc > 0 {
            lock steering to retrograde. }

        else {
            set Xc to -Xc.
            set Vc to -Vc.
            lock steering to prograde. }

        // We want to stop BEFORE we get there, in fact, "margin"
        // meters before that plane we discussed above. If we are
        // already too close ... cut throttle and move on to the
        // next mission plan step, which will handle the shorter
        // range work of the rendezvous.

        set Xc to Xc - margin.

        if Vc<=0 or Xc<=0 {
            lock throttle to 0.
            return 0. }

        // Base our decisions based on our maximum thrust, and how
        // far we would move before we got our velocity to zero.
        //
        // If we can't stop in time, give up and move on.
        //
        // If we have a much longer distance to go, run again
        // later when we are closer.
        //
        // Between those conditions, try to set the throttle so
        // we hit zero velocity as we reach our intended position.

        local cmd_A is availablethrust / ship:mass.     // available acceleration
        if cmd_A=0 return 1/100.                        // staging. deal with it.
        local cmd_X is Vc^2 / (2*cmd_A).                // minimum stopping distance.

        if Xc < cmd_X return 0.                         // we overshot.

        local Xr is cmd_X / Xc.
        if throttle=0 and Xr<0.90 {                     // wait until we are closer.
            lock throttle to 0.
            return 1/100. }

        if Xr < 0.01 {                                  // we are good.
            lock throttle to 0.
            return 0. }

        lock throttle to clamp(0,1,Xr).
        return 1/100. }).

    rdv:add("near", {                   // engine based approach dist <= TSD and speed<=1 m/s

        // Logic for handling the NEAR part of rendezvous. This spans
        // from the end of our "roughly match the orbit" burn, until we
        // are close enough that we want to come in on RCS thrusters.

        // As usual: if ABORT is set, move on; if we are in timewarp,
        // have the sequencer call us back later.

        if abort return 0.
        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        // Copy standoff distance into parking distance so we
        // can use common "parking spot" support code.

        local standoff_distance to targ:standoff_distance.
        set targ:parking_distance to standoff_distance.

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

                print "rdv:near starting maneuver.".
                set holding_position to false. }

            if d_p < 0.20*standoff_distance and r_v:mag < 1.0 {
                // when slow and within 20% of standoff distance from standoff, hold position.
                set holding_position to true.
                print "rdv:fine holding position.".
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

            local cmd_X is d_p - 0.05*standoff_distance.
            local cmd_A is availablethrust * 0.10 / ship:mass.
            local cmd_V is sqrt(2*cmd_A*cmd_X).
            return r_v + t_p:normalized*cmd_V. }).

        ctrl:dv(dv, 1, 1, 15).

        if holding_position {
            io:say("This is Fine.", false).
            ctrl:dv(V(0,0,0),1,1,5).
            return 0. }

        return 5. }).

    rdv:add("fine", {                   // entirely engine based rescue fine control and posing

        // rdv:fine performs fine rendezvous using the main engines.
        // This can be a bit fiddly if the thrust-to-weight ratio is high.

        if abort return 0.
        if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        local standoff_distance to targ:standoff_distance.
        set targ:parking_distance to standoff_distance.

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
                // we drift 100 meters away or if our
                // relative speed hits 0.1 m/s.

                if d_p < 0.50*standoff_distance and r_v:mag < 5.0
                    return V(0,0,0).

                set holding_position to false. }

            if d_p < 0.20*standoff_distance and r_v:mag < 1.0 {
                // when close and slow, hold position.
                set holding_position to true.
                return V(0,0,0). }

            if d_p < 0.40*standoff_distance
                // when close but not slow,
                // burn to cancel the velocity.
                return r_v.

            // not close enough. burn to set velocity
            // to close at a controlled rate based on
            // the stopping distance equation, using
            // a distance that is reduced by 10% of the
            // standoff distance.
            //
            // NOTE: once we accelerate to this rate,
            // we need to FLIP THE ROCKET AROUND
            // to be able to decelerate.

            local cmd_X is d_p - 10.
            local cmd_A is availablethrust * 0.10 / ship:mass.
            local cmd_V is sqrt(2*cmd_A*cmd_X).
            return r_v + t_p:normalized*cmd_V. }).

        ctrl:dv(dv, 1, 1, 15).

        if holding_position
            io:say("This is Fine.", false).

        return 5. }).

    rdv:add("rcs_5m", {

        // rdv:rcs_5m uses the RCS jets to gently nudge us to
        // our rescue spot, five meters away from the target.

        if abort return 0.
        if not hastarget return 0.
        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
        if kuniverse:timewarp:rate>1 {
            kuniverse:timewarp:cancelwarp().
            return 1/10. }

        set targ:parking_distance to 5.

        if targ:park_from_ship():mag>(2*targ:parking_distance) {
            io:say("Approaching to "+targ:parking_distance+" m.", false).
            io:say("Please be patient.", false). }

        else {
            io:say("Holding "+targ:parking_distance+" m from Target.", false). }

        ctrl:rcs_dx(targ:park_from_ship).
        return 5. }).
}
