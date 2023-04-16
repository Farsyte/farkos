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

        // This function examines our target orbit, which might be the
        // actual orbit of a target body, or a target vessel, or even
        // might be just a synthetic orbit. "targ" encapsuates all that.

        // This code seeks the ASCENDING NODE. Yes, we could launch a
        // few hours earlier by checking DESCENDING NODE but the added
        // complexity (not much) outweighs the added value (tiny).

        if abort return 0.

        local o is targ:orbit.
        local match_inc is o:inclination.
        local match_lan is o:lan.
        local match_lon_lead is nv:get("match/lon_lead", 1).

        // TODO: offset launch azimuth a bit east of the inclination
        // turns out this is close enough that our plane correction
        // is not horribly expensive, so we can defer the twealing of
        // our launch azimuth until later.

        nv:put("launch_azimuth", 90 - match_inc).

        // if the inclination is less than a degree, we do not need
        // to do a PAD-HOLD to get in-plane.

        if abs(match_inc)<1.0 return 0.

        // if we are in timewarp (or not settled) try again later.
        // we intend to hit this while "warpto" is active below,
        // but beware, we will also hit it if the flight engineer
        // turns on timewarp. That's on the flight engineer, and
        // when he turns it off, we will evaluate reality and then
        // wait until the next ascending node.

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

        // This function executes a main engine burn to push our apoapsis
        // out to be somewhere between the target orbit periapsis and apoapsis,
        // which makes it easy later to match the orbit, as long as we do not
        // really care about the argument of periapsis, but I digress.

        if abort return 0.

        local r0 is body:radius.
        local o is targ:orbit.

        local match_apo is o:apoapsis.
        local match_peri is o:periapsis.

        // Hey, if our apoapsis is already in that range, we are done.

        if match_peri <= apoapsis and apoapsis <= match_apo {    // SUCCESS.
            lock throttle to 0. lock steering to prograde.
            io:say("phase_match_apo complete").
            return 0. }

        local match_gain is nv:get("match_gain", 1, true).
        local match_max_facing_error is nv:get("match_max_facing_error", 15, true).
        local match_apo_grace is nv:get("match_apo_grace", 0.5, true).

        // Our goal apoapsis is just pulled out of mid-air.
        // I used to call this "target_apo" which was confusing
        // because it was not the apoapsis of the target, but
        // again I digress. In any case, it is quite likely that
        // our burn will be chopped off abruptly as we check every
        // five seconds to see if we are in range.

        local goal_apo is (match_peri+match_apo)/2.

        local _throttle is {    // compute throttle setting


            // visviva gives us the PROGRADE SPEED at a given radius,
            // of an orbit with the provided minimum and maximum radii,
            // which can be provided in either order. In this case, we
            // are intending to adjust our orbit so that we are at the
            // periapsis, thus our velocity vector is horizontal with that
            // particular velocity.
            //
            // TODO this is not exactly correct. Needs commentary or repair.
            // we are asking for our speed on an orbit from our periapsis to the
            // desired apoapsis. Since we are trying to make the velocity horizontal
            // it will drive periapsis up to altitude, over time, so this may
            // not be a concern ... or perhaps we should work out the proper
            // lateral speed, the proper radial speed, and the actually correct
            // vector. In short, this is a "adjust PE and AP" pass, which code has
            // been set up elsewhere and could be used.

            local desired_speed is visviva:v(r0+altitude,r0+goal_apo,r0+periapsis).
            local current_speed is velocity:orbit:mag.
            local delta_v is desired_speed - current_speed.

            // this code predates the CTRL package and could probably be simplified
            // by leveraging CTRL ... just an idea.

            local accel_wanted is match_gain * _delta_v.
            local force_wanted is mass * accel_wanted.
            local max_thrust is max(0.01, availablethrust).
            local des_throt is  force_wanted /  max_thrust.
            local throt_clamp is clamp(0,1, des_throt).
            local facing_error is vang(facing:vector,steering:vector).

            // TODO what if the engine has a MINIMUM THROTTLE?
            // currently we ignore this possibliy completely.

            local facing_error_factor is clamp(0,1,1- facing_error/match_max_facing_error).
            return clamp(0,1, facing_error_factor* throt_clamp). }.

        // make really sure we are not in TIMEWARP.
        phase_unwarp().

        lock steering to prograde.
        lock throttle to _throttle().

        return 5. }).

}
