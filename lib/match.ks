
// phase_match_apo: raise apoapsis to target apoapsis.
function phase_match_apo {

    local match_apo is persist_get("match_apo", 500000, true).
    local match_gain is persist_get("match_gain", 1, true).
    local match_max_facing_error is persist_get("match_max_facing_error", 5, true).
    local match_apo_grace is persist_get("match_apo_grace", 0.5, true).

    local _delta_v is {     // compute desired change in velocity magnitutde
        local desired_speed is visviva_v(altitude,match_apo,periapsis).
        local current_speed is velocity:orbit:mag.
        return desired_speed - current_speed. }.

    {   // check termination condition.
        if apoapsis >= match_apo - match_apo_grace {    // SUCCESS.
            lock throttle to 0. lock steering to prograde.
            say("phase_match_apo complete").
            print "final apoapsis error: "+abs(apoapsis-match_apo)+" m.".
            print "final speed error: "+abs(_delta_v())+" m/s.".
            return 0. } }

    local _throttle is {    // compute throttle setting
        local accel_wanted is match_gain * _delta_v().
        local force_wanted is mass * accel_wanted.
        local max_thrust is max(0.01, availablethrust).
        local des_throt is  force_wanted /  max_thrust.
        local throt_clamp is clamp(0,1, des_throt).
        local facing_error is vang(facing:vector,steering:vector).
        local facing_error_factor is clamp(0,1,1- facing_error/match_max_facing_error).
        return clamp(0,1, facing_error_factor* throt_clamp). }.

    phase_unwarp().
    lock steering to prograde.
    lock throttle to _throttle().

    return 5.
}

// get_orbit_to_match: Convert the target orbit parameters from a contract
// into an actual orbit structure. The target orbit is defined by values
// placed in persistent storage.

function get_orbit_to_match {

    // contracts must specify
    // - match_peri: altitude (in m) of periapsis
    // - match_apo: altitude (in m) of apoapsis
    // contracts may specify
    // - match_inc: inclination of orbit [defaults to 0°]
    // - match_lan: longitude of ascending node [defaults to 0°]
    // - match_body: which body to orbit, defaults to KERBIN.
    // - match_incl_within: maximum inclination error [defaults to 0.01°]

    local peri is persist_get("match_peri").
    local apo is persist_get("match_apo").
    local inc is persist_get("match_inc", 0).
    local lan is persist_get("match_lan", 0).
    local b is Body(persist_get("match_body", "Kerbin")).

    local sma is body:radius + (apo + peri)/2.

    // handle reversal of periapsis and apoapsis gracefully.
    local ecc is abs(apo - peri) / (2*sma).

    // current logic does not attempt to match Argument of Periapsis,
    // and for the "satellite in orbit" contracts, the Mean Anomaly
    // at Epoch and the Epoch time are immaterial.
    local o_t is createorbit(inc, ecc, sma, lan, 0, 0, 0, b).

    return o_t.
}

// phase_match_incl: match orbital plane
// matches both inclination and longitude of ascending node
local phase_match_incl_report_time is 0.
local match_throttle_prev is 0.

