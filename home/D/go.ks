@LAZYGLOBAL off.
{   parameter go. // GO script for "D" stacks.

    clearguis().

    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local lamb is import("lamb").
    local task is import("task").
    local targ is import("targ").
    local match is import("match").
    local mnv is import("mnv").
    local hill is import("hill").
    local rdv is import("rdv").
    local dbg is import("dbg").
    local ctrl is import("ctrl").

    local orbit_altitude is nv:get("launch_altitude", 320000, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, false).

    local has_node is { return HASNODE. }.
    local has_targ is { return HASTARGET. }.

    local act_num is 0.

    task:new("Circularize Here", always, nothing, phase:circ,nothing).
    task:new("Execute Node", has_node, nothing, mnv:step, nothing).
    task:new("Match Inclination", has_targ, targ:save, match:plane, nothing).
    // task:new("Plan Intercept", has_targ, targ:save, match:plan_xfer, nothing).
    // task:new("Plan Correction", has_targ, targ:save, match:plan_corr, nothing).
    task:new("Lamb Intercept", has_targ, targ:save, lamb:plan_xfer, nothing).
    task:new("Lamb Correction", has_targ, targ:save, lamb:plan_corr, nothing).
    task:new("Rescue Node", has_targ, targ:save, rdv:node, nothing).
    // task:new("Rescue Coarse", has_targ, targ:save, rdv:coarse, nothing).
    task:new("Rescue Fine", has_targ, targ:save, rdv:fine, nothing).

    set task:idle:step to phase:pose.

    local rcs_force_per_unit_translation is 0.

    local function rcs_experiment {

        if not hastarget return 0.

        local parking_offset is 5.

        print "stabilizing and releasing cooked control ...".
        ctrl:dv(V(0,0,0),1,1,5).
        wait until vang(steering:vector, facing:vector)<1
            and ship:angularvel:mag<0.01.
        unlock throttle.

        lock steering to facing.    // use cooked steering to keep us pointed.

        print "activating RCS raw control.".

        set ship:control:neutralize to true.
        set phase:force_rcs_on to phase:force_rcs_on + 1.
        wait 1.

        if rcs_force_per_unit_translation = 0 {
            local rcs_list is list().
            local it is 0.
            list rcs in rcs_list. for it in rcs_list
                set rcs_force_per_unit_translation to rcs_force_per_unit_translation + it:availablethrust.
            // derate to 50%
            set rcs_force_per_unit_translation to rcs_force_per_unit_translation / 2.
            print "rcs_force_per_unit_translation = "+rcs_force_per_unit_translation.
            if rcs_force_per_unit_translation < 1/1000 return 0. }

        print "parking is "+parking_offset+" m body-ward target.".

        local velocity_tofix_fn is {
            local park_from_ship is target:position
                + (body:position - target:position):normalized
                    * parking_offset.

            local velocity_tofix_linear is park_from_ship. // * gain?

            local cmd_X is park_from_ship:mag.
            local cmd_A is rcs_force_per_unit_translation / ship:mass.
            local cmd_V is sqrt(2*cmd_A*cmd_X).
            // cut approach speed to 50% to make it easier to control.
            // higher approach rates result in "ringing" when we arrive.
            local velocity_tofix_stopping is cmd_V * 0.5 * park_from_ship:normalized.

            return
                choose velocity_tofix_linear
                if velocity_tofix_linear:mag < velocity_tofix_stopping:mag
                else velocity_tofix_stopping. }.

        until false { // time:seconds>(t0+90) {
            local targ_vrel_ship is target:velocity:orbit - ship:velocity:orbit.  // target velocity relative to ship

            local velocity_tofix is velocity_tofix_fn().
            local velocity_error is velocity_tofix + targ_vrel_ship.
            local translation_tofix_raw is velocity_error. // * gain?
            local trmag is translation_tofix_raw:mag.

            if trmag<0.01 {
                set ship:control:neutralize to true. }
            else if trmag<1/20 {
                // do the coordinate frame change each time,
                // because facing may be changing.
                set ship:control:translation to facing:inverse*translation_tofix_raw:normalized/20.}
            else {
                // do the coordinate frame change each time,
                // because facing may be changing.
                set ship:control:translation to facing:inverse*translation_tofix_raw. } }


        print "going idle.".
        set ship:control:neutralize to true.
        set phase:force_rcs_on to phase:force_rcs_on - 1.
        return 0. }

    local function rcs_experiment_abort {
        print "end rcs experiment task.".
        set ship:control:neutralize to true.
        set phase:force_rcs_off to 0.
        set phase:force_rcs_on to 0.
        rcs off. sas off.
        ctrl:dv(V(0,0,0),1,5,5). }

    task:new("RCS experiment", has_targ, targ:save, rcs_experiment@, rcs_experiment_abort@).

    function process_actions {
          // ABORT returns us from orbit, whatever we are doing.
        if ABORT {
            say("Workhorse: aborting mission.").
            // cancel curent actions.
            say("STOP "+action_name(act_num)). action_stop(act_num).
            set act_num to 0.
            rcs on. sas off.
            lock throttle to 0.
            lock steering to facing.
            return 0. }

        if action_cond(act_num) {
            local dv is action_step(act_num).
            if dv>0 return dv. }

        say("STOP "+action_name(act_num)).
        action_stop(act_num).
        set act_num to 0.
        action_start(act_num).
        return 1. }

    mission:do(list(
        "PADHOLD", targ:wait, match:asc,
        "COUNTDOWN", phase:countdown,
        "LAUNCH", phase:launch,
        "ASCENT", phase:ascent,
        "COAST", phase:coast,
        "CIRC", phase:circ,
        "POSE", phase:pose,
        //
        // In READY orbit. Set up for semi-automatic commanding.
        // When ABORT is acdtivated, head home.
        //
        "READY", { if abort return 0. return task:step(). },

        "ABORT", { print "bringing the development lab home.".
            lights on. brakes on. abort off.
            ctrl:dv(V(0,0,0), 0, 0, 0). return -30. },

        "DEORBIT", phase:deorbit,
        "AERO", phase:aero,
        "FALL", phase:fall,
        // "DECEL", phase:decel,
        "LIGHTEN", phase:lighten,
        "PSAFE", phase:psafe,
        "CHUTE", phase:chute,
        "LAND", phase:land,
        "PARK", phase:park)).

    go:add("go", {
        task:show().
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }