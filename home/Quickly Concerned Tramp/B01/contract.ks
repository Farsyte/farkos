say(LIST(
    "Configuration B, Flight 1",
    "Experimental Engineering",
    "Satellite to 14,443x13,694 km",
    "Inclined +90° at 258.7°")).

    // Wow. This is higher than The Mun.
    // Antenna, can generate Power,
    // has Mystery Goo Unit

loadfile("persist").

// It will be important to carefully pick our launch window
// to minimize the plane change.
//
// Launch at Y001 D05 04:00 gives a -8.54° relative inclination.

local launch_azimuth is persist_get("launch_azimuth", 0, true).
local launch_altitude is persist_get("launch_altitude", 80_000, true).

function set_contract {
    persist_get("match_peri", 13694409, true).
    persist_get("match_apo", 14443787, true).
    persist_get("match_inc", 90.0, true).
    persist_get("match_lan", 258.7, true).

    mission_add(LIST(
        "ACTIVATE", { // reconfigure for operations
            LIGHTS ON. return 0. },
        "STATION", { // maintain configuration.
            say_banner().
            local _steering is {
                local r is -body:position.
                local v is velocity:orbit.
                local h is vcrs(v,r).
                return lookdirup(-h,v). }.
            lock steering to _steering().
            lock throttle to 0.
            return 10.  // refresh banner on hud every 10 seconds.
        }
    )).
}
