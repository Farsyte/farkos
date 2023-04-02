@LAZYGLOBAL off.
{   parameter phase is lex(). // stock mission phase library.

    local nv is import("nv").
    local io is import("io").
    local dbg is import("dbg").
    local ctrl is import("ctrl").
    local memo is import("memo").
    local radar is import("radar").
    local visviva is import("visviva").
    local predict is import("predict").

    local dbg is import("dbg").

    // countdown phase needs a local,
    // which resets when we boot.
    local countdown is 10.

    function phase_unwarp {
        if kuniverse:timewarp:rate <= 1 return.
        kuniverse:timewarp:cancelwarp().
        wait until kuniverse:timewarp:issettled. }

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
        wait until kuniverse:timewarp:issettled. }

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

        local radius_body is body:radius.

        local orbit_altitude is nv:get("launch_altitude", 80000, true).
        local launch_azimuth is nv:get("launch_azimuth", 90, true).
        local launch_pitchover is nv:get("launch_pitchover", 2, false).
        local max_facing_error is nv:get("ascent_max_facing_error", 90, true).
        local ascent_apo_grace is nv:get("ascent_apo_grace", 0.5).

        if apoapsis >= orbit_altitude-ascent_apo_grace and altitude >= body:atm:height {
            lock throttle to 0.
            lock steering to prograde.
            return 0. }

        if not kuniverse:timewarp:issettled return 1/10.
        if kuniverse:timewarp:rate > 1 {
            kuniverse:timewarp:cancelwarp().
            return 1/10. }

        local dv is memo:getter({
            local current_speed is velocity:orbit:mag.
            // aim a bit high or we faff about forever.
            local desired_speed is visviva:v(radius_body+altitude,radius_body+orbit_altitude+1000,radius_body+periapsis).
            local speed_change_wanted is max(0, desired_speed - current_speed).

            local altitude_fraction is clamp(0,1,altitude / min(70000,orbit_altitude)).
            local pitch_wanted is (90-launch_pitchover)*(1 - sqrt(altitude_fraction)).
            local cmd_steering is heading(launch_azimuth,pitch_wanted,0).

            return cmd_steering:vector:normalized*speed_change_wanted. }).

        ctrl:dv(dv, 1, max_facing_error/2, max_facing_error).
        return 5. }).

    phase:add("ascent_v2", { // throttle back to manage Apoapsis ETA
        if abort return 0.

        // Data collected from the M/01 launch configuration:

        // vacuum delta-v using ascent v1
        // TODO rerun with pitchover at 3 degrees
        //   6656 at launch
        //   6049 at stage 4,  3.1 km altitude
        //   5219 at stage 3, 13.4 km altitude
        //   3927 before circ from periapsis of about -450 km.
        //   3892 at stage 2, 79.3 km altitude (just after starting circ)
        //   3007 after circ (apo 79446, peri 78495, MET 04:39)

        // vacuum delta-v using ascent v2, range 45 to 90 seconds
        // going full throttle when periapsis is above atmosphere
        //   6656 at launch
        //   6049 at stage 4,  3.1 km altitude
        //   5219 at stage 3, 14.2 km altitude
        //   3892 at stage 2, 51.9 km altitude
        //   3074 before circ from periapsis of about -18.6 km.
        //   2984 after circ (apo 79845, peri 79018, MET 06:36)
        //   NOTE: circularized with 367 m/s remaining in stage 2!
        //   at stage 1

        // conclusion: original ascent is very slightly more efficient
        // and quite a bit faster, but the V2 ascent might allow the
        // use of more efficient but lower thrust engines.

        local eta_min is nv:get("ascent/eta/min", 45, false).
        local eta_max is nv:get("ascent/eta/max", 90, false).

        local radius_body is body:radius.

        local orbit_altitude is nv:get("launch_altitude", 80000, true).
        local launch_azimuth is nv:get("launch_azimuth", 90, true).
        local launch_pitchover is nv:get("launch_pitchover", 3, false).
        local max_facing_error is nv:get("ascent_max_facing_error", 90, true).
        local ascent_apo_grace is nv:get("ascent_apo_grace", 0.5).

        if apoapsis >= orbit_altitude-ascent_apo_grace and altitude >= body:atm:height {
            lock steering to prograde.
            lock throttle to 0.
            return 0. }

        if not kuniverse:timewarp:issettled return 1/10.
        if kuniverse:timewarp:rate > 1 {
            kuniverse:timewarp:cancelwarp().
            return 1/10. }

        local _throttle is {
            if periapsis >= body:atm:height return 1.
            local eta_curr is eta:apoapsis.
            if eta_curr <= eta_min return 1.
            if eta_curr >= eta_max return 0.
            return (eta_max - eta_curr)/(eta_max - eta_min). }.

        local _steering is {
            local altitude_fraction is clamp(0,1,altitude / min(80000,orbit_altitude)).
            local pitch_wanted is (90-launch_pitchover)*(1 - sqrt(altitude_fraction)).
            // TODO limit angle of attack?
            return heading(launch_azimuth,pitch_wanted,0). }.

        lock steering to _steering().
        lock throttle to _throttle().
        // ctrl:dv(dv, 1, max_facing_error/2, max_facing_error).
        return 5. }).

    phase:add("coast", {                // coast to near apoapsis
        if abort return 0.
        if not kuniverse:timewarp:issettled return 1/10.

        if verticalspeed<0 {            // terminate: we overshot apoapsis.
            if kuniverse:timewarp:rate > 1 { kuniverse:timewarp:cancelwarp(). return 1/10. }
            ctrl:dv(srfretrograde:vector/10000, 1, 1, 5).
            if vang(steering:vector, facing:vector)>5 return 1.
            return 0. }

        if eta:apoapsis<30 {            // terminate: approaching apoapsis.
            if kuniverse:timewarp:rate > 1 { kuniverse:timewarp:cancelwarp(). return 1/10. }
            ctrl:dv(prograde:vector/10000, 1, 1, 5).
            if vang(steering:vector, facing:vector)>5 return 1.
            return 0. }

        if eta:apoapsis>60 {

            if kuniverse:timewarp:mode = "PHYSICS" and altitude>ship:body:atm:height {
                if kuniverse:timewarp:rate > 1 { kuniverse:timewarp:cancelwarp(). return 1/10. }
                print "switching timewarp mode from PHYSICS to RAILS.".
                set kuniverse:timewarp:mode to "RAILS".
                return 1/10. }

            if kuniverse:timewarp:rate=1
                warpto(time:seconds+eta:apoapsis-45).
            return 5. }

        ctrl:dv(prograde:vector/10000, 1, 1, 5).

        return min(5, eta:apoapsis-30). }).

    phase:add("pose", {
        ctrl:dv(V(0,0,0), 0, 0, 0).
        return 0. }).

    phase:add("circ", {
        if abort return 0.

        phase_unwarp().

        local radius_body is body:radius.

        local max_facing_error is nv:get("circ_max_facing_error", 5, true).
        local good_enough is nv:get("circ_good_enough", 1, true).

        // we do not admit the possibility of circularizing
        // without liquid fuel engines.
        if ship:LiquidFuel <= 0 {   // deal with "no fuel" case.
            io:say("Circularize: no fuel.").
            abort on. return 0. }

        local dv is memo:getter({         // compute desired velocity change.
            local desired_lateral_speed is visviva:v(radius_body+altitude).
            local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
            local desired_velocity is lateral_direction*desired_lateral_speed.
            return desired_velocity - velocity:orbit. }).

        {   // check termination condition.
            local desired_velocity_change is dv():mag.
            if desired_velocity_change <= good_enough {
                return phase:pose(). } }

        ctrl:dv(dv, 1, 1, max_facing_error).

        return 5. }).

    phase:add("ap_pe", {    parameter ap, pe.
        if abort return 0.

        phase_unwarp().

        local radius_body is body:radius.

        local max_facing_error is nv:get("appe_max_facing_error", 5, true).
        local good_enough is nv:get("appe_good_enough", 1, true).

        // we do not admit the possibility of circularizing
        // without liquid fuel engines.
        if ship:LiquidFuel <= 0 {   // deal with "no fuel" case.
            io:say("Phase:AP_PE: no fuel.").
            abort on. return 0. }

        local r_ap is radius_body + min(ap, pe).
        local r_pe is radius_body + max(ap, pe).

        local dv is memo:getter({         // compute desired velocity change.
            local r_now is radius_body+altitude.
            local desired_prograde_speed is visviva:v(r_now, r_ap, r_pe).
            local ref_pe_speed is visviva:v(r_ap, r_ap, r_pe).
            local desired_lateral_speed is ref_pe_speed * r_pe / r_now.
            local desired_radial_speed is safe_sqrt(desired_prograde_speed^2 - desired_lateral_speed^2).
            if (verticalspeed < 0) set desired_radial_speed to -desired_radial_speed.
            local lateral_direction is vxcl(up:vector,velocity:orbit):normalized.
            local radial_direction is -body:position:normalized.
            local desired_velocity is lateral_direction*desired_lateral_speed
                + radial_direction * desired_radial_speed.
            return desired_velocity - velocity:orbit. }).

        {   // check termination condition.
            local desired_velocity_change is dv():mag.
            if desired_velocity_change <= good_enough {
                return phase:pose(). } }

        ctrl:dv(dv, 1, 1, max_facing_error).

        return 5. }).

    local hold_in_pose is false.
    phase:add("hold", {

        local max_facing_error is nv:get("hold_max_facing_error", 5, true).

        local hold_peri is nv:get("hold/periapsis", periapsis).
        local hold_apo is nv:get("hold/apoapsis", apoapsis).

        local dv is memo:getter({

            local radius_body is body:radius.
            local radius_curr is radius_body + altitude.
            local radius_peri is min(radius_curr, radius_body+hold_peri).
            local radius_apo is max(radius_curr, radius_body+hold_apo).
            local radius_curr is radius_body+altitude.

            local speed_req is visviva:v(radius_curr, radius_peri, radius_apo).
            local speed_peri is visviva:v(radius_peri, radius_peri, radius_apo).
            local angular_momentum is radius_peri * speed_peri.
            local lateral_req is angular_momentum/radius_curr.

            local radial_req is safe_sqrt(speed_req*speed_req - lateral_req*lateral_req).

            local signed_radial_req is
                choose radial_req if verticalspeed>=0 else -radial_req.

            local v_rad is -body:position:normalized*radial_req.
            local v_lat is vxcl(v_rad,prograde:vector):normalized*lateral_req.
            local v_cmd is v_rad + v_lat.

            return v_cmd - ship:velocity:orbit. }).

        phase_unwarp().

        // peek at the required throttle ignoring facing errors.
        local peek_throttle is dv():mag*ship:mass/availablethrust.

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
            ctrl:dv(V(0,0,0), 0, 0, 0). }

        else {
            ctrl:dv(dv, 1, 1, 5). }

        return 1. }).

    phase:add("deorbit", {

        local h is round(0.75 * body:atm:height).

        if round(periapsis) <= h {
            print "phase:deorbit complete, periapsis "+round(periapsis)+" <= target height "+round(h).

            ctrl:dv({return srfretrograde:vector:normalized/10000.}, 1, 1, 5).
            return -10. }

        phase_unwarp().

        local radius_body is body:radius.

        local dv is memo:getter({
            local desired_speed is visviva:v(radius_body+altitude, radius_body+h-100, radius_body+apoapsis).
            local current_speed is velocity:orbit:mag.
            local desired_speed_change is max(0, current_speed - desired_speed).
            return 0.10*retrograde:vector*desired_speed_change. }).

        ctrl:dv(dv, 1, 1, 5).

        return 1. }).

    phase:add("aero", {

        if not body:atm:exists return 0.

        local ah is body:atm:height.
        local hi is 0.95*ah.
        local lo is 0.50*ah.

        // if periapsis is deep in the atmosphere, we are done.
        if periapsis<lo
            return phase:pose().

        // when to do nothing:
        // - time warp in progress
        // - time warp not settled.
        if kuniverse:timewarp:warp>1 return 5.
        if not kuniverse:timewarp:issettled return 1/10.

        // if our periapsis is not in the atmosphere,
        // do a retrograde burn to get it down to 95%
        // of the height of the atmosphere. Be careful
        // to avoid overshooting.
        if periapsis > hi {

            local dv is memo:getter({
                if periapsis <= hi return V(0,0,0).
                local radius_body is body:radius.
                local v0 is ship:velocity:orbit.
                local r0 is radius_body + altitude.
                local r1 is radius_body + apoapsis.
                local r2 is radius_body + hi - 5000.
                local v1 is visviva:v(r0, r1, r2) *v0:normalized.
                return v1 - v0. }).

            ctrl:dv(dv, 1, 1, 5).
            return 1/10. }

        // if we are in space (plus some margin), warp until
        // we are about to enter the atmosphere.
        if altitude>ah*2.0 {    // in space: use timewarp.

            if kuniverse:timewarp:mode = "PHYSICS" {
                set kuniverse:timewarp:mode to "RAILS".
                return 1. }

            // assure we are in the idle pose.
            // command it every second until we are
            // sitting close to idle, then drop into
            // the timewarp logic.
            phase:pose(). wait 0.
            if vang(steering:vector, facing:vector)>5
                return 1.

            // figure out when we next enter the atmosphere.

            local tmin is time:seconds.
            local tmax is tmin + eta:periapsis.

            until tmax<tmin+1 {
                local tmid is (tmin+tmax)/2.
                local s_p is predict:pos(tmid, ship).
                local s_r is s_p:mag.
                if s_r > ah set tmin to tmid.
                else set tmax to tmid. }

            warpto(tmin-60).
            return 5+phase:pose(). }

        // we are in, or just above, atmosphere. burn retrograde
        // to help shed our orbital energy. direction is somewhat important
        // and magnitude is how much velocity we would like to shed.
        ctrl:dv(-ship:velocity:surface, 1, 5, 15).
        return 1. }).

    phase:add("lighten", { parameter dropstage is 1.
        if not kuniverse:timewarp:issettled return 1.
        if not stage:ready return 1.
        if stage:number<dropstage return 0.
        if kuniverse:timewarp:rate>1 {
            kuniverse:timewarp:cancelwarp().
            return 1. }

        ctrl:dv(V(0,0,0), 0, 0, 0).

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
        ctrl:dv(srfretrograde:vector, 0, 0, 0).
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
        if throttle>0 { lock throttle to 0. return 1. }
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
        local rcs_list is list().
        list rcs in rcs_list.
        for it in rcs_list
            if not it:flameout
                return false.
        return true. }

    phase:add("force_rcs_on", 0).
    phase:add("force_rcs_off", 0).
    lock steering to facing. // have to set it at least once ...
    phase:add("autorcs", {      // enable RCS when appropriate.
        local f is facing.
        local s is steering.
        if has_no_rcs()                                         return 0.
        else if 0<phase:force_rcs_on                            rcs on.
        else if 0<phase:force_rcs_off                           rcs off.
        else if altitude < body:atm:height                      rcs off.
        else if not s:istype("Direction")                       rcs off.
        else if not f:istype("Direction")                       rcs off.
        else if 0.1<ship:angularvel:mag                         rcs on.
        else if 4<vang(f:forevector, s:forevector)              rcs on.
        else if 4<vang(f:topvector, s:topvector)                rcs on.
        else if 0.01<ship:angularvel:mag                        return 1.
        else if 1<vang(f:forevector, s:forevector)              return 1.
        else if 1<vang(f:topvector, s:topvector)                return 1.
        else                                                    rcs off.
        return 1. }).

    {   // dump some info during boot.
        print " ".
        print "autostager initializing at stage "+stage:number.
        print "  MET: "+(time:seconds - nv:get("T0")).
        print "  altitude: "+altitude.
        print "  s velocity: "+velocity:surface:mag.
        print "  o velocity: "+velocity:orbit:mag.
        print "  delta-v: "+ship:deltav:vacuum. }

    {
        local autostager_callcount is 0.
        local mt is 0.
        local sn is stage:number.
        phase:add("autostager", {   // stage when appropriate.

            set autostager_callcount to autostager_callcount + 1.

            if stage:number<2 {
                print "autostager: done; stage number was "+stage:number.
                return 0. }

            if not stage:ready return 1.
            if alt:radar<100 and availablethrust<=0 return 1.

            local mt_old is mt.
            set mt to ship:maxthrustat(0).

            local sn_old is sn.
            set sn to stage:number.

            // TODO check if some future high tech engines
            // might change their maxthrustat(0) in some
            // situation other than ignition or flameout.

            if sn<>sn_old or (mt>0 and mt>=mt_old)
                return 1.

            // after any boot, do not autostage for the first two
            // calls to the autostager, because I think I have seen
            // some oddball behaviors when rebooting on orbit.
            if (autostager_callcount < 3) {
                print "autostager: would have staged but callcount=" + autostager_callcount.
                dbg:pv("sn", sn).
                dbg:pv("sn_old", sn_old).
                dbg:pv("mt", mt).
                dbg:pv("mt_old", mt_old).
                return 1.
            }

            if mt=0 {
                local engine_list is list().
                list engines in engine_list.
                if engine_list:length<1 {
                    print "autostager: no more engines.".
                    return 0. } }

            print "autostager: staging; stage number was "+stage:number.

            stage.
            return 1. }).
    }

    phase:add("autostager_enginelist", {   // stage when appropriate.

        // PAUSE if STAGE:READY is false.
        // - catches "we are doing an EVA"
        // - needs to be true anyway for us to stage.
        if not stage:ready return 1.

        // PAUSE if we have not yet launched.
        // This will also trigger during the very last moments
        // of a landing if we have no thrust. Not a problem.
        // this condition also will fire if we have not yet
        // terminated the autostager and are within 100 meters
        // of touching down.
        if alt:radar<100 and availablethrust<=0 return 1.

        // END if the engine list is empty.
        // - staging will not jettison anything useful.
        local engine_list is list().
        list engines in engine_list.
        if engine_list:length<1 {
            print "autostager: terminating, no more engines.".
            return 0. }

        // Return without staging if we have an ignited engine
        // that is not yet flamed out.
        local s is stage:number.
        for e in engine_list
            if e:decoupledin=s-1 and e:ignition and not e:flameout
                return 1.

        // NOTE: in one case, we were on Stage 0 of the
        // tourist mission, and were staging every second,
        // despite that stage having no actual engines?

        // Return TERMINATING the autostager if we are on stage zero.
        if s=0 {
            print "autostager special cancel!".
            print "  current stage numer is "+s.
            print "  engines remaining: "+engine_list:length.
            return 0. }

        local dv0 is ship:deltav:vacuum.
        stage. wait 0.
        local dv1 is ship:deltav:vacuum.
        local loss is dv0-dv1.
        print " ".
        print "autostager activating for stage "+stage:number.
        print "  engine count: "+engine_list:length.
        print "  MET: "+dbg:pr(TimeSpan(time:seconds - nv:get("T0"))).
        print "  altitude: "+round(altitude/1000,1)+" km".
        print "  s velocity: "+round(velocity:surface:mag)+" m/s".
        print "  o velocity: "+round(velocity:orbit:mag)+" m/s".
        print "  delta-v: "+round(dv0)+" m/s in vaccum". //  before staging".
        // print "  delta-v: "+round(dv1)+" m/s in vaccum after staging".
        if loss>0 print "  lost "+loss+" m/s during staging.".
        return 1. }).
}
