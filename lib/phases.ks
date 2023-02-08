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

    if eta:apoapsis<60 return.

    if kuniverse:timewarp:mode = "PHYSICS" {
        set kuniverse:timewarp:mode to "RAILS".
        wait 1.
    }
    kuniverse:timewarp:warpto(time:seconds+eta:apoapsis-30).
    wait 5.
    wait until kuniverse:timewarp:rate <= 1.
    wait until kuniverse:timewarp:issettled.
}

function phase_pose {
    // pose for a selfie.
    // if we are far away or rotating fast, RCS ON.
    // if we are close and rotating slow, RCS OFF.
    lock throttle to 0.
    lock steering to lookdirup(body:north:vector, -body:position).
    return 0.
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
    local s is stage:number. if s<1 return 0.
    list engines in engine_list.
    if engine_list:length<1 return 0.
    for e in engine_list
        if e:decoupledin=s-1 and e:ignition and not e:flameout
            return 1.
    if stage:ready stage.
    return 1.
}

function has_no_rcs {
    list rcs in rcs_list.
    for r in rcs_list
        if not r:flameout
            return false.
    return true.
}

// BG_RCS: A background task for RCS enable
//
// Enables the RCS when our steering command and facing
// are sufficiently different, or our angular rate is high.
function bg_rcs {
    if has_no_rcs()                                         return 0.

    if altitude < body:atm:height                           rcs off.
    else if ship:angularvel:mag>0.2                         rcs on.
    else if 5<vang(facing:forevector, steering:forevector)  rcs on.
    else if 5<vang(facing:topvector, steering:topvector)    rcs on.
    else                                                    rcs off.
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
    local launch_pitchover is persist_get("launch_pitchover", 2, false).
    local ascent_gain is persist_get("ascent_gain", 10, true).
    local max_facing_error is persist_get("ascent_max_facing_error", 90, true).
    local ascent_apo_grace is persist_get("ascent_apo_grace", 0.5).

    if apoapsis >= orbit_altitude-ascent_apo_grace and altitude >= body:atm:height return 0.

    local _steering is {        // simple pitch program
        // pitch over by launch_pitchover degrees when clear,
        // then gradually pitch down until we hit level
        // as we leave the atmosphere.
        local altitude_fraction is clamp(0,1,altitude / min(70000,orbit_altitude)).
        local pitch_wanted is (90-launch_pitchover)*(1 - sqrt(altitude_fraction)).
        return heading(launch_azimuth,pitch_wanted,0). }.

    local _throttle is {        // Proportional Controller to stop at target apoapsis
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

local launch_dv is persist_get("launch_dv", ship:deltav:vacuum, true).
function phase_circ {
    if abort return 0.

    phase_unwarp().

    local r0 is body:radius.

    local throttle_gain is persist_get("circ_throttle_gain", 5, true).
    local max_facing_error is persist_get("circ_max_facing_error", 5, true).
    local good_enough is persist_get("circ_good_enough", 1, true).

    if ship:LiquidFuel <= 0 {   // deal with "no fuel" case.
        say("Circularize: no fuel.").
        abort on. return 0. }

    local _delta_v is {         // compute desired velocity change.
        local desired_lateral_speed is visviva_v(r0+altitude).
        local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
        local desired_velocity is lateral_direction*desired_lateral_speed.
        return desired_velocity - velocity:orbit. }.

    {   // check termination condition.
        local desired_velocity_change is _delta_v():mag.
        if desired_velocity_change <= good_enough {
            print "circularization complete.".
            print "  achieved "+round(periapsis/1000)
                +"x"+round(apoapsis/1000)
                +" km orbit using "
                +round(launch_dv - ship:deltav:vacuum)
                +" m/s Delta V.".
            return phase_pose(). } }

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

    phase_pose().
    say("Activate ABORT to deorbit.", false).
    return 5.
}

function phase_deorbit {
    // Once we get periapsis down below the dirt,
    // this phase is well and truly complete.
    if periapsis < 0 {
        lock throttle to 0.
        lock steering to retrograde.
        return 0. }

    // If we are coming in from above 250km,
    // end the deorbit when periapsis is 90%
    // of the height of the atmosphere.
    //
    // we will make multiple aerobraking passes.
    if apoapsis > 250000 {
        local ah is body:atm:height.
        if altitude>ah and periapsis<ah*0.80 {
            lock throttle to 0.
            lock steering to retrograde.
            return 0.
        }
    }

    phase_unwarp().
    lock steering to retrograde.
    lock throttle to 1.
    return 1/10.
}

// Aerobraking.
function phase_aero {
    if not body:atm:exists return 0.

    local ah is body:atm:height.

    // if periapsis is deep in the atmosphere, we are done.
    if periapsis<ah*0.50 {
        lock steering to srfretrograde.
        set throttle to 0.
        return 0. }

    // when to do nothing:
    // - time warp in progress
    // - time warp not settled.
    if kuniverse:timewarp:warp>1 return 5.
    if not kuniverse:timewarp:issettled return 1/10.

    // if our periapsis is not in the atmosphere,
    // just burn to reduce energy. we don't care
    // where we are in the orbit when doing this.
    if periapsis > ah*0.90 {
        lock steering to retrograde.
        set throttle to 1.
        return 1.
    }

    // if we are in space (plus some margin), warp until
    // we are about to enter the atmosphere.
    if altitude>ah*1.10 {    // in space: use timewarp.
        if kuniverse:timewarp:mode = "PHYSICS" {
            set kuniverse:timewarp:mode to "RAILS".
            return 1.
        }

        // figure out when we next enter the atmosphere.

        local tmin is time:seconds.
        local tmax is tmin + eta:periapsis.

        until tmax<tmin+1 {
            local tmid is (tmin+tmax)/2.
            local s_p is predict_pos(tmid, ship).
            local s_r is s_p:mag.
            if s_r > ah set tmin to tmid.
            else set tmax to tmid. }

        warpto(tmin-30).
        return 5.
    }

    lock steering to retrograde.
    set throttle to 1.
    return 1.
}

function phase_fall {
    if body:atm:height<10000 return 0.
    if altitude<body:atm:height/2 return 0.

    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_decel {
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.

    lock steering to srfretrograde.

    // if no atmosphere, skip right to the next phase.
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
    // this is a decent rule of thumb for most parachutes
    // descending into Kerbin's atmosphere ...
    if altitude < 5000 and airspeed < 300 return 0.
    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if kuniverse:timewarp:rate>1 {
        phase_unwarp().
        return 1/10. }

    sas on.
    lock steering to srfretrograde.
    lock throttle to 0.
    return 1/10.
}

function phase_chute {
    if stage:number<1 return 0.

    if not kuniverse:timewarp:issettled return 1/10.            // if timewarp rate is changing, try again very shortly.
    if kuniverse:timewarp:rate>1 {
        phase_unwarp().
        return 1/10. }
    if stage:ready stage.
    sas on.
    unlock steering.
    unlock throttle.
    return 1.
}

function phase_gear {
    sas on.
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