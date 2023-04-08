@LAZYGLOBAL off.
{   parameter match is lex(). // matching logic

    local targ is import("targ").
    local hill is import("hill").
    local predict is import("predict").
    local visviva is import("visviva").
    local lambert is import("lambert").
    local plan is import("plan").
    local scan is import("scan").
    local dbg is import("dbg").
    local io is import("io").
    local nv is import("nv").

    // state retained between steps but not across reboots:
    local match_throttle_prev is 0.

    // global parameters
    local burn_steps is list(30, 10, 3, 1, 0.3, 0.1, 0.03, 0.01).

    match:add("asc", {              // launch when nearly under ascending node.
        if abort return 0.

        local o is targ:orbit.
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

    match:add("apo", {              // push apoapsis to be out between targ/peri and targ/apo
        if abort return 0.

        local r0 is body:radius.
        local o is targ:orbit.

        local match_apo is o:apoapsis.
        local match_peri is o:periapsis.

        local match_gain is nv:get("match_gain", 1, true).
        local match_max_facing_error is nv:get("match_max_facing_error", 15, true).
        local match_apo_grace is nv:get("match_apo_grace", 0.5, true).

        local target_apo is (match_peri+match_apo)/2.

        local _delta_v is {     // compute desired change in velocity magnitutde
            local desired_speed is visviva:v(r0+altitude,r0+target_apo,r0+periapsis).
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

        return 5. }).

}
