@LAZYGLOBAL off.
{   parameter go is lex().

    go:add("go", {

        // Precompute "total weight at sea level" for the thresholds below.
        // - Do not care that weight goes down as we burn fuel.
        // - Do not care that weight goes down as altitude goes up.
        // - Do not care that weight goes down when booster separates.
        // - Do not care where thrust is coming from.

        local weight is ship:mass * body:mu / body:radius^2.

        {   // Ignite booster after a short delay.
            wait 5.
            wait until stage:ready. stage. }

        {   // Release clamp when thrust is enough to lift off.
            // - holds here if booster does not ignite.
            // - holds here if booster does not produce enough thrust.
            wait until ship:thrust > weight.
            wait until stage:ready. stage. }

        {   // Ignite main engine when thrust falls below 50% of weight.
            wait until ship:thrust < 0.50 * weight.
            wait until stage:ready. stage. }

        {   // Jettison booster when total thrust is again above weight.
            wait until ship:thrust > weight.
            wait until stage:ready. stage. }

        {   // Keep running until interrupted or out of power
            wait until false. }
        }).
}