{   parameter go is lex(). // Mission G/01

    local mission is import("mission").

    local commanded_speed is 0.
    local current_speed is 0.
    local speed_error is 0.
    local throttle_pct is 0.
    local accel_gain is -5.


    function setspeed {
        if NOT RCS
            set commanded_speed to 0.
        else if NOT LIGHTS
            set commanded_speed to 5.
        else
            set commanded_speed to 10.
        print "setspeed: "+commanded_speed.
        return true.
    }


    function report {
        print " ".
        print "thrust_to_mass_ratio:                    " + thrust_to_mass_ratio.
        print "current_speed:          " + current_speed.
        print "speed_error:            " + speed_error.
        print "commanded_accel:        " + commanded_accel.
        print "commanded_force:        " + commanded_force.
        print "commanded_throttle:     " + commanded_throttle.
        return 5.
    }

    go:add("go", {

        setspeed().
        on RCS { return setspeed(). }
        on LIGHTS { return setspeed(). }
       // very simple autothrottle.

        lock thrust_to_mass_ratio to maxthrust / ship:mass.

        lock current_speed to velocity:surface:mag.
        lock speed_error to current_speed - commanded_speed.
        lock commanded_accel to speed_error * accel_gain.
        lock commanded_force to commanded_accel * ship:mass.
        lock commanded_throttle to commanded_force / max(0.01, ship:maxthrust).

        when speed_error > 0 then { brakes on. return true. }
        when speed_error < 0 then { brakes off. return true. }

        mission:bg(report@).

        lock throttle to clamp(0.1,1.0,commanded_throttle).

        wait until false.
    }).
}
