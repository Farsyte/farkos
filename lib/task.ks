// tasking package:
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

local task_gui is gui(0,0).
local task_panel is task_gui:addvlayout().
local task_list is list().

function new_task {
    parameter text, cond, start, step, stop.
    return lexicon("text", text, "cond", cond,
        "start", start, "step", step, "stop", stop).
}

local idle_task is new_task("Idle", { return true. }, { }, { return phase_pose(). }, { }).
idle_task:add("pressed", { return true. }).
idle_task:add("unpress", { }).

local curr_task is idle_task.

function add_task {
    parameter text, cond, start, step, stop.
    local t is new_task(text, cond, start, step, stop).
    local b is task_panel:addcheckbox(text, false).
    t:add("pressed", { return b:pressed. }).
    t:add("unpress", { set b:pressed to false. }).
    task_list:add(t).
}

function task_pick {
    for t in task_list
        if t:pressed() and t:cond()
            return t.
    return idle_task.
}

function task_step {
    local t is task_pick.
    if not(t=curr_task) {
        curr_task:stop().
        set curr_task to t.
        print "task: "+curr_task:text.
        curr_task:start().
    }
    local dt is curr_task:step().
    if dt>0 return dt.
    curr_task:unpress().
    return 1.
}

function task_gui_show {
    task_gui:show().
}
