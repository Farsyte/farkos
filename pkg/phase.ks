{
    parameter phase is lex(). // stock mission phase library.
    local nv is import("nv").
    local io is import("io").
    local radar is import("radar").

    // countdown phase needs a local,
    // which resets when we boot.
    local countdown is 10.

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
        return 1/10. }).

    phase:add("ascent", {       // follow ascent program
        if abort return 0.

        local orbit_altitude is nv:get("launch_altitude", 80000, true).
        local launch_azimuth is nv:get("launch_azimuth", 90, true).
        local launch_pitchover is nv:get("launch_pitchover", 2, false).

        // if we are completely out of fuel, give up.
        if availablethrust=0 {
            local _all_done is {  // "all engines are flamed out"
                list engines in el.
                for e in el
                    if not e:flameout
                        return false.
                return true. }.
            if _all_done() return 0. }

        // termination condition: apoapsis stable at or above target.

        if apoapsis>=orbit_altitude and altitude>body:atm:height {
            set throttle to 0.
            lock steering to prograde.
          return 0. }

        // simple throttle program:
        // full throttle until apoapsis is high enough,
        // then zero throttle when it is higher.

        set _throttle to {
            return max(0,min(1,(orbit_altitude+10-apoapsis)/1000)). }.
        lock throttle to _throttle().

        // simple pitch program:
        //
        // pitch over smoothly from nearly vertical at the ground
        // to horizontal 2km above the atmosphere, where the pitchover
        // goes as the square root of the fraction of the altitude.
        //
        // This does not run:
        //    lock steering to ({... return x. })().
        // It results in this error:
        //    Undefined Variable Name ''.

        set _steering to {
            local alt_thresh is 2000+body:atm:height.
            local alt_frac is max(0,min(1,altitude/alt_thresh)).
            local alt_frac_sqrt is sqrt(alt_frac).
            local pitch_cmd is (90-launch_pitchover)*(1-alt_frac_sqrt).
            return heading(launch_azimuth,pitch_cmd,0). }.
        lock steering to _steering().

        return 1. }).

    phase:add("coast", {        // coast to apoapsis
        if abort return 0.
        if verticalspeed<0 return 0.
        if eta:apoapsis<30 return 0.
        lock throttle to 0.
        lock steering to prograde.
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

        unlock steering.
        unlock throttle.
        return 1. }).

    phase:add("park", {         // control while parked
        unlock steering.
        unlock throttle.
        return 10. }).

    phase:add("autostager", {   // stage when appropriate.
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
        return 1. }). }