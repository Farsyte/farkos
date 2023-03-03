@LAZYGLOBAL off.
{
    parameter ctrl is lex().    // augmented control package

    // allow missions to tweak these parameters.
    ctrl:add("gain", 1).    // gain: acceleration per change in velocity
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
        return lookdirup(up:vector, facing:topvector). }).

    ctrl:add("steering", {              // steer based on delta-v
        parameter dv.                   // lambda that returns delta-v
        set dv to eval(dv).
        if dv:mag>0 return lookdirup(dv, facing:topvector).
        return ctrl:pose(). }).

    ctrl:add("throttle", {              // thrust based on delta-v.
        parameter dv.                   // lambda that returns delta-v
        parameter raw is false.         // add ", true" to see un-discounted value

        if availablethrust=0 return 0.

        local dv is eval(dv).
        if dv:mag<2/10000 return 0.     // tiny deadzone for tiny thrust -> engines off.

        local dt is ctrl:gain*dv:mag*ship:mass/availablethrust.
        local desired_throttle is clamp(0,1,dt/2).
        if raw return desired_throttle.

        local facing_error is vang(facing:vector,dv).
        if facing_error<=ctrl:emin return desired_throttle.
        if facing_error>=ctrl:emax return 0.

        local df is (facing_error-ctrl:emin) / (ctrl:emax-ctrl:emin).
        return round(df*desired_throttle,4). }).

    ctrl:add("dv", { parameter dv.
        parameter gain is ctrl:gain.
        parameter emin is ctrl:emin.
        parameter emax is ctrl:emacs.
        set ctrl:gain to gain.
        set ctrl:emin to emin.
        set ctrl:emax to emax.
        lock steering to ctrl:steering(dv).
        lock throttle to ctrl:throttle(dv).
        wait 0. }).

    ctrl:add("translate", { parameter dir.// vector along desired translation
        // not debugged yet, but this is the same formulation
        // used elsewhere. "dir" is RCS direction,
        // and with magnitude 1 is max thrust.
        set ship:control:translation to facing:inverse*dir. }).

}