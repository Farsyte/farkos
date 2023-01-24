say("PROJECT: Longingly Awful Trip").

loadfile("mission").
loadfile("phases").

lock steering to facing.

mission_bg(bg_stager@).

mission_add(LIST(
    {       // wait for flight engineer to initiate flight with SPACE.
        if availablethrust>0 return 0.
        lock steering to facing.
        lock throttle to 1.
        return 1/10. },
    {       // wait for the rocket to get clear of the launch site.
        if alt:radar>50 return 0.
        lock steering to facing.
        return 1/10. },
    {       // until we lose thrust, steer upward and toward water
        if availablethrust<=0 return 0.
        lock steering to heading(90, 45).
        return 1. },
    {       // until we start descending, steer into the wind.
        if verticalspeed<=0 return 0.
        lock steering to srfprograde.
        return 1. },
    {       // until we are safe to deploy the chute, put our back to the wind.
        if alt:radar<3000 and airspeed<300 return 0.
        lock steering to srfretrograde.
        return 1. },
    {       // until we have only stage zero remaining, stage (deploy parachutes).
        if stage:number<1 return 0.
        if stage:ready stage.
        return 1. },
    {       // until we stop descending, keep the nose pointed directly up.
        if verticalspeed >= 0 return 0.
        lock steering to up.
        return 1. },
    {       // until the cows come home, keep the capsule upright.
        return 10. })).

mission_bg({
    if mission_phase()>0 return -1.
    say("Press SPACE to launch.", false).
    return 5.
}).

mission_fg().
wait until false.