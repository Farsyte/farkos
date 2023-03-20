@LAZYGLOBAL off.

// time_svc(svc): timed calls to svc().
//
// time_svc uses a "WHEN THEN" construct to trigger a call to svc().
// This facility will preempt your normal scripting and any GUI
// callbacks. While the service is running, no other WHEN or ON
// triggers or GUI callbacks from starting.
//
// Please review the k-OS documentation relating to WHEN
// and triggers before doing anything nontrivial in svc:
//
// https://ksp-kos.github.io/KOS/general/cpu_hardware.html#interrupt-priority
//
// The value returned by svc() indicates how long it wants us to wait
// before calling it again; a zero (or negative) value indicates no
// further calls are wanted.
//
// The time_svc function returns a lexicon with these methods:
//
//   :pause     suspend calls to svc
//   :resume    resume calls to svc
//   :cancel    stop calling svc
//
// The :pause method remembers the scheduled time of the next call to
// svc. The :resume method will schedule the next call at this
// remembered time, if it is still in the future, or immediately if
// the remembered time passed with the service paused.

global function time_svc { parameter svc.

    local trigger_time is time:seconds.
    local paused_time is 0.

    when trigger_time <= time:seconds then {
        if trigger_time<0 return false.         // cancel
        local dt is svc().
        if dt<0 return false.                   // complete
        set trigger_time to time:seconds + dt.
        return true.
    }

    local function pause {      // temporarily suspend calls to svc.
        // do nothing if cancelled or paused
        if paused_time>0 or trigger_time<0 return.
        set paused_time to trigger_time.
        set trigger_time to 2^64.
    }

    local function resume {     // resume suspended calls to svc.
        // do nothing if cancelled or not paused.
        if paused_time=0 or trigger_time<0 return.
        set trigger_time to max(paused_time, time:seconds).
        set paused_time to 0.
    }

    local function cancel  {     // cancel time_svc calls to svc.
        // cancel works whether paused or not.
        set trigger_time to -1.
    }

    return lex(
        "pause", pause@,
        "resume", resume@,
        "cancel", cancel@ ).
}

// start_stager: automatically trigger staging
//
// This function starts a lightly stateful automatic stager
// that uses the time_svc() facility.
//
// NOTE: THE INNER METHOD IS EXECUTED INSIDE A "WHEN" TRIGGER.
// KEEP IT AS LEAN AS POSSIBLE, AND ESPECIALLY,
// DO NOT ADD ANY "WAIT" STATEMENTS IN THE INNER METHOD.
//
// Please review the k-OS documentation relating to WHEN
// and triggers before making any nontrivial changes to maybe_stage:
//
// https://ksp-kos.github.io/KOS/general/cpu_hardware.html#interrupt-priority
//
// This version of the automatic stager triggers staging when the
// maximum thrust of the vessel is zero (we want to stage to ignite
// an engine) or decreases (one or more engines have flamed out and
// should be jettisoned).
//
// The task terminates when we reach stage zero. Just saw this deploy
// parachutes in stage zero, so need to test this termination condition
// both with stage zero having chutes, and a satellite where the last
// engine ignites in stage zero.
//
// The start_stager() function returns the task lexicon provided
// by the time_svc, allowing the caller to pause, resume, or cancel
// the staging service.

function start_stager {
    local mt is 0.
    local sn is stage:number.
    local function maybe_stage {
        if stage:number<2 return 0.
        if not stage:ready return 1.

        // save the old maxthrust, and observe the
        // new maxthrust sample.
        local mt_old is mt.
        set mt to ship:maxthrustat(0).

        // If the stage number changed, then
        // do not even think about staging this time.
        //
        // NOTE: SOMEONE ELSE MIGHT STAGE! This not only handles
        // avoiding comparing thrust before staging with thrust
        // after, but does so even if it is because the flight
        // engineer (or his cat) touched the stage bar.
        local sn_old is sn.
        set sn to stage:number.
        if sn<>sn_old {
            print "maybe_stage: sn from "+sn_old+" to "+sn.
            return 1. }

        // If we have no thrust, then we need to stage to
        // get the next engine ignited. It is possible that
        // we have no more engines, so check that; if we are
        // out of engines, then terminate the autostager;
        // otherwise, stage.
        if mt=0 {
            local loe is list().
            list engines in loe.
            if loe.:length<1 {
                print "maybe_stage: no more engines.".
                return 0.
            }
            stage.
            return 1.
        }

        // If our max thrust decreased, we presume it is due to
        // one or more engines flaming out. Stage to jettison the
        // now dead weight of the engine and the empty fuel tanks
        // from which it was drawing.
        if mt<mt_old {
            print "maybe_stage: mt from "+mt_old+" to "+mt+", stage is "+stage:number+", staging.".
            stage.
            return 1
        }

        // we still have thrust, and it did not decrease.
        // we do not need to stage yet.
        return 1.
    }
    return time_svc(maybe_stage@).
}

wait until ship:unpacked.

print "launching in 10 seconds.".
print "please throttle up.".
wait 10.

local t0 is time:seconds.
lock met to time:seconds - t0.

local h0 is alt:radar.
lock alt_cal to alt:radar - h0.

// Set up some trivial steering and throttle
// to demonstrate the stager.
unlock steering.
sas on. rcs off.
unlock throttle.

// NOTE: if we have not launched yet,
// turning on the stager WILL stage
// to ignite the first set of engines,
// because it sees maxthrust=0.

local staging_task is start_stager().

// Having done the above, your mission script
// can go on about its business, secure in the
// faith that Stages will be Staged.
//
// call staging_task:pause() to suspend the auto-stager.
// call staging_task:resume() to resume the auto-stager.
// call staging_task:cancel() to cancel the auto-stager.

wait until met >= 20.
print "met "+met+": pausing the staging task.".
staging_task:pause().

wait until met >= 30.
print "met "+met+": resuming the staging task.".
staging_task:resume().

wait until met >= 55.
print "met "+met+": cancel the staging task.".
staging_task:cancel().

wait until met >= 60.
print "met "+met+": new staging task.".
local staging_task2 is start_stager().

wait until false.
