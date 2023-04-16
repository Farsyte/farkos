@LAZYGLOBAL OFF.

// Call tasks when scheduled.

// this code can be demonstrated via boot/sa.ks
// by setting the vessel name to demo/scheduler.

// SIMPLEST IMPLEMENTATION: task_list is just a sorted linear list
// where each element is a list containing time and delegate, and
// a sentinal element with far future time allows me to ignore
// the "list is empty" case entirely. Picking this initially allows
// rapidly getting something running that has the API that I want.
//
// Performance optimizations are possible in the future; this version
// is the minimal implementation that provides the API, so I can
// make sure the API is sufficient.
//
// Optimization 1: use a binary search in schedule_call. Should be
// a win for even fairly modest values of N. Not sure how much of
// a win it is for N=2 or N=3, which are my common cases.
//
// Optimization 2: use a task HEAP. Insert and remove are O(log N)
// but the code is more complicated. Absolutely would have to benchmark
// to find how large N has to be for the asymptotic performance
// curve to make up for the extra work at each iteration.

// I'm going to play the Single Responsibilty Principle card to
// push the Pause/Resume/Cancel feature up into another layer,
// since some tasks do not need it, but it should be consistently
// managed for those that do.

// Directly calling schedule_call from a trigger is unsafe.
//
// The LIST:INSERT and LIST:REMOVE calls themselves are atomic,
// but if we are about to do :INSERT(5) and a trigger comes along
// and does an :INSERT(3), then our new data inserted at 5 is now
// incorrectly ordered with respect to the element that was just
// pushed past it.
//
// When a use case of doing a schedule_call from a trigger is
// actually observed, the correct mechanism is to use a Queue
// to communcate the scheduling data back to the main line, and
// the main line will need to have a mechanism for picking up
// the data from the Queue and scheduling the task. This will
// make the schedule_runner loop a bit more complicated, so I am
// going to play the You Aren't Going To Need It Yet card.


local task_list is list(list(2^64, { return 0. })).

// schedule_call(ut, task) schedules a task
global function schedule_call { parameter ut, task.
    local i is 0.
    until task_list[i][0] > ut
        set i to i + 1.
    task_list:insert(i, list(ut, task)).
}

// schedule_runner() enters the scheduler service loop
global function schedule_runner {
    until task_list:length<2 {
        wait until time:seconds >= task_list[0][0].
        local task is task_list[0][1].
        task_list:remove(0).
        local dt is task().
        if dt>0 schedule_call(time:seconds + dt, task).
    }
}