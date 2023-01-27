say("Quickly Concerned Tramp/A01").
say("Contract Satellite Delivery").

loadfile("mission").
loadfile("phases").
loadfile("match").

local launch_azimuth is persist_get("launch_azimuth", 90, true).
local launch_altitude is persist_get("launch_altitude", 80_000, true).

// displayed numbers on contract sheet:
// | Periapsis                   | 4332992 | m |
// | Apoapsis                    | 4557075 | m |
// | Inclination                 |     1.3 | ° |
// | Longitude of Ascending Node |     269 | ° |

// Contract sheet does NOT specify AOP.
// HYPOTHESIS: contract may be satisfied if the
// above values are matched.

persist_get("match_peri", 4332992, true).
persist_get("match_apo", 4557075, true).
persist_get("match_inc", 1.3, true).
persist_get("match_lan", 269, true).

// exact numbers from the save file:
// | lan                 |  268.97516678505372 |
// | inclination         |  1.3391382173595772 |
// | argumentOfPeriapsis |  130.42710157596741 |
// | sma                 |  5044998.4300980354 |
// | eccentricity        | 0.02221545390963647 |

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
    // TODO match periapsis of more eccentric orbits
    // TODO may need to match argument of periapsis
    "PARK",       { // no further operations are needed.
        say(ship:name).
        say("on station "+round(periapsis/1000)+"x"+round(apoapsis/1000)).
        return 5. },
    "")).

mission_bg({    // remind flight engineer to use SPACE to launch.
    if mission_phase()>0 return -1.
    say("Press SPACE to launch.", false).
    return 5.}).

mission_fg().
wait until false.