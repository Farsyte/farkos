@LAZYGLOBAL off.
runpath("0:sa/scheduler").
// global function schedule_call { parameter ut, task. ... return. }
// glboal function schedule_runner { ... never returns. }

wait until ship:unpacked.

local t0 is time:seconds+3.
lock met to time:seconds - t0.

schedule_call(t0+0.1, {
    print "met="+round(met,4)+": one.".
    return 1.
}).

schedule_call(t0+0.3, {
    print "met="+round(met,4)+": Three.".
    return 3.
}).

schedule_call(t0+0.5, {
    print "met="+round(met,4)+": FIVE!".
    return 5.
}).

schedule_runner().

// We never get here.
print "schedule_runner returned.".
wait until false.
