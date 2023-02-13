{   parameter mission is lex(). // mission sequencing package

    local io is import("io").
    local nv is import("nv").
    local plan is list().

    mission:add("pname", { return nv:get("mission/phase/name", ""). }).
    mission:add("phase", { return max(0,min(plan:length-1,nv:get("mission/phase/number"))). }).

    mission:add("jump", {
        parameter n, v is 0.
        set phase_next to n.
        nv:put("mission/phase/number", phase_next).
        return v. }).

    local printed_phase_name is "".
    local phase_next is 0.

    local sayname is { parameter n.
        if printed_phase_name=n return.
        set printed_phase_name to n.
        nv:put("mission/phase/name", n).
        io:say("PHASE: "+n).
        return 0.
    }.

    mission:add("do", { parameter l.
        if l:istype("Delegate") { plan:add(l). return.}
        if l:istype("String") { mission:do(sayname:bind(l)). return. }
        if l:istype("List") { for e in l mission:do(e). return. }
        io:say("mission:do handling TBD for <"+l:typename+"> "+l).
    }).

    mission:add("fg", {
        abort off.
        sayname(mission:pname()).
        until abort {
            local p is mission:phase().
            set phase_next to p+1.
            local dt is plan[p]().
            if dt<=0 nv:put("mission/phase/number", phase_next).
            wait abs(dt).
        }
    }).

    mission:add("bg", { parameter task.
        local trigger_time is time:seconds.
        when time:seconds>trigger_time then {
            local dt is task().
            if dt<=0 return false.
            set trigger_time to time:seconds + dt.
            return true.
        }
    }).

    mission:do({ return 0. }).
}