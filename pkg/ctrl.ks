{
    parameter ctrl is lex().    // augmented control package

    ctrl:add("steering", {              // steer based on delta-v
        parameter dv.                   // lambda that returns delta-v
        return lookdirup(eval(dv), facing:topvector). }).

    local throttle_gain is 5.           // does this actually need to be tunable?
    local max_facing_error is 15.       // does this need to be tunable?

    ctrl:add("throttle", {              // thrust based on delta-v.
        parameter dv.                   // lambda that returns delta-v
        local desired_velocity_change is eval(dv).
        local desired_accel is throttle_gain * desired_velocity_change:mag.
        local desired_force is mass * desired_accel.
        local max_thrust is max(0.01, availablethrust).
        local desired_throttle is clamp(0,1,desired_force/max_thrust).

        local facing_error is vang(facing:vector,desired_velocity_change).
        local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
        return clamp(0,1,facing_error_factor*desired_throttle). }).
}