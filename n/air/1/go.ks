{
    local farkos is import("farkos").
    local persist is import("persist").

    global clamp is { parameter lo, hi, val.
        return max(lo, min(hi, val)).
    }.

    export(go@).

    local commanded_speed is 0.
    local current_speed is 0.
    local speed_error is 0.
    local throttle_pct is 0.
    local accel_gain is -5.

    function go {
        core:doAction("open terminal", true).

        on AG1 {
            set commanded_speed to clamp(0,10,0).
            print "new commanded speed: " + commanded_speed.
            return true.
        } print "AG1: stop vehicle.".

        on AG2 {
            set commanded_speed to clamp(0,10,commanded_speed - 5).
            print "new commanded speed: " + commanded_speed.
            return true.
        } print "AG2: decrease speed.".

        on AG3 {
            set commanded_speed to clamp(0,10,commanded_speed + 5).
            print "new commanded speed: " + commanded_speed.
            return true.
        } print "AG3: increase speed.".

        if maxthrust = 0 {
            print "ignite engines to start.".
            wait until maxthrust > 0.
        }

        // very simple autothrottle.
        lock twr to maxthrust / ship:mass.
        lock current_speed to velocity:surface:mag.
        lock speed_error to current_speed - commanded_speed.
        lock commanded_accel to speed_error * accel_gain.
        lock commanded_force to commanded_accel * ship:mass.
        lock commanded_throttle to commanded_force / ship:maxthrust.

        when speed_error > 0 then { brakes on. return true. }
        when speed_error < 0 then { brakes off. return true. }

        local next_print is time:seconds + 5.
        when time:seconds > next_print then {
            set next_print to time:seconds + 5.
            print " ".
            print "twr:                    " + twr.
            print "current_speed:          " + current_speed.
            print "speed_error:            " + speed_error.
            print "commanded_accel:        " + commanded_accel.
            print "commanded_force:        " + commanded_force.
            print "commanded_throttle:     " + commanded_throttle.
            return true.
        }

        lock throttle to commanded_throttle.

        wait until false.
    }
}
