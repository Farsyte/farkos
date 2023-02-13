{
    parameter phase is lex(). // stock mission phase library.
    local nv is import("nv").
    local io is import("io").
    local radar is import("radar").

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
        return 1.
    }).

    local countdown is 10.
    phase:add("countdown", {    // countdown, ignite, wait for thrust.
        if availablethrust>0 return 0.
        lock throttle to 1.
        lock steering to facing.
        if countdown > 0 {
            io:say("T-"+countdown, false).
            set countdown to countdown - 1.
            return 1.
        }
        radar:cal(). // trigger auto-calibration if needed.
        if stage:ready stage.
        return 1.
    }).

    phase:add("launch", {       // stabilize until clear of pad
        if alt:radar>50 return 0.
        lock steering to facing.
        lock throttle to 1.
        return 1/10.
    }).

    phase:add("psafe", {
        // this is a decent rule of thumb for most parachutes
        // descending into Kerbin's atmosphere ...
        if verticalspeed > 0 return 1.
        if altitude < 5000 and airspeed < 300 return 0.
        lock steering to srfretrograde.
        lock throttle to 0.
        return 1/10.
    }).

    phase:add("chute", {
        if stage:number<1 return 0.

        if stage:ready stage.
        unlock steering.
        unlock throttle.
        return 1.
    }).

    phase:add("land", {
        if verticalspeed>=0 return 0.

        unlock steering.
        unlock throttle.
        return 1.
    }).

    phase:add("park", {
        unlock steering.
        unlock throttle.
        return 10.
    }).
}