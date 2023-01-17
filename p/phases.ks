{
    local farkos is import("farkos").
    local persist is import("persist").
    local mission is import("mission").

    local phases is lex(
        "_get", _get@,
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

    function launch {
        set launch_azimuth to persist:get("launch_azimuth", 90, true).
        set launch_rotate to persist:get("launch_rotate", 100, true).
        set launch_clear to persist:get("launch_clear", 500, true).

        local tv is time.
        local t is tv:seconds.
        local t0 is persist:get("t0", t+9.99, true).

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
            persist:set("t0", t).
        }

        if alt:radar >= launch_clear {
            farkos:ev(ship:name + " is clear of the tower.").
            mission:next_phase().
        }

        return 0.1.
    }

    function stager {
        local p is persist:get("stager_period", 2, true).
        if alt:radar < 100 return p.
        local l is stage:resourceslex.
        local tfuel is ship:LiquidFuel.
        local sfuel is l:SolidFuel:amount.
        local lfuel is l:LiquidFuel:amount.
        if sfuel=0 and lfuel=0 and stage:ready stage.
        if ship:LiquidFuel > lfuel return p.
        return -1.
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
        lock Ct to clamp(0.01,1,ka*throttle_gain*error_magnitude/twr).

        lock steering to Cs.
        lock throttle to Ct.

        return 1.
    }

    function pause {
        local duration is persist:get("pause_duration", 0, true).

        if duration > 0 {
            wait duration.
            return.
        }

        farkos:ev("activate RCS to continue.").
        rcs off.
        wait until rcs.
        farkos:ev("resuming flight plan.").
        wait 1.
        rcs off.
        mission:next_phase().
        return 0.
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
        lock angle_error_fraction to clamp(0, 1, angle_error / max_angle_error).

        lock Cs to retrograde.
        lock Ct to clamp(0.01, 1, 1 - angle_error_fraction).
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
        lock angle_error_fraction to clamp(0,1,angle_error / max_angle_error).

        lock Ct to clamp(0.01, 1, 1 - angle_error_fraction).
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