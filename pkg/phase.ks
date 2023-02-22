@LAZYGLOBAL off.
{
    parameter phase is lex(). // stock mission phase library.
    local nv is import("nv").
    local io is import("io").
    local ctrl is import("ctrl").
    local memo is import("memo").
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

        local dv is memo:getter({
            local current_speed is velocity:orbit:mag.
            local desired_speed is visviva:v(r0+altitude,r0+orbit_altitude+1,r0+periapsis).
            local speed_change_wanted is max(0, desired_speed - current_speed).

            local altitude_fraction is clamp(0,1,altitude / min(70000,orbit_altitude)).
            local pitch_wanted is (90-launch_pitchover)*(1 - sqrt(altitude_fraction)).
            local cmd_steering is heading(launch_azimuth,pitch_wanted,0).

            return cmd_steering:vector:normalized*speed_change_wanted. }).

        set ctrl:gain to ascent_gain.
        set ctrl:emin to max_facing_error/2.
        set ctrl:emax to max_facing_error.

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

    phase:add("pose", {
        lock steering to ctrl:steering(V(0,0,0)).
        lock throttle to ctrl:throttle(V(0,0,0)).
        return 0. }).

    phase:add("circ", {
        if abort return 0.

        phase_unwarp().

        local r0 is body:radius.

        local throttle_gain is nv:get("circ_throttle_gain", 5, true).
        local max_facing_error is nv:get("circ_max_facing_error", 5, true).
        local good_enough is nv:get("circ_good_enough", 1, true).

        // we do not admit the possibility of circularizing
        // without liquid fuel engines.
        if ship:LiquidFuel <= 0 {   // deal with "no fuel" case.
            io:say("Circularize: no fuel.").
            abort on. return 0. }

        local dv is memo:getter({         // compute desired velocity change.
            local desired_lateral_speed is visviva:v(r0+altitude).
            local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
            local desired_velocity is lateral_direction*desired_lateral_speed.
            return desired_velocity - velocity:orbit. }).

        {   // check termination condition.
            local desired_velocity_change is dv():mag.
            if desired_velocity_change <= good_enough {
                return phase:pose(). } }

        set ctrl:gain to throttle_gain.
        set ctrl:emin to 1.
        set ctrl:emax to max_facing_error.

        lock steering to ctrl:steering(dv).
        lock throttle to ctrl:throttle(dv).

        return 5.
    }).

    local hold_in_pose is false.
    phase:add("hold", {

        local throttle_gain is nv:get("hold_throttle_gain", 1, true).
        local max_facing_error is nv:get("hold_max_facing_error", 5, true).

        local hold_peri is nv:get("hold/periapsis").
        local hold_apo is nv:get("hold/apoapsis").

        local dv is memo:getter({
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
            local vi_rad is choose -sqrt(-vir2) if vir2<0 else sqrt(vir2).

            local vi_rad is -body:position:normalized*vi_rad.
            local vi_lat is vxcl(vi_rad,prograde:vector):normalized*vi_lat.
            local vi_cmd is vi_rad + vi_lat.

            return vi_cmd - ship:velocity:orbit. }).

        phase_unwarp().

        // peek at the throttle request BEFORE facing adjustment.
        local peek_throttle is ctrl:throttle(dv, true).

        if hold_in_pose {
            // if we exceed the pose exit threshold, stop posing.
            if peek_throttle > nv:get("hold/pose/exit", 0.5) {
                io:say("HOLD maneuvering.").
                set hold_in_pose to false. } }

        else {
            // if we are within the pose entry threshold, start posing.
            if peek_throttle < nv:get("hold/pose/enter", 0.1) {
                io:say("HOLD in idle pose.").
                set hold_in_pose to true. } }

        if hold_in_pose {
            lock steering to ctrl:steering(V(0,0,0)).
            lock throttle to ctrl:throttle(V(0,0,0)). }

        else {
            lock steering to ctrl:steering(dv).
            lock throttle to ctrl:throttle(dv). }

        return 1. }).

    phase:add("deorbit", {

        local h is 0.75 * body:atm:height.

        if periapsis <= h {
            lock throttle to 0.
            lock steering to srfretrograde.
            wait 1.
            set warp to 4.
            return 0. }

        phase_unwarp().

        local r0 is body:radius.

        local dv is memo:getter({
            local desired_speed is visviva:v(r0+altitude, h, r0+apoapsis).
            local current_speed is velocity:orbit:mag.
            local desired_speed_change is max(0, current_speed - desired_speed).
            return retrograde:vector*desired_speed_change. }).

        local throttle_gain is nv:get("deorbit_throttle_gain", 5, true).

        set ctrl:gain to throttle_gain.
        set ctrl:emin to 1.
        set ctrl:emax to 10.

        lock steering to ctrl:steering(dv).
        lock throttle to ctrl:throttle(dv).

        return 1.
    }).

    phase:add("lighten", {
        if not kuniverse:timewarp:issettled return 1.
        if not stage:ready return 1.
        if stage:number<1 return 0.
        if kuniverse:timewarp:rate>1 {
            kuniverse:timewarp:cancelwarp().
            return 1. }

        lock steering to ctrl:steering(V(0,0,0)).
        lock throttle to ctrl:throttle(V(0,0,0)).

        print " ".
        print "lighten activating for stage "+stage:number.
        print "  MET: "+round(time:seconds - nv:get("T0")).
        print "  altitude: "+round(altitude).
        print "  apoapsis: "+round(apoapsis).
        print "  periapsis: "+round(periapsis).
        print "  s velocity: "+round(velocity:surface:mag).
        print "  o velocity: "+round(velocity:orbit:mag).
        print "  vacuum delta-v: "+round(ship:deltav:vacuum).
        wait 1.
        wait until stage:ready. stage.
        return 1. }).

    phase:add("fall", {         // fall into atmosphere
        if body:atm:height<10000 return 0.
        if altitude<body:atm:height/2 return 0.
        lock steering to ctrl:steering(V(0,0,0)).
        lock throttle to ctrl:throttle(V(0,0,0)).
        return 1. }).

    phase:add("decel", {        // active deceleration
        lock steering to srfretrograde.

        // if no atmosphere, skip right to the next phase.
        if body:atm:height < 10000 return 0.
        if altitude < body:atm:height/4 return 0.
        if airspeed<200 return 0.
        local engine_list is list().
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
        local engine_list is list().
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