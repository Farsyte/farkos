@LAZYGLOBAL off.
{   parameter mission is lex(). // mission sequencing package

    // This package provides for execution of a main sequence,
    // where generally we proceed from each step to the next,
    // with steps being able to request a repeat after a delay,
    // and with explicit action, even loop back to earlier steps.

    local io is import("io").
    local nv is import("nv").

    local printed_phase_name is "".
    local phase_next is 0.

    // This is the list of steps in the mission plan.
    // Additional steps can be appended, but that is the only alteration
    // allowed to the plan. This allows us to use an integer to indicate
    // which step we are on, such that a given value always goes back
    // to the same step.
    //
    // We do have the possibility that the mission plan will be built
    // differently after a reboot, and if the flight engineer sets that
    // up, then handling the old index saved to nonvolatile memory is
    // their responsibility.

    local plan is list(                         // main mission plan
        { return 0. }).                         // never empty, start with a "do nothing" entry.

    // Eliminate the "list is empty" special case by always starting
    // with a single "do nothing, move along to next step" entry.

    mission:add("do", { parameter l.            // append entry (or entries) to mission plan

        // This is the entry point that adds steps to the mission sequence. Generally
        // each step is a function delegate that returns a duration in seconds. If the
        // argument is a string, it is automatically wrapped in a "sayname" call to
        // make it a label. if it is a List, then it calls itself with each element of
        // the list, allowing construction of missions from lists of submissions.
        //
        // Anything other than a Delegate, String, or List is an error and is reported.

        if l:istype("Delegate") { plan:add(l). return.}
        if l:istype("String") { mission:do(sayname:bind(l)). return. }
        if l:istype("List") { for e in l mission:do(e). return. }

        io:say("mission:do handling TBD for <"+l:typename+"> "+l). }).

    mission:add("fg", {                         // execute mission plan

        // This is the entry point for actually executing the mission plan. This
        // function loops forever. On reboot, the most recent phase name will be
        // repeated to the HUD and console, and execution will resume at the
        // most recently stored step number.

        abort off.
        sayname(mission:pname()).
        until false {
            local p is mission:phase().
            set phase_next to p+1.
            local dt is plan[p]().
            if dt<=0 nv:put("mission/phase/number", phase_next).
            wait abs(dt). } }).

    mission:add("bg", { parameter task.         // start task running in background

        // This entry point initiates "WHEN..THEN" based execution of a provided
        // task, where the task can say "run me again in N seconds" or not.
        //
        // NOTE: this adds a constant load at the start of every physical tick for
        // evaluation of the time:seconds>trigger_time comparison, and when triggered
        // the task will run at elevated priority. When writing these tasks be aware
        // of all the risks documented in the k-OS code for "WHEN-THEN" triggered code.
        //
        // This mechanism needs to be replaced by a better foreground-based scheduler,
        // which runs the task at base priority.

        local trigger_time is time:seconds.
        when time:seconds>trigger_time then {
            local dt is task().
            if dt<=0 return false.
            set trigger_time to time:seconds + dt.
            return true. } }).

    mission:add("pname", {                      // return most recent mission phase label

        // Mission plans can include strings, which get turned into
        // a step function that just stashes the name, so these names
        // really provide names to multiple steps. This method will
        // retrieve the most recently set string. See "mission:do" for
        // how this is set up.

        return nv:get("mission/phase/name", ""). }).

    mission:add("phase", {                      // return current mission phase number

        // Get the current phase number, but clamp it to be a valid index
        // into the current mission list.
        //
        // Operation would be undefined for empty plan lists, except that we note
        // at the top that the plan list is never empty. Code that modifies the
        // plan list in any way other than to append an entry is a bug.

        return max(0,min(plan:length-1,nv:get("mission/phase/number"))). }).

    mission:add("jump", {                       // set next mission phase number
        parameter n, val is 0.

        // mission:jump(n,val) indicates that the mission runner should execute
        // phase number "n" next. If the optional "val" parameter is provided,
        // it is what this method returns, allowing code to say things like
        //     return mission:jump(nv:get("rewind-step"), 1.0)
        // TODO fix that we cancel the jump if the step returns a dt <= 0.0

        set phase_next to n.
        nv:put("mission/phase/number", phase_next).
        return val. }).

    local sayname is { parameter n.             // display and store label, if it changed.

        // this is the function that will be used in the mission plan
        // when the mission merely presents a string: it will store the
        // string in nonvolatile memory, and display it on the HUD, and
        // print it to the console.

        if printed_phase_name=n return.
        set printed_phase_name to n.
        nv:put("mission/phase/name", n).
        io:say("PHASE: "+n).
        return 0. }.
}
