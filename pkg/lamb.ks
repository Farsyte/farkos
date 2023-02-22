{
    parameter lamb is lex(). // lambert solver wrappers

    local predict is import("predict").
    local lambert is import("lambert").

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

        local perf_t is time:seconds.
        local perf_c is opcodesleft.

        local r1 is predict:pos(t1, ship).
        local r2 is predict:pos(t2, target).
        local mu is body:mu.

        local sF is lambert:v12(r1, r2, t2-t1, mu, false).
        local sT is lambert:v12(r1, r2, t2-t1, mu, true).

        local v1 is predict:vel(t1, ship).
        local dvF is sF:v1 - v1.
        local dvT is sT:v1 - v1.
        local dv is choose dvF if dvF:mag < dvT else dvT.

        set perf_o to perf_c - opcodesleft.
        set perf_t is time:seconds - perf_t.

        if perf_t > 0 {
            set dv_of_t1t2_osum to dv_of_t1t2_osum + perf_c.
            set dv_of_t1t2_ovf to dv_of_t1t2_ovf + 1. }

        else {
            set dv_of_t1t2_count to dv_of_t1t2_count + 1.
            set dv_of_t1t2_sum to dv_of_t1t2_sum + perf_o. }

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


}