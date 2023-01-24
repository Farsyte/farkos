loadfile("persist").

global mission_plan is list().
global mission_abort is false.

// MISSION_PHASE: return the currently valid mission phase,
// clipped to be a valid index into the non-empty mission_plan
// list (operation undefined if mission_plan is empty).

function mission_phase {
    return clamp(0, mission_plan:length-1, persist_get("mission_phase")).
}

// MISSION_INC: moves the mission phase to the next phase.

function mission_inc {
    persist_put("mission_phase", 1 + mission_phase()).
}

// MISSION_ADD: Add a phase (or a list of phases) to the mission plan.
//
// The phase is a delegate for a function that performs computations
// for that phase of flight, and returns (promptly!) how long to wait
// before the next time a mission phase runs.

function mission_add { parameter arg.
    if arg:istype("List")
        for a in arg mission_add(a).
    else mission_plan:add(arg).
}

// MISSION_FG: run the mission plan as a FOREGROUND task.
//
// This method runs mission phases, delaying between them
// by the value returned. If the value is not positive,
// the mission phase is advanced on the next cycle, and the
// delay time is the absolute value.
//
// MISSION_ABORT is checked at the top of each loop.

function mission_fg {

    until mission_abort {
        local phase_no is mission_phase().
        local phase_fn is mission_plan[phase_no].
        local dt is phase_fn().
        if dt<=0 mission_inc().
        set next_t to time:seconds + abs(dt).
        wait until mission_abort or time:seconds>next_t.
    }
}

// MISSION_BG: Start a background task running.
//
// The provided function is called repeatedly; its return
// value is the delay until the next call. The loop terminates
// if the retuned value is negative.

function mission_bg { parameter task_fn.
    local next_t is time:seconds.
    when mission_abort or time:seconds>next_t then {
        if mission_abort return false.
        local dt is task_fn().
        set next_t to time:seconds + abs(dt).
        return dt > 0.
    }
}
