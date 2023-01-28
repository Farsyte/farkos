say(LIST(
    "Configuration B, Flight 1",
    "Experimental Engineering",
    "Satellite to 14,443x13,694 km",
    "Inclined +90° at 258.7°")).

loadfile("persist").

// Establish launch path, if not already persisted.
// This happens during loadpath("contract") which
// is before the vessel class GO script will
// provide values (if unset).
persist_get("launch_azimuth", -10, true).
persist_get("launch_altitude", 80_000, true).

function set_contract {

    // Establish contract parameters, if not persisted.

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