{   parameter sch is lex(). // sch: task scheuler

    sch:add("schedule", schedule@).
    sch:add("execute", execute@).

    // Call tasks when scheduled.

    local task_list is list(list(2^64, { return 0. })).

    local function schedule { parameter ut, task.
        local i is 0.
        until task_list[i][0] > ut
            set i to i + 1.
        task_list:insert(i, list(ut, task)). }

    local function execute {
        until task_list:length<2 {
            wait until time:seconds >= task_list[0][0].
            local task is task_list[0][1].
            task_list:remove(0).
            local dt is task().
            if dt>0 sch:schedule(time:seconds + dt, task). } }

}