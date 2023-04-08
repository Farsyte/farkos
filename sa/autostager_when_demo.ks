@LAZYGLOBAL off.

// this code can be demonstrated via boot/sa.ks
// by setting the vessel name to demo/autostager_when.

// Demo the WHEN-trigger-based autostager.
runpath("0:sa/autostager_when").
// global function time_svc { parameter svc. ... return lex(). }
// global function start_stager { ... return lex(). }

wait until ship:unpacked.

print "launching in 10 seconds.".

local h0 is alt:radar.

lock throttle to 1.

lock cmd_p to 0.
lock cmd_f to heading(90, 90-cmd_p,0).
lock steering to cmd_f.

local t0 is time:seconds + 10.
lock met to round(time:seconds - t0, 2).
wait until met >= 0.
set t0 to time:seconds.

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
//
// These suffixes are common to all "tasks" that are created
// using the "task_svc" facility. Normally I would pull this
// out as an example task scheduler, but my general direction
// is away from using WHEN..THEN clauses.

// If we do not pause or cancel, we stage:
// MET 0: staging releases clamps and ignites engines
// MET 15: staging discards first pair
// MET 36: staging discards second pair
// MET 72: staging discards third pair
// MET 130: staging discards asparagus core
// MET 360: (approximate) staging discards upper core
//
// The auto-stager as written presumes that Stage Zero
// contains parachutes and avoids arming them. This has
// the consequence that, if we are launching a satellite
// where stage zero has the engines to place us into our
// final assigned orbit, the "maybe_stage" method would
// need to be adjusted to allow it to stage from 1 to 0.

// This example code uses "pause" to delay staging of the
// second pair, and "cancel" to delay discarding the core.

wait until met >= 1.
print "met "+met+": initial pitch-over.".
lock cmd_p to 30.   // this is a REALLY SHARP PITCHOVER. For demo puroses only.

wait until met >= 15.
lock cmd_p to vang(up:vector, srfprograde:vector).
print "met "+met+": switch steering to surface prograde.".

wait until met >= 30. // a few seconds before the second time we stage
print "met "+met+": pausing the staging task.".
staging_task:pause().

wait until met >= 40. // a few seconds after we should have staged
print "met "+met+": resuming the staging task.".
staging_task:resume().

wait until met >= 90. // when high enough that we can handle the side-winds
print "met "+met+": switch steering to orbital prograde.".
lock cmd_p to vang(up:vector, prograde:vector).

wait until met >= 120. // a few seconds before we stage for the 3rd time
print "met "+met+": cancel the staging task.".
staging_task:cancel().

// just for fun: turn the stager back on when we get to AP,
// which will drop our spent ascent stage and ignite the space engine.

wait until altitude > 80000.
if kuniverse:timewarp:mode = "PHYSICS" {
    set kuniverse:timewarp:mode to "RAILS".
    wait 1.
}

local stop_at is time:seconds + eta:apoapsis.
warpto(stop_at).
wait until time:seconds >= stop_at.
print "met "+met+": new staging task.".
local staging_task2 is start_stager().

wait until apoapsis > 60000000.
lock throttle to 0.
print "met "+met+": apoapsis " + apoapsis.

set stop_at to time:seconds + eta:apoapsis.
warpto(stop_at).
wait until time:seconds >= stop_at.
lock throttle to 1.

wait until false.
