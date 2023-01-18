{
    local farkos is import("farkos").
    local persist is import("persist").
    local mission is import("mission").

    local phases is lex(
        "_get", _get@,
        "ascent_log", ascent_log@,
        "descent_log", descent_log@,
        "launch", launch@,
        "stager", stager@,
        "ascent", ascent@,
        "coastu", coastu@,
        "circ", circ@,
        "pause", pause@,
        "deorbit", deorbit@,
        "decel", decel@,
        "chute", chute@,
        "end", end@).

    export(phases).

    global Cs is facing.
    global Ct is 0.

    function dummy {
        farkos:ev("Executing DUMMY phase!").
        mission:next_phase().
        return 0.
    }

    function _get {
        parameter phase_nm.
        if phases:haskey(phase_nm) return phases[phase_nm].
        farkos:ev("BAD PHASE: '" + phase_nm + "'.").
        return dummy@.
    }

    local ascent_log_file is "0:/l/" + ship:name + "/ascent.csv".
    function ascent_log {

        // if we are descending, stop logging.
        if verticalspeed < -1 {
            return -1.
        }

        // if we are above atmosphere, stop the task.
        if altitude > ship:body:atm:height {
            return -1.
        }

        // If we do not have a connection, try again shortly.
        if not homeconnection:isconnected {
            return 1.
        }

        local t is time:seconds.
        local t0 is persist:get("t0",t,false).


        // if we have not yet launched,
        // clear the log and try agin soon.
        if t <= t0 {
            if exists(ascent_log_file)
                    deletepath(ascent_log_file).
            return 1.
        }

        // if the log file does not exist, provide a header line.
        if not exists(ascent_log_file)
            log "MET,RAlt,GSpd,OSpd" to ascent_log_file.

        local MET is round(t-t0).
        local RAlt is alt:radar.
        local GSpd is velocity:surface:mag.
        local OSpd is velocity:orbit:mag.

        log list(MET,RAlt,GSpd,OSpd):join(",") to ascent_log_file.

        // schedule next run at the next MET tick.
        return 1 - mod(t-t0, 1).
    }

    local descent_log_file is "0:/l/" + ship:name + "/descent.csv".
    function descent_log {

        // If we do not have a connection, try again shortly.
        if not homeconnection:isconnected return 1.

        local t is time:seconds.
        local t0 is persist:get("t0",t,false).

        local MET is round(t - t0).

        // ignore calls within the first 15 seconds of the launch.
        if MET < 15 {
            return 1.
        }

        local RAlt is alt:radar.

        // if we are resting on the ground, terminate the task.
        if RAlt < 50 {
            return -1.
        }

        // if we are ascending in-atmosphere,
        // clear the log file (if it exists) and try again shortly.

        if verticalspeed>0 or altitude>ship:body:atm:height {
            if exists(descent_log_file)
                deletepath(descent_log_file).
            return 1.
        }

        // if the log file does not exist, provide a header line.
        if not exists(descent_log_file)
            log "MET,RAlt,GSpd,OSpd" to descent_log_file.

        local GSpd is velocity:surface:mag.
        local OSpd is velocity:orbit:mag.

        log list(MET,RAlt,GSpd,OSpd):join(",") to descent_log_file.

        // schedule next run at the next MET tick.
        return 1 - mod(t-t0, 1).
    }

    // rebooting resets countdown to 10.
    local countdown is 10.
    function launch {
        set launch_azimuth to persist:get("launch_azimuth", 90, true).
        set launch_rotate to persist:get("launch_rotate", 100, true).
        set launch_clear to persist:get("launch_clear", 500, true).

        local tv is time.
        local t is tv:seconds.

        if NOT persist:has("t0") {
            // do a ten second countdown.
            if countdown > 0 {
                farkos:ev("Launch in T-" + countdown, false).
                set countdown to countdown - 1.
                return 1.
            }
        }

        local t0 is persist:get("t0", t, true).

        if alt:radar >= launch_rotate {
            set Cs to heading(launch_azimuth, 89).
        } else {
            set Cs to facing.
        }

        set Ct to 1.
        lock throttle to Ct.
        lock steering to Cs.

        if t < t0 {
            farkos:ev("Launch in T-" + round(t0-t,0)).
            return mod(t0-t, 1).
        }

        if availablethrust = 0 and stage:ready {
            stage.
            farkos:ev(tv:full + " Launch of " + ship:name).
            persist:put("t0", t).
        }

        if alt:radar >= launch_clear {
            farkos:ev(ship:name + " is clear of the tower.").
            mission:next_phase().
        }

        return 0.1.
    }

    // simple auto-stager: stage when max thrust is zero.
    // stop when there is no liquid fuel after the current stage.
    function stager {
        if alt:radar<100 return 1.
        if maxthrust>0 return 1.
        if stage:number<1 return 0.
        if not stage:ready return 1.
        stage.
        local l is stage:resourceslex.
        local tfuel is round(ship:LiquidFuel).
        local lfuel is round(l:LiquidFuel:amount).
        return choose 1 if tfuel>lfuel else 0.
    }

    function ascent {
        local launch_azimuth is persist:get("launch_azimuth", 90, true).
        local orbit_altitude is persist:get("orbit_altitude", 80000, true).

        // check for ascent phase completion.
        if ship:apoapsis > orbit_altitude + 1000 {
            farkos:ev("MECO at " + round(altitude/1000,1) + " km").
            farkos:ev("  Apoapsis: " + round(apoapsis/1000,1) + " km").
            farkos:ev("  Remaining ΔV: " + round(ship:deltav:current, 1) + " m/s.").

            set Cs to facing. set Ct to 0.
            lock throttle to Ct. lock steering to Cs.
            mission:next_phase().
            return 0.1.
        }

        lock Af to alt:radar / orbit_altitude.
        lock Cp to 90*(1 - sqrt(Af)).

        // we want to thrust along our current orbit at the selected pitch.
        // just in case we have not yet established any horizontal velocity,
        // add in a modest bias (Cb) which is a bit of speed in the desired
        // direction. The actual velocity will dominate over this quickly.

        set Cb to heading(launch_azimuth,0,0):vector*10.

        // using LOCK for these computations so that we have smooth
        // changes in controls, despite only calling this ascent step
        // method periodically.

        lock Ch to VXCL(UP:VECTOR,velocity:surface + Cb).
        lock Cv to Ch*cos(Cp)/Ch:mag + UP:Vector*sin(Cp).
        lock Cs to LOOKDIRUP(Cv,UP:Vector).

        set Ct to 1.

        lock throttle to Ct. lock steering to Cs.

        return 1.
    }

    function coastu {
        local margin is persist:get("pre_circ", 30, true).
        set Ct to 0. lock Cs to prograde.
        lock throttle to Ct.
        lock steering to Cs.
        if eta:apoapsis < margin {
            farkos:ev("Ascent phase complete").
            farkos:ev("  Altitude: " + round(alt:radar/1000,1) + " km.").
            farkos:ev("  Apoapsis in " + round(eta:apoapsis,1) + " sec.").
            mission:next_phase().
            return 0.
        }
        return mod(eta:apoapsis-margin, 1).
    }

    function circ {
        local throttle_gain is persist:get("circ_throttle_gain", 5, true).
        local max_facing_error is persist:get("circ_max_facing_error", 5, true).
        local good_enough is persist:get("circ_good_enough", 1, true).

        lock circular_speed to sqrt(body:mu/(body:radius+altitude)).
        lock velocity_error to vxcl(up:vector,velocity:orbit):normalized*circular_speed-velocity:orbit.
        lock error_magnitude to velocity_error:mag.

        if error_magnitude <= good_enough or ship:LiquidFuel <= 0 {
            set Cs to prograde. set Ct to 0.
            lock steering to Cs.
            lock throttle to Ct.

            farkos:ev("CIRCULARIZE phase complete").
            farkos:ev("  Periapsis: " + round(periapsis/1000,1) + " km.").
            farkos:ev("  Apoapsis:  " + round(apoapsis/1000,1) + " km.").
            farkos:ev("  Remaining ΔV: " + round(ship:deltav:current, 1) + " m/s.").
            mission:next_phase().
            return 1.
        }

        lock Cs to lookdirup(velocity_error,facing:topvector).

        lock twr to clamp(0.01, 10, maxthrust / mass).
        lock ae to vang(facing:vector,velocity_error).
        lock ka to clamp(0,1,(max_facing_error-ae)/max_facing_error).
        lock Ct to clamp(0,1,ka*throttle_gain*error_magnitude/twr).

        lock steering to Cs.
        lock throttle to Ct.

        return 1.
    }

    function pause {
        local duration is persist:get("pause_duration", 0, true).

        local t is time:seconds.
        local stopat is persist:get("pause_finished", t + duration, true).
        if t < stopat {
            set Cs to prograde. set Ct to 0.
            lock steering to Cs.
            lock throttle to Ct.
            return stopat - t.
        }

        if duration > 0 {
            mission:next_phase().
            persist:clr("pause_finished").
            return 1.
        }

        // RCS based.
        if RCS {
            rcs off.
            persist:clr("pause_rcs_notified").
            mission:next_phase().
            return 0.
        }

        farkos:ev("activate RCS to continue.", false).

        set Cs to prograde. set Ct to 0.
        lock steering to Cs.
        lock throttle to Ct.
        return 10.
    }

    function deorbit {
        local deorbit_periapsis is persist:get("deorbit_periapsis", 2000, true).
        if periapsis <= deorbit_periapsis or maxthrust < 0.01 {
            lock Cs to retrograde. set Ct to 0.
            lock steering to Cs.
            lock throttle to Ct.
            mission:next_phase().
            return 1.
        }

        set max_angle_error to 15.

        lock angle_error to vang(facing:vector, retrograde:vector).
        lock angle_error_fraction to angle_error / max_angle_error.

        lock Cs to retrograde.
        lock Ct to clamp(0, 1, 1 - angle_error_fraction).
        lock steering to Cs.
        lock throttle to Ct.
        return 1.
    }

    function decel {
        local max_alt is persist:get("decel_max_alt", 50000, true).
        local min_alt is persist:get("decel_min_alt", 40000, true).
        lock Cs to srfretrograde.
        lock steering to Cs.

        if altitude <= min_alt or maxthrust < 0.01 {
            set Ct to 0.
            lock throttle to Ct.
            mission:next_phase().
            return 1.
        }

        if altitude > max_alt {
            set Ct to 0.
            lock throttle to Ct.
            return 1.
        }

        set max_angle_error to 15.

        lock angle_error to vang(facing:vector, retrograde:vector).
        lock angle_error_fraction to angle_error / max_angle_error.

        lock Ct to clamp(0, 1, 1 - angle_error_fraction).
        lock throttle to Ct.

        return 1.
    }

    function chute {
        GEAR ON.
        if stage:number < 1 {
            mission:next_phase().
            return 1.
        }
        if stage:ready stage.
        return 1.
    }

    function end {
        return 1.
    }
}