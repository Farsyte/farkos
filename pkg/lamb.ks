@LAZYGLOBAL off.

{
    parameter lamb is lex(). // lambert solver wrappers

    local predict is import("predict").
    local scan is import("scan").
    local lambert is import("lambert").
    local targ is import("targ").
    local dbg is import("dbg").
    local io is import("io").
    local nv is import("nv").
    local mnv is import("mnv").
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

        local tof is t2-t1.

        if t1=dv_of_t12_last_t1 and t2=dv_of_t12_last_t2 return dv_of_t12_last_dv.

        local r1 is predict:pos(t1, ship).
        local r2 is predict:pos(t2, target).
        local mu is body:mu.

        local onv is vcrs(body:position, ship:velocity:orbit):normalized.
        if vang(r1,r2)>90 set r2 to vxcl(onv,r2).
        local r1r2fac is onv*vcrs(r1,r2).
        local s is lambert:v1v2(r1, r2, tof, mu, r1r2fac>0).

        local v1 is predict:vel(t1, ship).
        local dv is s:v1 - v1.

        set dv_of_t12_last_t1 to t1.
        set dv_of_t12_last_t2 to t2.
        set dv_of_t12_last_dv to dv.

        return dv. }).

    local plan_xfer_timeout is 0.
    local plan_xfer_targ is SHIP.
    local plan_xfer_t1_scanner is 0.
    local plan_xfer_best is lex("score", -2^64).

    local function t1_fit { parameter state.

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
                if tof<=0 return "skip".
                local t2 is t1 + tof.
                local r2 is predict:pos(t2, target).
                local v2 is predict:vel(t2, target).

                if vang(r1,r2)>170 set r2 to vxcl(onv,r2).

                local r1r2fac is onv*vcrs(r1,r2).

                local s is lambert:v1v2(r1, r2, tof, mu, r1r2fac>0).

                local b1 is s:v1-v1.
                local b2 is v2-s:v2.

                set state:t2 to t2.
                set state:b1 to b1.
                set state:b2 to b2.
                set state:score to -(b1:mag+b2:mag).
                return state:score. },

            {   parameter state.
                set state:tof to min(tofmax, state:tof + tofstep).
                return state. },

            {   parameter state, ds.
                if ds<scorethresh return true.
                if tofstep<=tofeps return true.
                set tofstep to max(tofeps,tofstep/3).
                // dbg:pv("t2_fine tofstep", state:tofstep).
                return false. },

            lex("tof", state:tofmin, "score", 0,
                "t2", 0, "b1", V(0,0,0), "b2", V(0,0,0))).
        //
        // I am perfectly OK with stalling the master sequencer
        // while we riffle through times of flight, even though
        // this is taking us hundreds of ms.
        until plan_xfer_scan_t2:step() { }.

        if plan_xfer_scan_t2:failed {
            print "t1_fit["+round(t1pct)+"%]:"
                + "t2 scan failed".
            return "skip". }

        local result is plan_xfer_scan_t2:result.
        // dbg:pv("plan_xfer_scan_t2:result:t1 now+", result:t1-time:seconds).
        // dbg:pv("plan_xfer_scan_t2:result:t2 now+", result:t2-time:seconds).
        // dbg:pv("plan_xfer_scan_t2:result:tof", result:tof).
        // dbg:pv("plan_xfer_scan_t2:result:b1", result:b1).
        // dbg:pv("plan_xfer_scan_t2:result:b2", result:b2).

        set state:tof to result:tof.
        set state:t2 to result:t2.
        set state:b1 to result:b1.
        set state:b2 to result:b2.
        set state:score to result:score.

        print "t1_fit["+round(t1pct,2)+"%]:"
            +" t2 scan yields"
            +" eta "+round(t1-time:seconds)
            +" burn "+round(result:b1:mag)
            +" tof "+round(result:tof)
            +" burn "+round(result:b2:mag)
            +" score "+round(result:score).

        // mnv:update_dv_at_t(t1_scan_n1, state:b1, state:t1).
        // mnv:update_dv_at_t(t1_scan_n2, state:b2, state:t2).

        return result:score. }

    local function t1_incr { parameter state.
        set state:t1 to state:t1 + state:t1step.
        return state. }

    local function t1_fine { parameter state, ds.

        if ds<state:scorethresh or state:t1step<=state:t1eps
            return true.

        set state:t1step to max(state:t1eps,state:t1step/3).

        return false. }

    local lamb_plan_chat is 0.
    lamb:add("plan_xfer", {             // lambert based transfer planning

        targ:load().

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

            print " ".
            print "Lambert-based Transfer Planing Starts.".
            print " ".

            set plan_xfer_best to lex("score", -2^64).

            // start looking 10 minutes out,
            // and continue looking until our
            // phase angle repeats twice.

            local Ps is ship:orbit:period.
            local Pt is target:orbit:period.
            local P is (Ps*Pt)/abs(Ps-Pt).

            local t1min is time:seconds + 600.
            local t1end is t1min + 1.0*P.
            local t1max is t1min + 2.0*P.
            // local t1step is P / 8.
            // local t1eps is P / 3600.

            t1_scan_setup(t1min, t1min, t1end, t1max). }

        if lamb_plan_chat<time:seconds {
            set lamb_plan_chat to time:seconds+5.
            io:say("Lambert Planning", false). }

        if not plan_xfer_t1_scanner:step()
            return 1/10.

        until not hasnode { remove nextnode. wait 0. }

        if plan_xfer_t1_scanner:failed {
            io:say("Lambert Planning Failed.").
            return 0. }

        // scanner has found a LOCAL OPTIMUM.

        local result is plan_xfer_t1_scanner:result.

        local t1 is result:t1.
        local t1min is result:t1min.
        local t1end is result:t1end.
        local t1pct is (t1-t1min)*100/(t1end-t1min).

        if result:score > plan_xfer_best:score
            set plan_xfer_best to result.

        if result:t1 < result:t1end {
            t1_scan_setup(result:t1+60, result:t1min, result:t1end, result:t1max).
            return 1/10. }

        until not hasnode { remove nextnode. wait 0. }

        mnv:schedule_dv_at_t(plan_xfer_best:b1, plan_xfer_best:t1).
        // mnv:schedule_dv_at_t(plan_xfer_best:b2, plan_xfer_best:t2).

        io:say("Lambert Planning Successful.").
        nv:put("xfer/final", plan_xfer_best:t2).

        return 0. }).

    local function hms { parameter dt.
        local ts is timespan(abs(dt)).
        local bits is list().
        if ts:year>0 bits:add(ts:year+"y").
        if ts:day>0 bits:add(ts:day+"d").
        if ts:hour>0 bits:add(ts:hour+"h").
        if ts:minute>0 bits:add(ts:minute+"m").
        if ts:second>0 or bits:length<1 bits:add(ts:second+"s").
        return bits:join(" ").
    }

    lamb:add("plan_corr", {

        if not hastarget return 0.

        until not hasnode { remove nextnode. wait 0. }
        wait 1.

        local mu is body:mu.
        local onv is vcrs(body:position, ship:velocity:orbit):normalized.

        // plan the correction node.
        local t1 is time:seconds.
        local t2 is nv:get("xfer/final").
        local tof is t2 - t1.

        if tof < 60 {               // too close to use this method.
            io:say("Lambert Correction: no time.").
            lock steering to facing.
            lock throttle to 0.
            return 0. }

        local r1 is predict:pos(t1, ship).
        local v1 is predict:vel(t1, ship).

        local r2 is predict:pos(t2, target).
        local v2 is predict:vel(t2, target).

        local r2e is r2 - predict:pos(t2, ship).

        if r2e:mag<100
            return 0.

        local scorethresh is 1/10.
        local t1step is (t2-t1)/8.
        local t1eps is (t2-t1)/1024.


        local plan_corr_scanner is scan:init(

            {   parameter state.
                local t1 is state:t1.
                local tof is t2 - t1.
                if tof<=0 return "halt".
                local r1 is predict:pos(t1, ship).
                local v1 is predict:vel(t1, ship).

                local lr2 is r2.
                if vang(r1,lr2)>170 set lr2 to vxcl(onv,lr2).

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

            {   parameter state.
                set state:t1 to min(t2, state:t1 + t1step).
                return state. },

            {   parameter state, ds.
                if ds<scorethresh return true.
                if t1step<=t1eps return true.
                set t1step to max(t1eps,t1step/4).
                return false. },

            lex("t1", t1, "score", 0,
                "b1", V(0,0,0), "b2", V(0,0,0))).

        until plan_corr_scanner:step() { }

        if plan_corr_scanner:failed
            return 0.

        local result is plan_corr_scanner:result.

        set t1 to result:t1.

        print "lamb:plan_corr selected burn time.".
        dbg:pv("  at", "T+"+hms(t1 - time:seconds)).
        dbg:pv("  eta(burn)/eta(match)",
            (t1 - time:seconds) /
            (t2 - time:seconds)).

        print "lamb:plan_corr retaining arrival time.".
        dbg:pv("  at", "T+"+hms(t2 - time:seconds)).

        mnv:schedule_dv_at_t(result:b1, t1).

        local rs is predict:pos(t2, ship).
        local rt is predict:pos(t2, target).
        dbg:pv("  predicted error:", rt-rs).

        // mnv:schedule_dv_at_t(result:b2, t2).
        return 0.
    }).

}