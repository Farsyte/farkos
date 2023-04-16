@LAZYGLOBAL off.

// maybe_stage: conditionally trigger staging
//
// This is a function that can be scheduled by any runner that
// executes function delegates, which take no parameters and
// return how long to delay.
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

// TROUBLESOME CASES HANDLED:
// ** Verified to operate correctly for Asparagus configurations
//    constructed using Fuel Ducting.
// ** Verified to avoid activating parachutes in Stage Zero, which
//    is common for crewed missions.
// ** Gracefully handles staging triggered externally (if no care
//    is taken, we would stage again, erroneously).
//
// KNOWN ISSUES IN THIS APPROACH:
// ** It uses a WHEN..THEN construct, imposing inherent load
//    at the top of every physics tick.
// ** If launch clamp release is in a separate stage from igniting
//    the launch engines, this will not release launch clamps.
// ** This will not jettison Asparagus pairs that are empty but
//    are still connected to fuel via Cross-Feed.
// ** This does not ignite engines in Stage Zero, which is common
//    for satellite configurations.
// ** This facility does not notice exhausted Asparagus pairs
//    during initial boot.

local mt is 0.
local sn is stage:number.

global function maybe_stage {
    if stage:number<2 return 0.
    if not stage:ready return 1.

    // save the old maxthrust, and observe the
    // new maxthrust sample.
    local mt_old is mt.
    set mt to round(ship:maxthrustat(0)).

    // save the old stage number, and observe the
    // new stage number.

    local sn_old is sn.
    set sn to stage:number.

    // If the stage number changed, then
    // do not even think about staging this time.
    //
    // NOTE: SOMEONE ELSE MIGHT STAGE! This not only handles
    // avoiding comparing thrust before staging with thrust
    // after, but does so even if it is because the flight
    // engineer (or a visitor) touched the stage bar.

    if sn<>sn_old return 1.

    // if we have thrust, and it is not less than what we
    // had last time, come back later.

    if mt>0 and mt>=mt_old return 1.

    // Some missions may want to add code here to cancel
    // the task (return zero) if there are no more engines
    // on the vessel. The current demo will continue staging
    // until the "last stage" check at the top triggers.

    // Time to stage (our max thrust went down, presumably due
    // to engines flaming out, or is zero, and we want to stage
    // to discard dead engines and ignite the next ones).

    stage.
    return 1.
}
