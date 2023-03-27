@LAZYGLOBAL off.

// Demo the WHEN-trigger-based autostager.
runpath("0:sa/autostager_when").
// global function time_svc { parameter svc. ... return lex(). }
// global function start_stager { ... return lex(). }

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
