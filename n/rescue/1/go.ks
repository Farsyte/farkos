{
    local farkos is import("farkos").
    local persist is import("persist").
    local mission is import("mission").
    local phases is import("phases").
    local mt is import("node"):mt.

    local deg_per_rad is 180/constant:pi.

    // throttle and steering commands for rendesvous.
    global rv_Ct is 0.
    global rv_Cs is facing.

    local rv_incline_deadzone is true.
    local max_inclination_error is 1/10.

    function ang { parameter x. return mod(360+mod(x,360),360). }
    function hat { parameter v. return v:normalized. }
    function vnrm { parameter a,b. return hat(vcrs(a,b)). }
    function pr { parameter name, val.
      local s is val:tostring.
      if val:istype("Vector")
        set s to val:mag+" "+s.
      print name+": "+s.
    }

    export(go@).

    function go {

        persist:put("orbit_altitude", 200000).
        persist:put("pause_silently", true).

        init_target(). // yes, do this when we load the package.

        mission:add_phases(list(
            "launch", "ascent", "coastu", "circ",
            rv_select@,
            rv_incline@,
            rv_periapsis@,
            rv_position@,
            rv_velocity@,
            rv_approach@,
            rv_rescue@,
            "deorbit", "decel", "chute", "end")).

        mission:bg("stager").

        mission:go().

        wait until false.
    }

    function rv_select {
        persist:put("rv_select_phase", mission:get_phase()).
        if is_rv_select_needed(false) return 1.
        farkos:ev("RV target: " + target).
        mission:next_phase().
        return 1.
    }

    function rv_incline {
        if is_rv_select_needed() return 1.

        local b is body.                        // pr("b",b).              // print "Orbiting: "+b.

        local p_s is -b:position.               // pr("p_s",p_s).          // position from BODY to SHIP
        local v_s is velocity:orbit.            // pr("v_s",v_s).          // velocity of SHIP relative to BODY
        local h_s is vcrs(v_s,p_s):normalized.  // pr("h_s",h_s).          // angular momentum direction of SHIP

        local t is target.                      // pr("t",t).              // print "Target: "+t:name.
        local o_t is t:obt.
        local p_t is t:position+p_s.            // pr("p_t",p_t).          // position from BODY to TARGET
        local v_t is o_t:velocity:orbit.        // pr("v_t",v_t).          // velocity of TARGET relative to BODY
        local h_t is vcrs(v_t,p_t):normalized.  // pr("h_t",h_t).          // angular momentum vector of TARGET

        if vdot(h_s,h_t) <= 0 {
            farkos:error("rv_incline: retrograde target!").
            rv_stop_maneuver().
            set target to "".
            persist:clr("rv_target").
            mission:set_phase(persist:get("rv_select_phase")).
            return 1.
        }

        local i_r is vang(h_s, h_t).                // pr("i_r",i_r).
        if -0.01 < i_r and i_r < 0.01 {
            farkos:ev("rv_incline complete").
            farkos:ev("  final i_r is "+i_r).
            rv_stop_maneuver().
            mission:next_phase().
            return 1.
        }

        // p_dist: distance to the target orbital plane
        local p_dist is vdot(h_t, p_s).             // pr("p_dist",p_dist).

        // p_rate: speed parallel to target orbital plane normal
        local p_rate is vdot(h_t, v_s).             // pr("p_rate",p_rate).

        // given distance and rate, work out an acceleration and
        // time that brings both to zero. Basically, we start with
        // the equation for X and V given T and A, then solve for
        // T and A given X and V:
        //    V = A T                   X = A T^2 / 2
        // Solve for time by eliminating A from the X equation:
        //    A = V / T                 X = (V/T) T^2 2 = V T/2
        //    T = 2 X / V
        // Compute T, then compute A as seen above.

        local b_time is 2*p_dist/p_rate.            // pr("b_time",b_time).
        local b_accel is p_rate/b_time.             // pr("b_accel",b_accel).
        local b_force is b_accel*ship:mass.         // pr("b_force",b_force).
        local b_throt is b_force/maxthrust.         // pr("b_throt",b_throt).

        local next_dt is 10.        // default to slow period
        local next_Ct is b_throt.   // default to computed throttle
        local next_Cs is h_s.       // default to upward normal

        if next_Ct < 0 {
            // negative throttle is just positive in the other direction.
            // print "rt_incline: flip signs.".
            set next_Cs to -next_Cs.
            set next_Ct to -next_Ct.
        }

        if next_Ct > 1 {
            // too much thrust, try again next time around.
            // print "rt_incline: too much, try again next time.".
            set next_Ct to 0.
            set rv_incude_deadzone to true.
        }

        if b_time > 0 {
            set next_Ct to 0.
        }

        if next_ct > 0.1 {
            set next_dt to 1/10.
            set warp to 0.
        }

        // Deadzone logic: if the deadzone flag is set, and
        // our throttle command is 0% to 60%, do not throttle
        // up yet, wait for us to need 60%. Higher thresholds
        // risk actually not seeing a value above the threshold
        // but below our throttle limit.
        //
        // Then, if we ever cut the throttle to zero, turn the
        // deadzone flag back on.

        if rv_incline_deadzone and next_Ct>0 and next_Ct<0.6 {
            // print "rt_incline: deadzone.".
            set next_Ct to 0.
        }
        if next_Ct > 0 {
            set rv_incline_deadzone to false.
        } else {
            set rv_incline_deadzone to true.
        }

        // AFTER checking deazone: if the engine is not
        // facing near enough to the right way, then just
        // avoid turning on the engine this time.
        if next_Ct>0 and vang(next_Cs,facing:vector)>30 {
            set next_Ct to 0.
        }

        // carefully copy the final values of the commands
        // to the variables to which the throttle and steering
        // are locked. This avoids bouncing the values around
        // while computing above.

        set rv_Ct to next_Ct.
        set rv_Cs to next_Cs.

        lock throttle to rv_Ct.
        lock steering to rv_Cs.

        return next_dt.

    }

    function rv_periapsis {
        if is_rv_select_needed() return 1.
        farkos:ev("STUB: rv_periapsis").
        // mission:next_phase().
        return 10.
    }
    function rv_position {
        if is_rv_select_needed() return 1.
        farkos:ev("STUB: rv_position").
        // mission:next_phase().
        return 10.
    }
    function rv_velocity {
        if is_rv_select_needed() return 1.
        farkos:ev("STUB: rv_velocity").
        // mission:next_phase().
        return 10.
    }
    function rv_approach {
        if is_rv_select_needed() return 1.
        farkos:ev("STUB: rv_approach").
        // mission:next_phase().
        return 10.
    }
    function rv_rescue {
        if is_rv_select_needed() return 1.
        farkos:ev("STUB: rv_rescue").
        // mission:next_phase().
        return 10.
    }

    // ======== ======== ======== ========  ======== ======== ======== ========
    // INCLINATION CORRECTION


    // ======== ======== ======== ========  ======== ======== ======== ========
    // TARGET SELECTION

    // Do the "rewind to select" logic:
    // if we do not have a target,
    // set the mission phase back to the rv_select.
    function is_rv_select_needed { parameter verbose is true.
        if check_target() return false.
        if verbose farkos:ev("RV: returning to select").
        rv_stop_maneuver().
        mission:set_phase(persist:get("rv_select_phase")).
        return true.
    }

    // collect the list of target vessels during boot.
    local target_vessels is list().
    list targets in target_vessels.

    function init_target {
        if hastarget {
            local t is target.
            if target_vessels:find(t) < 0 {
                print "rv: reject unrecognized target "+t.
                persist:clr("rv_target").
                set target to "".
            } else {
                print "rv: accept new target "+t.
                persist:put("rv_target",t).
            }
        } else {
            if persist:has("rv_target") {
                local t is persist:get("rv_target").
                if target_vessels:find(t) < 0 {
                    print "rv: clear stale target "+t.
                    persist:clr("rv_target").
                } else {
                    print "rv: restore persisted target "+t.
                    set target to t.
                }
            }
        }
    }

    // steady state target update
    // basically, rv_target follows target.
    function check_target {
        if not hastarget {
            persist:clr("rv_target").
            return false.
        }
        local t is target.
        if target_vessels:find(t) < 0 {
            print "rv: reject target "+t.
            persist:clr("rv_target").
            set target to "".
            return false.
        }
        persist:put("rv_target", t).
        return true.
    }

    function rv_stop_maneuver {
        set rv_incline_burning to false.
        set rv_Cs to facing.
        set rv_Ct to 0.
        lock steering to rv_Cs.
        lock throttle to rv_Ct.
    }

    // ======== ======== ======== ========  ======== ======== ======== ========
}
