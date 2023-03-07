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
    task:new("Old Match Plan Xfer", has_targ, targ:save, match:plan_xfer, nothing).
    task:new("Old Match Plan Corr", has_targ, targ:save, match:plan_corr, nothing).
    task:new("Lamb Intercept", has_targ, targ:save, lamb:plan_xfer, nothing).
    task:new("Lamb Correction", has_targ, targ:save, lamb:plan_corr, nothing).
    task:new("RDV Node", has_targ, targ:save, rdv:node, nothing).
    task:new("RDV Coarse", has_targ, targ:save, rdv:coarse, nothing).
    task:new("RDV Fine", has_targ, targ:save, rdv:fine, nothing).
    task:new("RDV Near", has_targ, targ:save, rdv:near, nothing).
    task:new("RCS Velocity Match", has_targ, targ:save, rcs_vel_match@, ctrl:rcs_off).
    task:new("RCS Position Match", has_targ, targ:save, rcs_pos_match@, ctrl:rcs_off).

    set task:idle:step to phase:pose.

    local function rcs_vel_match {
        if not hastarget return 0.

        io:say("RCS Velocity Match", false).

        ctrl:rcs_dv({ return target:velocity:orbit - ship:velocity:orbit. }).
        return 5. }

    local function rcs_pos_match {
        if not hastarget return 0.

        local parking_offset is 10.

        io:say("RCS Position Match", false).
        io:say("  Standoff Distance: "+parking_offset+" m.", false).

        ctrl:rcs_dx({ return target:position
            - target:position:normalized
                * parking_offset. }).

        return 5. }

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