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

local task_gui is gui(500).
local task_panel is task_gui:addvlayout().
local task_list is list().
local task_gui_showing is false.

function new_task {
    parameter text, cond, start, step, stop.
    return lexicon("text", text, "cond", cond,
        "start", start, "step", step, "stop", stop).
}

global ret_v is { parameter v. return v. }.
global ret_t is ret_v:bind(true).
global ret_0 is ret_v:bind(0).
global ret_1 is ret_v:bind(1).
global noop is { }.

local idle_task is new_task("Idle", ret_t, noop, phase_pose@, noop).
idle_task:add("pressed", ret_t).
idle_task:add("unpress", noop).

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
    for t in task_list {
        if t:pressed() {
            if t:cond() return t.
            t:unpress().
        }
    }
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
