loadfile("persist").

global mission_plan is list().
global mission_terminated is false.

// MISSION_PHASE: return the currently valid mission phase,
// clipped to be a valid index into the non-empty mission_plan
// list (operation undefined if mission_plan is empty).

function mission_phase {
    return clamp(0, mission_plan:length-1, persist_get("mission_phase")).
}

// MISSION_JUMP: set the mission phase to a specific phase number.
function mission_jump { parameter to_phase.
    persist_put("mission_phase", to_phase).
}

// MISSION_INC: moves the mission phase to the next phase.

function mission_inc {
    mission_jump(1 + mission_phase()).
}

// MISSION_ADD: Add a phase (or a list of phases) to the mission plan.
//
// The phase is a delegate for a function that performs computations
// for that phase of flight, and returns (promptly!) how long to wait
// before the next time a mission phase runs.

function mission_add { parameter phase_obj.
    if phase_obj:istype("List")
        for a in phase_obj mission_add(a).
    else if phase_obj:istype("Delegate") or phase_obj:istype("String")
        mission_plan:add(phase_obj).
    else
        say("Bad Phase Data Type: "+phase_obj:typename+" "+phase_obj).
}

function mission_report_phase { parameter phase_obj, force is false.
    if NOT phase_obj:istype("String") return.
    if phase_obj="" return.
    if phase_obj=persist_get("mission_pname", "") and not force return.
    say("Phase: "+phase_obj).
    persist_put("mission_pname", phase_obj).
}

// MISSION_FG: run the mission plan as a FOREGROUND task.
//
// This method runs mission phases, delaying between them
// by the value returned. If the value is not positive,
// the mission phase is advanced on the next cycle, and the
// delay time is the absolute value.
//
// MISSION_TERMINATED are checked at the top of each loop. If
// it is set, processing stops.
//
// ABORT is monitored. If it is set, delays until the next
// mission phase method is called are eliminated.

function mission_fg {
    mission_report_phase(persist_get("mission_pname", ""), true).
    until mission_terminated {
        local phase_no is mission_phase().
        local phase_obj is mission_plan[phase_no].
        local dt is 0.
        if phase_obj:istype("Delegate")
            set dt to phase_obj().
        else if phase_obj:istype("String")
            mission_report_phase(phase_obj).
        else say("BAD PHASE: "+phase_obj:typename+" "+phase_obj).
        if dt<=0 mission_inc().
        set next_t to time:seconds + abs(dt).
        wait until abort or mission_terminated or time:seconds>next_t.
    }
}

// MISSION_BG: Start a background task running.
//
// The provided function is called repeatedly; its return
// value is the delay until the next call. The loop terminates
// if the retuned value is negative.

function mission_bg { parameter task_fn.
    local next_t is time:seconds.
    when mission_terminated or time:seconds>next_t then {
        if mission_terminated return false.
        local dt is task_fn().
        set next_t to time:seconds + abs(dt).
        return dt > 0.
    }
}
