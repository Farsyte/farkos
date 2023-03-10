@LAZYGLOBAL off.
{   parameter go. // GO script for "T/01".
    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").

    local orbit_altitude is nv:get("launch_altitude", 80000, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 2, false).

    mission:do(list(
      "COUNTDOWN", phase:countdown,
      "LAUNCH", phase:launch,
      "POGO", {
        if availablethrust=0 return 0.
        if apoapsis>75000 return 0.
        lock steering to lookdirup(up:vector,facing:topvector).
        lock throttle to 1.
        return 1. },
      "COAST", phase:coast,
      "FALL", phase:fall,
      "DECEL", phase:decel,
      "LIGHTEN", phase:lighten,
      "PSAFE", phase:psafe,
      "CHUTE", phase:chute,
      "LAND", phase:land,
      "PARK", phase:park)).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:fg(). }). }