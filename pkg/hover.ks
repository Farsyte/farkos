@LAZYGLOBAL off.
{   parameter hover is lex(). // HOVER package

    local radar is import("radar").
    local dbg is import("dbg").

    hover:add("hold", {                 // HOVER:HOLD(h_set,v_set): hover controller

        {   // Implementation Notes:
            //
            // Compute the amount of throttle we should use right now
            // if our plan is to be at altitude h_set, with asecent
            // velocity v_set, right now.
            //
            // When the vessel is within 10m of the altiude set point,
            // this smells a bit like a PI controller of velocity where
            // the position error is the integrator.
            //
            // For larger distances from the target altitude, it picks an
            // appropriate acceleration, then computes the velocity we
            // ought to have right now to get to the set point altitude with
            // the set point velocity.
        }

        parameter h_set is 100.
        parameter v_set is 0.

        local Kav is 10. // TUNING PARAMETER: accel per velocity error

        local r2 is body:position:sqrmagnitude.                 // radius for gravity computation
        local g is body:mu/r2.                                  // current gravitational acceleration

        local t_max is max(0.01,availablethrust).               // maximum achievable thrust
        local a_max is t_max/ship:mass.                         // maximum achievable acceleration

        local u_dir is -body:position:normalized.               // unit UP vector
        local f_cos is vdot(facing:vector,u_dir).               // fraction of thrust going down
        local a_net is a_max*f_cos - g.                         // achievable upward acceleration
        local a_nom is min(g, 0.80 * a_net).                    // target upward acceleration

        local h_obs is radar:alt().                             // current altitude above cal point

        {   // equations of motion:
            //      V = A*T
            //      X = A*T^2/2
            // elimiating T,
            //      V = sqrt(2*A*X)
            //
            // if we are above the set point,
            // we want to be descending at
            //    V = sqrt(2*A*Herr)
            // were A is a desired net upward acceleration,
            // so that we reach V=0 at Herr=0.
            //
            // if we are below the set point,
            // we want to be ascending at
            //    V = sqrt(2*G*Herr)
            // so that the acceleration G downward from gravity
            // will have V=0 at Herr=0.
            //
            // so a_des is the desired acceleration, positive upward,
            // including acceleration of gravity.
        }

        local v_cmd is v_set.       // in the absence of error, command the speed setpoint.

        if h_obs > h_set {          // above the set point
            if h_obs > h_set+10 {   // far above the set point

                // vessel more than 10m above the set point.
                // Intercept the trajectory where vessel is accelerating
                // upward at a_nom m/s^2 bringing V to 0 at Hobs=Hset.
                local h_dist is h_obs - h_set.                      // how far we are above set point
                local v_sub is sqrt(2*a_nom*h_dist).                // additional descent speed
                set v_cmd to v_cmd - v_sub. }                       // net ascent speed

            else {                // close above the set point

                // vessel above set point by 10m or less.
                // proportional control where the control at 10m error
                // matches the control above.
                local v_sub_10m is sqrt(2*a_nom*10).
                set v_cmd to v_cmd - v_sub_10m*(h_obs-h_set)/10. } }

        else if h_obs < h_set {   // below the set point
            if h_obs < h_set-10 {   // far below the set point

                // vessel more than 10m below the set point.
                // Intercept the trajectory where vessel is accelerating
                // downward due to gravity, bringing V to 0 at Hobs=Hset.
                local h_dist is h_set - h_obs.                      // how far we are above set point
                local v_add is sqrt(2*g*h_dist).                    // abs(speed) for that acceleration
                set v_cmd to v_cmd + v_add. }                       // net ascent speed

            else {                // close below the set point

                // vessel below set point by 10m or less.
                // proportional control where the control at 10m error
                // matches the control above.
                local v_add_10m is sqrt(2*g*10).
                set v_cmd to v_cmd + v_add_10m*(h_set-h_obs)/10. } }

        local v_obs is verticalspeed.                           // current ascent speed
        local v_err is v_cmd - v_obs.                           // positive is descending too fast.

        local a_cmd is Kav * v_err.                             // acceleration to correct error
        local a_cnet is a_cmd + g.                              // net acceleration from throttle
        local t_cmd is a_cnet / a_net.                          // throttle setting 0..1

        return t_cmd. }).
}
