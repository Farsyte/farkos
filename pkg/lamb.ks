@LAZYGLOBAL off.
{   parameter lamb is lex(). // lambert solver wrappers

    local predict is import("predict").
    local scan is import("scan").
    local lambert is import("lambert").
    local targ is import("targ").
    local dbg is import("dbg").
    local hud is import("hud").
    local nv is import("nv").
    local plan is import("plan").
    local ctrl is import("ctrl").
    local memo is import("memo").

    // memoize most recent computation.
    // multiple calls for the same (t1,t2)
    // will re-use the dv computed the first time.
    // NOTE: may need to add code here to allow a
    // caller to flush the memoized value, if it
    // is asking about the same time after changing
    // a maneuver node or applying thrust.
    local dv_of_t12_last_t1 is 0.
    local dv_of_t12_last_t2 is 0.
    local dv_of_t12_last_dv is V(0,0,0).

    lamb:add("dv_of_t1t2", {
        parameter t1.                       // instant of correction burn
        parameter t2.                       // instant of target match

        // lamb:dv_of_t1t2() returns the Delta-V that is required to place
        // us on the Lambert solution trajectory from our predicted position
        // at T1, leading to the predicted target standoff position at T2.
        //
        // First thing, we memoize our results, so if we are called more than
        // once for exactly the same T1 and T2, we can just return the value
        // we returned last time. Beware of this, if you do something that
        // changes the predicted position of the ship at T1, the predicted
        // standoff point at T2, or the ship's orbital plane.

        if t1=dv_of_t12_last_t1 and t2=dv_of_t12_last_t2 return dv_of_t12_last_dv.

        local tof is t2-t1.

        local r1 is predict:pos(t1, ship).
        local r2 is targ:standoff(t2).
        local mu is body:mu.

        // If the two points are far apart, the T2 point is modified by
        // dropping it perpendicularly to the current orbital plane, as
        // otherwise we might end up doing a pair of 90-degree plane changes
        // because the other side, at 180 degrees around, happens to be a tiny
        // bit outside our orbital plane.

        local onv is vcrs(body:position, ship:velocity:orbit):normalized.
        if vang(r1,r2)>135 set r2 to vxcl(onv,r2).
        local r1r2fac is onv*vcrs(r1,r2).

        // Hand the predicted positions and time of flight to Lambert to
        // get back the appropriate solution. There are actually two
        // solutions -- the "right" way around and the "other" way
        // around -- and I have modified my lambert solver so that this
        // specfic form of the call gives the one with smaller Delta-V
        // at the T1 point.

        local s is lambert:v1v2(r1, r2, tof, mu, r1r2fac>0).

        // Compute the Delta-V based on the T1 velocity from the lambert solution
        // and our predicted velocity at T1.

        local v1 is predict:vel(t1, ship).
        local dv is s:v1 - v1.

        // Store our input praameters and result for the next call,
        // in case it is a repeat evaluation.

        set dv_of_t12_last_t1 to t1.
        set dv_of_t12_last_t2 to t2.
        set dv_of_t12_last_dv to dv.

        return dv. }).

    local plan_xfer_timeout is 0.
    local plan_xfer_targ is SHIP.
    local plan_xfer_t1_scanner is 0.
    local plan_xfer_best is lex("score", -2^64).

    local function t1_fit { parameter state.

        // This is the Hillclimbing Fitness Function that is used to
        // evaluate a candidate T1 transfer time for a Hohmann transfer.
        //
        // This fitness function will itself use a Scan optimization sequence
        // to evaulate a range of T2 values, to find the one that is best,
        // then return the score of the best T1-T2 combination as the score
        // for this T1 point.

        until not hasnode { remove nextnode. wait 0. }

        // these were in inner state but never changed.
        local onv is state:onv.
        local mu is state:mu.
        local t1 is state:t1.
        local t1min is state:t1min.
        local t1end is state:t1end.
        local t1pct is (t1-t1min)*100/(t1end-t1min).

        local r1 is predict:pos(t1, ship).
        local v1 is predict:vel(t1, ship).

        local tofmax is state:tofmax.
        local tofstep is state:tofstep.
        local tofeps is state:tofeps.

        local scorethresh is state:scorethresh.

        local plan_xfer_scan_t2 is scan:init(

            {   parameter state.
                local tof is state:tof.

                // Evaluate a candidate transfer, knowing the starting time and
                // the time of flight. Fairly direct code.

                if tof<=0 return "skip".
                local t2 is t1 + tof.
                local r2 is targ:standoff(t2).
                local v2 is targ:standoff_v(t2).

                // For transfers that have large angles, snap the target position
                // perpendicualrly back into the current orbital plane to avoid
                // proposing wildly out-of-plane maneuvers.

                if vang(r1,r2)>135 set r2 to vxcl(onv,r2).

                local r1r2fac is onv*vcrs(r1,r2).

                local s is lambert:v1v2(r1, r2, tof, mu, r1r2fac>0).

                local b1 is s:v1-v1.
                local b2 is v2-s:v2.

                // stash the solution's T2, as well as the Delta-V of each
                // burn (B1 and B2), in the state vector, along with the
                // score. The score is "higher is better" and we want to
                // minimize the magnitude of the burns, so this is the
                // negative of the sum of the magnitudes.
                //
                // If having two SQRT calls in here seems significant, the
                // squared magnitudes can be used, but really, two SQRT calls
                // is just noise compared to the Lambert computation ;)

                set state:t2 to t2.
                set state:b1 to b1.
                set state:b2 to b2.
                set state:score to -(b1:mag+b2:mag).

                return state:score. },

            {   parameter state.
                // The second delegate is the "increment to next position"
                // for the Scan optimizer. Simple but needs to be specified.
                set state:tof to min(tofmax, state:tof + tofstep).
                return state. },

            {   parameter state, ds.
                // The second delegate is the "reduce step size"
                // for the Scan optimizer. Simple but needs to be specified.
                // The second parameter is a measure of how much the score
                // changed in the interval, so we are done if it is tiny
                // or if the step is tiny.
                if ds<scorethresh return true.
                if tofstep<=tofeps return true.
                set tofstep to max(tofeps,tofstep/3).
                return false. },

            // This is the initial state lexicon for the scan optimzer.
            lex("tof", state:tofmin, "score", 0,
                "t2", 0, "b1", V(0,0,0), "b2", V(0,0,0))).
        //
        // NOTE: yes, this stalls the master sequence while we
        // look at various times of flight. This is acceptable.
        until plan_xfer_scan_t2:step() { }.

        // Returning "skip" causes the scan optimizer to skip over this
        // data point and move on to the next grid point, it is used when
        // we probably have an intermediate candidate that is not feasible.

        if plan_xfer_scan_t2:failed
            return "skip".

        local result is plan_xfer_scan_t2:result.

        // copy all the interesting computed data into the state lexicon.

        set state:tof to result:tof.
        set state:t2 to result:t2.
        set state:b1 to result:b1.
        set state:b2 to result:b2.
        set state:score to result:score.

        return result:score. }

    local function t1_incr { parameter state.
        // Used by the scan optimizer to step to the next grid point.
        // Trivial but must be specified by the caller.
        set state:t1 to state:t1 + state:t1step.
        return state. }

    local function t1_fine { parameter state, ds.
        // Used by the scan optimizer to reduce the grid size.
        // Note that if the current span is essentially all the
        // same score, or if the step is already tiny, we are done.

        if ds<state:scorethresh or state:t1step<=state:t1eps
            return true.

        set state:t1step to max(state:t1eps,state:t1step/3).

        return false. }

    local lamb_plan_chat is 0.
    lamb:add("plan_xfer", {             // lambert based transfer planning

        // Plan a Hohmann transfer by examining Lambert solutions at a range
        // of starting times, each with a range of times of flight. Use the
        // Scan optimizer to find a local optimum that is not the first candidate,
        // but recognize that the earliest possible burn might be best.

        unlock steering.
        unlock throttle.

        if hastarget targ:save(). else targ:load().

        until not hasnode { remove nextnode. wait 0. }

        local t1_scan_do_start
            is plan_xfer_targ<>target
            or plan_xfer_timeout<time:seconds
            or plan_xfer_t1_scanner:istype("Scalar").

        set plan_xfer_timeout to time:seconds + 10.
        set plan_xfer_targ to target.

        // work out the correct T2 value for the T1.
        // We evaluate all T2 for a given T1 in one call.

        local function t1_scan_setup {
            parameter t1, t1min, t1end, t1max.

            local mu is body:mu.
            local onv is vcrs(body:position, ship:velocity:orbit):normalized.

            local t1step is (t1max-t1min) / 16.
            local t1eps is (t1max-t1min) / 720.

            local tofmin is 0.
            local tofmax is target:orbit:period.
            local tofstep is tofmax/8.
            local tofeps is tofmax/3600.

            local scorethresh is 10. // compute based on vessel capabilities?

            set plan_xfer_t1_scanner to scan:init(
                t1_fit@, t1_incr@, t1_fine@, lex(
                    "mu", mu, "onv", onv,
                    "t1min", t1min, "t1end", t1end, "t1max", t1max,
                    "t1step", t1step, "t1eps", t1eps,
                    "tofmin", tofmin, "tofmax", tofmax,
                    "tofstep", tofstep, "tofeps", tofeps,
                    "scorethresh", scorethresh,

                    "t1", t1,

                    "t2", 0, "b1", V(0,0,0), "b2", V(0,0,0))). }

        if t1_scan_do_start {

            // lamb:plan_xfer is going to be called repeatedly by
            // the main sequener loop. We want to be sure to initialize
            // the scan optimizer only on the first call; after that,
            // we just keep asking it to evaluate the next candidate.

            set plan_xfer_best to lex("score", -2^64).

            // start looking 10 minutes out,
            // and continue looking until our
            // phase angle repeats twice.

            local Ps is ship:orbit:period.
            local Pt is target:orbit:period.
            local P is (Ps*Pt)/abs(Ps-Pt).

            local t1min is time:seconds + 600.
            local t1end is t1min + 3.0*P.
            local t1max is t1min + 4.0*P.

            t1_scan_setup(t1min, t1min, t1end, t1max). }

        if lamb_plan_chat<time:seconds {
            // This can take a while. Paint a message on the HUD every
            // five seconds so the flight engineer knows we are actually
            // doing something.
            set lamb_plan_chat to time:seconds+5.
            hud:say("Lambert Planning", false). }

        // TERMINATION CONDITION! The step will return false for "please call
        // me again soon" -- so we return a tiny elapsed time, and will soon
        // reenter at the top. If it returns true, we proceed down to the
        // code to finalize this transfer.

        if not plan_xfer_t1_scanner:step()
            return 1/100.

        // SEARCH COMPLETE. Erase any maneuver nodes left behind by the
        // planning process.

        until not hasnode { remove nextnode. wait 0. }

        if plan_xfer_t1_scanner:failed {

            // This can happen, in theory. The mission will not be happy.
            //
            // TODO comfirm that we can't even use the earliest
            // possible burn if we get here. Recent test runs have
            // not encountered this condition. Perhaps it is not
            // something that can happen for rescues in Kerbin SOI
            // or for transfers to Mun and Minmus, which are my
            // current test cases.

            hud:say("Lambert Planning Failed.").
            return 0. }

        local result is plan_xfer_t1_scanner:result.

        local t1 is result:t1.
        local t1min is result:t1min.
        local t1end is result:t1end.
        local t1pct is (t1-t1min)*100/(t1end-t1min).

        // keep track of the best result so far.

        if result:score > plan_xfer_best:score
            set plan_xfer_best to result.

        if result:t1 < result:t1end {
            // We are not yet done scanning. Set up to do it again,
            // starting after the optimum we found.
            t1_scan_setup(result:t1+60, result:t1min, result:t1end, result:t1max).
            return 1/10. }

        // We have scanned all our acceptable T1 candidates, and the best result
        // remains in plan_xfer_best. Store the T2 time in nonvolatile storage so
        // it survives a reboot during the transfer.

        nv:put("xfer/final", plan_xfer_best:t2).

        // Inform the flight engineer. He will be happy.

        hud:say("Lambert Planning Successful.").

        // Dump any maneuver nodes that might be hanging around.
        // This is paranoia, but it has paid off.

        until not hasnode { remove nextnode. wait 0. }

        // Create a maneuver node for burn B1 at time T1, which will place
        // us on the "best" tranfer we saw from the Lambert solver.

        plan:dvt(plan_xfer_best:b1, plan_xfer_best:t1).

        // Create a maneuver node for burn B2 at time T2, unless we happen
        // to have an SOI transition (this happens if we are doing a transfer
        // to another body). Visually, this should show us ending up in the same
        // orbit as our target.

        if plan_xfer_best:t2 < time:seconds + nextnode:orbit:eta:transition
            plan:dvt(plan_xfer_best:b2, plan_xfer_best:t2).

        return 0. }).

    lamb:add("plan_corr", {

        // Plan a correction burn by examining Lambert solutions at a range
        // of starting times, with fixed arrival time and position. Use the
        // Scan optimizer to find a local optimum that is not the first candidate,
        // but recognize that the earliest possible burn might be best.

        if not hastarget return 0.

        if hasnode { remove nextnode. return 1/100. }

        local mu is body:mu.
        local onv is vcrs(body:position, ship:velocity:orbit):normalized.

        local t1 is time:seconds+300.
        local t2 is nv:get("xfer/final").
        local tof is t2 - t1.

        if tof < 60 {

            // If we do not have significant time until T2, then we
            // just want to ride out whatever error we might have.

            lock steering to facing.
            lock throttle to 0.
            return 0. }

        local r2 is targ:standoff(t2). // predict:pos(t2, target).
        local r2e is r2 - predict:pos(t2, ship).

        // If our position at T2 is close enough to our goal, then
        // do not need to do a correction.

        if r2e:mag<1000 {
            return 0. }

        // Create the initial state lexicon that will be used for
        // our scan step.

        local sInit is lex("t1", t1, "score", 0,
            "b1", V(0,0,0), "b2", V(0,0,0)).

        // Before we start, go get the Lambert solution for the
        // earliest possible T1, and tuck it into the "sMin"
        // result to be examined later.

        local r1 is predict:pos(t1, ship).
        local v1 is predict:vel(t1, ship).
        local v2 is targ:standoff_v(t2). // predict:vel(t2, target).

        local lr2 is r2.
        if vang(r1,lr2)>135                  // if over 120-degree transfer,
            set lr2 to vxcl(onv,lr2).       // leave plane change for later.

        // check normal and flipped, pick the one that is lower delta-v at v1.
        local s is lambert:v1v2(r1, lr2, tof, mu, false).
        local sR is lambert:v1v2(r1, lr2, tof, mu, true).
        if (s:v1-v1):mag>(sR:v1-v1):mag
            set s to sR.

        local t1pct is (t1-time:seconds)*100/(t2-time:seconds).

        local b1 is s:v1-v1.
        local b2 is v2-s:v2.

        local sMin is sInit:copy().
        set sMin:b1 to b1.
        set sMin:b2 to b2.
        set sMin:score to -(b1:mag+b2:mag).

        // ok, now we can go scan for a better T1,
        // if there is a better local optimum between
        // our minimum T1 and our fixed T2.

        local scorethresh is 1/10.
        local t1step is (t2-t1)/8.
        local t1eps is (t2-t1)/1024.

        local plan_corr_scanner is scan:init(

            {   parameter state.
                local t1 is state:t1.
                local tof is t2 - t1.
                if tof<=0 return "halt".

                // TODO surely we can unify all of these functions
                // that are evaluating Lambert solutions.

                local r1 is predict:pos(t1, ship).
                local v1 is predict:vel(t1, ship).

                local lr2 is r2.
                if vang(r1,lr2)>120                 // if more than 120-degree transfer,
                    set lr2 to vxcl(onv,lr2).       // ignore plane change.

                // check normal and flipped, pick the one that is lower delta-v at v1.

                // Not sure why we are not using the "single lambert call" form that
                // was worked out, but we call it fewer times so ... ok. Maybe in the
                // future we can finish unification of the lambert evaluations.

                local s is lambert:v1v2(r1, lr2, tof, mu, false).
                local sR is lambert:v1v2(r1, lr2, tof, mu, true).
                if (s:v1-v1):mag>(sR:v1-v1):mag
                    set s to sR.

                local b1 is s:v1-v1.
                local b2 is v2-s:v2.

                set state:b1 to b1.
                set state:b2 to b2.
                set state:score to -(b1:mag+b2:mag).

                return state:score. },

            {   parameter state.        // step to the next T1.
                set state:t1 to min(t2, state:t1 + t1step).
                return state. },

            {   parameter state, ds.    // reduce step size, detect completion.
                if ds<scorethresh return true.
                if t1step<=t1eps return true.
                set t1step to max(t1eps,t1step/4).
                return false. },

            sInit).

        until plan_corr_scanner:step() { }

        // Start with the "do the correction ASAP" burn,
        // but if scan found a lambert solution,
        // shift to that result.
        //
        // TODO work out why I didn't just use sMin as the
        // initial state vector.

        local result is sMin.
        if not plan_corr_scanner:failed {
            // print "lamb plan_corr best burn is located.".
            // TODO work out why I'm not comparing scores,
            // since evaluation was not looking at sMin.
            set result to plan_corr_scanner:result. }
        // else {
        //     print "lamb plan_corr best burn is earliest burn.". }

        // dbg:pv("lamb plan_corr b1 is ", result:b1).

        // If the correction is tiny, do not bother with it.
        if result:b1:mag < 0.1 return 0.

        // Set up a maneuver node for the B1 burn.
        // And set one up for T2, as long as we do not
        // change SOI before then.

        plan:dvt(result:b1, result:t1).
        if t2 < time:seconds + nextnode:orbit:eta:transition {
            // dbg:pv("lamb plan_corr b2 is ", result:b2).
            plan:dvt(result:b2, t2). }

        return 0. }).

}
