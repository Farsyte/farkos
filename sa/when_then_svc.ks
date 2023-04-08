@LAZYGLOBAL off.

// when_then_svc(svc): timed calls to svc() using WHEN..THEN.
//
// This code is DEPRECATED. It uses "WHEN..THEN" to trigger execution,
// which imposes a load at the front of every phys tick; it is better
// to move to a mechanism that manages scheudling in the foreground.
//
// If you want to use this, please review the k-OS documentation
// relating to WHEN and triggers:
//
// https://ksp-kos.github.io/KOS/general/cpu_hardware.html#interrupt-priority
//
// The value returned by svc() indicates how long it wants us to wait
// before calling it again; a zero (or negative) value indicates no
// further calls are wanted.
//
// The when_then_svc function returns a lexicon with these methods:
//
//   :pause     suspend calls to svc
//   :resume    resume calls to svc
//   :cancel    stop calling svc
//
// The :pause method remembers the scheduled time of the next call to
// svc. The :resume method will schedule the next call at this
// remembered time, if it is still in the future, or immediately if
// the remembered time passed with the service paused.

// KNOWN ISSUES IN THIS APPROACH:
// ** It uses a WHEN..THEN construct, imposing inherent load
//    at the top of every physics tick.

global function when_then_svc { parameter svc.

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

    local function cancel  {     // cancel when_then_svc calls to svc.
        // cancel works whether paused or not.
        set trigger_time to -1.
    }

    return lex(
        "pause", pause@,
        "resume", resume@,
        "cancel", cancel@ ).
}
