
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

// phase_match_launch: pick the launch time
// select the launch time based on the longitude of the
// ascending node of the target orbit.

function phase_match_lan {
    local inc is persist_get("match_inc", 0).
    local match_lan is persist_get("match_lan", 0).
    local match_lon_lead is persist_get("match_lon_lead", 1).

    if kuniverse:timewarp:rate > 1 return 1.
    if not kuniverse:timewarp:issettled return 1.

    local launch_lon is ua(match_lan - match_lon_lead).

    local ship_lonvec is vxcl(body:north:vector,up:vector).
    local ship_coslon is vdot(ship_lonvec,solarprimevector).
    local ship_sinlon is vdot(ship_lonvec,vcrs(solarprimevector,body:north:vector)).
    local ship_lon is ua(arctan2(ship_sinlon, ship_coslon)).
    local delta_lon is ua(launch_lon - ship_lon).
    local delta_sec is delta_lon * body:rotationperiod/360.

    if delta_sec < 11 {
        say("PAD HOLD released:", false).
        say("  delta_lon is "+delta_lon, false).
        say("  delta_sec is "+delta_sec, false).
        return 0.
    }
    if delta_sec > 30 {
        say("PAD HOLD warping:", false).
        say("  delta_lon is "+delta_lon, false).
        say("  delta_sec is "+delta_sec, false).
        kuniverse:timewarp:warpto(time:seconds+delta_sec-15).
    }
    return 1.
}

// phase_match_apo: raise apoapsis to target semi-major axis.
function phase_match_apo {

    local r0 is body:radius.

    local match_apo is persist_get("match_apo", 500000, true).
    local match_peri is persist_get("match_peri", 500000, true).
    local match_gain is persist_get("match_gain", 1, true).
    local match_max_facing_error is persist_get("match_max_facing_error", 15, true).
    local match_apo_grace is persist_get("match_apo_grace", 0.5, true).

    local target_apo is (match_peri+match_apo)/2.

    local _delta_v is {     // compute desired change in velocity magnitutde
        local desired_speed is visviva_v(r0+altitude,r0+target_apo,r0+periapsis).
        local current_speed is velocity:orbit:mag.
        return desired_speed - current_speed. }.

    {   // check termination condition.
        if apoapsis >= target_apo - match_apo_grace {    // SUCCESS.
            lock throttle to 0. lock steering to prograde.
            say("phase_match_apo complete").
            print "final apoapsis error: "+abs(apoapsis-target_apo)+" m.".
            print "final speed error: "+abs(_delta_v())+" m/s.".
            return 0. } }

    local _throttle is {    // compute throttle setting
        local accel_wanted is match_gain * _delta_v().
        local force_wanted is mass * accel_wanted.
        local max_thrust is max(0.01, availablethrust).
        local des_throt is  force_wanted /  max_thrust.
        local throt_clamp is clamp(0,1, des_throt).
        local facing_error is vang(facing:vector,steering:vector).
        // what if the engine has a MINIMUM THROTTLE?
        local facing_error_factor is clamp(0,1,1- facing_error/match_max_facing_error).
        return clamp(0,1, facing_error_factor* throt_clamp). }.

    phase_unwarp().
    lock steering to prograde.
    lock throttle to _throttle().

    return 5.
}

// phase_match_incl: match orbital plane
// matches both inclination and longitude of ascending node
local match_throttle_prev is 0.

// same thing without locks and delegates.
function phase_match_incl {

    // TODO consider the case: vdot(h_s,h_t) <= 0
    // ... current logic may end up going the wrong way.

    local max_facing_error is persist_get("match_incl_max_facing_error", 15).
    local max_i_r is persist_get("match_incl_within", 0.01).

    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

    local b is body.
    local o_t is get_orbit_to_match().                          // get Orbit for contract

    // TODO: fail if in orbit around the wrong body.

    local p_t is o_t:position-b:position.                       // position from BODY to TARGET
    local v_t is o_t:velocity:orbit.                            // velocity of TARGET relative to BODY
    local h_t is vcrs(v_t,p_t):normalized.                      // direction of angular momentum in TARGET ORBIT around BODY

    local p_s is -b:position.                                   // position from BODY to SHIP
    local v_s is velocity:orbit.                                // velocity of SHIP relative to BODY
    local h_s is vcrs(v_s,p_s):normalized.                      // direction of angular momentum of ship around its orbit

    local i_r is vang(h_s, h_t).                                // compute relative inclination

    if i_r <= max_i_r {                     // termination condition
        print "phase_match_incl: final i_r is "+i_r.
        set throttle to 0.
        set steering to prograde.
        return 0. }

    if availablethrust <= 0 return 1/10.                        // no thrust, try again later.

    local p_dist is vdot(h_t, p_s).                             // p_dist: distance to the target orbital plane
    local p_rate is vdot(h_t, v_s).                             // p_rate: speed along target plane normal

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

    local b_time is 2*p_dist/p_rate.                            // computed time until X=0 V=0 at constant A
    if b_time >= 0 {
        set throttle to 0.
        set steering to prograde.
        return 5. }

    local b_accel is p_rate/b_time.                             // b_accel: the required acceleration
    local b_force is b_accel*ship:mass.                         // b_force: the required force
    local b_throt is b_force/availablethrust.                   // desired throttle command

    local next_Ct is min(1,abs(b_throt)).                        // raw throttle command based on b_throt above

    {   // logic to maybe drop out of time warp (b_time, next_Ct)

        local ws is kuniverse:timewarp:warp.
        local wr is kuniverse:timewarp:rate.

        // If the time is getting too small for our current time warp rate,
        // then reduce the time warp step.

        if ws>0 and kuniverse:timewarp:rate>1 and b_time>-10*kuniverse:timewarp:rate {
            set ws to ws-1.
            set kuniverse:timewarp:warp to ws.
            return 1/10. }

        // If we computed that we need 10% throttle or more,
        // cancel any remaining timewarp.

        if next_Ct>0.1 and wr>1 {
            kuniverse:timewarp:cancelwarp().
            return 1/10. }
    }

    local next_Cs is h_s*sgn(b_throt).      // pick upward or downward normal
    local local_s is lookdirup(next_Cs,facing:topvector).
    set steering to local_s.

    if match_throttle_prev=0 {
        set throttle to 0.
        if next_ct<0.1 return 1.
        if next_ct<0.4 return 1/100.
    }
    set match_throttle_prev to next_Ct.

    local facing_error is vang(facing:vector,steering:vector).
    local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
    set throttle to clamp(0,1,facing_error_factor*next_Ct).

    return 1/100.
}
