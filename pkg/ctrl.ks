{
    parameter ctrl is lex().    // augmented control package

    // allow missions to tweak these parameters.
    ctrl:add("gain", 5).    // throttle controller gain (acceleration per delta-v)
    ctrl:add("emin", 1).    // if facing within this angle, use computed throttle
    ctrl:add("emax", 15).   // if facing outside this angle, use zero throttle

    ctrl:add("pose", {
        if altitude>body:atm:height
            return lookdirup(vcrs(ship:velocity:orbit, -body:position), -body:position).
        if verticalspeed>10
            return lookdirup(srfprograde:vector, facing:topvector).
        if verticalspeed<10
            return lookdirup(srfretrograde:vector, facing:topvector).
        if airspeed>100
            return lookdirup(srfprograde:vector, facing:topvector).
        return lookdirup(up:vector, facing:topvector).
    }).

    ctrl:add("steering", {              // steer based on delta-v
        parameter dv.                   // lambda that returns delta-v
        set dv to eval(dv).
        if dv:mag>0 return lookdirup(dv, facing:topvector).
        return ctrl:pose(). }).

    ctrl:add("throttle", {              // thrust based on delta-v.
        parameter dv.                   // lambda that returns delta-v
        parameter raw is false.         // add ", true" to see un-discounted value

        local desired_velocity_change is eval(dv).
        if desired_velocity_change:mag=0 return 0.

        local desired_accel is ctrl:gain * desired_velocity_change:mag.
        local desired_force is mass * desired_accel.
        if availablethrust=0 return 0.

        local desired_throttle is clamp(0,1,desired_force/availablethrust).
        if raw return desired_throttle.

        local facing_error is vang(facing:vector,desired_velocity_change).
        if facing_error<=ctrl:emin return 1.
        if facing_error>=ctrl:emax return 0.

        local df is (facing_error-ctrl:emin) / (ctrl:emax-ctrl:emin).
        return df*desired_throttle. }). }