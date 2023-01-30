say("Meaningfully Holistic Pickle").
say("Orbital Rescue Mission").

loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("rescue").
loadfile("visviva").

set target to persist_get("rescue_target", "").

global rescue_target is target.
global rescue_orbit is rescue_target:orbit.
global rescue_sma is (rescue_orbit:periapsis + rescue_orbit:apoapsis) / 2.

say("Rescue Target: "+rescue_target:name).

persist_put("match_peri", rescue_orbit:periapsis).
persist_put("match_apo", rescue_orbit:apoapsis).
persist_put("match_inc", rescue_orbit:inclination).
persist_put("match_lan", rescue_orbit:lan).

persist_put("launch_azimuth", 90-rescue_orbit:inclination).

// pick a starting orbit that is distinct from the target orbit.
if rescue_sma < 180000 {
    persist_put("launch_altitude", 250000).
} else {
    persist_put("launch_altitude", 120000).
}

function pv { parameter name, value.
    if value:istype("Vector") set value to "("+value:mag+") "+value.
    print name+": "+value.
}

    // if we were to hohmann transfer to the target orbit,
    // where would the target vessel be when we go there?

function initial_xfer { parameter t0.

    if hasnode and nextnode:eta>60 return nextnode.

    local b is body.
    local r0 is b:radius.
    local body_center is b:position.
    local targ is rescue_target.

    until not hasnode {
        remove nextnode.
        wait 0.
    }

    // create an approximate hohmann at time t0.

    local xfer_v1 is visviva_v(altitude, targ:altitude).                        // pv("xfer_v1", xfer_v1).
    local xfer_dv1 is xfer_v1 - velocity:orbit:mag.                             // pv("xfer_dv1", xfer_dv1).
    local node_h1 is node(t0, 0, 0, xfer_dv1).                                  // pv("node_h1", node_h1).
    add node_h1.
    wait 0.
    return node_h1.
}

function approach_error {
    parameter node_h1 is nextnode.
    wait 0.

    local targ is rescue_target.

    local b is body.
    local body_center is b:position.

    local h1_orbit is node_h1:orbit.
    local xfer_dt is h1_orbit:period/2.                                         // pv("xfer_dt", xfer_dt).
    local xfer_tF is time:seconds + node_h1:eta + xfer_dt.                      // pv("xfer_tF", xfer_tF).
    local pos_targ_tF is positionat(targ, xfer_tF) - body_center.               // pv("pos_targ_tF", pos_targ_tF).
    local pos_ship_tF is positionat(ship, xfer_tF) - body_center.               // pv("pos_ship_tF", pos_ship_tF).
    local error_total is pos_ship_tF - pos_targ_tF.                             // pv("error_total", error_total).
    return error_total:mag.
}

function until_better {
    parameter iter.
    parameter eval.
    local curr is eval().
    until false {
        iter().
        local prev is curr.
        set curr to eval().
        if curr < prev return.
    }
}

function until_worse {
    parameter iter.
    parameter eval.
    local curr is eval().
    until false {
        iter().
        local prev is curr.
        set curr to eval().
        if curr > prev return curr.
    }
}

function find_local_min {
    parameter incr.
    parameter decr.
    parameter eval.
    until_worse(incr, eval).
    until_worse(decr, eval).
    incr().
}

function optimize_h1_min {
    persist_put("optimize_rewind", mission_phase()-1).

    local dt is 300.                                                            // pv("dt",dt).
    local t0 is time:seconds + dt.                                              // pv("t0",t0).
    local node_h1 is initial_xfer(t0).                                          // pv("node_h1", node_h1).

    // it is possible that downhill leads back in time past now,
    // so push forward until it is improving again.

    until_better({ set node_h1:time to node_h1:time+60. }, approach_error@).

    // move forward by 60 sec until we are past the minimum,
    // then backward by 60 sec until we are past the minimum,
    // then forward again to our best candidate.
    find_local_min(
        { set node_h1:time to node_h1:time+60. },
        { set node_h1:time to node_h1:time-60. },
        approach_error@).

    return -1.
}

function optimize_rewind {
    say("optimize: node missing").
    say("  re-optimizing.").
    until not hasnode { remove nextnode. wait 0. }
    mission_jump(persist_get("optimize_rewind", 0)).
    return 1.
}

