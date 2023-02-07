// Mission Target Selection

function mission_drop_invalid_target { // if persisted mission_target gone, clear it.
    if persist_has("mission_target") {
        local tn is list().
        list targets in tl. for t in tl tn:add(t:name).
        list bodies in bl. for b in bl tn:add(b:name).
        if not tn:contains(persist_get("mission_target"))
            persist_clr("mission_target"). } }

function mission_new_target { // prompt flight engineer to target something.
    set target to "". wait 0.
    until hastarget {
        set remind to time:seconds + 5.
        say("Select Target", false).
        wait until time:seconds>remind or hastarget. } }

function mission_export_target { // global and persist mission and match values for TARGET
    global mission_target is target.
    global mission_orbit is mission_target:orbit.
    global mission_alt is (mission_orbit:periapsis + mission_orbit:apoapsis) / 2.

    persist_put("mission_target", target:name).

    persist_put("match_peri", mission_orbit:periapsis).         // periapsis altitude
    persist_put("match_apo", mission_orbit:apoapsis).           // apoapsis altitude
    persist_put("match_inc", mission_orbit:inclination).        // inclination
    persist_put("match_lan", mission_orbit:lan). }              // longitude of ascending node

function mission_pick_target {
    mission_drop_invalid_target().
    if persist_has("mission_target")
        set target to persist_get("mission_target").
    else
        mission_new_target().
    mission_export_target(). }

// mission_pick_target().
