@LAZYGLOBAL off.
{   parameter go. // GO script for "T/03".
    local io is import("io").
    local nv is import("nv").
    local mission is import("mission").
    local phase is import("phase").

    local orbit_altitude is nv:get("launch_altitude", 80000, true).
    local launch_azimuth is nv:get("launch_azimuth", 90, true).
    local launch_pitchover is nv:get("launch_pitchover", 3, false).

    function phase_atmwarp {
        if not kuniverse:timewarp:issettled return.
        if body:atm:height<10000 return 0.
        if altitude>body:atm:height return 1.

        if kuniverse:timewarp:rate>1 {
            kuniverse:timewarp:cancelwarp().
            return 1. }

        if kuniverse:timewarp:mode = "RAILS" {
            set kuniverse:timewarp:mode to "PHYSICS".
            return 1. }

        set warp to 4.
        return 0.
    }

    mission:do(list(
      "COUNTDOWN", phase:countdown,
      "LAUNCH", phase:launch,
      "ASCENT", phase:ascent,
      "COAST", phase:coast,
      "CIRC", phase:circ,
      "POSE", phase:pose,
      { return -30. },
      "DEORBIT", phase:deorbit,
      phase_atmwarp@,
      "FALL", phase:fall,
      "DECEL", phase:decel,
      "LIGHTEN", phase:lighten,
      "PSAFE", phase:psafe,
      "CHUTE", phase:chute,
      { set warp to 0. return 0. },
      "LAND", phase:land,
      "PARK", phase:park)).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:fg(). }). }