@LAZYGLOBAL OFF.

// this code can be demonstrated via boot/sa.ks
// by setting the vessel name to demo/sequencer.

// sequencer_demo does what autostager_when_demo does,
// but uses the mission sequencer to do it.

runpath("0:sa/sequencer").
// global function sequencer_pname { ... }
// global function sequencer_phase { ... }
// global function sequencer_jump { parameter n, val is 0. ... }
// global function sequencer_do { parameter l. ... }
// global function sequencer_go { ... }

// First cut: use the WHEN based autostager.

runpath("0:sa/autostager_when").
// global function start_stager { ... return lex(). }

wait until ship:unpacked.

// This script isn't really rebootable, it would need
// to push retained state via NONVOLATILE.

local h0 is alt:radar.
local t0 is time:seconds + 10.

lock throttle to 1.

lock cmd_p to 0.
lock cmd_f to heading(90, 90-cmd_p,0).
lock steering to cmd_f.

lock met to time:seconds - t0.
lock metsec to round(met).

local staging_task is lex().

// Repackage the mission scripting into a series of tiny tasks
// that run promptly to completion, and their return value indicates
// whether to move on to the next task, or to call the current
// task again after a specified delay.
//
// This particular mechanism lends itself to having a library of
// mission sequencer tasks available to do stock things that many
// missions will share.

sequencer_do(list(

    {   print "met "+metsec+": prelaunch.".
        return min(1, max(0, -met)). },

    {   print "met "+metsec+": liftoff.".
        set t0 to time:seconds. nv_put("t0", t0).
        set staging_task to start_stager().
        return 0. },

    {   if met < 1 return 1.
        print "met "+metsec+": initial pitch-over.".
        lock cmd_p to 30.   // this is a REALLY SHARP PITCHOVER. For demo puroses only.
        return 0. },

    {   if met < 15 return 1.
        lock cmd_p to vang(up:vector, srfprograde:vector).
        print "met "+metsec+": switch steering to surface prograde.".
        return 0. },

    {   if met < 30 return 1.
        print "met "+metsec+": pausing the staging task.".
        staging_task:pause().
        return 0. },

    {   if met < 40 return 1.
        print "met "+metsec+": resuming the staging task.".
        staging_task:resume().
        return 0. },

    {   if met < 90 return 1.
        print "met "+metsec+": switch steering to orbital prograde.".
        lock cmd_p to vang(up:vector, prograde:vector).
        return 0. },

    {   if met < 120 return 1.
        print "met "+metsec+": cancel the staging task.".
        staging_task:cancel().
        return 0. },

    {   if altitude < 80000 return 1.
        if kuniverse:timewarp:mode = "PHYSICS" {
            set kuniverse:timewarp:mode to "RAILS".
            return 1.
        }
        warpto(time:seconds + eta:apoapsis).
        return 0. },

    {   if not kuniverse:timewarp:issettled return 1/10.
        if kuniverse:timewarp:rate > 1 return 1.
        print "met "+metsec+": new staging task.".
        local staging_task2 is start_stager().
        return 0. },

    {   if apoapsis < 60000000 return 1.
        lock throttle to 0.
        print "met "+metsec+": apoapsis " + apoapsis.

        warpto(time:seconds + eta:apoapsis).
        return 0. },

    {   if not kuniverse:timewarp:issettled return 1/10.
        if kuniverse:timewarp:rate > 1 return 1.
        print "met "+metsec+": burning remaining fuel.".
        lock throttle to 1.
        return 1. },

    {   return 5. } )).


sequencer_go().
