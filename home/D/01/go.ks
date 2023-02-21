{   parameter go. // GO script for "O/02".

    clearguis().

    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").
    local task is import("task").
    local targ is import("targ").
    local match is import("match").
    local mnv is import("mnv").
    local hill is import("hill").

    local orbit_altitude is nv:get("launch_altitude", 320000, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, false).

    local has_node is { return HASNODE. }.
    local has_targ is { return HASTARGET. }.

    task:new("Circularize Here", always, nothing, phase:circ,nothing).
    task:new("Execute Node", has_node, nothing, mnv:step, nothing).
    task:new("Match Inclination", has_targ, targ:save, match:plane, nothing).
    task:new("Plan Intercept", has_targ, targ:save, match:plan_xfer, nothing).
    task:new("Plan Correction", has_targ, targ:save, match:plan_corr, nothing).

    set task:idle:step to phase:pose.

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
        //
        "READY", task:step)).

    go:add("go", {
        task:show().
        mission:bg(phase:autostager).
        mission:bg(phase:autorcs).
        mission:fg(). }). }