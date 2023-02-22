{
    parameter phase is lex(). // stock mission phase library.
    local nv is import("nv").
    local io is import("io").
    local ctrl is import("ctrl").
    local radar is import("radar").
    local visviva is import("visviva").

    local dbg is import("dbg").

    // countdown phase needs a local,
    // which resets when we boot.
    local countdown is 10.

    function phase_unwarp {
        if kuniverse:timewarp:rate <= 1 return.
        kuniverse:timewarp:cancelwarp().
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
        kuniverse:timewarp:warpto(time:seconds+eta:apoapsis-45).
        wait 5.
        wait until kuniverse:timewarp:rate <= 1.
        wait until kuniverse:timewarp:issettled.
    }

    phase:add("countdown", {    // countdown, ignite, wait for thrust.
        if availablethrust>0 return 0.
        lock throttle to 1.
        lock steering to facing.
        if countdown > 0 {
            io:say("T-"+countdown, false).
            set countdown to countdown - 1.
            return 1. }
        radar:cal(). // trigger auto-calibration if needed.
        if stage:ready stage.
        return 1. }).

    phase:add("launch", {       // stabilize until clear of pad
        if alt:radar>50 return 0.
        lock steering to facing.
        lock throttle to 1.
        nv:get("T0", time:seconds, true).
        return 1/10. }).

    phase:add("ascent", {
        if abort return 0.

        local r0 is body:radius.

        local orbit_altitude is nv:get("launch_altitude", 80000, true).
        local launch_azimuth is nv:get("launch_azimuth", 90, true).
        local launch_pitchover is nv:get("launch_pitchover", 2, false).
        local ascent_gain is nv:get("ascent_gain", 10, true).
        local max_facing_error is nv:get("ascent_max_facing_error", 90, true).
        local ascent_apo_grace is nv:get("ascent_apo_grace", 0.5).

        if apoapsis >= orbit_altitude-ascent_apo_grace and altitude >= body:atm:height return 0.

        phase_unwarp().

        local memo_dv_time is 0.
        local memo_dv_result is V(0,0,0).

        local dv is {
            if time:seconds=memo_dv_time return memo_dv_result.
            local current_speed is velocity:orbit:mag.
            local desired_speed is visviva:v(r0+altitude,r0+orbit_altitude+1,r0+periapsis).
            local speed_change_wanted is desired_speed - current_speed.

            local altitude_fraction is clamp(0,1,altitude / min(70000,orbit_altitude)).
            local pitch_wanted is (90-launch_pitchover)*(1 - sqrt(altitude_fraction)).
            local cmd_steering is heading(launch_azimuth,pitch_wanted,0).

            // NOTE: ctrl:steering takes a vector, not a direction,
            // it minimizes roll rather than trying to point our heads
            // away from the planet.
            set memo_dv_result to cmd_steering:vector:normalized*speed_change_wanted.
            set memo_dv_time to time:seconds.
            return memo_dv_result. }.

        lock steering to ctrl:steering(dv).
        lock throttle to ctrl:throttle(dv).
        return 5.
    }).

    phase:add("coast", {        // coast to apoapsis
        if abort return 0.
        if verticalspeed<0 return 0.
        if eta:apoapsis<30 {
            phase_unwarp().
            return 0. }
        lock throttle to 0.
        lock steering to prograde.
        phase_apowarp().
        return 1. }).

    phase:add("pose", {        // switch to an idle pose.
        lock throttle to 0.
        lock steering to lookdirup(vcrs(body:position,ship:velocity:orbit), -body:position).
        return 0. }).

    phase:add("circ", {
        if abort return 0.

        local r0 is body:radius.

        local throttle_gain is nv:get("circ_throttle_gain", 5, true).
        local max_facing_error is nv:get("circ_max_facing_error", 5, true).
        local good_enough is nv:get("circ_good_enough", 1, true).

        if ship:LiquidFuel <= 0 {   // deal with "no fuel" case.
            io:say("Circularize: no fuel.").
            abort on. return 0. }

        local _delta_v is {         // compute desired velocity change.
            local desired_lateral_speed is visviva:v(r0+altitude).
            local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
            local desired_velocity is lateral_direction*desired_lateral_speed.
            return desired_velocity - velocity:orbit. }.

        {   // check termination condition.
            local desired_velocity_change is _delta_v():mag.
            if desired_velocity_change <= good_enough {
                return phase:pose(). } }

        local _steering is {        // steer in direction of delta-v
        phase_unwarp().

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
    }).

    local hold_in_pose is false.
    phase:add("hold", {

        local throttle_gain is nv:get("hold_throttle_gain", 1, true).
        local max_facing_error is nv:get("hold_max_facing_error", 5, true).

        local hold_peri is nv:get("hold/periapsis").
        local hold_apo is nv:get("hold/apoapsis").
        local r0 is body:radius.
        local ri is r0+altitude.
        local rp is min(ri,r0+hold_peri).
        local ra is max(ri,r0+hold_apo).
        local vi is visviva:v(ri, rp, ra).
        local vp_lat is visviva:v(rp, rp, ra).
        local va_lat is visviva:v(ra, rp, ra).
        local hp is rp * vp_lat.
        local vi_lat is hp/ri.
        local hi is ri * vi_lat.
        local vi2 is vi*vi.
        local vil2 is vi_lat*vi_lat.
        local vir2 is round(vi2 - vil2, 3).
        local vi_rad is sqrt(vir2). if verticalspeed<0 set vi_rad to -vi_rad.

        local vi_rad is -body:position:normalized*vi_rad.
        local vi_lat is vxcl(vi_rad,prograde:vector):normalized*vi_lat.
        local vi_cmd is vi_rad + vi_lat.
        local dv is vi_cmd - ship:velocity:orbit.

        set steering to lookdirup(dv, facing:topvector).

        local desired_accel is throttle_gain * dv:mag.
        local desired_force is mass * desired_accel.
        local max_thrust is max(0.01, availablethrust).
        local desired_throttle is clamp(0,2,desired_force/max_thrust).

        // if we exceed the pose exit threshold, stop posing.
        if desired_throttle > nv:get("hold/pose/exit", 0.05)
            set hold_in_pose to false.

        // if we are within the pose entry threshold, start posing.
        if desired_throttle < nv:get("hold/pose/enter", 0.01)
            set hold_in_pose to true.

        if hold_in_pose
            return phase:pose().

        phase_unwarp().

        local facing_error is vang(dv, facing:vector).
        local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
        set throttle to clamp(0,1,facing_error_factor*desired_throttle).

        return 1/100. }).

    phase:add("deorbit", {

        local h is 0.75 * body:atm:height.
        if periapsis < h {
            lock throttle to 0.
            lock steering to srfretrograde.
            wait 1.
            set warp to 4.
            return 0. }

        phase_unwarp().

        lock steering to retrograde.
        if 10<vang(facing:vector,steering:vector) return 1/10.

        local r0 is body:radius.

        local throttle_gain is nv:get("deorbit_throttle_gain", 5, true).

        local _throttle is {        // throttle proportional to delta-v
            local desired_speed is visviva:v(r0+altitude, h, r0+apoapsis).
            local current_speed is velocity:orbit:mag.
            local desired_speed_change is current_speed - desired_speed.
            local desired_accel is throttle_gain * desired_speed_change.
            local desired_force is mass * desired_accel.
            local max_thrust is max(0.01, availablethrust).
            local desired_throttle is clamp(0,1,desired_force/max_thrust).
            return clamp(0,1,desired_throttle). }. lock throttle to _throttle().

        return 1.
    }).

    phase:add("lighten", {
        if not stage:ready return 1.
        if stage:number<1 return 0.

        phase_unwarp().

        print " ".
        print "lighten activating for stage "+stage:number.
        print "  MET: "+round(time:seconds - nv:get("T0")).
        print "  altitude: "+round(altitude).
        print "  apoapsis: "+round(apoapsis).
        print "  periapsis: "+round(periapsis).
        print "  s velocity: "+round(velocity:surface:mag).
        print "  o velocity: "+round(velocity:orbit:mag).
        print "  vacuum delta-v: "+round(ship:deltav:vacuum).
        if altitude>body:atm:height
            phase:pose().
        else
            lock throttle to 0.
        wait 1.
        wait until stage:ready. stage.
        return 1. }).

    phase:add("fall", {         // fall into atmosphere
        if body:atm:height<10000 return 0.
        if altitude<body:atm:height/2 return 0.
        lock steering to srfretrograde.
        lock throttle to 0.
        return 1. }).

    phase:add("decel", {        // active deceleration
        lock steering to srfretrograde.

        // if no atmosphere, skip right to the next phase.
        if body:atm:height < 10000 return 0.
        if altitude < body:atm:height/4 return 0.
        list engines in engine_list.
        if engine_list:length < 1 return 0.

        lock steering to srfretrograde.
        lock throttle to 1.
        return 1. }).

    phase:add("psafe", {        // wait until generally safe to deploy parachutes
        // TODO what if we are not on Kerbin?
        lock steering to srfretrograde.
        if throttle>0 { set throttle to 0. return 1. }
        if verticalspeed>0 return 1.
        if stage:number>0 and stage:ready { stage. return 1. }
        if altitude < 5000 and airspeed < 300 return 0.
        return 1. }).

    phase:add("chute", {        // deploy parachutes.

        // This code assumes the convention that parachutes are
        // activated when we stage to stage zero.

        if stage:number<1 return 0.

        if stage:ready stage.
        unlock steering.
        unlock throttle.
        return 1. }).

    phase:add("land", {         // control during final landing
        if verticalspeed>=0 return 0.

        gear on.
        unlock steering.
        unlock throttle.
        return 1. }).

    phase:add("park", {         // control while parked
        unlock steering.
        unlock throttle.
        return 10. }).

    function has_no_rcs {
        list rcs in rcs_list.
        for r in rcs_list
            if not r:flameout
                return false.
        return true. }

    set steering to facing. // have to set it at least once ...
    phase:add("autorcs", {      // enable RCS when appropriate.
        if has_no_rcs()                                         return 0.
        local f is facing.
        local s is steering.

        if altitude < body:atm:height                           rcs off.
        else if ship:angularvel:mag>0.5                         rcs on.
        else if 10<vang(f:forevector, s:forevector)             rcs on.
        else if 10<vang(f:topvector, s:topvector)               rcs on.
        else                                                    rcs off.
        return 1/10.
    }).

    {
        // dump some info during boot.

        print " ".
        print "autostager initializing at stage "+stage:number.
        print "  MET: "+(time:seconds - nv:get("T0")).
        print "  altitude: "+altitude.
        print "  s velocity: "+velocity:surface:mag.
        print "  o velocity: "+velocity:orbit:mag.
        print "  delta-v: "+ship:deltav:vacuum.

    }
    phase:add("autostager", {   // stage when appropriate.

        // PAUSE if STAGE:READY is false.
        // - catches "we are doing an EVA"
        // - needs to be true anyway for us to stage.
        if not stage:ready return 1.

        // PAUSE if we have not yet launched.
        // This will also trigger during the very last moments
        // of a landing if we have no thrust. Not a problem.
        if alt:radar<100 and availablethrust<=0 return 1.

        // END if the engine list is empty.
        // - staging will not jettison anything useful.
        list engines in engine_list.
        if engine_list:length<1 return 0.

        // Return without staging if we have an ignited engine
        // that is not yet flamed out.
        local s is stage:number.
        for e in engine_list
            if e:decoupledin=s-1 and e:ignition and not e:flameout
                return 1.

        print " ".
        print "autostager activating for stage "+stage:number.
        print "  MET: "+(time:seconds - nv:get("T0")).
        print "  altitude: "+altitude.
        print "  s velocity: "+velocity:surface:mag.
        print "  o velocity: "+velocity:orbit:mag.
        print "  delta-v: "+ship:deltav:vacuum.

        // stage to discard dead weight and activate
        // any currently not-yet-ignited engines.
        stage.
        return 1. }). }