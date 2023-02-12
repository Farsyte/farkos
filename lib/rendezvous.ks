
function coarse_approach { parameter targ is target.
    if abort return 0.

    // If we are in timewarp, come back later.
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

    // See if we are in the "fast approaching" phase.
    // This lasts until (margin) seconds before xfer_final_time
    // which should be our nearest approch time.
    //
    // TODO: work out a decent lead time based on our
    // expected relative velocity when we arrive.
    //
    // OBSERVED: arriving early ...???

    local Tf is persist_get("xfer_final_time").
    local stop_warp_at is Tf - 60.
    local wait_for is stop_warp_at - time:seconds.

   // use warpto if it is more than 30 sec from now:
    if wait_for>30 {
        set throttle to 0.
        wait 3.
        warpto(stop_warp_at).
    }

    if wait_for>0 {
        set throttle to 0.
        return min(1, wait_for).
    }

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
    //      X = V^2 / 2 A
    // Pick an acceleration. Work out the distance,
    // and set the throttle (or not) based on X and
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
        lock steering to retrograde.
    } else {
        set Xc to -Xc.      // pv("Xc", xc).
        set Vc to -Vc.      // pv("Vc", Vc).
        lock steering to prograde.
    }
    set Xc to Xc - margin.  // pv("Vc", Vc).

    if Vc<=0 or Xc<=0 {
        set throttle to 0.
        return 0.
    }

    local A is availablethrust / ship:mass.         // pv("A", A). // available acceleration
    if A=0 return 1/100. // staging while on approach. deal with it.
    local X is Vc^2 / (2*A).                        // pv("X", X). // minimum stopping distance.

    if Xc < X {
        return 0.        // we overshot.
    }

    local Xr is X / Xc. // pv("Xr", Xr).
    if throttle=0 {
        if Xr<0.90 {
            // wait until we are closer.
            set throttle to 0.
            return 1/100.
        }
    }

    if Xr < 0.01 {
        set throttle to 0.
        return 0.
    }

    set throttle to clamp(0,1,Xr).
    return 1/100. }

local holding_position is false.
function fine_approach { parameter targ is target.
    if abort return 0.
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

    local k_t is 2.                     // TODO make tunable, find good value.
    local max_facing_error is 15.        // TODO make tunable, find good value.

    // t_p: vector from ship to target
    local t_p is target:position.                               // pv("t_p", t_p).

    // d_p: distance from ship to target.
    local d_p is t_p:mag.                                   // pv(_v", r_v).

    // t_v: Body-relative target velocity
    local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
    // s_v: Body-relative ship velocity
    local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).
    // r_v: Velocity of Target relative to Ship.
    local r_v is t_v - s_v.

    // if we are already in the rescue pose,
    // do not change pose unless we are more than 100m
    // from the target or our relative velocity
    // exceeds 1.0 m/s.

    if holding_position {
        if d_p < 100 and r_v:mag < 1.0 {
            phase_pose().
            lock throttle to 0.
            return 5. }
        set holding_position to false. }

    // if we are within 20m of the target and our
    // speed is within 0.01 m/s of the target, then
    // enter the rescule pose.
    if d_p < 20 and r_v:mag < 0.01 {
        set holding_position to true.
        phase_pose().
        lock throttle to 0.
        return 1. }

    if d_p > 15 {

        // if more than 15 m from the target,
        // command an appropriate closing velocity.
        //      V = A T
        //      X = 1/2 A T^2
        // Known: X, A
        // Compute: desired V
        //      X = 1/2 A T^2
        //      2 X = A T^2
        //      2 X/A = T^2
        //      sqrt(2 X / A) = T
        //      V = A T
        //        = A sqrt(2 X / A)
        //        = sqrt(A^2 2 X / A)
        //        = sqrt(2 X A)

        local X is d_p - 10.
        local A is availablethrust * 0.1 / ship:mass.
        local V is sqrt(2*A*X).
        set r_v to r_v + t_p:normalized*V.
    }

    set steering to lookdirup(r_v, facing:topvector).

    local desired_delta_v to r_v:mag.                           // pv("desired_delta_v", desired_delta_v).
    if desired_delta_v < 0.01 { set throttle to 0. return 1. }
    local desired_accel to desired_delta_v * 2.                 // pv("desired_accel", desired_accel).
    local desired_force is ship:mass * desired_accel.           // pv("desired_force", desired_force).
    local desired_throttle is desired_force / availablethrust.  // pv("desired_throttle", desired_throttle).
    local clamped_throttle is clamp(0,1,desired_throttle).      // pv("clamped_throttle", clamped_throttle).

    local facing_error is vang(facing:vector,steering:vector).  // pv("facing_error", facing_error).
    local fefac is facing_error/max_facing_error.               // pv("fefac", fefac).
    local facing_error_factor is clamp(0,1,1-fefac).            // pv("facing_error_factor", facing_error_factor).

    set throttle to clamp(0,1,facing_error_factor*clamped_throttle).

    return 1/100. }