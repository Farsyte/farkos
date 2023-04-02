@LAZYGLOBAL off.
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

    function task_of {                          // create a "task" from these elements
        parameter text, cond, start, step, stop.
        assert(cond:istype("Delegate")).
        assert(start:istype("Delegate")).
        assert(step:istype("Delegate")).
        assert(stop:istype("Delegate")).
        return lexicon("text", text, "cond", cond,
            "start", start, "step", step, "stop", stop).}

    task:add("text", { parameter text.
        task:panel:addlabel(text).
    }).

    task:add("idle", task_of("Idle",            // the IDLE task, executes if nothing else does.
        always, nothing, { lock throttle to 0. lock steering to facing. return 0. }, nothing)).

    task:idle:add("pressed", always).           // backpatch "pressed" in idle to "always pressed"
    task:idle:add("unpress", always).           // backpatch "unpress" in idle to "do nothing?

    task:add("curr", task:idle).                // make the idle task current

    task:add("new", {                           // create a new task for a mission
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

    task:add("pick", {                          // pick a task to run
        for t in task:list
            if t:pressed() and t:cond()
                return t.
        return task:idle. }).

    task:add("step", {                          // run some task for one step
        local o is task:curr.
        local t is task:pick().
        if not(t=o) {
            o:stop().                           // changing tasks, stop the old one.
            set task:curr to t.
            print "task: "+t:text.
            t:start().                          // changing tasks, start the new one.
        }
        local dt is t:step().                   // run a step
        if dt>0 return dt.                      // positive return: want to do it again in a bit
        t:unpress().                            // zero or negative: unpress the button, stop this task.
        return 1. }).

    task:add("show", {                          // show the TASK GUI
        parameter x is 100.
        parameter y is 100.
        set task:gui:x to x.
        set task:gui:y to y.
        task:gui:show(). }).
}
