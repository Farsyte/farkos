
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

function phase_ascent {
    local orbit_altitude is persist_get("orbit_altitude", 80000, true).

    if ship:apoapsis >= orbit_altitude and altitude >= body:atm:height return 0.

    local ascent_gain is persist_get("ascent_gain", 1/10, true)..
    local increase_wanted is orbit_altitude-ship:apoapsis.
    local throttle_wanted is sqrt(clamp(0,1,increase_wanted*ascent_gain)).

    local launch_azimuth is persist_get("launch_azimuth", 90, true).

    local altitude_fraction to clamp(0,1,altitude / orbit_altitude).
    local pitch_wanted to 90*(1 - sqrt(altitude_fraction)).

    lock throttle to clamp(0,1,throttle_wanted).
    lock steering to heading(launch_azimuth,pitch_wanted,0).

    return 1/10.
}

function phase_coast {
    if verticalspeed<0 return 0.
    if eta:apoapsis<30 return 0.
    lock throttle to 0.
    lock steering to srfprograde.
    return 1/10.
}

function phase_circ {
    local throttle_gain is persist_get("circ_throttle_gain", 5, true).
    local max_facing_error is persist_get("circ_max_facing_error", 5, true).
    local good_enough is persist_get("circ_good_enough", 1, true).

    if ship:LiquidFuel <= 0 { say("Circularize: no fuel."). return 0.  }

    local desired_lateral_speed is sqrt(body:mu/(body:radius+altitude)).
    local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
    local desired_velocity is lateral_direction*desired_lateral_speed.
    local desired_velocity_change is desired_velocity - velocity:orbit.

    if desired_velocity_change:mag <= good_enough return 0.

    local desired_steering is lookdirup(desired_velocity_change,facing:topvector).
    lock steering to desired_steering.

    if availablethrust<=0 { lock throttle to 0. return 1/10. }

    local desired_accel is throttle_gain * desired_velocity_change:mag.
    local desired_force is mass * desired_accel.
    local desired_throttle is clamp(0,1,desired_force/availablethrust).

    local facing_error is vang(facing:vector,desired_velocity_change).
    local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
    local discounted_throttle is clamp(0,1,facing_error_factor*desired_throttle).

    lock throttle to discounted_throttle.

    return 1/10.
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
    lock steering to srfretrograde.
    lock throttle to 1.
    return 1/10.
}

function phase_psafe {
    // this is a decent rule of thumb for most parachutes
    // descending into Kerbin's atmosphere ...
    if altitude < 5000 and airspeed < 300 return 0.
    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_chute {
    if stage:number<1 return 0.
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
    unlock steering.
    unlock throttle.
    return 1.
}

function phase_park {
    unlock steering.
    unlock throttle.
    return 10.
}