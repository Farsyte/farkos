say(LIST(
    "Configuration A, Flight 1",
    "Experimental Engineering",
    "Satellite to 4557x4333 km",
    "Inclined +1.3° at 269°")).

loadfile("persist").

function set_contract {
    persist_get("match_peri", 4332992, true).
    persist_get("match_apo", 4557075, true).
    persist_get("match_inc", 1.3, true).
    persist_get("match_lan", 269, true).
}
