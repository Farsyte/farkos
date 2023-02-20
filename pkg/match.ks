{   parameter match is lex(). // matching logic

    local targ is import("targ").
    local io is import("io").
    local nv is import("nv").

    match:add("asc", { // launch when nearly under ascending node.
        if abort return 0.

        local o is targ:orbit().
        local match_inc is o:inclination.
        local match_lan is o:lan.
        local match_lon_lead is nv:get("match/lon_lead", 1).

        // TODO: offset launch azimuth a bit east of the inclination
        nv:put("launch_azimuth", 90 - match_inc).

        // if the inclination is less than a degree, we do not need
        // to do a PAD-HOLD to get in-plane.
        if abs(match_inc)<1.0 return 0.

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
            io:say("PAD HOLD released:", false).
            io:say("  delta_lon is "+delta_lon, false).
            io:say("  delta_sec is "+delta_sec, false).
            return 0. }

        if delta_sec > 30 {
            io:say("PAD HOLD warping:", false).
            io:say("  delta_lon is "+delta_lon, false).
            io:say("  delta_sec is "+delta_sec, false).
            kuniverse:timewarp:warpto(time:seconds+delta_sec-15). }

        return 1. }).

    local match_throttle_prev is 0.
    match:add("plane", {     // match orbital planes with target
        if abort return 0.

        if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

        local o is targ:orbit().

        // TODO consider the case: vdot(h_s,h_t) <= 0
        // ... current logic may end up going the wrong way.

        local max_facing_error is nv:get("match/incl/max_facing_error", 15).
        local max_i_r is nv:get("match/incl/good_enough", 0.01).

        local b is body.
        local o_t is targ:orbit().

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

        if availablethrust <= 0 {                                   // no thrust, try again later.
            io:say("match:plane -- staging").
            return 1. }

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
            if kuniverse:timewarp:rate=1 set warp to 4.
            set throttle to 0.
            set steering to prograde.
            return 5. }

        local b_accel is p_rate/b_time.                             // b_accel: the required acceleration
        local b_force is b_accel*ship:mass.                         // b_force: the required force
        local b_throt is b_force/availablethrust.                   // desired throttle command

        local next_Ct is min(1,abs(b_throt)).                        // raw throttle command based on b_throt above

        {   // logic to manage timewarp (b_time, next_Ct)

            local ws is kuniverse:timewarp:warp.
            local wr is kuniverse:timewarp:rate.

            // if we clearly have time, increase our timewarp.

            if kuniverse:timewarp:mode = "PHYSICS"
                set kuniverse:timewarp:mode to "RAILS".
            if ws=0 and wr=1 and b_time<-10*20 {
                set warp to 2.
                return 1/10. }
            if ws=0 and wr=1 and b_time<-10*100 {
                set warp to 3.
                return 1/10. }
            if ws=0 and wr=1 and b_time<-10*200 {
                set warp to 4.
                return 1/10. }

            // If the time is getting too small for our current time warp rate,
            // then reduce the time warp step.

            if ws>0 and wr>1 and b_time>-10*wr {
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

        return 1/100. }).

    match:add("apo", {      // push apoapsis to be out between targ/peri and targ/apo
        if abort return 0.

        local r0 is body:radius.
        local o is targ:orbit().

        local match_apo is o:apoapsis.
        local match_peri is o:periapsis.

        local match_gain is nv:get("match_gain", 1, true).
        local match_max_facing_error is nv:get("match_max_facing_error", 15, true).
        local match_apo_grace is nv:get("match_apo_grace", 0.5, true).

        local target_apo is (match_peri+match_apo)/2.

        local _delta_v is {     // compute desired change in velocity magnitutde
            local desired_speed is visviva_v(r0+altitude,r0+target_apo,r0+periapsis).
            local current_speed is velocity:orbit:mag.
            return desired_speed - current_speed. }.

        {   // check termination condition.
            if apoapsis >= target_apo - match_apo_grace {    // SUCCESS.
                lock throttle to 0. lock steering to prograde.
                io:say("phase_match_apo complete").
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

        return 5.}).
}