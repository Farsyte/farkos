@LAZYGLOBAL off.

{
    parameter lamb is lex(). // lambert solver wrappers

    local predict is import("predict").
    local scan is import("scan").
    local lambert is import("lambert").
    local targ is import("targ").
    local dbg is import("dbg").
    local mnv is import("mnv").

    global dv_of_t1t2_count is 0.
    global dv_of_t1t2_sum is 0.
    global dv_of_t1t2_ovf is 0.
    global dv_of_t1t2_osum is 0.

    global dv_of_t12_print is 0.

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

        if t1=dv_of_t12_last_t1 and t2=dv_of_t12_last_t2 return dv_of_t12_last_dv.

        local r1 is predict:pos(t1, ship).
        local r2 is predict:pos(t2, target).
        local mu is body:mu.

        local sF is lambert:v12(r1, r2, t2-t1, mu, false).
        local sT is lambert:v12(r1, r2, t2-t1, mu, true).

        local v1 is predict:vel(t1, ship).
        local dvF is sF:v1 - v1.
        local dvT is sT:v1 - v1.
        local dv is choose dvF if dvF:mag < dvT else dvT.

        if dv_of_t12_print < kuniverse:realtime {
            set dv_of_t12_print to kuniverse:realtime + 10.

            if dv_of_t1t2_count > 5 {
                print "dv_of_t12"
                    +" count: "+dv_of_t1t2_count
                    +" sum: "+dv_of_t1t2_sum
                    +" avg: "+(dv_of_t1t2_sum/dv_of_t1t2_count).
                set dv_of_t1t2_count to 0.
                set dv_of_t1t2_sum to 0. }

            if dv_of_t1t2_ovf > 5 {
                print "dv_of_t12"
                    +" ovf: "+dv_of_t1t2_ovf
                    +" sum: "+dv_of_t1t2_sum
                    +" avg: "+(dv_of_t1t2_osum/dv_of_t1t2_ovf).
                set dv_of_t1t2_ovf to 0.
                set dv_of_t1t2_osum to 0. } }

        set dv_of_t12_last_t1 to t1.
        set dv_of_t12_last_t2 to t2.
        set dv_of_t12_last_dv to dv.

        return dv. }).

    local plan_xfer_scan_t2 is 0.
    local plan_xfer_targ is SHIP.
    local plan_xfer_cont is 0.

    lamb:add("plan_xfer", {             // lambert based transfer planning

        //  local Ps is ship:orbit:period.
        //  local Pt is target:orbit:period.
        //  local P is (Ps*Pt)/abs(Ps-Pt).

        //  set plan_xfer_tmin to time:seconds + 60.
        //  set plan_xfer_tmax to plan_xfer_t1 + P.
        //  set plan_xfer_tstep to P/36.0

        targ:load().

        local start_t2_scan is false.
        if plan_xfer_targ<>target or plan_xfer_cont<time:seconds
            set plan_xfer_scan_t2 to 0.
        set plan_xfer_cont to time:seconds + 10.
        set plan_xfer_targ to target.

// this is the wrong approach:
// we need to be faster at rejecting t1 values
// where there is no reasonable transfer.

        // development bit ...
        // work out the correct T2 value for the T1.

        if plan_xfer_scan_t2:istype("Scalar") {

            until not hasnode { remove nextnode. wait 0. }

            // this comes from the outer optimization loop, really.
            local t1 is time:seconds + 300.
            local r1 is predict:pos(t1, ship).
            local v1 is predict:vel(t1, ship).
            local h1 is vcrs(v1, r1).
            local dt is 600.
            local mu is body:mu.

            // seek the transfer with minimum burn at t1.
            local t2_fit is { parameter state.
                local tof is state:tof.
                if tof<=0 return "skip".
                local t2 is t1 + tof.
                local r2 is predict:pos(t2, target).
                local v2 is predict:vel(t2, target).
                if vang(r1,r2)>90 set r2 to vxcl(h1, r2).
                local sF is lambert:v1v2(r1, r2, tof, mu, false).
                local sT is lambert:v1v2(r1, r2, tof, mu, true).
                local bF is sF:v1-v1.
                local bT is sT:v1-v1.
                local s is choose sF if bF:mag <= bT:mag else sT.
                local dv is s:v1-v1.
                set state:t1 to t1.
                set state:t2 to t2.
                set state:b1 to s:v1-v1.
                set state:b2 to v2-s:v2.
                local mag is state:b1:mag + state:b2:mag.
                // ignore any transits with dv>60k delta-v.
                if mag>60000 return "skip".
                return -mag. }.

            set plan_xfer_scan_t2 to scan:init(t2_fit,
                { parameter state. set state:tof to state:tof + dt. return state. },
                { parameter state. set dt to dt/3. return dt<1/30. },
                lex("tof", 0, "t1", 0, "t2", 0, "b1", 0, "b2", 0)). }


        local wall is kuniverse:realtime.
        local phys is time:seconds.
        local iter is 0.
        until plan_xfer_scan_t2:step() {
            set iter to iter + 1. }.
        set wall to kuniverse:realtime-wall.
        set phys to time:seconds-phys.
        dbg:pv("iter", iter).
        dbg:pv("wall", wall).
        dbg:pv("phys", phys).
        dbg:pv("wall*1000/iter", wall*1000/iter).
        dbg:pv("phys*1000/iter", phys*1000/iter).

        until not hasnode { remove nextnode. wait 0. }
        if not plan_xfer_scan_t2:failed {
            local state is plan_xfer_scan_t2:result.
            mnv:schedule_dv_at_t(state:b1, state:t1).
            mnv:schedule_dv_at_t(state:b2, state:t2). }


        return 0.

        // mnv:schedule_dv_at_t(dv2, t2).
        // mnv:schedule_dv_at_t(dv1, t1).

    }).

    lamb:add("plan_corr", {            // lambert based correction planning
        local t2 is nv:get("xfer/final").
        local t1 is time:seconds.
        if t1 + 60 > t2 {               // too close to use this method.
            lock steering to facing.
            lock throttle to 0.
            return 0. }

        local dv is lamb:dv_of_t1t2(t1, t2).
        if dv:mag < 0.1 {               // no correction needed.
            lock steering to facing.
            lock throttle to 0.
            return 0. }

        lock steering to lookdirup(dv, facing:topvector).

        local dvw is lamb:dv_of_t1t2(t1+1, t2).
        if dvw:mag <= dv:mag {          // prefer to wait.
            lock throttle to 0.
            return 1. }

        // TODO create generic "set throttle properly
        // for this desired delta-v, with discount for
        // being pointed not quite perfectly."

        local desired_velocity_change is lamb:dv_of_t1t2(time:seconds, t2).

        local desired_accel is throttle_gain * desired_velocity_change:mag.
        local desired_force is mass * desired_accel.
        local max_thrust is max(0.01, availablethrust).
        local desired_throttle is clamp(0,1,desired_force/max_thrust).

        local facing_error is vang(facing:vector,desired_velocity_change).
        local facing_error_factor is clamp(0,1,1-facing_error/max_facing_error).
        lock throttle to clamp(0,1,facing_error_factor*desired_throttle).

        return 1/100. }).
}