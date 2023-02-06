function coarse_approach { parameter targ is target.

    // If we are in timewarp, come back later.
    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

    // See if we are in the "fast approaching" phase.
    // This lasts until 30 seconds before xfer_final_time
    // which should be our nearest approch time.
    local Tf is persist_get("xfer_final_time").
    local stop_warp_at is Tf - 30.
    local wait_for is stop_warp_at - time:seconds.

    // long in advance:
    if wait_for>30 {
        wait 3.
        warpto(stop_warp_at).
    }

    lock steering to retrograde.

    if wait_for>0 {
        set throttle to 0.
        return min(1, wait_for).
    }

    // Coarse Approach Maneuver

    local dir is prograde:vector.                               // pv("dir", dir).

    local t_p is target:position.                               // pv("t_p", t_p).
    local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
    local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).

    local Xc is vdot(t_p, dir) - 20.                             // pv("Xc", Xc).
    local Vc is vdot(s_v - t_v, dir).                            // pv("Vc", Vc).

    local Xc is Xc.                                          // pv("Xc", Xc).
    local Vc is Vc.                                          // pv("Vc", Vc).

    local Tc is 2*Xc/Vc.                            // pv("Tc", Tc).

    if Tc < 0 {
        set throttle to 0.
        return 0. }

    // A: the required acceleration
    local A is Vc/Tc.                             // pv("A", A).

    // F: the required force
    local F is A*ship:mass.                         // pv("F", F).

    // desired throttle command
    local thr is F/availablethrust.                   // pv("thr", thr).

    if throttle>0 or thr>0.5
        set throttle to thr.

    if throttle=0 and thr<0.2
        return 1.

    return 1/100. }

local holding_position is false.
function fine_approach { parameter targ is target.

    if kuniverse:timewarp:rate>1 return 1.                      // timewarp active, come back later.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

    local k_t is 2.                     // TODO make tunable, find good value.
    local max_facing_error is 15.        // TODO make tunable, find good value.

    // pv("","").
    local s_p is -body:position.                                // pv("s_p", s_p).
    local t_p is target:position.                               // pv("t_p", t_p).
    local t_v is target:velocity:orbit.                         // pv("t_v", t_v).
    local s_v is ship:velocity:orbit.                           // pv("s_v", s_v).
    local r_v is t_v - s_v.                                     // pv(_v", r_v).

    // if we are already in the rescue pose,
    // do not change pose unless we are more than 100m
    // from the target or our relative velocity
    // exceeds 1.0 m/s.

    if holding_position {
        if t_p:mag < 100 and r_v:mag < 1.0 {
            lock steering to lookdirup(body:north:vector, -s_p:normalized).
            lock throttle to 0.
            return 5. }
        set holding_position to false. }

    // if we are within 20m of the target and our
    // speed is within 0.01 m/s of the target, then
    // enter the rescule pose.
    if t_p:mag < 20 and r_v:mag < 0.01 {
        set holding_position to true.
        lock steering to lookdirup(body:north:vector, -s_p:normalized).
        lock throttle to 0.
        return 1. }

    // if more than 15 m from the target,
    // match a velocity toward the target
    // of 1 m/s per 15 m of distance.

    if t_p:mag > 15
        set r_v to r_v + t_p/15.

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