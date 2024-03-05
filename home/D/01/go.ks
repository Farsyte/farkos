@LAZYGLOBAL off.
{   parameter go is lex().

    go:add("go", {

        // Precompute "total weight at sea level" for the thresholds below.
        // - Do not care that weight goes down as we burn fuel.
        // - Do not care that weight goes down as altitude goes up.
        // - Do not care that weight goes down when booster separates.
        // - Do not care where thrust is coming from.

        local weight is ship:mass * body:mu / body:radius^2.

        // Precompute altitude of start of grav turn.
        local Hmin is altitude + 40.

        // Configure altitude where we want to be burning horizontally.
        local Hmax is 140000.                     // altitude we would be horizontal

        {   // Start with controls locked for initial ascent
            local ascent_attitude is lookdirup(up:vector, facing:topvector).
            lock steering to ascent_attitude.
            lock throttle to 1. }

        {   // Ignite engine after a short delay.
            wait 5.
            wait until stage:ready. stage. }

        {   // Release the launch clamp when thrust exceeds weight.
            wait until ship:thrust * body:radius^2 >= ship:mass * body:mu.
            wait until stage:ready. stage. }

        {   // Ascend in launch altitude to Hmin.
            wait until altitude >= Hmin. }

        {   // Steer gradually from "up" to "east" until out of fuel.
            lock altitude_fraction to clamp(0,1,(altitude-Hmin)/(Hmax-Hmin)).
            lock pitch_wanted to 90*(1 - sqrt(altitude_fraction)).
            // limit angle of attack to ±5°.
            lock pitch_current to 90-vang(up:vector,velocity:surface).
            lock pitch_command to clamp(pitch_current-5,pitch_current+5,pitch_wanted).
            lock dir_steering to heading(90,pitch_command,0).
            lock steering to lookdirup(dir_steering:vector, facing:topvector).
            wait until ship:thrust <= 0. }

        lock descending to verticalspeed < 0.

        {   // Jettison the engine and tank when we hit 80km, or if we start descending.
            when (altitude > 80000 or descending) and stage:ready then stage. }

        {   // Open the petals when we ascend above 101 km.
            when (altitude > 101000) then lights on. }

        {   // Close the petals when we are descending below 99 km.
            when (altitude < 99000 and descending) then lights off. }

        {   // Arm the parachute when we are descending below 40 km.
            when (altitude < 40000 and descending and stage:ready) then stage.

        {   // Keep kOS running until we run out of electricity.
            wait until false. } }).
}