function phase_match_incl {
    // TODO consider the case: vdot(h_s,h_t) <= 0
    // ... current logic may end up going the wrong way.

    local max_facing_error is persist_get("match_incl_max_facing_error", 15).
    local max_i_r is persist_get("match_incl_within", 0.01).

    if not kuniverse:timewarp:issettled return 1/10.    // if timewarp rate is changing, try again shortly.

    local o_t is get_orbit_to_match().                  // get Orbit for contract

    local b is body.    // TODO: fail if in orbit around the wrong body.

    local _p_s is {     // position from BODY to SHIP
        return -b:position. }.

    local _v_s is {     // velocity of SHIP relative to BODY
        return velocity:orbit. }.

    local _h_s is {     // angular momentum of ship around its orbit
        local v_s is _v_s().                    // velocity of SHIP relative to BODY
        local p_s is _p_s().                    // position from BODY to SHIP
        return vcrs(v_s,p_s):normalized. }.

    local _h_t is {     // angular momentum in TARGET ORBIT around BODY
        local p_t is o_t:position-b:position.   // position from BODY to TARGET
        local v_t is o_t:velocity:orbit.        // velocity of TARGET relative to BODY
        return vcrs(v_t,p_t):normalized. }.

    local _i_r is {     // compute relative inclination
        local h_s is _h_s().                    // angular momentum direction of SHIP
        local h_t is _h_t().                    // angular momentum vector of TARGET
        return vang(h_s, h_t). }.

    {   // check termination condition.
        local i_r is _i_r().                    // relative inclination
        if i_r <= max_i_r {                     // termination condition
            print "phase_match_incl: final i_r is "+i_r.
            lock throttle to 0.
            lock steering to prograde.
            return 0. } }

    local _p_dist is {  // p_dist: distance to the target orbital plane
        local p_s is _p_s().                    // position from BODY to SHIP
        local h_t is _h_t().
        return vdot(h_t, p_s). }.

    local _p_rate is {  // p_rate: speed along target plane normal
        local v_s is _v_s().                    // velocity of SHIP relative to BODY
        local h_t is _h_t().
        return vdot(h_t, v_s). }.

    {   // Plan to burn at a constant acceleration A, such that
        // the burn reduces our position and velocity to zero at some
        // future time T=0. Solve for that acceleration A and
        // for the T for right now which will be negaitive.
        //     V = A T                   X = A T^2 / 2
        // Solve for time by eliminating A from the X equation:
        //     A = V / T                 X = (V/T) T^2 2 = V T/2
        //     T = 2 X / V
        // Compute T, then compute A as seen above.
    }

    local _b_time is {      // computed time until X=0 V=0 at constant A
        local p_dist is _p_dist().
        local p_rate is _p_rate().
        return 2*p_dist/p_rate. }.

    local _b_throt is {     // desired throttle command
        local b_time is _b_time().              // b_time: time from intercept to now
        local b_accel is _p_rate()/b_time.      // b_accel: the required acceleration
        local b_force is b_accel*ship:mass.     // b_force: the required force
        local max_force is max(0.01, availablethrust). // max force, protect against zero.
        return b_force/max_force. }.             // b_throt: throttle setting to get that force

    local _raw_Ct is {      // raw throttle command based on b_throt above
        local b_throt is _b_throt().            // throttle setting to get desired force
        return min(1,abs(_b_throt())). }.

    {   // logic to maybe drop out of time warp (b_time, raw_Ct)

        local ws is kuniverse:timewarp:warp.
        local wr is kuniverse:timewarp:rate.

        local b_time is _b_time().              // b_time: time from intercept to now
        local raw_Ct is _raw_Ct().

        // If the time is getting too small for our current time warp rate,
        // then reduce the time warp step.

        if ws>0 and kuniverse:timewarp:rate>1 and b_time<0 and b_time>-30*kuniverse:timewarp:rate {
            set ws to ws-1.
            print "phase_match_incl: reducing timewarp to step "+ws.
            set kuniverse:timewarp:warp to ws.
            return 1/10. }

        // If we computed that we need 10% throttle or more,
        // cancel any remaining timewarp.

        if raw_Ct>0.1 and wr>1 {
            print "phase_match_incl: cancel timewarp".
            kuniverse:timewarp:cancelwarp().
            return 1/10. } }

    local _steering is {    // All steering computations.
        local h_s is _h_s().                    // angular momentum direction of SHIP
        local b_throt is _b_throt().
        local next_Cs is h_s*sgn(b_throt).      // pick upward or downward normal
        return lookdirup(next_Cs,facing:topvector). }.

    local _next_Ct is {
        local raw_Ct is _raw_Ct().

        // If the engine is NOT currently burning, and the computed
        // throttle is less than 60%, then do not turn it on.
        if match_throttle_prev=0 and raw_Ct<0.6 return 0.
        return raw_Ct.
    }.

    local _throttle is {    // All throttle computations.
        local next_Ct is _next_Ct().

        // Reduce engine thrust if we are pointed the wrong way.
        local facing_error is vang(facing:vector,steering:vector).
        local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).

        set match_throttle_prev to clamp(0,1,facing_error_factor*next_Ct).
        return match_throttle_prev. }.

    {   // periodic printing (taking TIMEWARP into account)

        if time:seconds > (phase_match_incl_report_time+5*kuniverse:timewarp:rate) {
            set phase_match_incl_report_time to time:seconds.

            local i_r is _i_r().                // relative inclination
            local b_time is _b_time().              // b_time: time from intercept to now
            local b_throt is _b_throt().            // throttle setting to get desired force
            local facing_error is vang(facing:vector,steering:vector).
            local next_Ct is _next_Ct().

            print " ".
            print "phase_match_incl running".
            print "  i_r = "+i_r.
            print "  b_time = "+b_time.
            print "  b_throt = "+b_throt.
            print "  f_error = "+facing_error.
            print "  next_Ct = "+next_Ct.
            print "  throttle = "+throttle. } }

    // These two LOCK statements will cause kOS to evaluate all of
    // those delegates we just constructed above, each cycle when
    // it applies THROTTLE and STEERING controls.

    lock throttle to _throttle().
    lock steering to _steering().

    return 5.
}
