{   parameter sch is lex(). // sch: task scheuler

    sch:add("schedule", schedule@).
    sch:add("execute", execute@).

    // Call tasks when scheduled.

    // The task list starts with a sentinel task that is set up to
    // run so far in the future that it should never run, but more
    // importantly, so far in the future that all actual tasks will
    // be sorted before it.

    local task_list is list(list(2^64, { return 0. })).

    local function schedule { parameter ut, task.   // ad task to schedule.

        // Request that, at or after the given time, we call the task.
        // Current implementation uses list insertion, which is often
        // optimal when the number of items in the list is short.
        //
        // The "task list is empty" and "the new task goes after all
        // tasks on the list" cases can be ignored, as we always have
        // a sentinel task that is after the candidate.
        //
        // Operation is undefined if a call is made to schedule a task
        // at or after the same time as the sentinel.
        //
        // If we start building missions where the task list ends up
        // with a large number of tasks, the functions within this package
        // can be modified to change from a list to something with
        // better scaling (like a heap stored in a list).

        local i is 0.
        until task_list[i][0] > ut
            set i to i + 1.
        task_list:insert(i, list(ut, task)). }

    local function execute {        // execute all scheduled tasks (except the sentinel)

        // Execute tasks from the list at their designated times.
        //
        // This function returns when there is only one entry
        // remaining (the sentinel).
        //
        // First, we wait until it is time to run the next task.
        // Then we remove the task from the list and run it.
        // If the task returns a positive value, it is placed
        // back on the list, scheduled to run that many seconds
        // in the future.
        //
        // note that since time can pass while the task runs, the
        // value returned is the duration of the gap between when
        // one call ends and the next starts, not the period for
        // tasks that want to run at a given rate.
        //
        // Support for periodic tasks (needs to run 60 times per
        // minute, for example) is a feature that can be added if
        // it is needed, but YAGNIY.

        until task_list:length<2 {
            wait until time:seconds >= task_list[0][0].
            local task is task_list[0][1].
            task_list:remove(0).
            local dt is task().
            if dt>0 sch:schedule(time:seconds + dt, task). } }

}