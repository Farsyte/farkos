
// phase_match_apo: raise apoapsis to target apoapsis.
function phase_match_apo {

    local match_apo is persist_get("match_apo", 500000, true).
    local match_gain is persist_get("match_gain", 1, true).
    local match_max_facing_error is persist_get("match_max_facing_error", 5, true).

    local ra is round(apoapsis,1).

    lock current_speed to velocity:orbit:mag.
    lock desired_speed to visviva_vec(altitude,match_apo,periapsis):mag.

    lock desired_direction to prograde.

    lock spd_chg_wanted to desired_speed - current_speed.

    if ra >= match_apo { // or if speed change wanted is sufficiently small?
        lock throttle to 0.
        lock steering to prograde.
        say("phase_match_apo complete").
        print "final apoapsis error: "+abs(apoapsis-match_apo)+" m.".
        print "final speed error: "+abs(spd_chg_wanted)+" m/s.".
        return 0.
    }

    phase_unwarp().

    lock accel_wanted to spd_chg_wanted * match_gain.
    lock force_wanted to mass * accel_wanted.
    lock maxf to max(0.01, availablethrust).
    lock throttle_wanted to force_wanted / maxf.
    lock throttle_clamped to clamp(0,1,throttle_wanted).

    lock facing_error to vang(facing:vector,desired_direction:vector).
    lock facing_error_factor to clamp(0,1,1-facing_error/match_max_facing_error).
    lock discounted_throttle to clamp(0,1,facing_error_factor*throttle_clamped).

    lock steering to desired_direction.
    lock throttle to clamp(0,1,discounted_throttle).

    return 5.
}

global match_steering is facing.
global match_throttle is 0.

function pr { parameter name, value.
    print name+" = "+value.
}

// phase_match_incl: match orbital plane
// matches both inclination and longitude of ascending node
local phase_match_incl_report_time is 0.
function phase_match_incl {

    local warprate is kuniverse:timewarp:rate.

    local b is body.                        // pr("b",b).              // print "Orbiting: "+b.

    local p_s is -b:position.               // pr("p_s",p_s).          // position from BODY to SHIP
    local v_s is velocity:orbit.            // pr("v_s",v_s).          // velocity of SHIP relative to BODY
    local h_s is vcrs(v_s,p_s):normalized.  // pr("h_s",h_s).          // angular momentum direction of SHIP

    local match_peri is persist_get("match_peri", 4332992, true).
    local match_apo is persist_get("match_apo", 4557075, true).
    local match_inc is persist_get("match_inc", 1.3, true).
    local match_lan is persist_get("match_lan", 269, true).

    local maj is match_apo + match_peri + 2*body:radius.

    local inc is match_inc.
    local ecc is (match_apo - match_peri) / maj.
    local sma is maj/2.
    local lan is match_lan.
    local aop is 0. // not determined by contract sheet.
    local mae is 0. // not determined by contract sheet.

    local o_t is createorbit(inc, ecc, sma, lan, aop, mae, 0, b).

    local p_t is o_t:position-o_t:body:position. // pr("p_t",p_t).          // position from BODY to TARGET
    local v_t is o_t:velocity:orbit.        // pr("v_t",v_t).          // velocity of TARGET relative to BODY
    local h_t is vcrs(v_t,p_t):normalized.  // pr("h_t",h_t).          // angular momentum vector of TARGET

    if vdot(h_s,h_t) <= 0 {
        say("rv_incline: retrograde target!").
        lock steering to prograde. lock throttle to 0.
        return 5.
    }

    local i_r is vang(h_s, h_t).                // pr("i_r",i_r).
    if -0.01 < i_r and i_r < 0.01 {
        say("rv_incline complete").
        say("  final i_r is "+i_r).
        lock throttle to 0.
        lock steering to prograde.
        return 0.
    }

    // p_dist: distance to the target orbital plane
    local p_dist is vdot(h_t, p_s).             // pr("p_dist",p_dist).

    // p_rate: speed parallel to target orbital plane normal
    local p_rate is vdot(h_t, v_s).             // pr("p_rate",p_rate).

    // given distance and rate, work out an acceleration and
    // time that brings both to zero. Basically, we start with
    // the equation for X and V given T and A, then solve for
    // T and A given X and V:
    //    V = A T                   X = A T^2 / 2
    // Solve for time by eliminating A from the X equation:
    //    A = V / T                 X = (V/T) T^2 2 = V T/2
    //    T = 2 X / V
    // Compute T, then compute A as seen above.

    local b_time is 2*p_dist/p_rate.            // pr("b_time",b_time).
    local b_accel is p_rate/b_time.             // pr("b_accel",b_accel).
    local b_force is b_accel*ship:mass.         // pr("b_force",b_force).
    local b_throt is b_force/maxthrust.         // pr("b_throt",b_throt).

    local next_dt is 5.         // default to slow period
    local next_Ct is b_throt.   // default to computed throttle
    local next_Cs is h_s.       // default to upward normal

    if next_Ct < 0 {
        // negative throttle is just positive in the other direction.
        // print "rt_incline: flip signs.".
        set next_Cs to -next_Cs.
        set next_Ct to -next_Ct.
    }

    if next_Ct > 1 {
        // too much thrust, try again next time around.
        print "phase_match_incl: too much, try again next time.".
        set next_Ct to 0.
    }

    if b_time > 0 {
        set next_Ct to 0.
    }

    if warprate>1 and b_time<0 and b_time>-30*warprate {
        print "cancel "+warprate+"x timewarp: b_time is "+b_time.
        phase_unwarp().
        set warprate to 1.
    }

    if next_ct > 0.1 {
        set next_dt to 1/10.
        if warprate > 1 {
            print "phase_match_incl: cancel "+warprate+"x timewarp, next_ct="+next_ct.
            phase_unwarp().
        }
    }

    // Deadzone logic: if we are not commanding throttle, and
    // our throttle command is 0% to 60%, do not throttle
    // up yet, wait for us to need 60%. Higher thresholds
    // risk actually not seeing a value above the threshold
    // but below our throttle limit.
    //
    // Then, if we ever cut the throttle to zero, turn the
    // deadzone flag back on.

    if match_throttle=0 and next_Ct>0 and next_Ct<0.6 {
        set next_Ct to 0.
    }

    // AFTER checking deazone: if the engine is not
    // facing near enough to the right way, then just
    // avoid turning on the engine this time.
    //
    // TODO apply angle-based roll-off of thrust.
    if next_Ct>0 and vang(next_Cs,facing:vector)>30 {
        set next_Ct to 0.
    }

    if match_throttle=0 and next_Ct>0 {
        print "phase_match_incl: throttle up to "+next_Ct.
    }

    if time:seconds>phase_match_incl_report_time and warprate<=1 {
        set phase_match_incl_report_time to time:seconds+5.
        // print "rv_incline in progress".
        // print "  i_r is "+i_r.
        // print "  b_time is "+b_time.
        // print "  next_ct is "+next_ct.
    }

    // carefully copy the final values of the commands
    // to the variables to which the throttle and steering
    // are locked. This avoids bouncing the values around
    // while computing above.

    set match_throttle to next_Ct.
    set match_steering to next_Cs.

    lock throttle to match_throttle.
    lock steering to match_steering.

    return next_dt.
}
