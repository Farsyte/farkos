{   parameter go. // default GO script for "X" series vessels.
    local io is import("io").
    local mission is import("mission").
    local phase is import("phase").

    mission:do(list(
      "COUNTDOWN", phase:countdown,
      "LAUNCH", phase:launch,
      "PITCHOVER", { lock steering to heading(90, 45, 0). return 0. },
      "ASCENT", { return choose 1 if availablethrust>0 else 0. },
      "COAST", { unlock steering. return 0. },
      "PSAFE", phase:psafe,
      "CHUTE", phase:chute,
      "LAND", phase:land,
      "PARK", phase:park)).

    go:add("go", {
        mission:bg(phase:autostager).
        mission:fg().
    }).
}