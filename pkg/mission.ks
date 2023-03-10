@LAZYGLOBAL off.
{   parameter mission is lex(). // mission sequencing package

    local io is import("io").
    local nv is import("nv").

    local printed_phase_name is "".
    local phase_next is 0.

    local plan is list(                         // main mission plan
        { return 0. }).                         // never empty, start with a "do nothing" entry.

    // Eliminate the "list is empty" special case by always starting
    // with a single "do nothing, move along to next step" entry.

    mission:add("pname", {                      // return most recent mission phase label
        return nv:get("mission/phase/name", ""). }).

    mission:add("phase", {                      // return current mission phase number
        return max(0,min(plan:length-1,nv:get("mission/phase/number"))). }).

    mission:add("jump", {                       // set next mission phase number
        parameter n, val is 0.
        set phase_next to n.
        nv:put("mission/phase/number", phase_next).
        return val. }).

    local sayname is { parameter n.             // display and store label, if it changed.
        if printed_phase_name=n return.
        set printed_phase_name to n.
        nv:put("mission/phase/name", n).
        io:say("PHASE: "+n).
        return 0. }.

    mission:add("do", { parameter l.            // append entry (or entries) to mission plan
        if l:istype("Delegate") { plan:add(l). return.}
        if l:istype("String") { mission:do(sayname:bind(l)). return. }
        if l:istype("List") { for e in l mission:do(e). return. }
        io:say("mission:do handling TBD for <"+l:typename+"> "+l). }).

    mission:add("fg", {                         // execute mission plan
        abort off.
        sayname(mission:pname()).
        until false {
            local p is mission:phase().
            set phase_next to p+1.
            local dt is plan[p]().
            if dt<=0 nv:put("mission/phase/number", phase_next).
            wait abs(dt). } }).

    mission:add("bg", { parameter task.         // start task running in background
        local trigger_time is time:seconds.
        when time:seconds>trigger_time then {
            local dt is task().
            if dt<=0 return false.
            set trigger_time to time:seconds + dt.
            return true. } }).
}
