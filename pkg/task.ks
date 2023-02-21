{   parameter task is lex(). // tasking package.
    //
    // a list of tasks that can be requested
    // in the GUI, which have:
    // - text, a title for the task
    // - cond, enabling or disabling the task
    // - start, delegate to call when switching to the task
    // - step, delegate to call to run a task step
    // - stop, delegate to call when switching away
    //
    // Intended to be used for tasks like "circularize",
    // "plan maneuver", "run maneuver", and so on.
    //
    // return value from step controls how long we delay
    // before running the next task code.

    task:add("gui", gui(0,0)).
    task:add("panel", task:gui:addvlayout()).
    task:add("list", list()).

    function task_of {
        parameter text, cond, start, step, stop.
        assert(cond:istype("Delegate")).
        assert(start:istype("Delegate")).
        assert(step:istype("Delegate")).
        assert(stop:istype("Delegate")).
        return lexicon("text", text, "cond", cond,
            "start", start, "step", step, "stop", stop).}

    task:add("idle", task_of("Idle", always, nothing,
        { set throttle to 0. lock steering to facing. return 0. }, nothing)).

    task:idle:add("pressed", always).
    task:idle:add("unpress", always).

    task:add("curr", task:idle).

    task:add("new", {
        parameter text, cond, start, step, stop.
        assert(cond:istype("Delegate")).
        assert(start:istype("Delegate")).
        assert(step:istype("Delegate")).
        assert(stop:istype("Delegate")).
        local t is task_of(text, cond, start, step, stop).
        local b is task:panel:addcheckbox(text, false).
        t:add("pressed", { return b:pressed. }).
        t:add("unpress", { set b:pressed to false. }).
        task:list:add(t). }).

    task:add("pick", {
        for t in task:list
            if t:pressed() and t:cond()
                return t.
        return task:idle. }).

    task:add("step", {
        local o is task:curr.
        local t is task:pick().
        if not(t=o) {
            o:stop().
            set task:curr to t.
            print "task: "+t:text.
            t:start().
        }
        local dt is t:step().
        if dt>0 return dt.
        t:unpress().
        return 1. }).

    task:add("show", {
        task:gui:show(). }).
}
