@LAZYGLOBAL off.
{   parameter go is lex().

    local solid_fuel_name is "NGNC".
    local solid_fuel_min_pct is 12.

    function find_resource { parameter n. // find resource with the given name.
        for r in ship:resources if r:name = n return r. }

    go:add("go", {
        {   // Start with controls locked for initial ascent
            local ascent_attitude is lookdirup(up:vector, facing:topvector).
            lock steering to ascent_attitude.
            lock throttle to 1. }

        // Flight engineer hits SPACE BAR to initiate launch.
        {   // Ignite main engine when booster has low fuel remaining.
            local solid_fuel_res is find_resource(solid_fuel_name).
            local solid_fuel_low is solid_fuel_res:capacity * solid_fuel_min_pct / 100.
            wait until solid_fuel_res:amount < solid_fuel_low and stage:ready. stage. }

        {   // Keep running until interrupted or out of power
            wait until false. }

        }).
}