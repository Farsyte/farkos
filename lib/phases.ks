loadfile("visviva").

function phase_unwarp {
    if kuniverse:timewarp:rate <= 1 return.
    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:issettled.
}

function phase_apowarp {
    wait until kuniverse:timewarp:issettled.

    if kuniverse:timewarp:rate < 5 return.

    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:issettled.

    if eta:apoapsis<60 return.

    kuniverse:timewarp:warpto(time:seconds+eta:apoapsis-60).
    wait 5.
    wait until kuniverse:timewarp:rate <= 1.
    wait until kuniverse:timewarp:issettled.
}

// BG_STAGER: A background task for automatic staging.
// Generally, stages if all the engines this would discard
// have flamed out. Stops at stage zero or when the engine
// list is empty. Does not stage if radar altitude is tiny
// and we have no thrust, so we do not "autolaunch" but we
// DO properly manage the "stage 5 lights engines, stage 4
// releases the gantry" configuration.

function bg_stager {
    if alt:radar<100 and availablethrust<=0 return 1.
    local s is stage:number. if s<1 return 0.
    list engines in engine_list.
    if engine_list:length<1 return 0.
    for e in engine_list
        if e:decoupledin=s-1
            if not e:flameout
                return 1.
    if stage:ready
        stage.
    return 1.
}

function phase_preflight {
    if availablethrust>0 return 0.
    lock steering to facing.
    lock throttle to 1.
    return 1/10.
}

function phase_launch {
    if alt:radar>50 return 0.
    lock steering to facing.
    lock throttle to 1.
    return 1/10.
}

function phase_ascent_old {
    local orbit_altitude is persist_get("launch_altitude", 80000, true).

    if ship:apoapsis >= orbit_altitude and altitude >= body:atm:height return 0.

    local ascent_gain is persist_get("ascent_gain", 2, true).
    local increase_wanted is orbit_altitude-ship:apoapsis.
    local throttle_wanted is sqrt(clamp(0,1,increase_wanted*ascent_gain)).

    local launch_azimuth is persist_get("launch_azimuth", 90, true).

    local altitude_fraction to clamp(0,1,altitude / orbit_altitude).
    local pitch_wanted to 90*(1 - sqrt(altitude_fraction)).

    lock throttle to clamp(0,1,throttle_wanted).
    lock steering to heading(launch_azimuth,pitch_wanted,0).

    return 1/10.
}

function phase_ascent {

    phase_unwarp().

    local orbit_altitude is persist_get("launch_altitude", 80000, true).
    local launch_azimuth is persist_get("launch_azimuth", 90, true).
    local ascent_gain is persist_get("ascent_gain", 10, true).
    local max_facing_error is persist_get("ascent_max_facing_error", 90, true).

    local ra is round(apoapsis).

    if ra >= orbit_altitude and ra >= body:atm:height return 0.

    lock altitude_fraction to clamp(0,1,altitude / orbit_altitude).
    lock pitch_wanted to 90*(1 - sqrt(altitude_fraction)).

    lock steering_direction to heading(launch_azimuth,pitch_wanted,0).
    lock steering to steering_direction.

    // handle time spent staging gracefully.
    set maxf to max(0.01, availablethrust).

    lock current_speed to velocity:orbit:mag.
    lock vvvec to visviva_vec(altitude,orbit_altitude,periapsis).
    lock desired_speed to vvvec:mag.
    lock speed_change_wanted to desired_speed - current_speed.
    lock accel_wanted to speed_change_wanted * ascent_gain.
    lock force_wanted to mass * accel_wanted.
    lock throttle_wanted to force_wanted / maxf.
    lock throttle_clamped to clamp(0,1,throttle_wanted).

    lock facing_error to vang(facing:vector,steering_direction:vector).
    lock facing_error_factor to clamp(0,1,1-facing_error/max_facing_error).
    lock discounted_throttle to clamp(0,1,facing_error_factor*throttle_clamped).

    lock throttle to discounted_throttle.

    return 5.
}

function phase_coast {
    if verticalspeed<0 return 0.

    phase_apowarp().

    if eta:apoapsis<30 return 0.
    phase_unwarp().
    lock throttle to 0.
    lock steering to prograde.
    return 1/10.
}

function phase_circ {

    phase_unwarp().

    local throttle_gain is persist_get("circ_throttle_gain", 5, true).
    local max_facing_error is persist_get("circ_max_facing_error", 5, true).
    local good_enough is persist_get("circ_good_enough", 1, true).

    if ship:LiquidFuel <= 0 { say("Circularize: no fuel.").
        lock steering to prograde.
        lock throttle to 0.
    }

    lock vvvec to visviva_vec(altitude).
    lock desired_lateral_speed to vvvec:z.
    lock lateral_direction to vxcl(up:vector,velocity:orbit):normalized.
    lock desired_velocity to lateral_direction*desired_lateral_speed.
    lock desired_velocity_change to desired_velocity - velocity:orbit.

    if desired_velocity_change:mag <= good_enough {
        say("circularization complete").
        print "apoapsis-periapsis spread: "+(apoapsis-periapsis)+" m.".
        print "final speed error: "+desired_velocity_change:mag+" m/s.".

        lock steering to prograde.
        lock throttle to 0.
        return 0.
    }

    lock desired_steering to lookdirup(desired_velocity_change,facing:topvector).
    lock steering to desired_steering.

    lock maxf to max(0.01, availablethrust).
    lock desired_accel to throttle_gain * desired_velocity_change:mag.
    lock desired_force to mass * desired_accel.
    lock desired_throttle to clamp(0,1,desired_force/maxf).

    lock facing_error to vang(facing:vector,desired_velocity_change).
    lock facing_error_factor to clamp(0,1,1-facing_error/max_facing_error).
    lock discounted_throttle to clamp(0,1,facing_error_factor*desired_throttle).

    lock throttle to discounted_throttle.

    return 5.
}

function phase_hold_brakes_to_deorbit {
    if BRAKES return 0.

    say("Hold BRAKES on to continue.", false).
    lock steering to retrograde.
    lock throttle to 0.
    return 5.
}

function phase_deorbit {
    if periapsis < body:atm:height/2 return 0.

    phase_unwarp().
    lock steering to retrograde.
    lock throttle to 1.
    return 1/10.
}

function phase_fall {
    if body:atm:height<10000 return 0.
    if altitude<body:atm:height/2 return 0.

    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_decel {
    if body:atm:height < 10000 return 0.
    if altitude < body:atm:height/4 return 0.
    list engines in engine_list.
    if engine_list:length < 1 return 0.

    phase_unwarp().
    lock steering to srfretrograde.
    lock throttle to 1.
    return 1/10.
}

function phase_psafe {
    // this is a decent rule of thumb for most parachutes
    // descending into Kerbin's atmosphere ...
    if altitude < 5000 and airspeed < 300 return 0.

    phase_unwarp().
    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_chute {
    if stage:number<1 return 0.

    phase_unwarp().
    if stage:ready stage.
    unlock steering.
    unlock throttle.
    return 1.
}

function phase_gear {
    gear on. return 0.
}

function phase_land {
    if verticalspeed>=0 return 0.

    phase_unwarp().
    unlock steering.
    unlock throttle.
    return 1.
}

function phase_park {
    unlock steering.
    unlock throttle.
    return 10.
}