function optimize_h1_10s {
    if not hasnode return optimize_rewind().
    local node_h1 is nextnode.

    // move forward by 10 sec until we are past the minimum,
    // then backward by 10 sec until we are past the minimum,
    // then forward again to our best candidate.
    find_local_min(
        { set node_h1:time to node_h1:time+10. },
        { set node_h1:time to node_h1:time-10. },
        approach_error@).

    return -1.
}

function optimize_h1_sec {
    if not hasnode return optimize_rewind().
    local node_h1 is nextnode.

    // move forward by 1 sec until we are past the minimum,
    // then backward by 1 sec until we are past the minimum,
    // then forward again to our best candidate.
    find_local_min(
        { set node_h1:time to node_h1:time+1. },
        { set node_h1:time to node_h1:time-1. },
        approach_error@).

    return -1.
}

function twoprobe { parameter eval, dv, incr.
    set base to eval().
    incr(dv).
    set imp_pp to eval()-base.
    incr(-2*dv).
    set imp_pn to eval()-base.
    incr(dv).
    if imp_pp>=0 and imp_pn>=0 return 0.
    local imp_ppn is imp_pp-imp_pn.
    // print "twoprobe: pp="+imp_pp+" pn="+imp_pn+" net="+imp_ppn.
    return imp_ppn.
}

function optimize_h1_burn {
    if not hasnode return optimize_rewind().
    local node_h1 is nextnode.

    set base to approach_error().
    set original to base.
    local probe_dv is 10.
    until probe_dv < 0.005 {
        local chg_v is V(0,0,0).
        until false {
            // consider the effects of burns in each direction,
            // positive and negative. if we can get an improvement,
            // consruct a burn in the gradient direction.
            local chg_p is twoprobe(approach_error@, probe_dv, { parameter dv. set node_h1:prograde to node_h1:prograde+dv. }).
            local chg_r is twoprobe(approach_error@, probe_dv, { parameter dv. set node_h1:radialout to node_h1:radialout+dv. }).
            local chg_n is twoprobe(approach_error@, probe_dv, { parameter dv. set node_h1:normal to node_h1:normal+dv. }).

            set chg_v to V(chg_p,chg_r,chg_n).
            if chg_v:mag <= 0 break.
            set chg_v to -chg_v:normalized*probe_dv.
            set node_h1:prograde to node_h1:prograde+chg_v:x.
            set node_h1:radialout to node_h1:radialout+chg_v:y.
            set node_h1:normal to node_h1:normal+chg_v:z.
            local cand is approach_error().

            if cand>=base break.
            set base to cand.
        }
        set node_h1:prograde to node_h1:prograde-chg_v:x.
        set node_h1:radialout to node_h1:radialout-chg_v:y.
        set node_h1:normal to node_h1:normal-chg_v:z.
        set base to approach_error().
        set probe_dv to probe_dv / 1.6.
    }

    set original to round(original,1).
    set base to round(base, 1).

    if original > base
        print "improved by "+(original-base)+" from "+original+" to "+base.
    return 0.
}

function ready_h1 {
    if not hasnode return optimize_rewind().
    local node_h1 is nextnode.

    say("next node eta: "+round(node_h1:eta,2)).
    return 5.
}

function autolaunch {
    if availablethrust>0 return 0.
    lock throttle to 1.
    lock steering to facing.
    if countdown > 0 {
        say("T-"+countdown, false).
        set countdown to countdown - 1.
        return 1.
    }
    if stage:ready stage.
    return 1. }

mission_bg(bg_stager@).

local countdown is 10.
mission_add(LIST(
    "PADHOLD",      phase_match_lan@,   // PADHOLD until we can match target ascending node.
    "AUTOLAUNCH",   autolaunch@,        // initiate unmanned flight.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    "MATCH_INCL",   phase_match_incl@,  // match inclination of rescue target

    "OPTIMIZE_H1",  optimize_h1_min@,   // move forward by 60s until we find a local minimum
                    optimize_h1_10s@,   // hunt around by 10s to find local minimum
                    optimize_h1_sec@,   // hunt around by 1s to find local minimum
                    optimize_h1_burn@,  // fine tune the burn.

    "READY_H1",     ready_h1@,

    "TBD", {
        say("TBD", false). return 5. },
    "")).

mission_fg().
wait until false.