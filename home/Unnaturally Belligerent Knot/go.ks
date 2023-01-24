// loadfile("persist").
loadfile("mission").

local commanded_speed is 0.
local current_speed is 0.
local speed_error is 0.
local throttle_pct is 0.
local accel_gain is -5.

// print "Alas, this requires Custom Action Groups.".
// 
// on AG1 {
//     set commanded_speed to clamp(0,10,0).
//     say("SPEED: "+commanded_speed).
//     return true.
// } print "AG1: stop vehicle.".
// 
// on AG2 {
//     set commanded_speed to clamp(0,10,commanded_speed - 5).
//     say("SPEED: "+commanded_speed).
//     return true.
// } print "AG2: decrease speed.".
// 
// on AG3 {
//     set commanded_speed to clamp(0,10,commanded_speed + 5).
//     say("SPEED: "+commanded_speed).
//     return true.
// } print "AG3: increase speed.".

on RCS {
    if RCS {
        if LIGHTS {
            set commanded_speed to 20.
        } else {
            set commanded_speed to 5.
        }
    } else {
        set commanded_speed to 0.
    }
    return true.
}

on LIGHTS {
    if RCS {
        if LIGHTS {
            set commanded_speed to 10.
        } else {
            set commanded_speed to 5.
        }
    } else {
        set commanded_speed to 0.
    }
    return true.
}

// if maxthrust = 0 {
//     say("ignite engines to start.").
//     wait until maxthrust > 0.
// }

// very simple autothrottle.

lock twr to maxthrust / ship:mass.
lock current_speed to velocity:surface:mag.
lock speed_error to current_speed - commanded_speed.
lock commanded_accel to speed_error * accel_gain.
lock commanded_force to commanded_accel * ship:mass.
lock commanded_throttle to commanded_force / max(0.01, ship:maxthrust).

when speed_error > 0 then { brakes on. return true. }
when speed_error < 0 then { brakes off. return true. }

mission_bg({
    print " ".
    print "twr:                    " + twr.
    print "current_speed:          " + current_speed.
    print "speed_error:            " + speed_error.
    print "commanded_accel:        " + commanded_accel.
    print "commanded_force:        " + commanded_force.
    print "commanded_throttle:     " + commanded_throttle.
    return 5.
}).

lock throttle to clamp(0.1,1.0,commanded_throttle).

wait until false.

