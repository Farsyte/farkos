say("Quickly Concerned Tramp").
say("Contract Satellite Delivery").

loadfile("mission").
loadfile("phases").
loadfile("match").
loadfile("contract").


local launch_azimuth is persist_get("launch_azimuth", 90, true).
local launch_altitude is persist_get("launch_altitude", 80_000, true).

mission_bg(bg_stager@).

local countdown is 10.
mission_add(LIST(
    "AUTOLAUNCH", { // initiate unmanned flight.
        if availablethrust>0 return 0.
        lock throttle to 1.
        lock steering to facing.
        if countdown > 0 {
            say("T-"+countdown, false).
            set countdown to countdown - 1.
            return 1.
        }
        if stage:ready stage.
        return 1. },
    "LAUNCH",       phase_launch@,      // wait for the rocket to get clear of the launch site.
    "ASCENT",       phase_ascent@,      // until apoapsis is in space, steer upward and east.
    "COAST",        phase_coast@,       // until we are near our orbit, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    "MATCH_APO",    phase_match_apo@,   // orbit matching phase 1: raise apoapsis
    "COAST",        phase_coast@,       // until we are near our apoapsis, coast up pointing prograde.
    "CIRC",         phase_circ@,        // until our periapsis is in space, burn prograde.
    "MATCH_INCL",   phase_match_incl@,  // orbit matching phase 2: approach apoapsis
    // TODO match argument of periapsis
    // TODO match periapsis
    "")).

// Set up contract parameters.
// This may include adding steps to the mission plan.
set_contract().

// Add a standard satellite trailing plan,
// which is to just say "yes, I'm here."
mission_add(LIST(
    "PARK",       { // report we are parked. release controls.
        say(LIST(
            ship:name,
            "Parked at "+round(periapsis/1000)+"x"+round(apoapsis/1000),
            "Inclined "+round(obt:inclination,1)+"° at "+round(obt:lan)+"°")).
        unlock throttle. unlock steering.
        return 10. },
    "")).

mission_bg({    // remind flight engineer to use SPACE to launch.
    if mission_phase()>0 return -1.
    say("Press SPACE to launch.", false).
    return 5.}).

mission_fg().
wait until false.