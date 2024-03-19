@LAZYGLOBAL off.
{   parameter go is lex().

    local Hmin is altitude.             // command 90 pitch at this altitude.
    local Hmax is 140000.               // command 0 pitch at this altitude.

    // Hmax of 140km gives us 211 km high and 645 km far.

    go:add("go", {
        {   // Start with controls locked for initial ascent
            local ascent_attitude is lookdirup(up:vector, facing:topvector).
            lock steering to ascent_attitude.
            lock throttle to 1. }

        {   // Flight engineer hits SPACE BAR to initiate launch.
            wait until ship:thrust>0. }

        {   // Release the launch clamp when thrust exceeds thrust_wanted.
            local thrust_wanted is ship:mass * body:mu / body:radius^2.
            wait until ship:thrust>thrust_wanted and stage:ready. stage. }

        {   // Ascend in launch altitude to Hmin.
            wait until altitude >= Hmin. }

        {   // Steer gradually from "up" to "east" until out of fuel.
            print "Hmax is "+round(Hmax/1000)+" km.".
            lock altitude_fraction to clamp(0,1,(altitude-Hmin)/(Hmax-Hmin)).
            lock pitch_wanted to 90*(1 - sqrt(altitude_fraction)).
            // limit angle of attack to ±5°.
            lock pitch_current to 90-vang(up:vector,velocity:surface).
            lock pitch_command to clamp(pitch_current-5,pitch_current+5,pitch_wanted).
            lock dir_steering to heading(90,pitch_command,0).
            lock steering to lookdirup(dir_steering:vector, facing:topvector).
            wait until ship:thrust <= 0. unlock throttle. unlock steering. }

        {   // report flight path pitch angle when we cross 100 km.
            wait until altitude>=100000.
            print "Passing Karman line with "
                +round(90-VANG(up:vector,velocity:orbit),1)
                +"° flight path pitch". }

        {   // report flight path pitch angle when we cross 140 km.
            wait until altitude>=140000.
            print "Entering space with "
                +round(90-VANG(up:vector,velocity:orbit),1)
                +"° flight path pitch". }

        {   // Keep kOS running until we run out of electricity.
            wait until false. } }).
}