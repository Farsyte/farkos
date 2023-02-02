loadfile("visviva").

function phase_unwarp {
    if kuniverse:timewarp:rate <= 1 return.
    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:issettled.
}

function phase_decwarp {
    local warpstep is kuniverse:timewarp:warp.
    if warpstep<1 return.
    set kunvierse:timewarp:warp to warpstep-1.
    wait until kuniverse:timewarp:issettled.
}

function phase_apowarp {
    if not kuniverse:timewarp:issettled return.

    if kuniverse:timewarp:rate>1 {
        kuniverse:timewarp:cancelwarp().
        return.
    }

    if eta:apoapsis<20 return.

    kuniverse:timewarp:warpto(time:seconds+eta:apoapsis-10).
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
    // current convention is that stage 0 has the parachutes.
    // we do not trigger parachutes with the autostager.
    local s is stage:number. if s<2 return 0.
    list engines in engine_list.
    // if engine_list:length<1 return 0.
    for e in engine_list
        if e:decoupledin=s-1 and not e:flameout
            return 1.
    if stage:ready stage.
    return 1.
}

local countdown is 10.
function phase_countdown {
    if availablethrust>0 return 0.
    lock throttle to 1.
    lock steering to facing.
    if countdown > 0 {
        say("T-"+countdown, false).
        set countdown to countdown - 1.
        return 1. }
    if stage:ready stage.
    return 1. }

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
    if abort return 0.

    local r0 is body:radius.

    local orbit_altitude is persist_get("launch_altitude", 80000, true).
    local launch_azimuth is persist_get("launch_azimuth", 90, true).
    local ascent_gain is persist_get("ascent_gain", 10, true).
    local max_facing_error is persist_get("ascent_max_facing_error", 90, true).
    local ascent_apo_grace is persist_get("ascent_apo_grace", 0.5).

    if apoapsis >= orbit_altitude-ascent_apo_grace and altitude >= body:atm:height return 0.

    local _steering is {        // simple pitch program
        local altitude_fraction is clamp(0,1,altitude / min(80000,orbit_altitude)).
        local pitch_wanted is 90*(1 - sqrt(altitude_fraction)).
        return heading(launch_azimuth,pitch_wanted,0). }.

    local _throttle is {        // P conttroller to stop at target apoapsis
        local current_speed is velocity:orbit:mag.
        local desired_speed is visviva_v(r0+altitude,r0+orbit_altitude+1,r0+periapsis).
        local speed_change_wanted is desired_speed - current_speed.
        local accel_wanted is speed_change_wanted * ascent_gain.
        local force_wanted is mass * accel_wanted.
        local max_thrust is max(0.01, availablethrust).
        local throttle_wanted is force_wanted / max_thrust.
        local throttle_wanted_clamped is clamp(0,1,throttle_wanted).
        local facing_error is vang(facing:vector,steering:vector).
        local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
        return throttle_wanted_clamped*facing_error_factor. }.

    phase_unwarp().
    lock steering to _steering().
    lock throttle to _throttle().

    return 5.
}

function phase_coast {
    if abort return 0.
    if verticalspeed<0 return 0.

    phase_apowarp().

    if eta:apoapsis<30 return 0.
    phase_unwarp().
    lock throttle to 0.
    lock steering to prograde.
    return 1/10.
}

function phase_circ {
    if abort return 0.

    phase_unwarp().

    local r0 is body:radius.

    local throttle_gain is persist_get("circ_throttle_gain", 5, true).
    local max_facing_error is persist_get("circ_max_facing_error", 5, true).
    local good_enough is persist_get("circ_good_enough", 1, true).

    if ship:LiquidFuel <= 0 {   // deal with "no fuel" case.
        say("Circularize: no fuel.").
        local steering is prograde.
        local throttle is 0. }

    local _delta_v is {         // compute desired velocity change.
        local desired_lateral_speed is visviva_v(r0+altitude).
        local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
        local desired_velocity is lateral_direction*desired_lateral_speed.
        return desired_velocity - velocity:orbit. }.

    {   // check termination condition.
        local desired_velocity_change is _delta_v():mag.
        if desired_velocity_change <= good_enough {
            // say("circularization complete").
            // print "apoapsis-periapsis spread: "+(apoapsis-periapsis)+" m.".
            // print "final speed error: "+desired_velocity_change+" m/s.".

            local steering is prograde.
            local throttle is 0.
            return 0. } }

    local _steering is {        // steer in direction of delta-v
        return lookdirup(_delta_v(),facing:topvector). }.

    local _throttle is {        // throttle proportional to delta-v
        local desired_velocity_change is _delta_v().

        local desired_accel is throttle_gain * desired_velocity_change:mag.
        local desired_force is mass * desired_accel.
        local max_thrust is max(0.01, availablethrust).
        local desired_throttle is clamp(0,1,desired_force/max_thrust).

        local facing_error is vang(facing:vector,desired_velocity_change).
        local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
        return clamp(0,1,facing_error_factor*desired_throttle). }.

    lock steering to _steering().
    lock throttle to _throttle().

    return 5.
}

function phase_hold_brakes_to_deorbit {
    if abort return 0.

    say("Activate ABORT to deorbit.", false).
    lock steering to retrograde.
    lock throttle to 0.
    return 5.
}

function phase_deorbit {
    if abort abort off.
    if periapsis < 0 {
        lock throttle to 0.
        lock steering to retrograde.
        wait 3.
        if altitude > body:atm:height
            set warp to 3.
        return 0. }

    phase_unwarp().
    lock steering to retrograde.
    lock throttle to 1.
    return 1/10.
}

function phase_fall {
    abort off.
    if body:atm:height<10000 return 0.
    if altitude<body:atm:height/2 return 0.

    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_decel {
    abort off.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if body:atm:height < 10000 return 0.
    if altitude < body:atm:height/4 return 0.
    list engines in engine_list.
    if engine_list:length < 1 return 0.

    if kuniverse:timewarp:rate>1 {
        phase_unwarp().
        return 1/10. }

    lock steering to srfretrograde.
    lock throttle to 1.
    return 1/10.
}

function phase_psafe {
    abort off.
    // this is a decent rule of thumb for most parachutes
    // descending into Kerbin's atmosphere ...
    if altitude < 5000 and airspeed < 300 return 0.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if kuniverse:timewarp:rate>1 {
        phase_unwarp().
        return 1/10. }

    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_chute {
    abort off.
    if stage:number<1 return 0.

    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if kuniverse:timewarp:rate>1 {
        phase_unwarp().
        return 1/10. }
    if stage:ready stage.
    unlock steering.
    unlock throttle.
    return 1.
}

function phase_gear {
    abort off.
    gear on. return 0.
}

function phase_land {
    abort off.
    if verticalspeed>=0 return 0.

    phase_unwarp().
    unlock steering.
    unlock throttle.
    return 1.
}

function phase_park {
    abort off.
    unlock steering.
    unlock throttle.
    return 10.
}