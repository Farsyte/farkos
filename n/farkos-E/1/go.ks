{
    local farkos is import("farkos").
    local persist is import("persist").
    local mission is import("mission").
    local phases is import("phases").

    export(go@).

    function go {

        mission:add_phases(list(
            "launch", "ascent", "coastu", "circ",
            "pause", "deorbit", "decel", "chute",
            "end")).

        mission:bg("stager").

        mission:go().

        wait until false.
    }
}
