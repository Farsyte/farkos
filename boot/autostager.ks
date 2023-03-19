@LAZYGLOBAL off.

// bg(task): run a task periodically in the background.
// this code uses a k-OS "WHEN <cond> THEN { <task> }"
// construct to run the task while your main script is
// off doing whatever it is doing. If the task returns
// a positive value, the WHEN is persisted and the task
// is run again that many seconds later; if the task
// returns zero (or negative), then the WHEN is not
// persisted and the task goes away.

global function bg { parameter task.
    local trigger_time is time:seconds.
    when trigger_time <= time:seconds then {
        local dt is task().
        if dt<=0 return false.
        set trigger_time to time:seconds + dt.
        return true.
    }
}

// maybe_stage: automatically trigger staging
// this function can be run as a background task.
//
// It will trigger staging when all ignnited engines that
// would be discarded by staging have run out of fuel. This
// has been tested in Asparagus configurations where engines
// exist that are ignited and have fuel, which are not
// jettisoned by this staging. It has also been tested with
// boosters that have separatrons attached to the same stage
// as the decoupler.
//
// The task terminates when we reach stage zero,
// or when there are no engines remaining. This assures that
// the autostager does not deploy my parachutes, which sit in
// stage zero, even when stage zero also has an engine that
// has flamed out.

local function maybe_stage {
    local s is stage:number.
    if s=0 return 0.
    local engine_list is list().
    list engines in engine_list.
    if engine_list:length<1 return 0.
    for e in engine_list
        if e:ignition and not e:flameout and e:decoupledin=s-1
            return 1.
    if stage:ready stage.
    return 1.
}

// Set up some trivial steering and throttle
// to demonstrate the stager.
unlock steering.
sas on. rcs on.
lock throttle to 1.

// NOTE: if we have not launched yet,
// turning on the stager WILL launch.
bg(maybe_stage@).

// Having done the above, your mission script
// can go on about its business, secure in the
// faith that Stages will be Staged.

wait until false.
