{   parameter go. // GO script for "O/01".
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
      "ASCENT", phase:ascent,
      "COAST", phase:coast,
      "CIRC", phase:circ,
      "POSE", phase:pose,
      { return -30. },
      "DEORBIT", phase:deorbit,
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