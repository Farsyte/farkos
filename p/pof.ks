{
    local farkos is import("farkos").

    // pof: phases of flight.
    // returns a lexicon of flight phase methods.

    function launch {
        parameter launch_azimuth is 90,
                  turn_alt is 100,
                  phase_alt is 500.

        // explicit initial control settings
        lock Cs to facing. set Ct to 0.
        lock throttle to Ct. lock steering to Cs.

        if availablethrust <= 0
            farkos:ev("push GO to launch").
        wait until availablethrust > 0.

        set Ct to 1.

        wait until alt:radar >= turn_alt.

        // we have ascended 100m, rotate and pitch over a tiny bit.
        lock Cs to heading(launch_azimuth, 89).

        wait until alt:radar >= phase_alt.

        // explicit final control settings
        // if we do nothing, just thrust forward along surface prograde.
        lock steering to lookdirup(srfprograde:vector,up:vector).
        lock throttle to 1.
    }

    function stager {
        local t is time:seconds.
        local l is stage:resourceslex.
        lock tfuel to ship:LiquidFuel.
        lock sfuel to l:SolidFuel:amount.
        lock lfuel to l:LiquidFuel:amount.
        when sfuel=0 and lfuel=0 then {
            stage. return tfuel > lfuel.
        }
    }

    function ascend {
        parameter launch_azimuth, orbit_altitude.

        // detect "phase complete" before changing any vehicle state.
        if ship:apoapsis > orbit_altitude
            return.

        // explicit initial control settings
        set Cs to facing. set Ct to 1.
        lock throttle to Ct. lock steering to Cs.

        lock Af to alt:radar / orbit_altitude.
        lock Cp to 90*(1 - sqrt(Af)).

        // we want to thrust along our current orbit at the selected pitch.
        // just in case we have not yet established any horizontal velocity,
        // add in a modest bias (Cb) which is a bit of speed in the desired
        // direction. The actual velocity will dominate over this quickly.

        set Cb to heading(launch_azimuth,0,0):vector*10.
        lock Ch to VXCL(UP:VECTOR,velocity:surface + Cb).
        lock Cv to Ch*cos(Cp)/Ch:mag + UP:Vector*sin(Cp).
        lock Cs to LOOKDIRUP(Cv,UP:Vector).

        wait until ship:apoapsis > orbit_altitude + 1000.

        farkos:ev("meco at " + round(altitude/1000,1) + " km").
        farkos:ev("  apoapsis: "+round(apoapsis/1000,1) + " km").

        unlock Cs. unlock Ct.
        unlock throttle. unlock steering.
    }

    function coastu {
        parameter margin.

        // explicit initial control settings
        global Cs is facing. global Ct is 0.
        lock throttle to Ct. lock steering to Cs.

        lock Cs to prograde.

        wait until eta:apoapsis < margin or ship:verticalspeed < 0.

        // explicit final control settings -- no change.
        // lock Cs to prograde. set Ct to 0.
    }

    function circ {
        parameter throttle_gain,max_facing_error,good_enough.

        // explicit initial control settings
        global Cs is facing. global Ct is 0.
        lock throttle to Ct. lock steering to Cs.

        lock circular_speed to sqrt(body:mu/(body:radius+altitude)).
        lock velocity_error to vxcl(up:vector,velocity:orbit):normalized*circular_speed-velocity:orbit.
        lock error_magnitude to velocity_error:mag.

        if error_magnitude > good_enough and maxthrust > 0 {

            lock Cs to lookdirup(velocity_error,facing:topvector).

            lock twr to clamp(0.01, 10, maxthrust / mass).
            lock ae to vang(facing:vector,velocity_error).
            lock ka to clamp(0,1,(max_facing_error-ae)/max_facing_error).
            lock Ct to clamp(0.01,1,ka*throttle_gain*error_magnitude/twr).

            wait until error_magnitude <= good_enough or maxthrust <= 0.
        }

        // explicit final control settings
        lock Cs to prograde. set Ct to 0.

        return true.
    }

    function pause {
        parameter duration is 0.

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
    }

    function deorbit {
        parameter desired_periapsis.

        // explicit initial control settings
        global Cs is facing. global Ct is 0.
        lock throttle to Ct. lock steering to Cs.

        farkos:ev("initiating deorbit.").

        set max_angle_error to 15.

        lock angle_error to vang(facing:vector, retrograde:vector).
        lock angle_error_fraction to clamp(0, 1, angle_error / max_angle_error).

        lock Cs to retrograde.
        lock Ct to clamp(0.01, 1, 1 - angle_error_fraction).

        wait until maxthrust < 0.01 or periapsis <= desired_periapsis.

        farkos:ev("deorbit terminating.").
        farkos:ev("  periapsis: " + round(periapsis/1000, 1) + " km.").

        // explicit final control settings
        lock Cs to retrograde. set Ct to 0.
    }

    function decel {
        parameter max_alt, min_alt.

        // explicit initial control settings
        global Cs is facing. global Ct is 0.
        lock throttle to Ct. lock steering to Cs.

        farkos:ev("preparing for decel.").
        lock Cs to retrograde.

        wait until altitude <= max_alt.

        farkos:ev("initiating decel.").

        set max_angle_error to 15.

        lock angle_error to vang(facing:vector, retrograde:vector).
        lock angle_error_fraction to clamp(0,1,angle_error / max_angle_error).

        lock Cs to retrograde.
        lock Ct to clamp(0.01, 1, 1 - angle_error_fraction).

        wait until maxthrust < 0.01 or altitude <= min_alt.

        farkos:ev("decel terminating.").
        farkos:ev("  velocity: " + round(velocity:orbit:mag/1000, 1) + " km.").

        // explicit final control settings
        lock Cs to retrograde. set Ct to 0.
    }

    function chute {

        farkos:ev("Reconfiguring for landing.").
        GEAR ON.

        until stage:number < 1 {
            wait 2.
            wait until stage:ready. stage.
        }
    }

    function end {
        farkos:ev("end of flight plan.").
        wait until false.
    }

    export(lex(
        "launch", launch@,
        "stager", stager@,
        "ascend", ascend@,
        "coastu", coastu@,
        "circ", circ@,
        "pause", pause@,
        "deorbit", deorbit@,
        "decel", decel@,
        "chute", chute@,
        "end", end@)).
}