{   parameter plan is lex().        // generate maneuver nodes.

    local io is import("io").
    local dbg is import("dbg").
    local mnv is import("mnv").
    local lamb is import("lamb").
    local targ is import("targ").
    local scan is import("scan").
    local predict is import("predict").
    local visviva is import("visviva").

    plan:add("go", mnv:step).

    plan:add("dvt", {               // create maneuver for dv at time t
        parameter dv.               // Body-rel change in velocity
        parameter t.                // universal

        // the vector DV is in body-raw coordinates.
        // need to find its representation in the coordinate
        // system "radial out, normal, prograde" at the time
        // of the burn, where "prograde" is the direction of
        // our velocity, "normal" is parallel to our angular
        // momentum, and "radial out" is the vector perpendicular
        // to them that is rougly "outward" from the body.

        local ship_from_body is predict:pos(t, ship).
        local ship_vrel_body is predict:vel(t, ship).

        local normal_dir is vcrs(ship_vrel_body, ship_from_body):normalized.
        local prograde_dir is ship_vrel_body:normalized.

        local dir is lookdirup(prograde_dir, normal_dir).
        local rnp is dir:inverse*dv.

        local n is node(t, rnp:x, rnp:y, rnp:z).
        add n. wait 0.
        return n. }).

    plan:add("circ_ap", {           // circularize at apoapsis

        // could be implemented via adj_at
        //     plan:adj_at(apoapsis, apoapsis, apoapsis)
        // but that would do a lot of extra work.

        until not hasnode { remove nextnode. wait 0. }

        local ut is time:seconds + eta:apoapsis.

        local r0 is body:radius + apoapsis.
        local vc is sqrt(body:mu/r0).
        local vs is predict:vel(ut, ship).
        local dv is vs:normalized*(vc-vs:mag).
        local n is plan:dvt(dv, ut).

        // print "Circularization at Apoapsis planned.".
        // dbg:pv("  Burn ETA: ", timespan(n:eta)).
        // dbg:pv("  Burn DV: ", n:deltav:mag).
        // dbg:pv("  Burn Vector: ", n:deltav).

        return 0. }).

    plan:add("circ_pe", {           // circularize at periapsis

        // could be implemented via adj_at
        //     plan:adj_at(periapsis, periapsis, periapsis)
        // but that would do a lot of extra work.

        until not hasnode { remove nextnode. wait 0. }

        local ut is time:seconds + eta:periapsis.

        local r0 is body:radius + periapsis.
        local vc is sqrt(body:mu/r0).
        local vs is predict:vel(ut, ship).
        local dv is vs:normalized*(vc-vs:mag).

        local n is plan:dvt(dv, ut).

        // print "Circularization at Periapsis planned.".
        // dbg:pv("  Burn ETA: ", timespan(n:eta)).
        // dbg:pv("  Burn DV: ", n:deltav:mag).
        // dbg:pv("  Burn Vector: ", n:deltav).

        return 0. }).

    local function next_time_near_altitude { parameter des_alt.

        if (des_alt >= apoapsis) return time:seconds + eta:apoapsis.
        if (des_alt <= periapsis) return time:seconds + eta:periapsis.

        local ddt_min is 1.
        local scorethresh is 100.
        local dt is 300.
        local dt_min is 60.
        local t_min is time:seconds + dt_min.
        local t is t_min.
        local scanner is scan:init(
            {   parameter t.
                local pos_t is predict:pos(t, ship).
                local rad_t is pos_t:mag.
                local alt_t is rad_t - body:radius.
                return -abs(des_alt - alt_t). },
            {   parameter t. return t + dt. },
            {   parameter t, ds.
                if ds <= scorethresh return true.
                if dt <= dt_min return true.
                set dt to max(dt_min, dt/3).
                return false. },
            t).
        until scanner:step() {}
        return choose t_min if scanner:failed else scanner:result. }

    plan:add("adj_at_md", {    // when we are near altitude h1, adjust to h1-by-h2 orbit.
        parameter h1, h2.

        until not hasnode { remove nextnode. wait 0. }

        local hc is (periapsis + apoapsis) / 2.

        local ut is next_time_near_altitude(hc).
        return plan:adj_at_ut(ut, h1, h2). }).

    plan:add("adj_at", {    // when we are near altitude h1, adjust to h1-by-h2 orbit.
        parameter h1, h2, h3.

        until not hasnode { remove nextnode. wait 0. }

        local ut is next_time_near_altitude(h1).
        return plan:adj_at_ut(ut, h2, h3). }).

    plan:add("adj_at_pe", {    // when we are near altitude h1, adjust to h1-by-h2 orbit.
        parameter h.

        until not hasnode { remove nextnode. wait 0. }

        local ut is time:seconds + eta:periapsis.
        return plan:adj_at_ut(ut, periapsis, h). }).

    plan:add("adj_at_ap", {    // when we are near altitude h1, adjust to h1-by-h2 orbit.
        parameter h.

        until not hasnode { remove nextnode. wait 0. }

        local ut is time:seconds + eta:apoapsis.
        return plan:adj_at_ut(ut, h, apoapsis). }).

    plan:add("adj_at_ut", {    // at time ut, adjust to h1-by-h1 orbit.
        parameter ut, h1, h2.

        until not hasnode { remove nextnode. wait 0. }

        local r0 is body:radius.
        local des_rad_pe is r0 + min(h1, h2).
        local des_rad_ap is r0 + max(h1, h2).

        local r0 is body:radius.

        local ship_from_body is predict:pos(ut, ship).
        local ship_vrel_body is predict:vel(ut, ship).
        local burn_ship_radius is ship_from_body:mag.

        local ship_lat_dir is vxcl(ship_from_body, ship_vrel_body):normalized.
        local desired_velocity is V(0,0,0).

        if ((des_rad_pe < burn_ship_radius) and (burn_ship_radius < des_rad_ap)) {
            // desired velocity has a nonzero radial component
            // in the same direction as ship vertical speed.

            local des_speed_prograde is visviva:v(burn_ship_radius, des_rad_pe, des_rad_ap).
            local des_speed_pe is visviva:v(des_rad_pe, des_rad_pe, des_rad_ap).
            local des_lateral_speed is des_speed_pe * des_rad_pe / burn_ship_radius.
            local des_radial_speed is safe_sqrt(des_speed_prograde^2 - des_lateral_speed^2).
            if (ship_from_body * ship_vrel_body < 0)
                set des_radial_speed to -des_radial_speed.

            set desired_velocity to ship_lat_dir * des_lateral_speed
                + ship_from_body:normalized * des_radial_speed.

        } else {
            // desired velocity is purely horizontal.
            local ship_far_radius is des_rad_pe + des_rad_ap - burn_ship_radius.
            local speed_desired is visviva:v(burn_ship_radius, burn_ship_radius, ship_far_radius).
            set desired_velocity to ship_lat_dir * speed_desired.
        }

        local dv is desired_velocity - ship_vrel_body.
        local n is plan:dvt(dv, ut).

        // print "Orbital Adjustment at Altitude planned.".
        // dbg:pv("  Burn ETA: ", TimeSpan(n:eta)).
        // dbg:pv("  Burn DV: ", n:deltav:mag).
        // dbg:pv("  Burn Vector: ", n:deltav).

        return 0. }).

    plan:add("circ_at", {           // circularize at specified altitude
        parameter des_alt.

        return plan:adj_at(des_alt, des_alt, des_alt). }).

    plan:add("match_incl", {

        until not hasnode { remove nextnode. wait 0. }

        local b is body.
        local os is ship:orbit.
        local ot is targ:orbit().

        local rs is -b:position.
        local vs is velocity:orbit.
        local hs is vcrs(vs,rs).            // normal to ship orbital plane

        local ro is ot:position+rs.
        local vo is ot:velocity:orbit.
        local ho is vcrs(vo,ro).            // normal to targ orbital plane

        local ea is vang(ho,hs).            // inclination error angle
        if (ea < 0.5) return 0.

        local nv is vcrs(ho,hs).            // vector from body to ascending node

        local t1 is find_node(nv).          // scan for when we arrive at the node

        // we want to rotate our velocity vector, at t1,
        // by the rotation from hs to ho.
        local rot is rotatefromto(hs,ho).   // rotation from ship to targ plane
        local v1 is predict:vel(t1, ship).
        local v2 is rot*v1.
        local dv is v2 - v1.

        local n is plan:dvt(dv, t1).

        // print "Inclination Correction Planned.".
        // print "  Initial inclination error: "+ea.
        // dbg:pv("  Burn ETA: ", timespan(n:eta)).
        // dbg:pv("  Burn DV: ", n:deltav:mag).
        // dbg:pv("  Burn Vector: ", n:deltav).

        return 0. }).


    // find the time (at least 2 minutes in the future)
    // where our position is along the NV vector.
    local function find_node { parameter nv.
        local t1 is time:seconds + 120.
        local dt is 64.
        local function fitness { parameter t1.
            local rt is predict:pos(t1, ship).
            local n2 is vxcl(nv, rt).
            return -n2:mag. }
        local function fitincr { parameter t1. return t1 + dt. }
        local function fitfine { parameter t1, ds.
            if ds<100 return true.
            if dt<0.1 return true.
            set dt to dt/4. return false. }
        local scanner is scan:init( fitness@, fitincr@, fitfine@, t1).
        until scanner:step() {}
        if scanner:failed {
            until (false) {
                print "plan find_node scanner failed.".
                wait 5. }}
        return scanner:result. }

    local approach_ap_drawvec_list is list().
    local approach_ap_debug_flag is false.

    plan:add("approach_ap", { parameter aop, ap.

        until not hasnode { remove nextnode. wait 0. }

        // the earliest we want to do this is in two minutes.
        local t1 is time:seconds() + 120.

        if aop:istype("Scalar") {
            // hmmf. need eta of ascending node.

            // ASSUMPTION: we are in a (very nearly) circular orbit.

            local rvec is -body:position.               // ship (from body)
            local vvec is ship:velocity:orbit.          // ship (vrel body)
            local hvec is vcrs(vvec, rvec).             // ship ang mom vec
            local pole is V(0,1,0).                     // body north pole
            local nvec is vcrs(hvec,pole).              // ascending node vector

            local nang is vang(rvec, nvec).

            // if we are moving forward from the ascending node
            // in a circular orbit, then the dot product of our
            // velocity with the nodal vector is negative. Correct
            // the angle to be 360 degrees minus the angle computed
            // above which is the "wrong way" around the orbit.
            //
            // this can misbehave wildly if our orbit is eccentric.

            if vvec*nvec < 0
                set nang to 360 - nang.

            // nang is the angle forward in our orbit from our
            // current position to the ascending node.

            set pang to nang + aop.

            // pang is the angle forward in our orbit to the
            // periapsis.

            local eta_pe is pang * orbit:period / 360.0.
            local ut_pe is time:seconds() + eta_pe.

            if (ut_pe < t1)
                set ut_pe to ut_pe + orbit:period.

            until (ut_pe - t1 < orbit:period)
                set ut_pe to ut_pe - orbit:period.

            set t1 to ut_pe.

            if (approach_ap_debug_flag) {
                local pos_at_burn is predict:pos(t1, ship).
                local vel_before_burn is predict:vel(t1, ship).

                local r0 is rvec:mag.
                local vlen is r0 * 3.

                print "-- compute eta of ascending node.".
                dbg:pv("aop", aop).
                dbg:pv("ap", ap).
                dbg:pv("nvec*vvec", nvec*vvec).
                dbg:pv("nang", nang).
                dbg:pv("pang", pang).
                dbg:pv("eta_pe", TimeSpan(eta_pe)).
                dbg:pv("period", TimeSpan(orbit:period)).
                dbg:pv("eta_t1", TimeSpan(t1 - time:seconds())).

                clearvecdraws().
                approach_ap_drawvec_list:clear().
                approach_ap_drawvec_list:add(vecdraw(
                    -rvec, 3*rvec, RGB(1,1,1), "Ship Position", 1.0, true, 0.1, true, true)).
                approach_ap_drawvec_list:add(vecdraw(
                    V(0,0,0), vlen*velocity:orbit:normalized, RGB(1,1,1), "Ship Velocity", 1.0, true, 0.1, true, true)).
                approach_ap_drawvec_list:add(vecdraw(
                    -rvec, vlen*hvec:normalized, RGB(1,1,1), "Ship Orbital Plane normal", 1.0, true, 0.1, true, true)).
                approach_ap_drawvec_list:add(vecdraw(
                    -rvec, vlen*pole:normalized, RGB(1,1,1), "Body North", 1.0, true, 0.1, true, true)).
                approach_ap_drawvec_list:add(vecdraw(
                    -rvec, vlen*nvec:normalized, RGB(1,1,1), "Ship Ascending Node", 1.0, true, 0.1, true, true)).
                approach_ap_drawvec_list:add(vecdraw(
                    -rvec, 3*pos_at_burn, RGB(1,1,1), "BURN HERE", 1.0, true, 0.1, true, true)).
                approach_ap_drawvec_list:add(vecdraw(
                    pos_at_burn-rvec, vlen*vel_before_burn:normalized, RGB(1,1,1), "BURN DIR", 1.0, true, 0.1, true, true)).
            }
        }

        local pos_at_burn is predict:pos(t1, ship).
        local vel_before_burn is predict:vel(t1, ship).

        local rad_at_burn is pos_at_burn:mag.
        local spd_after_burn is visviva:v(rad_at_burn, rad_at_burn, body:radius + ap).
        local vel_after_burn is vel_before_burn:normalized * spd_after_burn.
        local burn_dv is vel_after_burn - vel_before_burn.

        local n is plan:dvt(burn_dv, t1).

        // print "Approaching AP at AoP Planned.".
        // dbg:pv("  Burn ETA", timespan(n:eta)).
        // dbg:pv("  Burn DV", n:deltav:mag).
        // dbg:pv("  Burn Vector", n:deltav).

        return 0. }).

    // lamb and plan depend on each other, so if we
    // imported plan first, lamb will not yet have
    // its suffixes set when we run. The first time
    // plan:xfer or plan:corr is called, update the
    // plan map to drop the indirection.
    plan:add("xfer", {
        set plan["xfer"] to lamb:plan_xfer.
        return lamb:plan_xfer(). }).

    plan:add("corr", {
        set plan["corr"] to lamb:plan_corr.
        return lamb:plan_corr(). }).

}