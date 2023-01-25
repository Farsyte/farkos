say("Perfectly Periodic Existence").
say("Orbital Tourism").

loadfile("mission").
loadfile("phases").

local launch_azimuth is persist_get("launch_azimuth", 90, true).
local launch_altitude is persist_get("launch_altitude", 80_000, true).

mission_bg(bg_stager@).

local countdown is 10.
mission_add(LIST(
    "TOURIST",      {                   // initiate tourist flight.
        if availablethrust>0 return 0.
        if countdown > 0 {
            say("T-"+countdown, false).
            set countdown to countdown - 1.
            return 1.
        }
        if stage:ready stage.
        return 1. },
    "PREFLIGHT",    phase_preflight@,   // wait for flight engineer to initiate flight with SPACE.
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_launch@,      // until we are above atmosphere, coast up pointing into the wind.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing orbital-prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    "PAUSE",        {                   // SPACE WELCOMES TOURISTS. Brifely.
        say("Welcome to Orbit.").
        say("Now go home.").
        return 30. },
    "DEORBIT",      phase_deorbit@,     // until our periapsis is low enough, burn retrograde.
    "FALL",         phase_fall@,        // fall to half of the atmosphere height.
    "DECEL",        phase_decel@,       // decelerate to 1/4th of atmosphere height.
    "PSAFE",        phase_psafe@,       // fall until safe for parachutes
    "CHUTE",        phase_chute@,       // fall until safe for parachutes
    "GEAR",         phase_gear@,        // extend landing gear.
    "LAND",         phase_land@,        // until we stop descending, keep the nose pointed directly up.
    "PARK",         phase_park@,        // until the cows come home, keep the capsule upright.
    "")).

mission_fg().
wait until false.