{   parameter plan is lex().        // generate maneuver nodes.

    local dbg is import("dbg").
    local mnv is import("mnv").
    local lamb is import("lamb").
    local scan is import("scan").
    local predict is import("predict").
    local visviva is import("visviva").

    plan:add("go", mnv:step).

    plan:add("dvt", {               // create maneuver for dv at time t
        parameter dv.               // Body-rel change in velocity
        parameter t.                // universal time to apply change.

        until not hasnode { remove nextnode. wait 0. }

        local ship_radial_dir is predict:pos(t, ship):normalized.
        local prograde_dir is predict:vel(t, ship):normalized.
        local normal_dir is vcrs(prograde_dir, ship_radial_dir).
        local node_radial_dir is vcrs(normal_dir, prograde_dir).

        local n is node(t, vdot(node_radial_dir, dv), vdot(normal_dir, dv), vdot(prograde_dir, dv)).
        add n. wait 0. return n. }).

    plan:add("circ_ap", {           // circularize at apoapsis

        until not hasnode { remove nextnode. wait 0. }

        local ut is time:seconds + eta:apoapsis.

        local r0 is body:radius + apoapsis.
        local vc is sqrt(body:mu/r0).
        local vs is predict:vel(ut, ship):orbit.
        local dv is vs*(vc-vs:mag).
        local n is plan:dvt(dv, ut).

        print "Circularization at Apoapsis planned.".
        print "  Burn ETA: "+dbg:pr(timespan(n:eta)).
        print "  Burn DV: "+n:deltav:mag.
        print "  Burn Vector: "+dbg:pr(n:deltav).

        return 0. }).

    plan:add("circ_pe", {           // circularize at periapsis

        until not hasnode { remove nextnode. wait 0. }

        local ut is time:seconds + eta:apoapsis.

        local r0 is body:radius + periapsis.
        local vc is sqrt(body:mu/r0).
        local vs is predict:vel(ut, ship):orbit.
        local dv is vs*(vc-vs:mag).
        local n is plan:dvt(dv, ut).

        print "Circularization at Periapsis planned.".
        print "  Burn ETA: "+dbg:pr(timespan(n:eta)).
        print "  Burn DV: "+n:deltav:mag.
        print "  Burn Vector: "+dbg:pr(n:deltav).

        return 0. }).

    local function next_time_near_altitude { parameter des_alt.
        local ddt_min is 1.
        local scorethresh is 100.
        local dt is 300.
        local dt_min is 60.
        local t_min is time:seconds + dt_min.
        local t is t_min.
        local scanner is scan:init(
            {   parameter t.
                local pos_t is positionat(ship, t) - body:position.
                local rad_t is pos_t:mag.
                local alt_t is rad_t - body:radius.
                return abs(des_alt - alt_t). },
            {   parameter t. return t + dt. },
            {   parameter t, ds.
                if ds <= scorethresh return true.
                if dt <= dt_min return true.
                set dt to max(dt_min, dt/3).
                return false. },
            t).
        until scanner:step() {}
        return choose t_min if scanner:failed else scanner:result. }

    plan:add("circ_at", {           // circularize at bound altitude
        parameter des_alt.

        until not hasnode { remove nextnode. wait 0. }

        local ut is next_time_near_altitude(des_alt).

        local r0 is body:radius.

        local ship_from_body is predict:pos(ut, ship).
        local ship_vrel_body is predict:vel(ut, ship).
        local radius_ship is ship_from_body:mag.
        local radius_other is 2*des_alt + 2*r0 - radius_ship.
        local speed_desired is visviva:v(radius_ship, radius_ship, radius_other).

        local ship_lat_dir is vxcl(ship_from_body, ship_vrel_body):normalized.
        local desired_velocity is ship_lat_dir * speed_desired.

        local dv is desired_velocity - ship_vrel_body.
        local n is plan:dvt(dv, ut).

        print "Circularization at Altitude planned.".
        print "  Original Apoapsis: "+dbg:pr(apoapsis).
        print "  Desired ALT: "+dbg:pr(des_alt).
        print "  Burn ALT: "+dbg:pr(radius_ship - r0).
        print "  Other ALT: "+dbg:pr(radius_other - r0).
        print "  Burn ETA: "+dbg:pr(timespan(n:eta)).
        print "  Burn DV: "+n:deltav:mag.
        print "  Burn Vector: "+dbg:pr(n:deltav).

        return 0. }).

    plan:add("match_incl", {

        until not hasnode { remove nextnode. wait 0. }

        local b is body.
        local os is ship:orbit.
        local ot is targ:orbit().

        local rs is -b:position.
        local vs is velocity:orbit.
        local hs is vcrs(vs,rs).            // normal to ship orbital plane

        local ro is rs+ot:position.
        local vo is ot:velocity:orbit.
        local ho is vcrs(vo,ro).            // normal to targ orbital plane

        local nv is vcrs(ho,hs).            // vector from body to ascending node

        local t1 is find_node(nv).          // scan for when we arrive at the node

        // we want to rotate our velocity vector, at t1,
        // by the rotation from hs to ho.
        local rot is rotatefromto(hs,ho).   // rotation from ship to targ plane
        local v1 is predict:vel(t1, ship).
        local v2 is rot*v1.
        local dv is v2 - v1.

        local n is plan:dvt(dv, t1).

        print "Inclination Correction Planned.".
        print "  Initial inclination error: "+vang(ho,hs).
        print "  Burn ETA: "+dbg:pr(timespan(n:eta)).
        print "  Burn DV: "+n:deltav:mag.
        print "  Burn Vector: "+dbg:pr(n:deltav).

        return 0. }).

    plan:add("xfer", lamb:plan_xfer).
    plan:add("corr", lamb:plan_corr).

}